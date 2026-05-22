function [zc, dependence, Value, Ac, bc] = Gen_nextRes(MOSMODEL, Mostype, MOSW, MOSL, mosNum, mosNodeMat, MOSLine, MOSID, ...
                                               diodeNum, diodeNodeMat, diodeLine, Is, ...
                                               BJTMODEL, BJTtype, BJTJunctionarea, bjtNum, bjtNodeMat, BJTLine, BJTID, ...
                                               A0, b0, N1, N2, dependence, Value, zp)
% GEN_NEXTRES Update nonlinear companion devices and solve one Newton step.
% The solved MNA vector does not include ground; prepend it once so all
% device node tables can use their original ground-inclusive node numbers.

nodeSolution = [0; zp];

for mosCount = 1:mosNum
    drainVoltage = nodeSolution(mosNodeMat(mosCount, 1) + 1);
    gateVoltage = nodeSolution(mosNodeMat(mosCount, 2) + 1);
    sourceVoltage = nodeSolution(mosNodeMat(mosCount, 3) + 1);

    isNmosSourceSwapped = Mostype(mosCount) == 2 && drainVoltage < sourceVoltage && sourceVoltage ~= 0;
    isPmosSourceSwapped = Mostype(mosCount) == 1 && drainVoltage > sourceVoltage;
    companionIndex = MOSLine + 3 * (mosCount - 1);

    if isNmosSourceSwapped || isPmosSourceSwapped
        vds = sourceVoltage - drainVoltage;
        vgs = gateVoltage - drainVoltage;
        [nextIeq, nextGM, nextGDS] = Mos_Calculator(vds, vgs, MOSMODEL(:, MOSID(mosCount)), MOSW(mosCount), MOSL(mosCount));
        nextIeq = -nextIeq;
        nextGM = -nextGM;
        % Source/drain swap changes the controlling terminal for the GM stamp.
        dependence{MOSLine + 3 * mosCount - 2}(2) = mosNodeMat(mosCount, 1);
    else
        vds = drainVoltage - sourceVoltage;
        vgs = gateVoltage - sourceVoltage;
        [nextIeq, nextGM, nextGDS] = Mos_Calculator(vds, vgs, MOSMODEL(:, MOSID(mosCount)), MOSW(mosCount), MOSL(mosCount));
        dependence{MOSLine + 3 * mosCount - 2}(2) = mosNodeMat(mosCount, 3);
    end

    Value(companionIndex) = 1 / nextGDS;
    Value(companionIndex + 1) = nextGM;
    Value(companionIndex + 2) = nextIeq;
end

for diodeCount = 1:diodeNum
    pVoltage = nodeSolution(diodeNodeMat(diodeCount, 1) + 1);
    nVoltage = nodeSolution(diodeNodeMat(diodeCount, 2) + 1);
    [Gdk, Ieqk] = Diode_Calculator(pVoltage - nVoltage, Is(diodeCount), 27);
    companionIndex = diodeLine + diodeCount * 2 - 2;
    Value(companionIndex) = 1 / Gdk;
    Value(companionIndex + 1) = Ieqk;
end

bjtTemperature = 300;
for bjtCount = 1:bjtNum
    collectorVoltage = nodeSolution(bjtNodeMat(bjtCount, 1) + 1);
    baseVoltage = nodeSolution(bjtNodeMat(bjtCount, 2) + 1);
    emitterVoltage = nodeSolution(bjtNodeMat(bjtCount, 3) + 1);

    bjtPolarity = 0;
    if BJTtype(bjtCount) == 2
        bjtPolarity = 1;
    elseif BJTtype(bjtCount) == 1
        bjtPolarity = -1;
    end

    vbe = baseVoltage - emitterVoltage;
    vbc = baseVoltage - collectorVoltage;
    [nextRbe, nextGbcE, nextIeq, nextRbc, nextGbeC, nextIcq] = ...
        BJT_Calculator(vbe, vbc, BJTMODEL(:, BJTID(bjtCount)), BJTJunctionarea(bjtCount), bjtPolarity, bjtTemperature);

    companionIndex = BJTLine + 6 * (bjtCount - 1);
    Value(companionIndex) = nextRbe;
    Value(companionIndex + 1) = nextGbcE;
    Value(companionIndex + 2) = nextIeq;
    Value(companionIndex + 3) = nextRbc;
    Value(companionIndex + 4) = nextGbeC;
    Value(companionIndex + 5) = nextIcq;
end

[Ac, bc] = Gen_nextA(A0, b0, N1, N2, dependence, Value, MOSLine, mosNum, diodeLine, diodeNum, BJTLine, bjtNum);
zc = LU_solve(Ac, bc);
end
