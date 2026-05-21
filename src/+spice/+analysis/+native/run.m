function result = run(circuit, ir, options)
% RUN Execute native DC, AC, transient, shooting, and PZ analyses.
% The native backend reuses one operating-point solver plus one device
% linearization interface so nonlinear DC, AC, transient, shooting, and
% descriptor-form pole-zero analysis all stay on the same device state.
analysisType = string(circuit.Analysis.Type);
nativeCircuit = spice.analysis.native.NativeCircuit(circuit);
solver = spice.analysis.native.OperatingPointSolver(nativeCircuit, options);

switch analysisType
    case "dc"
        result = runDcNative(circuit, ir, nativeCircuit, solver, options);
    case "dcsweep"
        result = runDcSweepNative(circuit, ir, nativeCircuit, solver, options);
    case "ac"
        result = runAcNative(circuit, ir, nativeCircuit, solver, options);
    case "trans"
        result = runTransientNative(circuit, ir, nativeCircuit, solver, options);
    case "shoot"
        result = runShootNative(circuit, ir, nativeCircuit, solver, options);
    case "pz"
        result = runPzNative(circuit, ir, nativeCircuit, solver, options);
    otherwise
        error('spice:analysis:native:UnsupportedAnalysis', 'Native backend does not support %s.', analysisType);
end
end

function result = runDcNative(circuit, ir, nativeCircuit, solver, options)
[solution, opContext, stats] = solveOperatingPoint(nativeCircuit, solver, options, "dc", []);
axis = struct('name', "operating_point", 'values', 0, 'unit', "", 'scale', "scalar");
signals = spice.analysis.native.buildSignals(circuit, "dc", axis, nativeCircuit, solution);
result = baseResult("dc", axis, signals, ir, nativeCircuit, circuit, options);
result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', solution);
result.deviceState = struct('names', nativeCircuit.solutionLabels(), 'values', solution, 'nodeMap', nativeCircuit.NodeIds);
result.meta.newton = stats;
result.meta.backendReason = "native_success";
result.meta.operatingPointIterations = stats.iterations;
result.meta.deviceStates = opContext.DeviceStates;
end

function result = runDcSweepNative(circuit, ir, nativeCircuit, solver, options)
analysisParams = circuit.Analysis.Parameters;
sweepValues = buildSweepAxis(analysisParams.startValue, analysisParams.stopValue, analysisParams.stepValue);

nativeCircuit.configureAnalysis("dc", 'TransientMethod', options.TransientMethod);
solutionMatrix = zeros(nativeCircuit.matrixSize(), numel(sweepValues));
iterationCounts = zeros(1, numel(sweepValues));
lastContext = [];
lastSolution = [];
reusedPreviousSolution = false(1, numel(sweepValues));
convergedPerPoint = true(1, numel(sweepValues));

for idx = 1:numel(sweepValues)
    overrides = struct();
    overrides.(matlab.lang.makeValidName(char(analysisParams.deviceName))) = sweepValues(idx);
    context = spice.analysis.native.AnalysisContext("dcsweep", nativeCircuit, options, 'SweepOverrides', overrides);
    [solutionMatrix(:, idx), lastContext, stats] = solver.solve(context, lastSolution);
    lastSolution = solutionMatrix(:, idx);
    iterationCounts(idx) = stats.iterations;
    convergedPerPoint(idx) = stats.converged;
    reusedPreviousSolution(idx) = idx > 1;
end

nativeCircuit.OperatingPointSolution = lastSolution;
nativeCircuit.OperatingPointContext = lastContext;
axis = struct('name', "sweep", 'values', sweepValues, 'unit', "", 'scale', "linear");
signals = spice.analysis.native.buildSignals(circuit, "dcsweep", axis, nativeCircuit, solutionMatrix);
result = baseResult("dcsweep", axis, signals, ir, nativeCircuit, circuit, options);
result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', lastSolution);
result.deviceState = struct('names', nativeCircuit.solutionLabels(), 'values', solutionMatrix, 'nodeMap', nativeCircuit.NodeIds);
result.meta.newton = struct('iterationsPerPoint', iterationCounts, 'converged', all(convergedPerPoint));
result.meta.continuation = struct( ...
    'enabled', true, ...
    'source', "native", ...
    'initialGuessSource', "previous_point", ...
    'reusedPreviousSolution', reusedPreviousSolution, ...
    'iterationsPerPoint', iterationCounts, ...
    'convergedPerPoint', convergedPerPoint, ...
    'converged', all(convergedPerPoint));
result.meta.backendReason = "native_success";
result.meta.sweepTarget = analysisParams.deviceName;
end

function result = runAcNative(circuit, ir, nativeCircuit, solver, options)
analysisParams = circuit.Analysis.Parameters;
[dcSolution, dcContext, stats] = solveOperatingPoint(nativeCircuit, solver, options, "dc", []);
freq = buildFrequencyAxis(analysisParams);

nativeCircuit.configureAnalysis("ac", 'TransientMethod', options.TransientMethod);
solutionMatrix = complex(zeros(nativeCircuit.matrixSize(), numel(freq)));
for idx = 1:numel(freq)
    omega = 2 * pi * freq(idx);
    acContext = spice.analysis.native.AnalysisContext("ac", nativeCircuit, options, ...
        'Omega', omega, 'OperatingPointSolution', dcSolution);
    acContext.DeviceStates = dcContext.DeviceStates;
    [matrix, rhs, ~] = solver.assembleLinearized(acContext, dcSolution);
    solutionMatrix(:, idx) = spice.solver.solveLinearSystem(matrix, rhs);
end

axis = struct('name', "frequency", 'values', freq, 'unit', "Hz", 'scale', lower(string(analysisParams.mode)));
signals = spice.analysis.native.buildSignals(circuit, "ac", axis, nativeCircuit, solutionMatrix);
result = baseResult("ac", axis, signals, ir, nativeCircuit, circuit, options);
result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', dcSolution);
result.deviceState = struct('names', nativeCircuit.solutionLabels(), 'values', solutionMatrix, 'nodeMap', nativeCircuit.NodeIds);
result.meta.newton = stats;
result.meta.backendReason = "native_success";
result.meta.operatingPointIterations = stats.iterations;
end

