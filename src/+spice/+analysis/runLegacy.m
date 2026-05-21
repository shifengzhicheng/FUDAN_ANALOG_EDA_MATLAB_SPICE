function result = runLegacy(circuit, ir, options, fallbackReason)
% RUNLEGACY Execute analyses on the preserved legacy numerical kernels.
% This function is the single entry point for forced legacy baselines and
% for native->legacy fallback, so regression code can collect a legacy
% result directly without going through the dispatcher side effects.
arguments
    circuit
    ir struct
    options struct
    fallbackReason (1,1) string = "legacy_requested"
end

spice.util.ensureLegacyPath();
probes = circuit.probeStructs();
legacy = spice.stamp.buildLegacyInput(circuit);
analysisType = string(circuit.Analysis.Type);

switch analysisType
    case "dc"
        result = runDc(circuit, probes, ir, legacy, options, fallbackReason);
    case "dcsweep"
        result = runDcSweep(circuit, probes, ir, legacy, options, fallbackReason);
    case "ac"
        result = runAc(circuit, probes, ir, legacy, options, fallbackReason);
    case "trans"
        result = runTransient(circuit, probes, ir, legacy, options, fallbackReason);
    case "shoot"
        result = runShoot(circuit, probes, ir, legacy, options, fallbackReason);
    case "pz"
        result = runPz(circuit, ir, legacy, options, fallbackReason);
    otherwise
        error('spice:analysis:Unsupported', 'Unsupported analysis type %s.', analysisType);
end
end

function result = runDc(circuit, probes, ir, legacy, options, fallbackReason)
[linerNet, mosInfo, diodeInfo, bjtInfo, nodeMap] = Generate_DCnetlist( ...
    legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO);
[dcRes, xLabels, deviceValues] = calculateDC(linerNet, mosInfo, diodeInfo, bjtInfo, options.ErrorTolerance);
dcVector = [0; dcRes];
linerNet('Value') = deviceValues';

axis = struct('name', "operating_point", 'values', 0, 'unit', "", 'scale', "scalar");
context = makeContext(nodeMap, dcVector, xLabels, linerNet, []);
signals = spice.output.buildSignals(probes, "dc", axis, context);

