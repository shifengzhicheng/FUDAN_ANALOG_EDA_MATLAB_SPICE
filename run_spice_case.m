function result = run_spice_case(caseName, opts)
% RUN_SPICE_CASE Run one legacy SPICE testcase by name or path.
% The numerical kernels are unchanged from the original top-level script;
% this function only makes the entry point parameterized and non-blocking.
arguments
    caseName {mustBeTextScalar}
    opts.EmitPlots (1,1) logical = false
    opts.FigureVisible {mustBeTextScalar} = "off"
    opts.OutputDir {mustBeTextScalar} = "picture"
    opts.ErrorTolerance (1,1) double = 1e-6
    opts.TransientInitMethod {mustBeTextScalar} = "Poweron"
    opts.TransientMethod {mustBeTextScalar} = "BE"
    opts.TransientStepMode {mustBeTextScalar} = "Fix"
end

caseName = string(caseName);
netlistPath = resolveNetlistPath(caseName);
if opts.EmitPlots
    ensureDirectory(opts.OutputDir);
end

% Keep the original parser and numerical kernels as-is; this wrapper only
% standardizes how a testcase is selected, timed, and called from automation.
[RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation] = parse_netlist(char(netlistPath));
operation = lower(string(SPICEOperation{1}{1}));
timer = tic;

switch operation
    case ".dcsweep"
        result = runDcSweep(caseName, RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation, opts);
    case ".ac"
        result = runAc(caseName, RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation, opts);
    case ".trans"
        result = runTransient(caseName, RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation, opts);
    case ".dc"
        result = runDc(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, opts);
    case ".pz"
        result = runPz(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, opts);
    case ".shoot"
        result = runShoot(caseName, RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation, opts);
    otherwise
        error('spice:legacy:UnsupportedOperation', 'Unsupported operation %s in %s.', operation, netlistPath);
end

result.caseName = caseName;
result.netlistPath = netlistPath;
result.operation = operation;
result.elapsedSeconds = toc(timer);
result.summary = sprintf('%s %s completed in %.3fs', caseName, operation, result.elapsedSeconds);
end

function result = runDcSweep(caseName, RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation, opts)
[LinerNet, MOSINFO, DIODEINFO, BJTINFO, Node_Map] = Generate_DCnetlist(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO);
deviceName = SPICEOperation{1}{2};
% Avoid eval for sweep ranges so testcase execution stays deterministic.
range = parseSweepRange(SPICEOperation{1}{3});
step = tranNumber(SPICEOperation{1}{4});
operationInfo = {deviceName, range, step};
[inputData, objects, values] = Sweep_DC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, opts.ErrorTolerance, operationInfo, PLOT, Node_Map);

for idx = 1:size(objects, 1)
    saveSignalPlot(inputData, values(idx, :), objects{idx}, caseName, objects{idx}, opts);
end

result = struct('objects', {objects}, 'axis', inputData, 'values', values);
end

function result = runAc(caseName, RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation, opts)
% AC linearization depends on the nonlinear DC operating point.
[dcNet, mos, diode, bjt, nodeMap] = Generate_DCnetlist(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO);
[dcResult, ~] = calculateDC(dcNet, mos, diode, bjt, opts.ErrorTolerance);
dcResult = [0; dcResult];
[acNet, capacitorInfo, inductorInfo] = Generate_ACnetlist(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, dcResult, nodeMap);

acMode = SPICEOperation{1}{2};
acPoint = str2double(SPICEOperation{1}{3});
startFrequency = tranNumber(SPICEOperation{1}{4});
stopFrequency = tranNumber(SPICEOperation{1}{5});
[solution, frequency, acNet, x0] = Sweep_AC(acNet, capacitorInfo, inductorInfo, {acMode, acPoint, startFrequency, stopFrequency});

[plotNodes, plotCurrents] = portMapping(PLOT, nodeMap);
[objects, frequency, gain, phase] = ValueCalcAC(plotCurrents', plotNodes', solution, frequency, acNet, nodeMap, x0);
plotFrequency = frequency;
if lower(string(acMode)) == "dec"
    % Preserve the original plotting convention: DEC sweeps are plotted on log10(f).
    plotFrequency = log10(frequency);
end

