# Accuracy Tracker

This document tracks accuracy debt discovered while native results are being
compared against the forced legacy baseline. Legacy remains the automated
baseline for now, but it is not treated as an unquestioned gold source.
Whenever HSPICE disagrees with legacy in a material way, the issue should be
recorded here and later resolved in favor of the HSPICE-consistent behavior.

## Confirmed Native Bug

### MOS Probe Semantics template
- Case:
- Symptom:
- Native hypothesis:
- Legacy branch-sum reference:
- HSPICE note:
- Exit criterion:

### Several otherwise-stable MOS cases still fail on current probe extraction
- Cases: `bufferDC`, `bufferAC`, `SmosAC`
- Symptom: node voltages and operating points are close, but one or more device current probes still miss the legacy baseline enough to fail regression.
- Primary suspects: `currentForProbe(...)` sign conventions, port mapping, or branch/current reconstruction for MOS devices.
- Exit criterion: those cases leave `expectedFail` and remain green under the same regression tolerances.

### BJT Small-Signal Sign/Cap template
- Case:
- Symptom:
- Native hypothesis:
- Legacy branch-sum reference:
- HSPICE note:
- Exit criterion:

### BJT small-signal AC still deviates materially on amplifier-class circuits
- Cases: `bjtAmplifierAC`, likely also `dbmixerAC`
- Symptom: native AC can run, but the current implementation is still far from the legacy baseline on BJT-heavy cases.
- Primary suspects: BJT `gm/gpi/cmu/cpi` sign conventions, collector/base/emitter current definitions, or AC operating point reuse.
- Exit criterion: regression passes against legacy and HSPICE operating-point audit stays consistent.

### Dynamic Step Controller template
- Case:
- Symptom:
- Native hypothesis:
- Legacy branch-sum reference:
- HSPICE note:
- Exit criterion:

### Fixed-step native transient is executable but not yet numerically accepted
- Cases: `bufferTrans`, `bjtAmplifierTrans`, `dbmixerTrans`, `diftestTrans`
- Symptom: waveforms can be produced, but sampled traces still exceed transient regression tolerances.
- Primary suspects: per-step initial guess policy, companion history updates, nonlinear device re-linearization, and current probe extraction.
- Exit criterion: all fixed-step transient cases pass regression without relying on relaxed convergence.

### Dynamic + TR native path is enabled, but full regression sign-off is still pending
- Cases: `bufferTransDynamicTR`, `bjtAmplifierTransDynamicTR`
- Symptom: small integration cases now run on the native backend, but large example-netlist regression remains expected-fail and is currently too slow for the quick test budget.
- Primary suspects: adaptive-step acceptance policy under TR, expensive repeated Newton solves in step-doubling mode, and heavy-example convergence/runtime behavior rather than parser/backend dispatch.
- Exit criterion: the manifest cases finish inside the normal regression budget and pass comparison without relying on relaxed convergence.

### Dynamic + TR now uses HSPICE-aligned netlists and DC initialization, but native still underflows on the large audit cases
- Cases: `bufferTransDynamicTR`, `bjtAmplifierTransDynamicTR`
- Symptom: the regression entries now point at parser-friendly netlists that match the HSPICE `.tr0` fixtures and force `TransientInitMethod="DC"`, yet native Dynamic + TR still reaches `DynamicStepUnderflow` or `NonlinearDiverged` before full sign-off.
- Native hypothesis: the remaining gap is in the Dynamic + TR integrator itself rather than in the old netlist mismatch; likely contributors are step-doubling acceptance policy, hidden-state stiffness, and remaining variable-step TR history handling limitations.
- HSPICE note: waveform gating is now wired to `.tr0` node voltages for these cases, so future fixes can be judged against the right reference instead of legacy-only behavior.
- Exit criterion: native completes both HSPICE-aligned cases, writes HSPICE waveform diff reports, and leaves `expectedFail`.

## Legacy Suspicion

### Legacy parasitic companion reconstruction is hidden inside the bridge layer
- Files: [buildLegacyInput.m](C:\Users\zhiyu\Documents\Projects\FUDAN_ANALOG_EDA_MATLAB_SPICE\src\+spice\+stamp\buildLegacyInput.m), [LegacyCollector.m](C:\Users\zhiyu\Documents\Projects\FUDAN_ANALOG_EDA_MATLAB_SPICE\src\+spice\+stamp\LegacyCollector.m)
- Symptom: `LegacyCollector.build()` injects `compCINFO(...)` after object-model export, so legacy parasitics are re-synthesized in the bridge rather than coming directly from the parsed device objects.
- Risk: native and legacy may disagree because they are not consuming exactly the same capacitor/parasitic interpretation.
- Follow-up: compare bridge-generated `CINFO` against HSPICE operating-point and AC behavior before tightening AC/transient tolerances.

### Some transient netlists rely on HSPICE-tolerated nonstandard numeric suffixes
- Case: `bufferTrans.sp`
- Evidence: `buffertrans.lis` logs warnings for `1e-9s` and `2e-7s` being interpreted as nonstandard numbers.
- Risk: parser behavior can silently diverge across native, legacy, and HSPICE if suffix normalization is inconsistent.
- Follow-up: keep suffix parsing explicit and avoid treating the legacy parser as authoritative when HSPICE already emitted a warning.

### The original Dynamic + TR regression entries were not actually aligned with the HSPICE fixtures
- Cases: old `bufferTransDynamicTR`, old `bjtAmplifierTransDynamicTR`
- Symptom: the repo examples used different transient stop times, source amplitudes, and startup assumptions than the `.tr0` fixtures they were being compared against.
- Resolution: the regression manifest now points at dedicated HSPICE-aligned parser-friendly netlists and forces DC initialization for those audit cases.

## Need HSPICE Arbitration

### Shooting Jacobian template
- Case:
- Symptom:
- Native hypothesis:
- Legacy branch-sum reference:
- HSPICE note:
- Exit criterion:

### PZ Descriptor Consistency template
- Case:
- Symptom:
- Native hypothesis:
- Legacy branch-sum reference:
- HSPICE note:
- Exit criterion:

### DC sweep disagreements should be resolved with HSPICE before calling legacy a gold standard
- Cases: `bufferSweep`, `bjtAmplifierSweep`, `invertbufferSweep`, `diftestSweep`
- Symptom: native sweep is wired up, but several cases still sit outside the current DC tolerance band relative to legacy.
- Decision needed: determine whether the disagreement is from native continuation/Newton policy or from legacy sweep semantics.
- Required evidence: compare against HSPICE `.lis` transfer tables before locking tolerances.

### BJT AC lacks a dedicated HSPICE `.lis` fixture in the current repo snapshot
- Case: `bjtAmplifierAC`
- Symptom: there is a source netlist fixture, but no matching `.lis` text report was found alongside the other HSPICE references.
- Risk: legacy-only validation can hide a shared modeling error.
- Follow-up: regenerate or locate a text `.lis` reference before declaring BJT AC complete.

## Closed

- None yet.
