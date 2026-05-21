# Contributing

This project is organized as a MATLAB package under `src/+spice`.
Keep new code inside the package unless it is a script, fixture, or archived
legacy implementation.

## Development Loop

Run the full local test suite before committing:

```powershell
matlab -batch "addpath(genpath('src')); addpath(genpath('tests')); run_all"
```

Run the quick regression smoke matrix when changing parser, analysis, solver,
or output contracts:

```powershell
matlab -batch "addpath(genpath('src')); summary = spice.regression.runManifest(IncludeCases=string({'bufferDC','bufferAC','diftestSweep','bufferTrans'}), EmitPlots=false, WriteCaseArtifacts=false, WriteReports=false); disp(summary.unexpectedFailureCount)"
```

Use the full manifest for longer accuracy audits:

```powershell
matlab -batch "addpath(genpath('src')); summary = spice.regression.runManifest(); disp(summary)"
```

The full manifest includes expected-fail accuracy cases and large Dynamic/TR
transient audits, so it is not the default edit loop.

The validation ladder and expected quick-regression summary are documented in
[docs/validation.md](docs/validation.md).

## Architecture Rules

- Public entry points live in `src/+spice` and `src/+spice/+cli`.
- Parser code builds model objects and should not stamp matrices directly.
- Device classes own device-specific native stamping and probe extraction.
- Analysis dispatch lives in `src/+spice/+analysis`; numerical solve helpers
  live in `src/+spice/+solver`.
- `legacy/` is a compatibility baseline. Do not add new architecture there.
- Generated outputs belong under `runs/`, which is ignored by git.

## Change Policy

- Prefer small, testable refactors over broad rewrites.
- Keep native and legacy behavior comparable through `spice.regression`.
- When changing output schemas, update tests and README together.
- Record known numerical accuracy debt in `docs/accuracy-tracker.md`.
- Keep high-level design notes current in `docs/architecture.md`.
