# MATLAB SPICE Refactor

This repository now uses a layered architecture:

```text
src/+spice/        Public API, parser, domain model, analysis, solver, output, regression
legacy/            Preserved numerical kernels used as compatibility and regression baseline
scripts/           Batch entry points
examples/netlists/ Example netlists
tests/             Parser, integration, and regression tests
fixtures/hspice/   HSPICE reference data used for audit spot checks
docs/              Reports, archived reference material, and accuracy tracker
runs/              Generated outputs (gitignored)
```

## Core Design

The parser now builds a domain object model centered on:

- `spice.model.Circuit`
- `spice.model.Device`
- `spice.model.AnalysisRequest`
- `spice.model.Probe`
- `spice.model.ModelLibrary`

Built-in devices are created through `spice.model.DeviceFactory`, which keeps
parser logic small and makes device extension explicit.

The parser has a small preprocessing stage before object construction. It
normalizes CRLF input, strips `$` inline comments, folds `+` continuation
lines, accepts `.op` as an operating-point alias, and accepts standard
`.tran <step> <stop>` alongside the course-compatible `.trans <stop> <step>`.

## Public API

Simulate from a file:

```matlab
addpath(genpath('src'));
result = spice.simulate('examples/netlists/bufferAC.sp');
```

Simulate from raw text:

```matlab
result = spice.simulate(fileread('examples/netlists/bufferDC.sp'), InputKind="text");
```

Batch entry point:

```powershell
matlab -batch "addpath(genpath('src')); spice.cli.run('examples/netlists/bufferAC.sp','OutputDir','runs/bufferAC')"
```

Run the full testcase gallery with plots:

```powershell
matlab -batch "addpath(genpath('scripts')); run_all_testcases"
```

Manifest-driven regression run:

```powershell
matlab -batch "addpath(genpath('src')); summary = spice.regression.runManifest(); disp(summary.unexpectedFailureCount)"
```

Quick regression smoke run:

```powershell
matlab -batch "addpath(genpath('src')); summary = spice.regression.runManifest(IncludeCases=string({'bufferDC','bufferAC','diftestSweep','bufferTrans'}), EmitPlots=false, WriteCaseArtifacts=false, WriteReports=false); disp(summary.unexpectedFailureCount)"
```

## Simulation Result

`spice.simulate(...)` returns a unified `SimulationResult` struct with:

- `analysisType`
- `axis`
- `signals`
- `operatingPoint`
- `deviceState`
- `artifacts`
- `meta`

`result.meta` now keeps stable regression-oriented fields, including:

- `backend`
- `backendReason`
- `newton`
- `continuation`
- `transientMethod`
- `acceptedByRegression`

## Current Backend Strategy

The architectural layers are object-oriented, while the numerical kernels are
still being migrated incrementally.

At the moment:

- native execution exists for `dc`, `dcsweep`, `ac`, fixed-step `trans`, `Dynamic + BE` transient, `Dynamic + TR` transient, `shoot`, and `pz`
- `legacy` is the primary automated regression baseline
- HSPICE `.lis` files are used for operating-point audits, and HSPICE `.tr0` files are now used for Dynamic + TR waveform audits on the aligned transient cases

Native coverage does not automatically mean the analysis is numerically signed
off. The regression harness is the source of truth for that status.

## Regression and Accuracy Tracking

`spice.regression.manifest()` defines the current validation matrix.
`spice.regression.runManifest()` collects:

- native results
- forced legacy baselines
- HSPICE `.lis` operating-point audits when available
- HSPICE `.tr0` waveform audits for the Dynamic + TR cases that have aligned fixtures

Reports are written under `runs/regression/<case>/<analysis>/` and include:

- `summary.json`
- `signal_diff.csv`
- `max_error.csv`
- `backend_summary.txt`
- diff plots in `plots/`

Known accuracy issues and suspected legacy problems are tracked in
[accuracy-tracker.md](docs/accuracy-tracker.md).

## Extending Devices

To add a new device family:

1. Add a new subclass of `spice.model.Device`.
2. Register its prefix in `spice.model.DeviceFactory`.
3. Add native or legacy export support only where the numerical kernel needs it.

This keeps parsing, ownership, probes, and higher-level analysis wiring stable
when device coverage grows.

## Tests

Run all tests:

```powershell
matlab -batch "addpath(genpath('src')); addpath(genpath('tests')); run_all"
```

The full manifest intentionally includes expected-fail accuracy cases and
large Dynamic/TR transient audits. Use the quick regression command above for
normal edit/verify loops, and reserve the full manifest for longer audit runs.

The same test command runs in GitHub Actions on pushes and pull requests to
`main`. Development workflow and architecture rules are documented in
[CONTRIBUTING.md](CONTRIBUTING.md).
