function period = determineShootingPeriod(circuit)
% DETERMINESHOOTINGPERIOD Return the fundamental period for sinusoidal sources.
freqs = zeros(1, 0);
for idx = 1:numel(circuit.Elements)
    device = circuit.Elements{idx};
    if isa(device, 'spice.model.IndependentSource') ...
            && upper(string(device.Parameters.waveform)) == "SIN" ...
            && device.Parameters.freq > 0
        freqs(end + 1) = device.Parameters.freq; %#ok<AGROW>
    end
end

if isempty(freqs)
    error('spice:analysis:native:ShootingRequiresSinSource', 'Native shooting requires at least one sinusoidal source.');
end

baseFrequency = freqs(1);
for idx = 2:numel(freqs)
    baseFrequency = approximateFrequencyGcd(baseFrequency, freqs(idx));
end
if baseFrequency <= 0
    baseFrequency = min(freqs);
end
period = 1 / baseFrequency;
end

function value = approximateFrequencyGcd(a, b)
a = abs(a);
b = abs(b);
tolerance = 1e-9 * max([a, b, 1]);
while b > tolerance
    remainder = rem(a, b);
    if remainder < tolerance || abs(remainder - b) < tolerance
        value = b;
        return;
    end
    a = b;
    b = remainder;
end
value = a;
end
