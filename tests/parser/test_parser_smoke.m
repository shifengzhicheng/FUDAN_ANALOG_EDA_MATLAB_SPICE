function test_parser_smoke()
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

cases = {
    fullfile(rootDir, 'examples', 'netlists', 'bufferDC.sp'), "dc";
    fullfile(rootDir, 'examples', 'netlists', 'bufferSweep.sp'), "dcsweep";
    fullfile(rootDir, 'examples', 'netlists', 'bufferAC.sp'), "ac";
    fullfile(rootDir, 'examples', 'netlists', 'bufferTrans.sp'), "trans";
    fullfile(rootDir, 'examples', 'netlists', 'bufferShoot.sp'), "shoot";
    fullfile(rootDir, 'examples', 'netlists', 'bufferPZ.sp'), "pz";
    };

for idx = 1:size(cases, 1)
    sourcePath = cases{idx, 1};
    expectedType = cases{idx, 2};
    circuit = spice.parser.parseNetlist(fileread(sourcePath), SourceName=sourcePath);
    assert(isa(circuit, 'spice.model.Circuit'));
    assert(circuit.Analysis.Type == expectedType);
    assert(circuit.elementCount() > 0);
    assert(circuit.probeCount() > 0);

    spec = circuit.toStruct();
    assert(spec.analysis.type == expectedType);
    assert(~isempty(spec.elements));
    assert(~isempty(spec.probes));
end

standardNetlist = sprintf([ ...
    '* Standard SPICE-style aliases and preprocessing\n' ...
    '.options list node\n' ...
    'V1 1 0 3V $ bare DC source value\n' ...
    'R1 1 2 1k\n' ...
    'R2 2 0\n' ...
    '+ 2k\n' ...
    '.plotnv 2\n' ...
    '.op\n' ...
    '.end\n']);
standardResult = spice.simulate(standardNetlist, InputKind="text");
assert(standardResult.analysisType == "dc");
assert(abs(standardResult.signals(1).values - 2) < 1e-9);

tranAliasNetlist = sprintf([ ...
    'V1 1 0 DC 1\n' ...
    'R1 1 0 1k\n' ...
    '.plotnv 1\n' ...
    '.tran 1e-3 2e-3\n' ...
    '.end\n']);
tranCircuit = spice.parser.parseNetlist(tranAliasNetlist, SourceName="tran-alias");
assert(tranCircuit.Analysis.Type == "trans");
assert(abs(tranCircuit.Analysis.Parameters.stepTime - 1e-3) < 1e-15);
assert(abs(tranCircuit.Analysis.Parameters.totalTime - 2e-3) < 1e-15);

disp('PARSER_SMOKE_PASSED');
end
