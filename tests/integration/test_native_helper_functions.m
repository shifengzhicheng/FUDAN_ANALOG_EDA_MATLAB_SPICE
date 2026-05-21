function test_native_helper_functions()
% TEST_NATIVE_HELPER_FUNCTIONS Cover small native analysis helper contracts.
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

%% Axis builders
assert(isequal(spice.analysis.native.buildSweepAxis(0, 1, 0.5), [0 0.5 1]));
assert(isequal(spice.analysis.native.buildSweepAxis(1, 0, -0.5), [1 0.5 0]));

try
    spice.analysis.native.buildSweepAxis(0, 1, 0);
    error('test:ExpectedError', 'Expected zero sweep step to fail.');
catch err
    assert(string(err.identifier) == "spice:analysis:native:BadSweepStep");
end

params = struct('mode', "lin", 'startFreq', 10, 'stopFreq', 30, 'points', 3);
assert(isequal(spice.analysis.native.buildFrequencyAxis(params), [10 20 30]));
params.mode = "dec";
params.startFreq = 10;
params.stopFreq = 1000;
params.points = 1;
freq = spice.analysis.native.buildFrequencyAxis(params);
assert(numel(freq) == 3);
assert(abs(freq(1) - 10) < 1e-12);
assert(abs(freq(end) - 1000) < 1e-9);

%% Dynamic step bookkeeping
cache = struct('currentTime', 0.25, 'stepTime', 0.125);
assert(spice.analysis.native.canReuseDynamicHalfStep(cache, 0.25, 0.125, 0));
assert(~spice.analysis.native.canReuseDynamicHalfStep(cache, 0.25, 0.25, 0));
assert(spice.analysis.native.dominantTransientMode(["strict", "relaxed"]) == "relaxed");
assert(spice.analysis.native.dominantTransientMode(["strict", "failed"]) == "failed");

trace = spice.analysis.native.DynamicTransientTrace([1; 2], 2);
trace.recordAttempt(0.1, 0.2, 0.3);
trace.recordAttempt(0.4, 0.5, 0.6);
trace.recordAttempt(0.7, 0.8, 0.9);
trace.appendAcceptedStep(1e-9, [3; 4], 2, true, "strict", 1e-9);
trace.appendAcceptedStep(2e-9, [5; 6], 3, true, "relaxed", 1e-9);
snapshot = trace.snapshot();
assert(isequal(snapshot.timeValues, [0 1e-9 2e-9]));
assert(isequal(snapshot.solutionMatrix, [1 3 5; 2 4 6]));
assert(isequal(snapshot.stepIterations, [2; 3]));
assert(isequal(snapshot.stepConverged, [true; true]));
assert(isequal(snapshot.stepModes, ["strict"; "relaxed"]));
assert(isequal(snapshot.lteValues, [0.1; 0.4; 0.7]));

%% Circuit-derived helper selections
netlist = sprintf([ ...
    'Vin in 0 AC 0 1 0\n' ...
    'R1 in out 1k\n' ...
    'C1 out 0 1n\n' ...
    '.plotnv out\n' ...
    '.plotnv out\n' ...
    '.ac LIN 1 1 1\n' ...
    '.end\n']);
circuit = spice.parser.parseNetlist(netlist, SourceName="native-helper-test");
assert(isequal(spice.analysis.native.activeAcSourceNames(circuit), "Vin"));
assert(isequal(spice.analysis.native.nodeVoltageProbeTargets(circuit), "out"));

shootNetlist = sprintf([ ...
    'V1 in 0 SIN 0 1 1000 0\n' ...
    'V2 bias 0 SIN 0 1 2000 0\n' ...
    'R1 in 0 1k\n' ...
    '.plotnv in\n' ...
    '.shoot 1e-3 1e-5\n' ...
    '.end\n']);
shootCircuit = spice.parser.parseNetlist(shootNetlist, SourceName="native-helper-shoot-test");
assert(abs(spice.analysis.native.determineShootingPeriod(shootCircuit) - 1e-3) < 1e-15);

disp('NATIVE_HELPER_FUNCTIONS_PASSED');
end
