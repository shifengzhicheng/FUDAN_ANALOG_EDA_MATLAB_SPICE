function test_hspice_lis_parser()
% TEST_HSPICE_LIS_PARSER Verify the lightweight HSPICE audit parser.
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

audit = spice.regression.parseHspiceLis(fullfile(rootDir, 'fixtures', 'hspice', 'bufferac.lis'));
assert(numel(audit.operatingPoint.nodeIds) >= 5);
assert(any(audit.operatingPoint.nodeIds == 118));
assert(~isempty(audit.analysisBlocks));
assert(any(cellfun(@(item) item.analysisType == "ac", audit.analysisBlocks)));

disp('HSPICE_LIS_PARSER_PASSED');
end