for idx = 1:size(objects, 1)
    saveSignalPlot(plotFrequency, gain(idx, :), objects{idx} + "Gain", caseName, objects{idx} + "_Gain", opts);
    saveSignalPlot(plotFrequency, rad2deg(phase(idx, :)), objects{idx} + "Phase", caseName, objects{idx} + "_Phase", opts);
end

result = struct('objects', {objects}, 'frequency', frequency, 'gain', gain, 'phase', phase);
end

function result = runTransient(caseName, RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation, opts)
[transNet, mosTrans, diodeTrans, bjtTrans, capacitorInfo, inductorInfo, sinInfo, nodeMap] = ...
    Generate_transnetlist(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO);
stopTime = str2double(SPICEOperation{1}{2});
stepTime = str2double(SPICEOperation{1}{3});
% The legacy transient kernels use a half-step companion state for startup.
initialStep = 0.5 * stepTime;

[initialResult, initialDeviceValue, capacitorVoltage, capacitorCurrent, inductorVoltage, inductorCurrent] = ...
    transientInitialState(opts.TransientInitMethod, transNet, SourceINFO, mosTrans, diodeTrans, bjtTrans, ...
    RCLINFO, MOSINFO, DIODEINFO, BJTINFO, capacitorInfo, inductorInfo, opts.ErrorTolerance, initialStep, opts.TransientMethod);

if string(opts.TransientStepMode) == "Dynamic"
    [solution, deviceValues] = TransBE_Dynamic(initialResult, initialDeviceValue, capacitorVoltage, capacitorCurrent, ...
        inductorVoltage, inductorCurrent, transNet, mosTrans, diodeTrans, bjtTrans, capacitorInfo, inductorInfo, sinInfo, ...
        opts.ErrorTolerance, initialStep, stopTime, stepTime);
else
    [solution, deviceValues] = TransTR_fix(initialResult, initialDeviceValue, capacitorVoltage, capacitorCurrent, ...
        inductorVoltage, inductorCurrent, transNet, mosTrans, diodeTrans, bjtTrans, capacitorInfo, inductorInfo, sinInfo, ...
        opts.ErrorTolerance, initialStep, stopTime, stepTime);
end

[~, x0, ~] = Gen_Matrix(transNet('Name'), transNet('N1'), transNet('N2'), transNet('dependence'), transNet('Value'));
[plotNodes, plotCurrents] = portMapping(PLOT, nodeMap);
transNet('Value') = deviceValues;
[objects, values] = ValueCalcTrans(solution, transNet, nodeMap, x0, plotNodes, plotCurrents);
time = 0:stepTime:stopTime;

for idx = 1:size(objects, 1)
    saveSignalPlot(time, values(idx, :), objects{idx}, caseName, objects{idx}, opts);
end

result = struct('objects', {objects}, 'time', time, 'values', values);
end

function result = runDc(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, opts)
[dcNet, MOSINFO, DIODEINFO, BJTINFO, nodeMap] = Generate_DCnetlist(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO);
[dcResult, x0, newValue] = calculateDC(dcNet, MOSINFO, DIODEINFO, BJTINFO, opts.ErrorTolerance);
dcResult = [0; dcResult];
dcNet('Value') = newValue';
[plotNodes, plotCurrents] = portMapping(PLOT, nodeMap);
[objects, values] = ValueCalcDC(plotNodes, plotCurrents, dcResult, x0, nodeMap, dcNet);

for idx = 1:size(objects, 1)
    fprintf('%s: %s\n', objects{idx}, num2str(values(idx)));
end

result = struct('objects', {objects}, 'values', values);
end

function result = runPz(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, opts)
% PZ analysis also starts from a DC operating point before building the AC netlist.
[dcNet, mos, diode, bjt, nodeMap] = Generate_DCnetlist(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO);
[dcResult, ~] = calculateDC(dcNet, mos, diode, bjt, opts.ErrorTolerance);
dcResult = [0; dcResult];
[acNet, capacitorInfo, inductorInfo] = Generate_ACnetlist(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, dcResult, nodeMap);
pz = Gen_PZ(acNet, capacitorInfo, inductorInfo, PLOT, nodeMap);
nodes = pz('ID');
zerosByNode = pz('zero');
polesByNode = pz('pole');

