MOSW = {'2', '1'};
MOSL = {'1', '1'};
MOSMODEL = {zeros(6,1), zeros(6,1)};
MOSMODEL{1} = [1; -1; 1; 1; 3; 4e-16];%p
MOSMODEL{2} = [2; 0.5; 1; 1; 0.5; 4e-16];%n

MOStype = {'p', 'n'};

MOSLine = 3;

Name = {'VDD', 'VG', 'RM1', 'GM1', 'IM1', 'RM2', 'GM2', 'IM2'};

N1 = [1, 2, 3, 3, 3, 0, 0, 0];
N2 = [0, 0, 1, 1, 1, 3, 3, 3];

[i1, gm1, g1] = Mos_Calculator(-1, -1.8, MOSMODEL(:,1), 2, 1);  %p初始解
[i2, gm2, g2] = Mos_Calculator(1.5, 1.5, MOSMODEL(:,2), 1, 1);  %n初始解

dependence = cell(1,8);
dependence{4} = [2, 1];%pmos vgs
dependence{7} = [2, 0];%nmos vgs
Value = [3, 1.5, 1/g1, gm1, i1, 1/g2, gm2, i2];

Error = 10e-6;

[resINV, mIs, x0] = calculateDC(MOSMODEL, MOStype, MOSW, MOSL, ...
    Name, N1, N2, dependence, Value, MOSLine, Error);
