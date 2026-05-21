function [conductance, rhsCurrent] = capacitorCompanion(capacitance, dt, method, previousVoltage, previousCurrent)
% CAPACITORCOMPANION Return the capacitor companion model for one time step.
method = upper(string(method));
switch method
    case "TR"
        conductance = 2 * capacitance / dt;
        rhsCurrent = conductance * previousVoltage + previousCurrent;
    otherwise
        conductance = capacitance / dt;
        rhsCurrent = conductance * previousVoltage;
end
end