function result = runTransientNative(circuit, ir, nativeCircuit, solver, options)
if string(options.TransientStepMode) == "Dynamic"
    result = runTransientDynamicNative(circuit, ir, nativeCircuit, solver, options);
else
    result = runTransientFixedNative(circuit, ir, nativeCircuit, solver, options);
end
end

function result = runTransientFixedNative(circuit, ir, nativeCircuit, solver, options)
analysisParams = circuit.Analysis.Parameters;
timeAxis = 0:analysisParams.stepTime:analysisParams.totalTime;
[initialSolution, stateContext, operatingPoint, dcStats] = seedTransientAnalysis(circuit, nativeCircuit, solver, options, analysisParams.stepTime);

solutionMatrix = zeros(nativeCircuit.matrixSize(), numel(timeAxis));
solutionMatrix(:, 1) = initialSolution;
stepIterations = zeros(1, max(numel(timeAxis) - 1, 0));
stepConverged = true(1, max(numel(timeAxis) - 1, 0));
stepModes = strings(1, max(numel(timeAxis) - 1, 0));
previousSolution = initialSolution;

for idx = 2:numel(timeAxis)
    initialGuess = chooseTransientInitialGuess(options, previousSolution, idx == 2);
    [solutionMatrix(:, idx), stateContext, stats] = solveTransientOneStep( ...
        circuit, nativeCircuit, solver, options, stateContext, previousSolution, timeAxis(idx), analysisParams.stepTime, initialGuess);
    stepIterations(idx - 1) = stats.iterations;
    stepConverged(idx - 1) = stats.converged;
    stepModes(idx - 1) = string(stats.mode);
    previousSolution = solutionMatrix(:, idx);
end

nativeCircuit.OperatingPointSolution = previousSolution;
nativeCircuit.OperatingPointContext = stateContext;
axis = struct('name', "time", 'values', timeAxis, 'unit', "s", 'scale', "linear");
signals = spice.analysis.native.buildSignals(circuit, "trans", axis, nativeCircuit, solutionMatrix);
result = baseResult("trans", axis, signals, ir, nativeCircuit, circuit, options);
if isempty(operatingPoint)
    result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', solutionMatrix(:, 1));
else
    result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', operatingPoint);
end
result.deviceState = struct('names', nativeCircuit.solutionLabels(), 'values', solutionMatrix, 'nodeMap', nativeCircuit.NodeIds);
result.meta.newton = struct( ...
    'operatingPoint', dcStats, ...
    'iterationsPerStep', stepIterations, ...
    'converged', all(stepConverged), ...
    'stepConverged', stepConverged, ...
    'stepModes', stepModes, ...
    'relaxedUsed', any(stepModes == "relaxed"));
result.meta.dynamicStep = struct('acceptedSteps', 0, 'rejectedSteps', 0, 'minStep', NaN, 'maxStep', NaN, 'finalStep', NaN, 'lteMetric', NaN);
result.meta.backendReason = "native_success";
end
function result = runTransientDynamicNative(circuit, ir, nativeCircuit, solver, options)
analysisParams = circuit.Analysis.Parameters;
baseStep = analysisParams.stepTime;
method = upper(string(options.TransientMethod));
controller = buildDynamicController(circuit, analysisParams, options);
controller.errorNodeIndices = dynamicTransientErrorNodeIndices(circuit, nativeCircuit);
[initialSolution, stateContext, operatingPoint, dcStats] = seedTransientAnalysis(circuit, nativeCircuit, solver, options, controller.initialStep);

currentTime = 0;
currentSolution = initialSolution;
timeValues = 0;
solutionMatrix = initialSolution;
stepIterations = zeros(0, 1);
stepConverged = true(0, 1);
stepModes = strings(0, 1);
stepSizes = zeros(0, 1);
lteValues = zeros(0, 1);
voltageErrorNorms = zeros(0, 1);
currentErrorNorms = zeros(0, 1);
acceptedSteps = 0;
rejectedSteps = 0;
breakpointHits = 0;
cachedHalfStepReuses = 0;
dt = controller.initialStep;
reuseCache = [];
runTimer = tic;

while currentTime < analysisParams.totalTime - max(eps(analysisParams.totalTime), baseStep * 1e-12)
    [dt, hitsBreakpoint] = limitDynamicStep(dt, currentTime, analysisParams.totalTime, controller);
    attempt = attemptDynamicTransientStep(circuit, nativeCircuit, solver, options, stateContext, currentSolution, currentTime, dt, controller, reuseCache);
    if attempt.usedCachedFullStep
        cachedHalfStepReuses = cachedHalfStepReuses + 1;
    end
    lteValues(end + 1, 1) = attempt.lteMetric; %#ok<AGROW>
    voltageErrorNorms(end + 1, 1) = attempt.voltageErrorNorm; %#ok<AGROW>
    currentErrorNorms(end + 1, 1) = attempt.currentErrorNorm; %#ok<AGROW>
    if attempt.accepted
        currentTime = currentTime + dt;
        currentSolution = attempt.solution;
        stateContext = attempt.nextContext;
        timeValues(end + 1) = currentTime; %#ok<AGROW>
        solutionMatrix(:, end + 1) = currentSolution; %#ok<AGROW>
        stepIterations(end + 1, 1) = attempt.iterations; %#ok<AGROW>
        stepConverged(end + 1, 1) = attempt.converged; %#ok<AGROW>
        stepModes(end + 1, 1) = string(attempt.mode); %#ok<AGROW>
        stepSizes(end + 1, 1) = dt; %#ok<AGROW>
        acceptedSteps = acceptedSteps + 1;
        if hitsBreakpoint
            breakpointHits = breakpointHits + 1;
        end
        reuseCache = [];
        if method == "TR"
            dt = updateDynamicTimeStepTR(dt, controller, attempt.voltageErrorNorm, true);
        else
            dt = updateDynamicTimeStep(dt, controller.maxStep, attempt.lteMetric, attempt.tolerance);
        end
    else
        rejectedSteps = rejectedSteps + 1;
        if method == "TR"
            previousDt = dt;
            dt = updateDynamicTimeStepTR(dt, controller, attempt.voltageErrorNorm, false);
            if previousDt <= controller.minStep * (1 + 1e-12) || dt <= controller.minStep * (1 + 1e-12)
                error('spice:analysis:native:DynamicStepUnderflow', ...
                    'Native dynamic TR step control reached the minimum step size without acceptance.');
            end
            if canReuseDynamicHalfStep(attempt.reusableHalfStep, currentTime, dt, controller.breakpointTolerance)
                reuseCache = attempt.reusableHalfStep;
            else
                reuseCache = [];
            end
        elseif 0.5 * dt < controller.minStep
            currentTime = currentTime + dt;
            currentSolution = attempt.solution;
            stateContext = attempt.nextContext;
            timeValues(end + 1) = currentTime; %#ok<AGROW>
            solutionMatrix(:, end + 1) = currentSolution; %#ok<AGROW>
            stepIterations(end + 1, 1) = attempt.iterations; %#ok<AGROW>
            stepConverged(end + 1, 1) = attempt.converged; %#ok<AGROW>
            stepModes(end + 1, 1) = "relaxed"; %#ok<AGROW>
            stepSizes(end + 1, 1) = dt; %#ok<AGROW>
            acceptedSteps = acceptedSteps + 1;
            reuseCache = [];
            dt = controller.minStep;
        else
            dt = 0.5 * dt;
            reuseCache = [];
            if dt < controller.minStep
                error('spice:analysis:native:DynamicStepUnderflow', 'Native dynamic transient step control reached the minimum step size without acceptance.');
            end
        end
    end
