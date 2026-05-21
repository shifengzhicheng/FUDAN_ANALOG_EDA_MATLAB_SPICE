function test_simulate_file_and_text()
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(rootDir, 'src')));

filePath = fullfile(rootDir, 'examples', 'netlists', 'bufferDC.sp');
fileResult = spice.simulate(filePath);
textResult = spice.simulate(fileread(filePath), InputKind="text");

assert(fileResult.analysisType == "dc");
assert(textResult.analysisType == "dc");
assert(numel(fileResult.signals) == numel(textResult.signals));
assert(abs(fileResult.signals(1).values - textResult.signals(1).values) < 1e-12);

disp('INTEGRATION_FILE_TEXT_PASSED');
end