result = baseResult("dc", axis, signals, ir, circuit, options, fallbackReason);
result.operatingPoint = makeOperatingPoint(nodeMap, dcVector);
result.deviceState = makeDeviceState(linerNet('Name'), deviceValues', nodeMap);
result.meta.newton = struct('available', false, 'source', "legacy");
end

function result = runDcSweep(circuit, probes, ir, legacy, options, fallbackReason)
[linerNet, mosInfo, diodeInfo, bjtInfo, nodeMap] = Generate_DCnetlist( ...
    legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO);

analysisParams = circuit.Analysis.Parameters;
sweepValues = analysisParams.startValue:analysisParams.stepValue:analysisParams.stopValue;
sweepIndex = find(strcmp(linerNet('Name'), char(analysisParams.deviceName)), 1);
if isempty(sweepIndex)
    error('spice:analysis:DCSweepTargetNotFound', ...
        'Sweep target %s was not found in the generated netlist.', analysisParams.deviceName);
end

[~, xLabels, ~] = calculateDC(linerNet, mosInfo, diodeInfo, bjtInfo, options.ErrorTolerance);
deviceValueMatrix = zeros(numel(linerNet('Name')), numel(sweepValues));
resultMatrix = zeros(numel(xLabels) + 1, numel(sweepValues));

for idx = 1:numel(sweepValues)
    currentValues = linerNet('Value');
    currentValues(sweepIndex) = sweepValues(idx);
    linerNet('Value') = currentValues;
    [dcRes, ~, deviceValues] = calculateDC(linerNet, mosInfo, diodeInfo, bjtInfo, options.ErrorTolerance);
    deviceValueMatrix(:, idx) = deviceValues';
    resultMatrix(:, idx) = [0; dcRes];
end

linerNet('Value') = deviceValueMatrix;
axis = struct('name', "sweep", 'values', sweepValues, 'unit', "", 'scale', "linear");
context = makeContext(nodeMap, resultMatrix, xLabels, linerNet, []);
signals = spice.output.buildSignals(probes, "dcsweep", axis, context);

result = baseResult("dcsweep", axis, signals, ir, circuit, options, fallbackReason);
result.operatingPoint = makeOperatingPoint(nodeMap, resultMatrix(:, end));
result.deviceState = makeDeviceState(linerNet('Name'), deviceValueMatrix, nodeMap);
result.meta.continuation = struct('enabled', true, 'source', "legacy", 'available', false);
result.meta.newton = struct('available', false, 'source', "legacy");
result.meta.sweepTarget = analysisParams.deviceName;
end

function result = runAc(circuit, probes, ir, legacy, options, fallbackReason)
[linerNetDc, mosDc, diodeDc, bjtDc, nodeMap] = Generate_DCnetlist( ...
    legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO);
[dcRes, ~, ~] = calculateDC(linerNetDc, mosDc, diodeDc, bjtDc, options.ErrorTolerance);
dcVector = [0; dcRes];
[linerNet, cInfo, lInfo] = Generate_ACnetlist( ...
    legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO, dcVector, nodeMap);

analysisParams = circuit.Analysis.Parameters;
sweepInfo = {char(analysisParams.mode), analysisParams.points, analysisParams.startFreq, analysisParams.stopFreq};
[resultMatrix, freq, linerNet, xLabels] = Sweep_AC(linerNet, cInfo, lInfo, sweepInfo);

axis = struct('name', "frequency", 'values', freq, 'unit', "Hz", 'scale', lower(string(analysisParams.mode)));
context = makeContext(nodeMap, resultMatrix, xLabels, linerNet, freq);
signals = spice.output.buildSignals(probes, "ac", axis, context);

result = baseResult("ac", axis, signals, ir, circuit, options, fallbackReason);
result.operatingPoint = makeOperatingPoint(nodeMap, dcVector);
result.deviceState = makeDeviceState(linerNet('Name'), linerNet('Value'), nodeMap);
result.meta.newton = struct('available', false, 'source', "legacy");
end

function result = runTransient(circuit, probes, ir, legacy, options, fallbackReason)
[linerNet, mosInfo, diodeInfo, bjtInfo, cInfo, lInfo, sinInfo, nodeMap] = Generate_transnetlist( ...
    legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO);
analysisParams = circuit.Analysis.Parameters;
[initRes, initDeviceValue, cVi, cIi, lVi, lIi] = initializeTransientState( ...
    options, analysisParams.stepTime, linerNet, legacy, mosInfo, diodeInfo, bjtInfo, cInfo, lInfo);

switch options.TransientStepMode
    case "Fix"
        [resultMatrix, deviceValues] = TransTR_fix(initRes, initDeviceValue, cVi, cIi, lVi, lIi, ...
            linerNet, mosInfo, diodeInfo, bjtInfo, cInfo, lInfo, sinInfo, ...
            options.ErrorTolerance, 0.5 * analysisParams.stepTime, ...
            analysisParams.totalTime, analysisParams.stepTime);
    case "Dynamic"
        [resultMatrix, deviceValues] = TransBE_Dynamic(initRes, initDeviceValue, cVi, cIi, lVi, lIi, ...
            linerNet, mosInfo, diodeInfo, bjtInfo, cInfo, lInfo, sinInfo, ...
            options.ErrorTolerance, 0.5 * analysisParams.stepTime, ...
            analysisParams.totalTime, analysisParams.stepTime);
end

[~, xLabels, ~] = Gen_Matrix(linerNet('Name'), linerNet('N1'), linerNet('N2'), linerNet('dependence'), linerNet('Value'));
linerNet('Value') = deviceValues;
timeAxis = 0:analysisParams.stepTime:analysisParams.totalTime;
timeAxis = timeAxis(1:min(numel(timeAxis), size(resultMatrix, 2)));
resultMatrix = resultMatrix(:, 1:numel(timeAxis));
deviceValues = deviceValues(:, 1:numel(timeAxis));

axis = struct('name', "time", 'values', timeAxis, 'unit', "s", 'scale', "linear");
context = makeContext(nodeMap, resultMatrix, xLabels, linerNet, []);
signals = spice.output.buildSignals(probes, "trans", axis, context);

result = baseResult("trans", axis, signals, ir, circuit, options, fallbackReason);
result.operatingPoint = makeOperatingPoint(nodeMap, resultMatrix(:, 1));
result.deviceState = makeDeviceState(linerNet('Name'), deviceValues, nodeMap);
result.meta.newton = struct('available', false, 'source', "legacy");
end

function result = runShoot(circuit, probes, ir, legacy, options, fallbackReason)
[linerNet, mosInfo, diodeInfo, bjtInfo, cInfo, lInfo, sinInfo, nodeMap] = Generate_transnetlist( ...
    legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO);
analysisParams = circuit.Analysis.Parameters;
[resultMatrix, deviceValues, timeAxis] = shooting_method( ...
    linerNet, mosInfo, diodeInfo, bjtInfo, cInfo, lInfo, sinInfo, nodeMap, ...
    options.ErrorTolerance, analysisParams.stepTime, analysisParams.totalTime, legacy.PlotCards);
[~, xLabels, ~] = Gen_Matrix(linerNet('Name'), linerNet('N1'), linerNet('N2'), linerNet('dependence'), linerNet('Value'));
linerNet('Value') = deviceValues;

axis = struct('name', "time", 'values', timeAxis, 'unit', "s", 'scale', "linear");
context = makeContext(nodeMap, resultMatrix, xLabels, linerNet, []);
signals = spice.output.buildSignals(probes, "shoot", axis, context);

result = baseResult("shoot", axis, signals, ir, circuit, options, fallbackReason);
result.operatingPoint = makeOperatingPoint(nodeMap, resultMatrix(:, 1));
result.deviceState = makeDeviceState(linerNet('Name'), deviceValues, nodeMap);
result.meta.newton = struct('available', false, 'source', "legacy");
end

function result = runPz(circuit, ir, legacy, options, fallbackReason)
nodeOnlyPlots = legacy.PlotCards(cellfun(@(item) strcmpi(item{1}, '.plotnv'), legacy.PlotCards));
if isempty(nodeOnlyPlots)
    error('spice:analysis:PZRequiresNodeProbe', 'PZ analysis requires at least one node voltage probe.');
end

[linerNetDc, mosDc, diodeDc, bjtDc, nodeMap] = Generate_DCnetlist( ...
    legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO);
[dcRes, ~, ~] = calculateDC(linerNetDc, mosDc, diodeDc, bjtDc, options.ErrorTolerance);
dcVector = [0; dcRes];
[linerNet, cInfo, lInfo] = Generate_ACnetlist( ...
    legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO, dcVector, nodeMap);
rawResult = Gen_PZ(linerNet, cInfo, lInfo, nodeOnlyPlots, nodeMap);

nodeIds = rawResult('ID');
zeroRoots = rawResult('zero');
poleRoots = rawResult('pole');
signals = repmat(struct('name', "", 'kind', "", 'axisName', "root_index", 'axisValues', [], ...
    'unit', "rad/s", 'domain', "complex", 'values', [], 'magnitude', [], 'phaseDeg', []), 0, 1);

for idx = 1:numel(nodeIds)
    zerosForNode = zeroRoots{idx}(:).';
    polesForNode = poleRoots{idx}(:).';
    signals(end + 1, 1) = makePzSignal("Zeros(" + string(nodeIds(idx)) + ")", "zeroRoots", zerosForNode); %#ok<AGROW>
    signals(end + 1, 1) = makePzSignal("Poles(" + string(nodeIds(idx)) + ")", "poleRoots", polesForNode); %#ok<AGROW>
end

axis = struct('name', "root_index", 'values', [], 'unit', "", 'scale', "categorical");
result = baseResult("pz", axis, signals, ir, circuit, options, fallbackReason);
result.operatingPoint = makeOperatingPoint(nodeMap, dcVector);
result.deviceState = makeDeviceState(linerNet('Name'), linerNet('Value'), nodeMap);
result.meta.newton = struct('available', false, 'source', "legacy");
end

function [initRes, initDeviceValue, cVi, cIi, lVi, lIi] = initializeTransientState(options, stepTime, linerNet, legacy, mosInfo, diodeInfo, bjtInfo, cInfo, lInfo)
deltaT0 = 0.5 * stepTime;
switch options.TransientInitMethod
    case "DC"
        [initRes, initDeviceValue, cVi, cIi, lVi, lIi] = TransInitial_byDC( ...
            linerNet, mosInfo, diodeInfo, bjtInfo, ...
            legacy.RCLINFO, legacy.SourceINFO, legacy.MOSINFO, legacy.DIODEINFO, legacy.BJTINFO, ...
            cInfo, lInfo, options.ErrorTolerance, deltaT0, options.TransientMethod);
    otherwise
        [initRes, initDeviceValue, cVi, cIi, lVi, lIi] = TransInitial( ...
            linerNet, legacy.SourceINFO, mosInfo, diodeInfo, bjtInfo, ...
            cInfo, lInfo, options.ErrorTolerance, deltaT0, options.TransientMethod);
end
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

function result = baseResult(analysisType, axis, signals, ir, circuit, options, fallbackReason)
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
    'backend', "legacy", ...
    'backendReason', fallbackReason, ...
    'newton', struct(), ...
    'continuation', struct(), ...
    'probeModel', "branchSum", ...
    'dynamicStep', struct(), ...
    'shooting', struct(), ...
    'pz', struct(), ...
    'transientMethod', transientMethodForMeta(analysisType, options), ...
    'acceptedByRegression', false);
end

function context = makeContext(nodeMap, resultMatrix, xLabels, linerNet, frequencyVector)
context = struct();
context.nodeMap = nodeMap;
context.resultMatrix = resultMatrix;
context.xLabels = xLabels;
context.linerNet = linerNet;
context.frequencyVector = frequencyVector;
end

function operatingPoint = makeOperatingPoint(nodeMap, solution)
operatingPoint = struct();
operatingPoint.nodeMap = nodeMap;
operatingPoint.solution = solution;
end

function deviceState = makeDeviceState(names, values, nodeMap)
deviceState = struct();
deviceState.names = names;
deviceState.values = values;
deviceState.nodeMap = nodeMap;
end

function value = transientMethodForMeta(analysisType, options)
if any(string(analysisType) == ["trans", "shoot"])
    value = string(options.TransientMethod) + "/" + string(options.TransientStepMode);
else
    value = "";
end
end