end

nativeCircuit.OperatingPointSolution = currentSolution;
nativeCircuit.OperatingPointContext = stateContext;
axis = struct('name', "time", 'values', timeValues, 'unit', "s", 'scale', "linear");
signals = spice.analysis.native.buildSignals(circuit, "trans", axis, nativeCircuit, solutionMatrix);
result = baseResult("trans", axis, signals, ir, nativeCircuit, circuit, options);
if isempty(operatingPoint)
    result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', solutionMatrix(:, 1));
else
    result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', operatingPoint);
end
result.deviceState = struct('names', nativeCircuit.solutionLabels(), 'values', solutionMatrix, 'nodeMap', nativeCircuit.NodeIds);
result.meta.newton = struct( ...
    'operatingPoint', dcStats, ...
    'iterationsPerStep', stepIterations, ...
    'converged', all(stepConverged), ...
    'stepConverged', stepConverged, ...
    'stepModes', stepModes, ...
    'stepSizes', stepSizes, ...
    'relaxedUsed', any(stepModes == "relaxed"));
result.meta.dynamicStep = struct( ...
    'acceptedSteps', acceptedSteps, ...
    'rejectedSteps', rejectedSteps, ...
    'minStep', valueOrNaN(min(stepSizes)), ...
    'maxStep', valueOrNaN(max(stepSizes)), ...
    'finalStep', lastValueOrNaN(stepSizes), ...
    'lteMetric', valueOrNaN(max(lteValues)), ...
    'voltageErrorNorm', valueOrNaN(max(voltageErrorNorms)), ...
    'currentErrorNorm', valueOrNaN(max(currentErrorNorms)), ...
    'breakpointHits', breakpointHits, ...
    'cachedHalfStepReuses', cachedHalfStepReuses, ...
    'runtimeSeconds', toc(runTimer));
result.meta.backendReason = "native_success";
end

function result = runShootNative(circuit, ir, nativeCircuit, solver, options)
if upper(string(options.TransientMethod)) ~= "BE"
    error('spice:analysis:native:ShootingTRUnsupported', 'Native shooting currently supports BE only.');
end

analysisParams = circuit.Analysis.Parameters;
period = determineShootingPeriod(circuit);
baseStep = analysisParams.stepTime;
[initialSolution, ~, operatingPoint, dcStats] = seedTransientAnalysis(circuit, nativeCircuit, solver, options, baseStep);

shootMaxIterations = 12;
shootTolerance = max(options.ErrorTolerance, options.ErrorTolerance * max(1, norm(initialSolution, inf)));
stateGuess = initialSolution;
residualNorm = inf;
updateNorm = inf;
converged = false;
iterationCount = 0;

for iter = 1:shootMaxIterations
    iterationCount = iter;
    [~, periodSolutionMatrix] = integrateTransientWindow(circuit, nativeCircuit, solver, options, stateGuess, period, baseStep);
    finalState = periodSolutionMatrix(:, end);
    residual = finalState - stateGuess;
    residualNorm = norm(residual, inf);
    if residualNorm <= shootTolerance
        converged = true;
        updateNorm = 0;
        break;
    end

    jacobian = buildShootingJacobian(circuit, nativeCircuit, solver, options, stateGuess, finalState, period, baseStep);
    delta = spice.solver.solveLinearSystem(jacobian - speye(size(jacobian, 1)), -residual);
    updateNorm = norm(delta, inf);
    if updateNorm <= shootTolerance
        stateGuess = stateGuess + delta;
        converged = true;
        break;
    end

    damping = 1;
    accepted = false;
    while damping >= 0.125
        candidate = stateGuess + damping * delta;
        [~, candidateSolutionMatrix] = integrateTransientWindow(circuit, nativeCircuit, solver, options, candidate, period, baseStep);
        candidateFinal = candidateSolutionMatrix(:, end);
        candidateResidual = candidateFinal - candidate;
        if norm(candidateResidual, inf) < residualNorm
            stateGuess = candidate;
            accepted = true;
            break;
        end
        damping = damping / 2;
    end
    if ~accepted
        stateGuess = stateGuess + 0.25 * delta;
    end
end

[timeAxis, solutionMatrix, finalContext, stepIterations, stepModes] = integrateTransientWindow( ...
    circuit, nativeCircuit, solver, options, stateGuess, analysisParams.totalTime, baseStep);
