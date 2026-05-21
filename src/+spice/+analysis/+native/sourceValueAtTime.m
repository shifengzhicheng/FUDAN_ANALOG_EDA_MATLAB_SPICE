function value = sourceValueAtTime(parameters, timePoint)
% SOURCEVALUEATTIME Evaluate a source waveform at a transient time point.
waveform = upper(string(parameters.waveform));
switch waveform
    case {"DC", "AC"}
        value = parameters.dcValue;
    case "SIN"
        value = parameters.dcValue + parameters.acValue * sin(2 * pi * parameters.freq * timePoint + deg2rad(parameters.phase));
    otherwise
        error('spice:analysis:native:UnsupportedSourceWaveform', 'Unsupported source waveform %s.', waveform);
end
end
