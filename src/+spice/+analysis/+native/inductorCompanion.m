function [seriesCoeff, rhsValue] = inductorCompanion(inductance, dt, method, previousCurrent, previousVoltage)
% INDUCTORCOMPANION Return the inductor companion branch equation terms.
method = upper(string(method));
switch method
    case "TR"
        seriesCoeff = 2 * inductance / dt;
        rhsValue = -seriesCoeff * previousCurrent - previousVoltage;
    otherwise
        seriesCoeff = inductance / dt;
        rhsValue = -seriesCoeff * previousCurrent;
end
end