nativeCircuit.OperatingPointSolution = solutionMatrix(:, end);
nativeCircuit.OperatingPointContext = finalContext;
axis = struct('name', "time", 'values', timeAxis, 'unit', "s", 'scale', "linear");
signals = spice.analysis.native.buildSignals(circuit, "shoot", axis, nativeCircuit, solutionMatrix);
result = baseResult("shoot", axis, signals, ir, nativeCircuit, circuit, options);
if isempty(operatingPoint)
    result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', solutionMatrix(:, 1));
else
    result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', operatingPoint);
end
result.deviceState = struct('names', nativeCircuit.solutionLabels(), 'values', solutionMatrix, 'nodeMap', nativeCircuit.NodeIds);
result.meta.newton = struct( ...
    'operatingPoint', dcStats, ...
    'iterationsPerStep', stepIterations, ...
    'converged', all(stepModes ~= "failed"), ...
    'stepModes', stepModes, ...
    'relaxedUsed', any(stepModes == "relaxed"));
result.meta.shooting = struct( ...
    'period', period, ...
    'iterations', iterationCount, ...
    'residualNorm', residualNorm, ...
    'updateNorm', updateNorm, ...
    'jacobianMethod', "finite_difference", ...
    'converged', converged);
result.meta.backendReason = "native_success";
end

function result = runPzNative(circuit, ir, nativeCircuit, solver, options)
[dcSolution, dcContext, stats] = solveOperatingPoint(nativeCircuit, solver, options, "dc", []);
activeSources = activeAcSourceNames(circuit);
if isempty(activeSources)
    error('spice:analysis:native:PzRequiresAcInput', 'PZ analysis requires at least one active AC source.');
end
outputNodes = nodeVoltageProbeTargets(circuit);
if isempty(outputNodes)
    error('spice:analysis:native:PzRequiresNodeProbe', 'PZ analysis requires at least one node-voltage probe.');
end

nativeCircuit.configureAnalysis("ac", 'TransientMethod', options.TransientMethod);
context0 = spice.analysis.native.AnalysisContext("ac", nativeCircuit, options, 'Omega', 0, 'OperatingPointSolution', dcSolution);
context0.DeviceStates = dcContext.DeviceStates;
[gMatrix, inputVector] = solver.assembleLinearized(context0, dcSolution);
context1 = spice.analysis.native.AnalysisContext("ac", nativeCircuit, options, 'Omega', 1, 'OperatingPointSolution', dcSolution);
context1.DeviceStates = dcContext.DeviceStates;
[matrixAtOne, ~] = solver.assembleLinearized(context1, dcSolution);

gMatrix = full(gMatrix);
eMatrix = full(imag(matrixAtOne));
inputVector = full(inputVector(:));

poleRoots = finiteRoots(eig(-gMatrix, eMatrix));
signals = repmat(struct('name', "", 'kind', "", 'axisName', "root_index", 'axisValues', [], ...
    'unit', "rad/s", 'domain', "complex", 'values', [], 'magnitude', [], 'phaseDeg', []), 0, 1);
for idx = 1:numel(outputNodes)
    outputNode = outputNodes(idx);
    outputIndex = nativeCircuit.nodeVarIndex(outputNode);
    outputSelector = zeros(1, size(gMatrix, 1));
    outputSelector(outputIndex) = 1;
    zeroRoots = finiteRoots(computePzZeros(gMatrix, eMatrix, inputVector, outputSelector));
    signals(end + 1, 1) = makePzSignal("Zeros(" + outputNode + ")", "zeroRoots", zeroRoots); %#ok<AGROW>
    signals(end + 1, 1) = makePzSignal("Poles(" + outputNode + ")", "poleRoots", poleRoots); %#ok<AGROW>
end

axis = struct('name', "root_index", 'values', [], 'unit', "", 'scale', "categorical");
result = baseResult("pz", axis, signals, ir, nativeCircuit, circuit, options);
result.operatingPoint = struct('nodeMap', nativeCircuit.NodeIds, 'solution', dcSolution);
result.deviceState = struct('names', nativeCircuit.solutionLabels(), 'values', dcSolution, 'nodeMap', nativeCircuit.NodeIds);
result.meta.newton = stats;
result.meta.pz = struct( ...
    'matrixForm', "descriptor_mna", ...
    'inputSourceNames', activeSources, ...
    'outputNodeNames', outputNodes);
result.meta.backendReason = "native_success";
end
function [solution, context, stats] = solveOperatingPoint(nativeCircuit, solver, options, analysisType, initialGuess)
context = spice.analysis.native.AnalysisContext(analysisType, nativeCircuit, options);
[solution, context, stats] = solver.solve(context, initialGuess);
nativeCircuit.OperatingPointSolution = solution;
nativeCircuit.OperatingPointContext = context;
end

function [initialSolution, stateContext, operatingPoint, dcStats] = seedTransientAnalysis(circuit, nativeCircuit, solver, options, stepTime)
analysisType = string(circuit.Analysis.Type);
operatingPoint = [];
if string(options.TransientInitMethod) == "DC"
    [operatingPoint, ~, dcStats] = solveOperatingPoint(nativeCircuit, solver, options, "dc", []);
    initialSolution = operatingPoint;
else
    dcStats = struct('iterations', 0, 'converged', true);
    nativeCircuit.configureAnalysis(transientConfigureKind(analysisType), 'TransientMethod', options.TransientMethod);
    initialSolution = zeros(nativeCircuit.matrixSize(), 1);
end
stateContext = seedTransientContext(nativeCircuit, options, initialSolution, stepTime);
end

function context = seedTransientContext(nativeCircuit, options, initialSolution, stepTime)
context = spice.analysis.native.AnalysisContext("trans", nativeCircuit, options, ...
    'Time', 0, 'TimeStep', stepTime, 'OperatingPointSolution', initialSolution);
for idx = 1:numel(nativeCircuit.Circuit.Elements)
    device = nativeCircuit.Circuit.Elements{idx};
    state = device.evaluateOperatingPoint(nativeCircuit, initialSolution, context);
    context.setDeviceState(device.Name, state);
    if isfield(state, 'dynamicCaps')
        for capIdx = 1:numel(state.dynamicCaps)
            cap = state.dynamicCaps(capIdx);
            voltage = nativeCircuit.nodeVoltage(initialSolution, cap.n1) - nativeCircuit.nodeVoltage(initialSolution, cap.n2);
            context.setCapacitorHistory(cap.historyKey, voltage, 0);
        end
    end
    if isfield(state, 'branchIndex')
        current = nativeCircuit.branchCurrent(initialSolution, state.branchIndex);
        context.setInductorHistory(state.historyKey, 0, current);
    end
