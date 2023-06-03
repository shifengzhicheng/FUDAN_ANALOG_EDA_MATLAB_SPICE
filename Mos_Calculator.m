%% 文件作者：朱瑞宸
%% Mos_Calculater
%% 根据牛顿迭代公式得到MOS伴随器件信息
function [Ikk,GMk,GDSk]=Mos_Calculator(VDSk,VGSk,Mosarg,W,L)
%   Mosarg = cell2mat(Mosarg);
%   Type = power(-1,Mosarg(1,1)); %-1是PMOS,1是NMOS
    Vth = Mosarg(2,1);
    Type = sign(Vth);
    MU = Mosarg(3,1);
    COX = Mosarg(4,1);
    LAMBDA = Mosarg(5,1);
% 根据P、NMOS不同Vth有正负，迭代公式完全是ids推导，PMOS注意也是ids方向
    if VGSk*Type < Vth*Type           % 截止区
%       Ik = 0;
        GMk = 0;
        GDSk = 0;
        Ikk = 0;
    elseif (VGSk-VDSk)*Type > Vth*Type   % 线性区
        Ik = Type*MU*COX*(W/L)*(VGSk-Vth-(1/2)*VDSk)*VDSk;
        GMk = Type*MU*COX*(W/L)*VDSk;
        GDSk = Type*MU*COX*(W/L)*(VGSk-Vth-VDSk);
        Ikk = Ik - GMk*VGSk - GDSk*VDSk;
    else                    % 饱和区
        if  Vth*Type - (VGSk-VDSk)*Type < 0.01  % 交界处，换为连续
            Ik = Type*(1/2)*MU*COX*(W/L)*(VGSk-Vth)*(VGSk-Vth)*(1+LAMBDA*(VDSk-VGSk+Vth)*Type);
            GMk = Type*MU*COX*(W/L)*(VGSk-Vth)*(1+LAMBDA*VDSk*Type)-3/2*Type*MU*COX*(W/L)*(VGSk-Vth)*(VGSk-Vth)*LAMBDA;
            GDSk = 1/2*MU*COX*(W/L)*(VGSk-Vth)*(VGSk-Vth)*LAMBDA;
            Ikk = Ik - GMk*VGSk - GDSk*VDSk;
        else
            Ik = Type*(1/2)*MU*COX*(W/L)*(VGSk-Vth)*(VGSk-Vth)*(1+LAMBDA*VDSk*Type);
            GMk = Type*MU*COX*(W/L)*(VGSk-Vth)*(1+LAMBDA*VDSk*Type);
            GDSk = 1/2*MU*COX*(W/L)*(VGSk-Vth)*(VGSk-Vth)*LAMBDA;
            Ikk = Ik - GMk*VGSk - GDSk*VDSk;
        end
    end

end