for idx = 1:length(nodes)
    fprintf('Node %d : \n', nodes(idx));
    fprintf('Zeros: \n');
    disp(zerosByNode{idx});
    fprintf('Poles: \n');
    disp(polesByNode{idx});
end

result = struct('nodes', nodes, 'zeros', {zerosByNode}, 'poles', {polesByNode});
end

function result = runShoot(caseName, RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, PLOT, SPICEOperation, opts)
[transNet, mos, diode, bjt, capacitorInfo, inductorInfo, sinInfo, nodeMap] = ...
    Generate_transnetlist(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO);
stepTime = tranNumber(SPICEOperation{1}{3});
totalTime = tranNumber(SPICEOperation{1}{2});
[solution, deviceValues, time] = shooting_method(transNet, mos, diode, bjt, capacitorInfo, inductorInfo, sinInfo, nodeMap, ...
    opts.ErrorTolerance, stepTime, totalTime, PLOT);

[~, x0, ~] = Gen_Matrix(transNet('Name'), transNet('N1'), transNet('N2'), transNet('dependence'), transNet('Value'));
transNet('Value') = deviceValues;
[plotNodes, plotCurrents] = portMapping(PLOT, nodeMap);
[objects, values] = ValueCalcTrans(solution, transNet, nodeMap, x0, plotNodes, plotCurrents);

for idx = 1:size(objects, 1)
    saveSignalPlot(time, values(idx, :), objects{idx}, caseName, objects{idx}, opts);
end

result = struct('objects', {objects}, 'time', time, 'values', values);
end

function [initialResult, initialDeviceValue, capacitorVoltage, capacitorCurrent, inductorVoltage, inductorCurrent] = ...
        transientInitialState(method, transNet, sourceInfo, mosTrans, diodeTrans, bjtTrans, rclInfo, mosInfo, diodeInfo, bjtInfo, capacitorInfo, inductorInfo, errorTolerance, initialStep, transientMethod)
if string(method) == "DC"
    [initialResult, initialDeviceValue, capacitorVoltage, capacitorCurrent, inductorVoltage, inductorCurrent] = ...
        TransInitial_byDC(transNet, mosTrans, diodeTrans, bjtTrans, rclInfo, sourceInfo, mosInfo, diodeInfo, bjtInfo, ...
        capacitorInfo, inductorInfo, errorTolerance, initialStep, transientMethod);
else
    [initialResult, initialDeviceValue, capacitorVoltage, capacitorCurrent, inductorVoltage, inductorCurrent] = ...
        TransInitial(transNet, sourceInfo, mosTrans, diodeTrans, bjtTrans, capacitorInfo, inductorInfo, errorTolerance, initialStep, transientMethod);
end
end

function saveSignalPlot(x, y, titleText, caseName, signalName, opts)
if ~opts.EmitPlots
    return;
end

% Plotting is intentionally isolated so batch runs can disable all figure I/O.
figureHandle = figure('Name', char(titleText), 'Visible', char(opts.FigureVisible));
cleanup = onCleanup(@() closeFigure(figureHandle));
plot(x, y);
title(titleText);
outputPath = fullfile(char(opts.OutputDir), char(sanitizeFileName(caseName + "_" + string(signalName) + ".png")));
saveas(figureHandle, outputPath);
delete(cleanup);
end

function netlistPath = resolveNetlistPath(caseName)
caseName = string(caseName);
if endsWith(caseName, ".sp")
    netlistPath = caseName;
else
    netlistPath = fullfile("testfile", caseName + ".sp");
end
if ~isfile(netlistPath)
    error('spice:legacy:MissingNetlist', 'Netlist not found: %s.', netlistPath);
end
end

function ensureDirectory(pathValue)
if ~isfolder(pathValue)
    mkdir(pathValue);
end
end

function range = parseSweepRange(textValue)
% Expected legacy syntax is a two-value bracketed range, for example [0,3].
tokens = regexp(char(textValue), '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
if numel(tokens) ~= 2
    error('spice:legacy:BadSweepRange', 'Expected sweep range like [0,3], got %s.', string(textValue));
end
range = [str2double(tokens{1}), str2double(tokens{2})];
end

function name = sanitizeFileName(name)
name = regexprep(string(name), '[<>:"/\\|?*]', '_');
end

function closeFigure(figureHandle)
if ishghandle(figureHandle)
    close(figureHandle);
end
end
