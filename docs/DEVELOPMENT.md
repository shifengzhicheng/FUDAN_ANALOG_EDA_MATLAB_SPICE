# Development Guide

This repository is a MATLAB SPICE-style simulator.  The current engineering
goal is to keep the legacy numerical behavior stable while making entry
points, solver boundaries, and regression testing explicit.

## Main Entry Points

- `Top_module.m`: interactive legacy entry point.  It selects one testcase and
  calls `run_spice_case`.
- `run_spice_case.m`: programmatic entry point for one netlist.  Use this for
  scripts, tests, and profiling.
- `run_all_cases.m`: regression entry point for every root-level
  `testfile/*.sp` testcase.  Reference folders under `testfile/test_hspice`
  are intentionally skipped.

## Solver Boundaries

- Netlist generation still uses the project-owned data structures and the
  legacy `SpM` sparse matrix container.
- `LU_solve.m` is the linear solve boundary.  It converts `SpM` to MATLAB's
  built-in sparse matrix and uses backslash for pivoting and performance.
- AC stamping is handled by `Gen_NextACmatrix.m`.  It restores the ground row
  and column only while stamping C/L admittances, then removes them before
  solving.
- PZ analysis in `Gen_PZ.m` intentionally converts to dense form once because
  it calls dense operations such as `det`, `eig`, and `residue`.

## Regression Commands

Run a fast mixed smoke set:

```matlab
addpath(pwd);
cases = string({'bufferDC','diftestSweep','bufferAC','RCPZ','bufferTrans'});
for c = cases
    r = run_spice_case(c);
    fprintf('PASS %s %s %.3fs\n', c, r.operation, r.elapsedSeconds);
end
```

Run all project-owned testcases:

```matlab
addpath(pwd);
summary = run_all_cases(EmitPlots=false);
assert(summary.failedCount == 0);
```

Run static checks for recently touched files:

```matlab
files = string({'run_spice_case.m','run_all_cases.m','Trans.m','Gen_nextRes.m'});
for f = files
    issues = checkcode(f, '-id');
    assert(isempty(issues), f);
end
```

## Refactoring Rules

- Preserve numerical outputs unless a change is explicitly intended to improve
  accuracy and is backed by comparison data.
- Keep comments around non-obvious numerical boundaries: companion models,
  ground-row handling, sparse/dense conversions, and convergence guards.
- Avoid debug printing inside inner loops or testcase-wide utilities.  Batch
  output should report testcase status and requested simulation results only.
- Prefer focused commits with a reproducible MATLAB command in the commit or
  review notes.

## Current Known Notes

- `bufferPZ` can emit near-singular matrix warnings while still completing.
  Treat this as a numerical conditioning warning, not a regression failure.
- `.shoot` cases are intentionally more expensive than DC/AC/PZ cases.  The
  current heavy case is `dbmixerShoot`, which is expected to take tens of
  seconds on MATLAB R2023b.
