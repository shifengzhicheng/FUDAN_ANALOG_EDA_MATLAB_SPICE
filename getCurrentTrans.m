function Current = getCurrentTrans(Device, port, LinerNet, x, Res)
% GETCURRENTTRANS Calculate one transient device terminal current.
% The transient netlist replaces nonlinear and dynamic devices with
% companion R/G/I/V elements.  This function maps a requested physical port
% back to the signed sum of those companion currents.

Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
dependence = LinerNet('dependence');
value = LinerNet('Value');
freq = 0;

switch Device(1)
    case 'M'
        Mdevice = find(contains(Name, Device));
        switch port
            case 'd'
                Current = calcCurrent(Mdevice(1), Res, x, Name, N1, N2, dependence, value, freq) ...
                    + calcCurrent(Mdevice(2), Res, x, Name, N1, N2, dependence, value, freq) ...
                    + calcCurrent(Mdevice(3), Res, x, Name, N1, N2, dependence, value, freq) ...
                    - calcCurrent(Mdevice(7), Res, x, Name, N1, N2, dependence, value, freq) ...
                    + calcCurrent(Mdevice(9), Res, x, Name, N1, N2, dependence, value, freq);
            case 'g'
                Current = calcCurrent(Mdevice(5), Res, x, Name, N1, N2, dependence, value, freq) ...
                    + calcCurrent(Mdevice(7), Res, x, Name, N1, N2, dependence, value, freq);
            case 's'
                Current = calcCurrent(Mdevice(11), Res, x, Name, N1, N2, dependence, value, freq) ...
                    - calcCurrent(Mdevice(1), Res, x, Name, N1, N2, dependence, value, freq) ...
                    - calcCurrent(Mdevice(2), Res, x, Name, N1, N2, dependence, value, freq) ...
                    - calcCurrent(Mdevice(3), Res, x, Name, N1, N2, dependence, value, freq) ...
                    - calcCurrent(Mdevice(5), Res, x, Name, N1, N2, dependence, value, freq);
        end

    case 'D'
        Ddevice = find(contains(Name, Device));
        switch port
            case '+'
                Current = calcCurrent(Ddevice(1), Res, x, Name, N1, N2, dependence, value, freq) ...
                    + calcCurrent(Ddevice(2), Res, x, Name, N1, N2, dependence, value, freq);
            case '-'
                Current = -calcCurrent(Ddevice(1), Res, x, Name, N1, N2, dependence, value, freq) ...
                    - calcCurrent(Ddevice(2), Res, x, Name, N1, N2, dependence, value, freq);
        end

    case 'Q'
        emitterCurrent = currentByName(['R' Device '_E'], Res, x, Name, N1, N2, dependence, value, freq) ...
            + currentByName(['G' Device '_E'], Res, x, Name, N1, N2, dependence, value, freq) ...
            + currentByName(['I' Device '_E'], Res, x, Name, N1, N2, dependence, value, freq);
        collectorCurrent = currentByName(['R' Device '_C'], Res, x, Name, N1, N2, dependence, value, freq) ...
            + currentByName(['G' Device '_C'], Res, x, Name, N1, N2, dependence, value, freq) ...
            + currentByName(['I' Device '_C'], Res, x, Name, N1, N2, dependence, value, freq);
        cbeCurrent = currentByName(['RCe' Device], Res, x, Name, N1, N2, dependence, value, freq);
        cbcCurrent = currentByName(['RCc' Device], Res, x, Name, N1, N2, dependence, value, freq);

        % BJT nonlinear companions are positive E/C -> B.  Parasitic
        % capacitance companions are positive B -> E/C.
        switch port
            case 'c'
                Current = collectorCurrent - cbcCurrent;
            case 'b'
                Current = -emitterCurrent - collectorCurrent + cbeCurrent + cbcCurrent;
            case 'e'
                Current = emitterCurrent - cbeCurrent;
        end

    case {'V', 'I', 'R', 'C', 'L', 'G', 'H', 'F', 'E'}
        Mdevice = find(contains(Name, Device));
        switch port
            case '+'
                Current = calcCurrent(Mdevice, Res, x, Name, N1, N2, dependence, value, freq);
            case '-'
                Current = -calcCurrent(Mdevice, Res, x, Name, N1, N2, dependence, value, freq);
        end
end
end

function Current = currentByName(deviceName, Res, x, Name, N1, N2, dependence, value, freq)
deviceIndex = find(strcmp(Name, deviceName), 1);
if isempty(deviceIndex)
    Current = zeros(1, size(Res, 2));
    return;
end
Current = calcCurrent(deviceIndex, Res, x, Name, N1, N2, dependence, value, freq);
end
