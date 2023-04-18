MOSW = {'2'};
MOSL = {'1'};
MOSMODEL = {zeros(6,1), zeros(6,1)};
MOSMODEL{2} = [2; 0.5; 1; 1; 1/12; 4e-16];
MOStype = {'n'};

MOSLine = 4;

Name = {'Rls', 'VG', 'VD', 'RM', 'GM', 'IM'};

N1 = [3,2,1,1,1,1];
N2 = [0,0,0,3,3,3];

%设初始d g s=2 2 1V
[i, gm, g] = Mos_Calculater(1, 1, MOSMODEL(:,2), 2, 1);
% arg1 = {'0.1'; '3'; '3.5'; '48'; '2'; '-0.833'};
% arg2 = {'0'; '0'; '0'; '0'; '3'; '0'};
% arg3 = {'0'; '0'; '0'; '0'; '1.0833'; '0'};

dependence = cell(1,6);
dependence{5} = [2,3];
Value = [0.1, 3, 3.5, 1/g, gm, i];

Error = 10e-5;

[res, moscurrent, x_0] = calculateDC(MOSMODEL, MOStype, MOSW, MOSL, ...
    Name, N1, N2, dependence, Value, MOSLine, Error);

