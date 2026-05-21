function value = sourcePhasor(parameters)
% SOURCEPHASOR Convert an independent source into its AC small-signal value.
waveform = upper(string(parameters.waveform));
if waveform == "AC"
    value = parameters.acValue * exp(1i * deg2rad(parameters.phase));
else
    value = 0;
end
end
