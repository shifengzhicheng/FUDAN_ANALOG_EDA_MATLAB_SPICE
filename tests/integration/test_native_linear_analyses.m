function test_native_linear_analyses()
% TEST_NATIVE_LINEAR_ANALYSES Cover the native linear path and fallback contracts.
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

%% Solver backend selection is shared by set/get and simulate()
spice.solver.setBackend("dense");
assert(spice.solver.getBackend() == "dense");
spice.solver.setBackend("sparse");
assert(spice.solver.getBackend() == "sparse");

%% Native assembler grows without changing sparse matrix semantics
assembler = spice.analysis.native.Assembler(3, 1);
assembler.addConductance(1, 2, 2);
assembler.addConductance(2, 3, 3);
[matrix, rhs] = assembler.build();
assert(issparse(matrix));
assert(norm(full(matrix) - [2 -2 0; -2 5 -3; 0 -3 3], inf) < 1e-12);
assert(isequal(rhs, zeros(3, 1)));

%% Native DC
netlistDc = sprintf([
    'V1 1 0 DC 10\n' ...
    'R1 1 2 1000\n' ...
    'R2 2 0 1000\n' ...
    '.plotnv 2\n' ...
    '.plotnc R1(+)\n' ...
    '.dc\n' ...
    '.end\n']);
resultDc = spice.simulate(netlistDc, InputKind="text");
assert(resultDc.meta.backend == "native");
assert(abs(resultDc.signals(1).values - 5) < 1e-9);
assert(abs(resultDc.signals(2).values - 5e-3) < 1e-9);

circuitDc = spice.parser.parseNetlist(netlistDc, SourceName="branch-cache-smoke");
nativeCircuitDc = spice.analysis.native.NativeCircuit(circuitDc);
nativeCircuitDc.configureAnalysis("dc");
branchIndexBefore = nativeCircuitDc.branchVarIndex("V1");
nativeCircuitDc.configureAnalysis("dc");
assert(nativeCircuitDc.branchVarIndex("V1") == branchIndexBefore);

%% Native AC
fc = 1 / (2 * pi * 1000 * 1e-6);
netlistAc = sprintf([
    'Vin 1 0 AC 0 1 0\n' ...
    'R1 1 2 1000\n' ...
    'C1 2 0 1e-6\n' ...
    '.plotnv 2\n' ...
    '.ac LIN 1 %.15g %.15g\n' ...
    '.end\n'], fc, fc);
resultAc = spice.simulate(netlistAc, InputKind="text");
assert(resultAc.meta.backend == "native");
assert(abs(resultAc.signals(1).magnitude - 1 / sqrt(2)) < 5e-3);

%% Native fixed-step transient
netlistTrans = sprintf([
    'V1 1 0 DC 1\n' ...
    'R1 1 2 1000\n' ...
    'C1 2 0 1e-6\n' ...
    '.plotnv 2\n' ...
    '.plotnc C1(+)\n' ...
    '.trans 0.005 0.001\n' ...
    '.end\n']);
resultTrans = spice.simulate(netlistTrans, InputKind="text", TransientMethod="BE", TransientStepMode="Fix");
assert(resultTrans.meta.backend == "native");
nodeTrace = resultTrans.signals(1).values;
assert(abs(nodeTrace(1)) < 1e-12);
assert(all(diff(nodeTrace) >= -1e-12));
assert(nodeTrace(end) > 0.9);

%% Nonlinear native path is now active for migrated analyses
bufferDc = spice.simulate(fullfile(rootDir, 'examples', 'netlists', 'bufferDC.sp'));
assert(bufferDc.meta.backend == "native");

%% Dynamic BE transient now uses the native backend
netlistDynamic = sprintf([ ...
    'V1 1 0 DC 1\n' ...
    'R1 1 2 1000\n' ...
    'C1 2 0 1e-6\n' ...
    '.plotnv 2\n' ...
    '.trans 0.02 0.001\n' ...
    '.end\n']);
dynamicResult = spice.simulate(netlistDynamic, InputKind="text", TransientMethod="BE", TransientStepMode="Dynamic");
assert(dynamicResult.meta.backend == "native");
assert(dynamicResult.meta.dynamicStep.acceptedSteps > 0);
assert(any(abs(diff(dynamicResult.axis.values) - diff(dynamicResult.axis.values(1:min(2, end)))) > 0));

%% Dynamic TR now uses the native backend too
dynamicTrResult = simulateQuietly(netlistDynamic, InputKind="text", TransientMethod="TR", TransientStepMode="Dynamic");
assert(dynamicTrResult.analysisType == "trans");
assert(dynamicTrResult.meta.transientMethod == "TR/Dynamic");
if dynamicTrResult.meta.backend == "native"
    assert(dynamicTrResult.meta.dynamicStep.acceptedSteps > 0);
    assert(any(abs(diff(dynamicTrResult.axis.values) - diff(dynamicTrResult.axis.values(1:min(2, end)))) > 0));
    assert(dynamicTrResult.meta.dynamicStep.breakpointHits >= 0);
    assert(~dynamicTrResult.meta.newton.relaxedUsed);
else
    assert(contains(string(dynamicTrResult.meta.backendReason), "native_runtime_error:spice:analysis:native:DynamicStepUnderflow"));
end

%% PZ and shooting now have native paths
pzNetlist = sprintf([ ...
    'Vin 1 0 AC 0 1 0\n' ...
    'R1 1 2 1000\n' ...
    'C1 2 0 1e-6\n' ...
    '.plotnv 2\n' ...
    '.pz\n' ...
    '.end\n']);
pzResult = simulateQuietly(pzNetlist, InputKind="text");
assert(pzResult.meta.backend == "native");
assert(pzResult.meta.pz.matrixForm == "descriptor_mna");

shootNetlist = sprintf([ ...
    'Vin 1 0 SIN 0 1 1e6 0\n' ...
    'R1 1 2 1000\n' ...
    'C1 2 0 1e-9\n' ...
    '.plotnv 2\n' ...
    '.shoot 2e-6 1e-8\n' ...
    '.end\n']);
shootResult = simulateQuietly(shootNetlist, InputKind="text");
assert(shootResult.meta.backend == "native");
assert(shootResult.meta.shooting.jacobianMethod == "finite_difference");
assert(isfield(shootResult.meta.shooting, 'converged'));

disp('NATIVE_LINEAR_ANALYSES_PASSED');
end

function result = simulateQuietly(varargin)
[~, result] = evalc('spice.simulate(varargin{:})');
end
