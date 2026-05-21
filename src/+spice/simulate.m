function result = simulate(netlistSource, opts)
arguments
    netlistSource {mustBeTextScalar}
    opts.InputKind (1,1) string {mustBeMember(opts.InputKind, ["file", "text"])} = "file"
    opts.MatrixBackend (1,1) string {mustBeMember(opts.MatrixBackend, ["sparse", "dense", "legacySpM"])} = "sparse"
    opts.EmitPlots (1,1) logical = false
    opts.OutputDir {mustBeTextScalar} = ""
    opts.ErrorTolerance (1,1) double {mustBePositive} = 1e-6
    opts.TransientInitMethod (1,1) string {mustBeMember(opts.TransientInitMethod, ["Poweron", "DC"])} = "Poweron"
    opts.TransientMethod (1,1) string {mustBeMember(opts.TransientMethod, ["BE", "TR"])} = "BE"
    opts.TransientStepMode (1,1) string {mustBeMember(opts.TransientStepMode, ["Fix", "Dynamic"])} = "Fix"
    opts.WriteJSON (1,1) logical = true
    opts.WriteMAT (1,1) logical = true
    opts.WriteCSV (1,1) logical = true
end

options = spice.model.defaultOptions();
optionNames = fieldnames(opts);
for idx = 1:numel(optionNames)
    options.(optionNames{idx}) = opts.(optionNames{idx});
end

[sourceText, sourceName, sourcePath] = spice.util.readInput(netlistSource, options.InputKind);
spice.util.ensureLegacyPath();
spice.solver.setBackend(options.MatrixBackend);

circuit = spice.parser.parseNetlist(sourceText, SourceName=sourceName);
ir = spice.ir.build(circuit);
result = spice.analysis.run(circuit, ir, options);

result.meta.sourcePath = sourcePath;
result.meta.sourceName = sourceName;
result.meta.inputKind = options.InputKind;
result.meta.matrixBackend = options.MatrixBackend;
result.meta.emitPlots = options.EmitPlots;
result.meta.circuit = circuit.summary();

if strlength(string(options.OutputDir)) > 0 || options.EmitPlots
    artifacts = spice.output.emit(result, ...
        OutputDir=string(options.OutputDir), ...
        EmitPlots=options.EmitPlots, ...
        WriteJSON=options.WriteJSON, ...
        WriteMAT=options.WriteMAT, ...
        WriteCSV=options.WriteCSV);
    result.artifacts = artifacts;
end
end