end
end

function sweepValues = buildSweepAxis(startValue, stopValue, stepValue)
stepValue = double(stepValue);
if stepValue == 0
    error('spice:analysis:native:BadSweepStep', 'DC sweep step must be non-zero.');
end
sampleCount = floor((stopValue - startValue) / stepValue + 0.5) + 1;
if sampleCount < 1
    sampleCount = 1;
end
sweepValues = startValue + (0:sampleCount - 1) * stepValue;
if stepValue > 0
    sweepValues = sweepValues(sweepValues <= stopValue + abs(stepValue) * 1e-9);
else
    sweepValues = sweepValues(sweepValues >= stopValue - abs(stepValue) * 1e-9);
end
end

function freq = buildFrequencyAxis(params)
switch lower(string(params.mode))
    case "dec"
        startValue = log10(params.startFreq);
        stopValue = log10(params.stopFreq);
        sampleCount = max(2, floor((stopValue - startValue) * params.points) + 1);
        freq = logspace(startValue, stopValue, sampleCount);
    otherwise
        freq = linspace(params.startFreq, params.stopFreq, params.points);
end
end

function [solution, nextContext, stats] = solveTransientOneStep(circuit, nativeCircuit, solver, options, previousContext, previousSolution, targetTime, stepTime, initialGuess)
stepContext = spice.analysis.native.AnalysisContext("trans", nativeCircuit, options, ...
    'Time', targetTime, 'TimeStep', stepTime, 'TransientHistory', previousContext.TransientHistory);
[solution, convergedContext, stats] = solveTransientStep(solver, stepContext, initialGuess);
nextContext = advanceTransientState(circuit, nativeCircuit, options, previousContext, convergedContext, solution, targetTime, stepTime);
end

function nextContext = advanceTransientState(circuit, nativeCircuit, options, previousContext, convergedContext, solution, timePoint, stepTime)
nextContext = spice.analysis.native.AnalysisContext("trans", nativeCircuit, options, ...
    'Time', timePoint, 'TimeStep', stepTime, ...
    'OperatingPointSolution', solution, ...
    'TransientHistory', previousContext.TransientHistory);
nextContext.DeviceStates = convergedContext.DeviceStates;
for deviceIdx = 1:numel(circuit.Elements)
    device = circuit.Elements{deviceIdx};
    device.updateDynamicState(nativeCircuit, solution, previousContext, nextContext, convergedContext.deviceState(device.Name));
end
end

function refreshedContext = refreshTransientDeviceContext(nativeCircuit, options, templateContext, solution)
refreshedContext = spice.analysis.native.AnalysisContext("trans", nativeCircuit, options, ...
    'Time', templateContext.Time, ...
    'TimeStep', templateContext.TimeStep, ...
    'OperatingPointSolution', solution, ...
    'TransientHistory', templateContext.TransientHistory);
for idx = 1:numel(nativeCircuit.Circuit.Elements)
    device = nativeCircuit.Circuit.Elements{idx};
    refreshedContext.setDeviceState(device.Name, device.evaluateOperatingPoint(nativeCircuit, solution, refreshedContext));
end
end

function [acceptedSolution, acceptedContext] = dynamicAcceptedTransientState(circuit, nativeCircuit, options, previousContext, fullSolution, halfSolution, halfContext, targetTime, stepTime)
if upper(string(options.TransientMethod)) ~= "TR"
    acceptedSolution = halfSolution;
    acceptedContext = halfContext;
    return;
end

acceptedSolution = halfSolution + (halfSolution - fullSolution) / 3;
acceptedSolution = nativeCircuit.clampNodeVoltages(acceptedSolution);
refreshedContext = refreshTransientDeviceContext(nativeCircuit, options, halfContext, acceptedSolution);
acceptedContext = advanceTransientState(circuit, nativeCircuit, options, previousContext, refreshedContext, acceptedSolution, targetTime, stepTime);
end

function initialGuess = chooseTransientInitialGuess(options, previousSolution, isFirstStep)
if isFirstStep && string(options.TransientInitMethod) == "Poweron"
    initialGuess = [];
else
    initialGuess = previousSolution;
end
end

function attempt = attemptDynamicTransientStep(circuit, nativeCircuit, solver, options, previousContext, previousSolution, currentTime, stepTime, controller, reusableFullStep)
if nargin < 10
    reusableFullStep = [];
end

firstGuess = chooseTransientInitialGuess(options, previousSolution, currentTime == 0);
usedCachedFullStep = canReuseDynamicHalfStep(reusableFullStep, currentTime, stepTime, 0);
if usedCachedFullStep
    fullSolution = reusableFullStep.solution;
    fullStats = reusableFullStep.stats;
else
    [fullSolution, ~, fullStats] = solveTransientOneStep( ...
        circuit, nativeCircuit, solver, options, previousContext, previousSolution, currentTime + stepTime, stepTime, firstGuess);
end
[halfSolution1, halfContext1, halfStats1] = solveTransientOneStep( ...
    circuit, nativeCircuit, solver, options, previousContext, previousSolution, currentTime + 0.5 * stepTime, 0.5 * stepTime, firstGuess);
[halfSolution2, halfContext2, halfStats2] = solveTransientOneStep( ...
    circuit, nativeCircuit, solver, options, halfContext1, halfSolution1, currentTime + stepTime, 0.5 * stepTime, halfSolution1);
[acceptedSolution, acceptedContext] = dynamicAcceptedTransientState( ...
    circuit, nativeCircuit, options, previousContext, fullSolution, halfSolution2, halfContext2, currentTime + stepTime, stepTime);

[lteMetric, tolerance, voltageErrorNorm, currentErrorNorm] = dynamicErrorMetrics( ...
    fullSolution, halfSolution2, nativeCircuit, options, upper(string(options.TransientMethod)), controller.errorNodeIndices);
