function test_hspice_tr0_parser()
% TEST_HSPICE_TR0_PARSER Verify the minimal HSPICE transient parser.
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

bufferAudit = spice.regression.parseHspiceTr0(fullfile(rootDir, 'fixtures', 'hspice', 'buffertrans.tr0'));
assert(bufferAudit.rowCount > 10);
assert(all(diff(bufferAudit.time) >= 0));
assert(any(bufferAudit.variableNames == "104"));

bjtAudit = spice.regression.parseHspiceTr0(fullfile(rootDir, 'fixtures', 'hspice', 'bjtamplifiertrans.tr0'));
assert(bjtAudit.rowCount > 10);
assert(all(diff(bjtAudit.time) >= 0));
assert(any(bjtAudit.variableNames == "108"));

disp('HSPICE_TR0_PARSER_PASSED');
end
