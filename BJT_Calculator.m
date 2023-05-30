%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Mos_Calculater%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 根据牛顿迭代公式得到MOS伴随器件信息
function [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(VBE, VBC, BJTarg, BJTJunctionarea, BJTflag, T)
    
%     if VBE > 0.8
%        VBE = 0.8;
%     end
%     if VBC > 0.8
%        VBC = 0.8;
%     end
%     VCES = 0.2;
%     if VBC > VBE - VCES
%         VBC = VBE - VCES;
%     end
%     disp("<BJT_calculator>VBE VBC:\n\n");
%     disp(VBE);
%     disp(VBC);

    % ########################## BJT模型定义格式如下 ##########################
    % ###### .BIPOLAR 1 Is 1e-16 alpha_f 0.995 alpha_r 0.05 #######
    % ############# Jf0 2e-12 和 的单位是A/um^2 ####################
    BJTarg = cell2mat(BJTarg);
    Js = BJTarg(2,1);
    alpha_f = BJTarg(3,1);
    alpha_r = BJTarg(4,1);
    % ################################## 常数 ####################################
    q = 1.602e-19;
    k = 1.381e-23;
    Vt = k*T/q;
    Is = Js * BJTJunctionarea;
    If0 = Is / alpha_f;
    Ir0 = Is / alpha_r;
    % fprintf("<BJT_calculator>VBE VBC:\n\n");
    % disp(VBE);
    % disp(VBC);
    % Ie\Ic均为流入E\C的电流
    Ie = BJTflag * ( - If0*(exp(VBE/Vt) - 1) + Is*(exp(VBC/Vt) - 1) );
%     if Ie > 1
%         Ie = 1;
%     end
    Gbe = - If0/Vt * exp(VBE/Vt);
    Rbe_k = - 1 / Gbe;
    Gbc_e_k = Is/Vt * exp(VBC/Vt);
%     Gbc_e_k = 0;
    Ieq_k = Ie + VBE / Rbe_k - Gbc_e_k * VBC;
%     Ieq_k = 0;
    
    Ic = BJTflag * ( - Ir0*(exp(VBC/Vt) - 1) + Is*(exp(VBE/Vt) - 1) );
%     if Ic > 1
%         Ic = 1;
%     end
    Gbc = - Ir0/Vt * exp(VBC/Vt);
    Rbc_k = - 1 / Gbc;
    Gbe_c_k = Is/Vt * exp(VBE/Vt);
%     Gbe_c_k = 0;
    Icq_k = Ic + VBC / Rbc_k - Gbe_c_k * VBE;
%     Icq_k = 0;
    
    fprintf("<BJT_calculator>result:\n\n");
%     disp(Ie);
%     disp(Rbe_k);
    disp(Gbc_e_k);
    disp(Ieq_k);
%     disp(Ic);
%     disp(Rbc_k);
    disp(Gbe_c_k);
    disp(Icq_k);
end