converged = fullStats.converged && halfStats1.converged && halfStats2.converged;
if upper(string(options.TransientMethod)) == "TR"
    accepted = converged && voltageErrorNorm <= controller.acceptErrorNorm && (~isfinite(currentErrorNorm) || currentErrorNorm <= 1e6);
else
    accepted = converged && lteMetric <= tolerance;
end
attempt = struct( ...
    'accepted', accepted, ...
    'solution', acceptedSolution, ...
    'nextContext', acceptedContext, ...
    'iterations', fullStats.iterations + halfStats1.iterations + halfStats2.iterations, ...
    'converged', converged, ...
    'mode', dominantTransientMode([string(fullStats.mode), string(halfStats1.mode), string(halfStats2.mode)]), ...
    'lteMetric', lteMetric, ...
    'tolerance', tolerance, ...
    'voltageErrorNorm', voltageErrorNorm, ...
    'currentErrorNorm', currentErrorNorm, ...
    'usedCachedFullStep', usedCachedFullStep, ...
    'reusableHalfStep', struct( ...
        'currentTime', currentTime, ...
        'stepTime', 0.5 * stepTime, ...
        'solution', halfSolution1, ...
        'nextContext', halfContext1, ...
        'stats', halfStats1));
end
function tolerance = dynamicTolerance(solution, baseTolerance)
reference = max(1, norm(solution, inf));
tolerance = max(1e3 * baseTolerance, 256 * baseTolerance * reference);
end

function [lteMetric, tolerance, voltageErrorNorm, currentErrorNorm] = dynamicErrorMetrics(fullSolution, halfSolution, nativeCircuit, options, method, errorNodeIndices)
if method ~= "TR"
    tolerance = dynamicTolerance(halfSolution, options.ErrorTolerance);
    lteMetric = norm(halfSolution - fullSolution, inf);
    voltageErrorNorm = NaN;
    currentErrorNorm = NaN;
    return;
end

delta = abs(halfSolution - fullSolution) / 3;
nodeCount = numel(nativeCircuit.NodeIds);
if nargin < 6 || isempty(errorNodeIndices)
    errorNodeIndices = (1:nodeCount).';
else
    errorNodeIndices = errorNodeIndices(:);
    errorNodeIndices = errorNodeIndices(errorNodeIndices >= 1 & errorNodeIndices <= nodeCount);
    if isempty(errorNodeIndices)
        errorNodeIndices = (1:nodeCount).';
    end
end
fullNodes = abs(fullSolution(errorNodeIndices));
halfNodes = abs(halfSolution(errorNodeIndices));
nodeReference = max(max(fullNodes, halfNodes), 1);
effectiveRelTol = dynamicTrRelativeTolerance(options);
nodeTolerance = 1e-6 + effectiveRelTol .* nodeReference;
if nodeCount > 0
    voltageErrorNorm = max(delta(errorNodeIndices) ./ nodeTolerance);
else
    voltageErrorNorm = 0;
end

if numel(delta) > nodeCount
    fullCurrents = abs(fullSolution(nodeCount + 1:end));
    halfCurrents = abs(halfSolution(nodeCount + 1:end));
    currentReference = max(max(fullCurrents, halfCurrents), 1);
    currentTolerance = 1e-9 + 10 * effectiveRelTol .* currentReference;
    currentErrorNorm = max(delta(nodeCount + 1:end) ./ currentTolerance);
else
    currentErrorNorm = 0;
end

lteMetric = voltageErrorNorm;
tolerance = 1;
end

function controller = buildDynamicController(circuit, analysisParams, options)
method = upper(string(options.TransientMethod));
baseStep = analysisParams.stepTime;
totalTime = analysisParams.totalTime;
period = fastestSinPeriod(circuit);

if method == "TR"
    if isfinite(period)
        initialStep = min(baseStep, period / 32);
        maxStep = min(max(baseStep * 32, totalTime / 20), period / 8);
        minStep = max([initialStep / 16384, period / 32768, totalTime * 1e-12]);
    else
        initialStep = baseStep;
        maxStep = max(baseStep * 32, totalTime / 20);
        minStep = max(initialStep / 16384, totalTime * 1e-12);
    end
    breakpoints = buildTransientBreakpoints(circuit, totalTime);
else
    initialStep = baseStep;
    maxStep = max(baseStep * 32, totalTime / 20);
    minStep = max(initialStep / 1024, totalTime * 1e-9);
    breakpoints = zeros(0, 1);
end

controller = struct( ...
    'method', method, ...
    'initialStep', initialStep, ...
    'minStep', minStep, ...
    'maxStep', max(initialStep, maxStep), ...
    'breakpoints', breakpoints(:), ...
    'breakpointTolerance', max(1e-15, totalTime * 1e-12), ...
    'safety', 0.9, ...
    'acceptErrorNorm', 5);
end

function period = fastestSinPeriod(circuit)
period = inf;
for idx = 1:numel(circuit.Elements)
    device = circuit.Elements{idx};
    if isa(device, 'spice.model.IndependentSource') && upper(string(device.Parameters.waveform)) == "SIN" && device.Parameters.freq > 0
        period = min(period, 1 / device.Parameters.freq);
    end
end
end

function breakpoints = buildTransientBreakpoints(circuit, totalTime)
breakpoints = zeros(0, 1);
fractions = [0, 0.25, 0.5, 0.75];
for idx = 1:numel(circuit.Elements)
    device = circuit.Elements{idx};
    if ~isa(device, 'spice.model.IndependentSource')
        continue;
    end
    parameters = device.Parameters;
    if upper(string(parameters.waveform)) ~= "SIN" || parameters.freq <= 0
        continue;
    end
    period = 1 / parameters.freq;
    delay = sourceDelay(parameters);
    cycleCount = ceil(max(totalTime - delay, 0) / period) + 1;
    for cycleIdx = 0:cycleCount
        cycleStart = delay + cycleIdx * period;
        for fracIdx = 1:numel(fractions)
            value = cycleStart + fractions(fracIdx) * period;
            if value >= 0 && value <= totalTime
                breakpoints(end + 1, 1) = value; %#ok<AGROW>
            end
        end
    end
