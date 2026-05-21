function value = dynamicTrRelativeTolerance(options)
% DYNAMICTRRELATIVETOLERANCE Return the adaptive TR acceptance RELTOL floor.
% The nonlinear Newton tolerance still follows options.ErrorTolerance; only
% the adaptive transient controller uses this floor so the native driver
% tracks HSPICE-style waveform behavior without collapsing to picosecond
% steps on large mixed-signal examples.
value = max(3e-3, options.ErrorTolerance);
end
