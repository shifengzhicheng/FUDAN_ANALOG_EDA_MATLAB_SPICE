# Architecture

This project is organized as a MATLAB package under `src/+spice`.
The current design separates parsing, circuit modeling, analysis dispatch,
numerical solving, output, and regression so each layer has one main reason
to change.

## Layer Map

```text
src/+spice/simulate.m              Public API
src/+spice/+cli                    Command-line entry points
src/+spice/+parser                 Netlist preprocessing and parsing
src/+spice/+model                  Circuit, analysis, device, model objects
src/+spice/+analysis               Backend selection and legacy wrapper
src/+spice/+analysis/+native       Native MNA analysis implementation
src/+spice/+solver                 Linear solver backend abstraction
src/+spice/+output                 JSON/MAT/CSV/plot artifact emission
src/+spice/+regression             Native-vs-legacy/HSPICE validation harness
legacy/                            Preserved compatibility baseline
tests/                             Parser, integration, and regression tests
scripts/                           Manual batch workflows
```

## Execution Flow

1. `spice.simulate(...)` reads file or text input and builds a `Circuit`.
2. `spice.ir.build(...)` creates stable metadata for output and regression.
3. `spice.analysis.run(...)` chooses the native backend when supported.
4. Unsupported or failing native paths fall back through `runLegacy`.
5. `spice.output.emit(...)` writes optional artifacts while the API returns a
   unified result struct.

The result struct contract is:

```text
analysisType
axis
signals
operatingPoint
deviceState
artifacts
meta
```

## Native Backend

The native backend is centered on MNA assembly and one nonlinear operating
point solver:

- `NativeCircuit` owns node/branch indexing and model lookup caches.
- `AnalysisContext` carries analysis-specific state and transient history.
- `Assembler` builds sparse MNA matrices.
- `OperatingPointSolver` handles Newton iteration and convergence checks.
- Device classes own their own native stamping and probe extraction.

`src/+spice/+analysis/+native/run.m` is intentionally kept as an orchestration
file. Lower-level responsibilities are split into package functions such as
`solveTransientOneStep`, `buildDynamicController`, `attemptDynamicTransientStep`,
`buildPoleZeroSignals`, and `determineShootingPeriod`.

Adaptive transient traces use `DynamicTransientTrace`, a preallocated recorder
for time points, solution columns, step sizes, Newton modes, and LTE metrics.
This avoids repeated dynamic array growth in long Dynamic BE/TR runs.

## Regression Harness

`spice.regression.manifest()` defines the validation matrix. Each entry declares:

- testcase name and netlist path
- analysis type
- tolerance profile
- expected-fail status
- optional HSPICE operating-point or waveform audit data

`spice.regression.runManifest()` executes native and forced-legacy results,
compares them through `compareResults`, attaches optional HSPICE audit output,
and writes reports when requested.

## Extension Rules

- Add devices as `spice.model.Device` subclasses.
- Register device prefixes in `spice.model.DeviceFactory`.
- Keep parser code focused on object construction, not matrix stamping.
- Put new native numerical behavior under `src/+spice/+analysis/+native`.
- Keep generated outputs under `runs/`.
- Update tests and docs when changing public result fields or regression status.
