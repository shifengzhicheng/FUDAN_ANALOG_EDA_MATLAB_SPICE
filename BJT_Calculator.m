%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Mos_Calculater%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 根据牛顿迭代公式得到MOS伴随器件信息
function [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(VBE, VBC, BJTarg, BJTJunctionarea, BJTflag, T)
    
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
    Ie = BJTflag * ( - If0*(exp(VBE/Vt) - 1) + alpha_r*Ir0*(exp(VBC/Vt) - 1) );
    Gbe = - If0/Vt * exp(VBE/Vt);
    Rbe_k = - 1 / Gbe;
    Gbc_e_k = alpha_r * Ir0/Vt * exp(VBC/Vt);
    Ieq_k = Ie + VBE / Rbe_k - Gbc_e_k * VBC;
    
    Ic = BJTflag * ( - Ir0*(exp(VBC/Vt) - 1) + alpha_f*If0*(exp(VBE/Vt) - 1) );
    Gbc = - Ir0/Vt * exp(VBC/Vt);
    Rbc_k = - 1 / Gbc;
    Gbe_c_k = alpha_f * If0/Vt * exp(VBE/Vt);
    Icq_k = Ic + VBC / Rbc_k - Gbe_c_k * VBE;
    
    %{
    Rbe_k = 1 * Rbe_k;
    Gbc_e_k = 1 * Gbc_e_k;
    Ieq_k = 1 * Ieq_k;
    Rbc_k = 1 * Rbc_k;
    Gbe_c_k = 1 * Gbe_c_k;
    Icq_k = 1 * Icq_k;
    %}
    
    fprintf("<BJT_calculator>result:\n\n");
    disp(Ie);
    disp(Rbe_k);
    disp(Gbc_e_k);
    disp(Ieq_k);
    disp(Ic);
    disp(Rbc_k);
    disp(Gbe_c_k);
    disp(Icq_k);
end
