function controller = buildDynamicController(circuit, analysisParams, options)
% BUILDDYNAMICCONTROLLER Configure adaptive transient step control limits.
method = upper(string(options.TransientMethod));
baseStep = analysisParams.stepTime;
totalTime = analysisParams.totalTime;
period = fastestSinPeriod(circuit);

if method == "TR"
    if isfinite(period)
        initialStep = min(baseStep, period / 32);
        maxStep = min(max(baseStep * 32, totalTime / 20), period / 8);
        minStep = max([initialStep / 16384, period / 32768, totalTime * 1e-12]);
    else
        initialStep = baseStep;
        maxStep = max(baseStep * 32, totalTime / 20);
        minStep = max(initialStep / 16384, totalTime * 1e-12);
    end
    breakpoints = buildTransientBreakpoints(circuit, totalTime);
else
    initialStep = baseStep;
    maxStep = max(baseStep * 32, totalTime / 20);
    minStep = max(initialStep / 1024, totalTime * 1e-9);
    breakpoints = zeros(0, 1);
end

controller = struct( ...
    'method', method, ...
    'initialStep', initialStep, ...
    'minStep', minStep, ...
    'maxStep', max(initialStep, maxStep), ...
    'breakpoints', breakpoints(:), ...
    'breakpointTolerance', max(1e-15, totalTime * 1e-12), ...
    'safety', 0.9, ...
    'acceptErrorNorm', 5);
end

function period = fastestSinPeriod(circuit)
period = inf;
for idx = 1:numel(circuit.Elements)
    device = circuit.Elements{idx};
    if isa(device, 'spice.model.IndependentSource') ...
            && upper(string(device.Parameters.waveform)) == "SIN" ...
            && device.Parameters.freq > 0
        period = min(period, 1 / device.Parameters.freq);
    end
end
end

function breakpoints = buildTransientBreakpoints(circuit, totalTime)
breakpoints = zeros(0, 1);
fractions = [0, 0.25, 0.5, 0.75];
for idx = 1:numel(circuit.Elements)
    device = circuit.Elements{idx};
    if ~isa(device, 'spice.model.IndependentSource')
        continue;
    end

    parameters = device.Parameters;
    if upper(string(parameters.waveform)) ~= "SIN" || parameters.freq <= 0
        continue;
    end

    period = 1 / parameters.freq;
    delay = sourceDelay(parameters);
    cycleCount = ceil(max(totalTime - delay, 0) / period) + 1;
    for cycleIdx = 0:cycleCount
        cycleStart = delay + cycleIdx * period;
        for fracIdx = 1:numel(fractions)
            value = cycleStart + fractions(fracIdx) * period;
            if value >= 0 && value <= totalTime
                breakpoints(end + 1, 1) = value; %#ok<AGROW>
            end
        end
    end
end

breakpoints(end + 1, 1) = 0;
breakpoints(end + 1, 1) = totalTime;
scale = max(totalTime, 1);
breakpoints = unique(round(breakpoints / scale * 1e12) / 1e12 * scale, 'stable');
breakpoints = sort(breakpoints);
end

function delay = sourceDelay(parameters)
if isfield(parameters, 'delay')
    delay = double(parameters.delay);
else
    delay = 0;
end
end
