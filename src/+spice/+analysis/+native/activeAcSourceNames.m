function names = activeAcSourceNames(circuit)
% ACTIVEACSOURCENAMES Return source names with non-zero AC excitation.
names = strings(0, 1);
for idx = 1:numel(circuit.Elements)
    device = circuit.Elements{idx};
    if isa(device, 'spice.model.VoltageSource') || isa(device, 'spice.model.CurrentSource')
        if abs(spice.analysis.native.sourcePhasor(device.Parameters)) > 0
            names(end + 1, 1) = device.Name; %#ok<AGROW>
        end
    end
end
end
