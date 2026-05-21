function run_all()
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(rootDir, '..', 'src')));
addpath(genpath(rootDir));

test_parser_smoke();
test_object_model();
test_simulate_file_and_text();
test_native_linear_analyses();
test_hspice_lis_parser();
test_hspice_tr0_parser();
test_regression_smoke();
test_regression_artifacts();

disp('ALL_TESTS_PASSED');
end