end
breakpoints(end + 1, 1) = 0; %#ok<AGROW>
breakpoints(end + 1, 1) = totalTime; %#ok<AGROW>
breakpoints = unique(round(breakpoints / max(totalTime, 1) * 1e12) / 1e12 * max(totalTime, 1), 'stable');
breakpoints = sort(breakpoints);
end

function delay = sourceDelay(parameters)
if isfield(parameters, 'delay')
    delay = double(parameters.delay);
else
    delay = 0;
end
end

function [step, hitsBreakpoint] = limitDynamicStep(step, currentTime, totalTime, controller)
step = min(step, totalTime - currentTime);
hitsBreakpoint = false;
if isempty(controller.breakpoints)
    return;
end
futureBreakpoints = controller.breakpoints(controller.breakpoints > currentTime + controller.breakpointTolerance);
if isempty(futureBreakpoints)
    return;
end
distance = futureBreakpoints(1) - currentTime;
if distance < step - controller.breakpointTolerance
    step = distance;
    hitsBreakpoint = true;
elseif abs(distance - step) <= controller.breakpointTolerance
    step = distance;
    hitsBreakpoint = true;
end
end

function nextStep = updateDynamicTimeStepTR(currentStep, controller, errorNorm, accepted)
effectiveError = max(errorNorm / controller.acceptErrorNorm, 1e-6);
factor = controller.safety * effectiveError ^ (-1 / 3);
if accepted
    factor = clampScalar(factor, 0.75, 2.0);
else
    factor = clampScalar(factor, 0.25, 0.5);
end
nextStep = currentStep * factor;
nextStep = min(max(nextStep, controller.minStep), controller.maxStep);
end

function value = dynamicTrRelativeTolerance(options)
% Use a practical RELTOL floor for Dynamic+TR step acceptance.
% The nonlinear Newton tolerance still follows options.ErrorTolerance; only
% the adaptive transient controller uses this floor so the native driver
% tracks HSPICE-style waveform behavior without collapsing to picosecond
% steps on large mixed-signal examples.
value = max(3e-3, options.ErrorTolerance);
end

function indices = dynamicTransientErrorNodeIndices(circuit, nativeCircuit)
indices = zeros(0, 1);
for idx = 1:numel(circuit.Probes)
    probe = circuit.Probes{idx};
    if probe.Kind ~= "nodeVoltage"
        continue;
    end
    nodeIndex = nativeCircuit.nodeVarIndex(probe.Target);
    if nodeIndex > 0
        indices(end + 1, 1) = nodeIndex; %#ok<AGROW>
    end
end
indices = unique(indices, 'stable');
end

function tf = canReuseDynamicHalfStep(reusableHalfStep, currentTime, stepTime, tolerance)
tf = isstruct(reusableHalfStep) ...
    && isfield(reusableHalfStep, 'stepTime') ...
    && isfield(reusableHalfStep, 'currentTime') ...
    && abs(reusableHalfStep.stepTime - stepTime) <= max(tolerance, 1e-18) ...
    && abs(reusableHalfStep.currentTime - currentTime) <= max(tolerance, 1e-18);
end

function value = clampScalar(value, minValue, maxValue)
value = min(max(value, minValue), maxValue);
end

function nextStep = updateDynamicTimeStep(currentStep, maxStep, lteMetric, tolerance)
if lteMetric < 0.1 * tolerance
    nextStep = min(2 * currentStep, maxStep);
elseif lteMetric < 0.5 * tolerance
    nextStep = min(1.25 * currentStep, maxStep);
else
    nextStep = currentStep;
end
end

function mode = dominantTransientMode(modes)
if any(modes == "relaxed")
    mode = "relaxed";
elseif any(modes == "failed")
    mode = "failed";
else
    mode = "strict";
end
end

function [timeAxis, solutionMatrix, finalContext, stepIterations, stepModes] = integrateTransientWindow(circuit, nativeCircuit, solver, options, initialSolution, totalTime, stepTime)
timeAxis = 0:stepTime:totalTime;
stateContext = seedTransientContext(nativeCircuit, options, initialSolution, stepTime);
solutionMatrix = zeros(nativeCircuit.matrixSize(), numel(timeAxis));
solutionMatrix(:, 1) = initialSolution;
stepIterations = zeros(1, max(numel(timeAxis) - 1, 0));
stepModes = strings(1, max(numel(timeAxis) - 1, 0));
previousSolution = initialSolution;

for idx = 2:numel(timeAxis)
    initialGuess = chooseTransientInitialGuess(options, previousSolution, idx == 2);
    [solutionMatrix(:, idx), stateContext, stats] = solveTransientOneStep( ...
        circuit, nativeCircuit, solver, options, stateContext, previousSolution, timeAxis(idx), stepTime, initialGuess);
    stepIterations(idx - 1) = stats.iterations;
    if stats.converged
        stepModes(idx - 1) = string(stats.mode);
    else
        stepModes(idx - 1) = "failed";
    end
    previousSolution = solutionMatrix(:, idx);
end
finalContext = stateContext;
nativeCircuit.OperatingPointSolution = solutionMatrix(:, end);
nativeCircuit.OperatingPointContext = stateContext;
end

function jacobian = buildShootingJacobian(circuit, nativeCircuit, solver, options, stateGuess, finalState, period, stepTime)
stateCount = numel(stateGuess);
jacobian = zeros(stateCount, stateCount);
for idx = 1:stateCount
    perturbation = max(1e-8, 1e-6 * max(1, abs(stateGuess(idx))));
    perturbedState = stateGuess;
    perturbedState(idx) = perturbedState(idx) + perturbation;
    [~, perturbedSolutionMatrix] = integrateTransientWindow(circuit, nativeCircuit, solver, options, perturbedState, period, stepTime);
    perturbedFinalState = perturbedSolutionMatrix(:, end);
    jacobian(:, idx) = (perturbedFinalState - finalState) / perturbation;
end
end

