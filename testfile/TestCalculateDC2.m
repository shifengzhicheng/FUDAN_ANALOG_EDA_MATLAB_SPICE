MOSW = {'1'};
MOSL = {'1'};
MOSMODEL = {zeros(6,1), zeros(6,1)};
MOSMODEL{1} = [1; -1; 1; 0.5; 1; 4e-16];
MOStype = {'p'};

MOSLine = 6;

Name = {'RlsD', 'RlsS', 'RloadG', 'VG', 'VDD', 'RM', 'GM', 'IM'};

N1 = [1, 5, 4, 4, 1, 5, 5, 5];
N2 = [2, 0, 3, 0, 0, 2, 2, 2];

[i, gm, g] = Mos_Calculater(-0.5, -0.5, MOSMODEL(:,1), 1, 1);  %初始解

dependence = cell(1,8);
dependence{7} = [3,2];
Value = [1, 1, 2, 2, 5, 1/g, gm, i];

Error = 10e-5;

[res2,x_0] = calculateDC(MOSMODEL, MOStype, MOSW, MOSL, ...
    Name, N1, N2, dependence, Value, MOSLine, Error);
