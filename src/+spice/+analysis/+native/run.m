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
[solution, opContext, stats] = spice.analysis.native.solveOperatingPoint(nativeCircuit, solver, options, "dc", []);
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
sweepValues = spice.analysis.native.buildSweepAxis(analysisParams.startValue, analysisParams.stopValue, analysisParams.stepValue);

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
[dcSolution, dcContext, stats] = spice.analysis.native.solveOperatingPoint(nativeCircuit, solver, options, "dc", []);
freq = spice.analysis.native.buildFrequencyAxis(analysisParams);

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
[initialSolution, stateContext, operatingPoint, dcStats] = spice.analysis.native.seedTransientAnalysis(circuit, nativeCircuit, solver, options, analysisParams.stepTime);

solutionMatrix = zeros(nativeCircuit.matrixSize(), numel(timeAxis));
solutionMatrix(:, 1) = initialSolution;
stepIterations = zeros(1, max(numel(timeAxis) - 1, 0));
stepConverged = true(1, max(numel(timeAxis) - 1, 0));
stepModes = strings(1, max(numel(timeAxis) - 1, 0));
previousSolution = initialSolution;

for idx = 2:numel(timeAxis)
    initialGuess = spice.analysis.native.chooseTransientInitialGuess(options, previousSolution, idx == 2);
    [solutionMatrix(:, idx), stateContext, stats] = spice.analysis.native.solveTransientOneStep( ...
        circuit, nativeCircuit, solver, options, stateContext, timeAxis(idx), analysisParams.stepTime, initialGuess);
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
controller = spice.analysis.native.buildDynamicController(circuit, analysisParams, options);
controller.errorNodeIndices = spice.analysis.native.dynamicTransientErrorNodeIndices(circuit, nativeCircuit);
[initialSolution, stateContext, operatingPoint, dcStats] = spice.analysis.native.seedTransientAnalysis(circuit, nativeCircuit, solver, options, controller.initialStep);

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
    [dt, hitsBreakpoint] = spice.analysis.native.limitDynamicStep(dt, currentTime, analysisParams.totalTime, controller);
    attempt = spice.analysis.native.attemptDynamicTransientStep(circuit, nativeCircuit, solver, options, stateContext, currentSolution, currentTime, dt, controller, reuseCache);
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
            dt = spice.analysis.native.updateDynamicTimeStepTR(dt, controller, attempt.voltageErrorNorm, true);
        else
            dt = spice.analysis.native.updateDynamicTimeStep(dt, controller.maxStep, attempt.lteMetric, attempt.tolerance);
        end
    else
        rejectedSteps = rejectedSteps + 1;
        if method == "TR"
            previousDt = dt;
            dt = spice.analysis.native.updateDynamicTimeStepTR(dt, controller, attempt.voltageErrorNorm, false);
            if previousDt <= controller.minStep * (1 + 1e-12) || dt <= controller.minStep * (1 + 1e-12)
                error('spice:analysis:native:DynamicStepUnderflow', ...
                    'Native dynamic TR step control reached the minimum step size without acceptance.');
            end
            if spice.analysis.native.canReuseDynamicHalfStep(attempt.reusableHalfStep, currentTime, dt, controller.breakpointTolerance)
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
period = spice.analysis.native.determineShootingPeriod(circuit);
baseStep = analysisParams.stepTime;
[initialSolution, ~, operatingPoint, dcStats] = spice.analysis.native.seedTransientAnalysis(circuit, nativeCircuit, solver, options, baseStep);

shootMaxIterations = 12;
shootTolerance = max(options.ErrorTolerance, options.ErrorTolerance * max(1, norm(initialSolution, inf)));
stateGuess = initialSolution;
residualNorm = inf;
updateNorm = inf;
converged = false;
iterationCount = 0;

for iter = 1:shootMaxIterations
    iterationCount = iter;
    [~, periodSolutionMatrix] = spice.analysis.native.integrateTransientWindow(circuit, nativeCircuit, solver, options, stateGuess, period, baseStep);
    finalState = periodSolutionMatrix(:, end);
    residual = finalState - stateGuess;
    residualNorm = norm(residual, inf);
    if residualNorm <= shootTolerance
        converged = true;
        updateNorm = 0;
        break;
    end

    jacobian = spice.analysis.native.buildShootingJacobian(circuit, nativeCircuit, solver, options, stateGuess, finalState, period, baseStep);
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
        [~, candidateSolutionMatrix] = spice.analysis.native.integrateTransientWindow(circuit, nativeCircuit, solver, options, candidate, period, baseStep);
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

[timeAxis, solutionMatrix, finalContext, stepIterations, stepModes] = spice.analysis.native.integrateTransientWindow( ...
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
[dcSolution, dcContext, stats] = spice.analysis.native.solveOperatingPoint(nativeCircuit, solver, options, "dc", []);
activeSources = spice.analysis.native.activeAcSourceNames(circuit);
if isempty(activeSources)
    error('spice:analysis:native:PzRequiresAcInput', 'PZ analysis requires at least one active AC source.');
end
outputNodes = spice.analysis.native.nodeVoltageProbeTargets(circuit);
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

signals = spice.analysis.native.buildPoleZeroSignals(gMatrix, imag(matrixAtOne), inputVector, outputNodes, nativeCircuit);

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
