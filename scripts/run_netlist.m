function result = run_netlist(netlistSource, varargin)
scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
addpath(genpath(fullfile(repoRoot, 'src')));
result = spice.cli.run(netlistSource, varargin{:});
end
