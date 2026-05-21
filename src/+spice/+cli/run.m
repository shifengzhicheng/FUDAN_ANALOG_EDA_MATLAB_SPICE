function result = run(netlistSource, varargin)
result = spice.simulate(netlistSource, varargin{:});

fprintf("Analysis: %s\n", result.analysisType);
fprintf("Signals: %d\n", numel(result.signals));
if isfield(result, "axis") && isfield(result.axis, "values")
    fprintf("Samples: %d\n", numel(result.axis.values));
end
if isfield(result, "artifacts") && isfield(result.artifacts, "files")
    fprintf("Artifacts written: %d\n", numel(result.artifacts.files));
end
end