function period = determineShootingPeriod(circuit)
freqs = zeros(1, 0);
for idx = 1:numel(circuit.Elements)
    device = circuit.Elements{idx};
    if isa(device, 'spice.model.IndependentSource') && upper(string(device.Parameters.waveform)) == "SIN" && device.Parameters.freq > 0
        freqs(end + 1) = device.Parameters.freq; %#ok<AGROW>
    end
end
if isempty(freqs)
    error('spice:analysis:native:ShootingRequiresSinSource', 'Native shooting requires at least one sinusoidal source.');
end
baseFrequency = freqs(1);
for idx = 2:numel(freqs)
    baseFrequency = approximateFrequencyGcd(baseFrequency, freqs(idx));
end
if baseFrequency <= 0
    baseFrequency = min(freqs);
end
period = 1 / baseFrequency;
end

function value = approximateFrequencyGcd(a, b)
a = abs(a);
b = abs(b);
tolerance = 1e-9 * max([a, b, 1]);
while b > tolerance
    remainder = rem(a, b);
    if remainder < tolerance || abs(remainder - b) < tolerance
        value = b;
        return;
    end
    a = b;
    b = remainder;
end
value = a;
end

function names = activeAcSourceNames(circuit)
names = strings(0, 1);
for idx = 1:numel(circuit.Elements)
    device = circuit.Elements{idx};
    if isa(device, 'spice.model.VoltageSource') || isa(device, 'spice.model.CurrentSource')
        if abs(spice.analysis.native.sourcePhasor(device.Parameters)) > 0
            names(end + 1, 1) = device.Name; %#ok<AGROW>
        end
    end
end
end

function outputNodes = nodeVoltageProbeTargets(circuit)
outputNodes = strings(0, 1);
for idx = 1:numel(circuit.Probes)
    probe = circuit.Probes{idx};
    if probe.Kind == "nodeVoltage"
        outputNodes(end + 1, 1) = probe.Target; %#ok<AGROW>
    end
end
outputNodes = unique(outputNodes, 'stable');
end

function roots = computePzZeros(gMatrix, eMatrix, inputVector, outputSelector)
augG = [gMatrix, inputVector; outputSelector, 0];
augE = [eMatrix, zeros(size(eMatrix, 1), 1); zeros(1, size(eMatrix, 2) + 1)];
roots = eig(-augG, augE);
end

function roots = finiteRoots(values)
values = values(:).';
mask = isfinite(real(values)) & isfinite(imag(values));
roots = values(mask);
if isempty(roots)
    return;
end
[~, order] = sortrows([real(roots(:)), imag(roots(:))], [1 2]);
roots = roots(order).';
end

function signal = makePzSignal(name, kind, values)
signal = struct( ...
    'name', string(name), ...
    'kind', string(kind), ...
    'axisName', "root_index", ...
    'axisValues', 1:numel(values), ...
    'unit', "rad/s", ...
    'domain', "complex", ...
    'values', values, ...
    'magnitude', abs(values), ...
    'phaseDeg', rad2deg(angle(values)));
end
function [solution, context, stats] = solveTransientStep(solver, stepContext, initialGuess)
try
    [solution, context, stats] = solver.solve(stepContext, initialGuess);
    stats.mode = "strict";
    return;
catch err
    if string(err.identifier) ~= "spice:analysis:native:NonlinearNotConverged"
        rethrow(err);
    end
end

if isempty(initialGuess)
    guess = solver.buildInitialGuess(stepContext);
else
    guess = initialGuess;
end
guess = stepContext.NativeCircuit.clampNodeVoltages(guess);
maxRelaxIterations = 60;
tolerance = stepContext.Options.ErrorTolerance;
context = stepContext.copy();

for idx = 1:maxRelaxIterations
    [matrix, rhs, iterationContext] = solver.assembleLinearized(stepContext.copy(), guess);
    candidate = spice.solver.solveLinearSystem(matrix, rhs);
    candidate = stepContext.NativeCircuit.clampNodeVoltages(candidate);
    if norm(candidate - guess, inf) <= max(tolerance, tolerance * max(1, norm(candidate, inf)))
        context = iterationContext;
        context.OperatingPointSolution = candidate;
        solution = candidate;
        stats = struct('iterations', idx, 'converged', true, 'mode', "relaxed");
        return;
    end
    guess = 0.5 * guess + 0.5 * candidate;
    context = iterationContext;
end

solution = guess;
context.OperatingPointSolution = solution;
stats = struct('iterations', maxRelaxIterations, 'converged', false, 'mode', "failed");
end

function result = baseResult(analysisType, axis, signals, ir, nativeCircuit, circuit, options)
result = struct();
result.analysisType = string(analysisType);
result.axis = axis;
result.signals = signals;
result.operatingPoint = struct();
result.deviceState = struct();
result.artifacts = struct('outputDir', "", 'files', {{}}, 'plotFiles', {{}}, 'csvFiles', {{}}, 'jsonFile', "", 'matFile', "");
result.meta = struct( ...
    'ir', ir, ...
    'probeCount', circuit.probeCount(), ...
    'elementCount', circuit.elementCount(), ...
    'analysisLine', circuit.Analysis.LineNumber, ...
    'backend', "native", ...
    'backendReason', "native_success", ...
    'solutionLabels', nativeCircuit.solutionLabels(), ...
    'newton', struct(), ...
    'continuation', struct(), ...
    'probeModel', "analyticState", ...
    'dynamicStep', struct(), ...
    'shooting', struct(), ...
    'pz', struct(), ...
    'transientMethod', transientMethodForMeta(analysisType, options), ...
    'acceptedByRegression', false);
end

function value = transientMethodForMeta(analysisType, options)
if any(string(analysisType) == ["trans", "shoot"])
    value = string(options.TransientMethod) + "/" + string(options.TransientStepMode);
else
    value = "";
end
end

function value = valueOrNaN(inputValue)
if isempty(inputValue)
    value = NaN;
else
    value = inputValue;
end
end

function value = lastValueOrNaN(values)
if isempty(values)
    value = NaN;
else
    value = values(end);
end
end

function kind = transientConfigureKind(analysisType)
if string(analysisType) == "shoot"
    kind = "trans";
else
    kind = string(analysisType);
end
end
