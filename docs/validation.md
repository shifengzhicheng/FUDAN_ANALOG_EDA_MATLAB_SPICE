# Validation

This repository has three validation levels. Use the lowest level that gives
useful feedback during development, then run broader validation before pushing
changes that affect parser, analysis, solver, output, or regression contracts.

## Level 1: Unit and Integration Tests

Run this after ordinary code changes:

```powershell
matlab -batch "addpath(genpath('src')); addpath(genpath('tests')); run_all"
```

The suite covers parser smoke tests, object model construction, public API
file/text input, native linear and nonlinear analysis paths, HSPICE parsers,
regression smoke behavior, and regression artifact generation.

## Level 2: Quick Regression Manifest

Run this after changes to simulation behavior or normalized output:

```powershell
matlab -batch "addpath(genpath('src')); summary = spice.regression.runManifest(IncludeCases=string({'bufferDC','bufferAC','diftestSweep','bufferTrans'}), EmitPlots=false, WriteCaseArtifacts=false, WriteReports=false); fprintf('QUICK_REGRESSION total=%d unexpected=%d expected=%d passed=%d\n', summary.totalCases, summary.unexpectedFailureCount, summary.expectedFailureCount, summary.passedCount);"
```

Expected current result:

```text
QUICK_REGRESSION total=4 unexpected=0 expected=3 passed=1
```

The expected-fail cases are still valuable because they exercise known accuracy
gaps while confirming the runner classifies them correctly.

## Level 3: Full Manifest and Testcase Gallery

Run the full manifest for accuracy audits:

```powershell
matlab -batch "addpath(genpath('src')); summary = spice.regression.runManifest(); disp(summary)"
```

Run the manual testcase gallery when plots and per-case artifacts are needed:

```powershell
matlab -batch "addpath(genpath('scripts')); run_all_testcases"
```

Outputs are written under `runs/`, which is ignored by git.

The full manifest intentionally includes expected-fail and large Dynamic/TR
cases. It is slower than the normal edit loop and should be treated as an audit
run, not a quick unit test.

Expected current testcase-gallery summary with plots disabled:

```text
FULL_TESTCASE_GALLERY total=28 unexpected=0 expected=24 passed=4
```

## Static Checks

MATLAB `checkcode` is useful for touched files:

```powershell
matlab -batch "issues = checkcode(fullfile('src','+spice','+analysis','+native','run.m'), '-id'); disp(numel(issues))"
```

For package-wide refactors, check the package directory being changed and keep
new files warning-free unless there is a documented reason.

## Accuracy Tracking

Known numerical gaps are tracked in
[accuracy-tracker.md](accuracy-tracker.md). When a change improves or worsens a
manifest case, update the tracker or the manifest metadata in the same change.
