function test_object_model()
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

sourcePath = fullfile(rootDir, 'examples', 'netlists', 'bufferAC.sp');
circuit = spice.parser.parseNetlist(fileread(sourcePath), SourceName=sourcePath);

assert(isa(circuit, 'spice.model.Circuit'));
assert(isa(circuit.Analysis, 'spice.model.AnalysisRequest'));
assert(~isempty(circuit.Elements));
assert(~isempty(circuit.Probes));
assert(isa(circuit.Elements{1}, 'spice.model.Device'));
assert(isa(circuit.Probes{1}, 'spice.model.Probe'));
assert(isa(circuit.Models.Mos{1}, 'spice.model.MosModel'));

ir = spice.ir.build(circuit);
assert(ir.analysisType == "ac");
assert(ir.meta.elementCount == circuit.elementCount());
assert(ir.meta.probeCount == circuit.probeCount());

legacy = spice.stamp.buildLegacyInput(circuit);
assert(isfield(legacy, 'RCLINFO'));
assert(isfield(legacy, 'SourceINFO'));
assert(isfield(legacy, 'PlotCards'));
assert(~isempty(legacy.PlotCards));

spice.model.DeviceFactory.register("Z", @(tokens, line) spice.model.Resistor( ...
    tokens{1}, string(tokens(2:3)), spice.util.parseNumericWithSuffix(tokens{4}), line, tokens));
customCircuit = spice.parser.parseNetlist(sprintf("Z1 1 0 1k\n.plotnv 1\n.dc\n.end"), SourceName="factory-extension");
assert(isa(customCircuit.Elements{1}, 'spice.model.Resistor'));
assert(customCircuit.Elements{1}.Name == "Z1");

disp('OBJECT_MODEL_PASSED');
end
