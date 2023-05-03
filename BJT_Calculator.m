%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Mos_Calculater%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 根据牛顿迭代公式得到MOS伴随器件信息
function [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(VBE, VBC, BJTarg, BJTJunctionarea, BJTflag)
    
    % ########################## BJT模型定义格式如下 ##########################
    % ###### .BIPOLAR 1 Jf0 2e-12 Jr0 2e-16  alpha_f 0.995 alpha_r 0.05 #######
    % ############# Jf0 2e-12 和 Jr0 2e-16 的单位是A/um^2 ####################
    BJTarg = cell2mat(BJTarg);
    Jf0 = BJTarg(2,1);
    Jr0 = BJTarg(3,1);
    alpha_f = BJTarg(4,1);
    alpha_r = BJTarg(5,1);
    % ################################## 常数 ####################################
    q = 1.602e-19;
    k = 1.381e-23;
    T = 300;
    If0 = Jf0 * BJTJunctionarea;
    Ir0 = Jr0 * BJTJunctionarea;
    fprintf("<BJT_calculator>:\n\n");
    disp(VBE);
    disp(VBC);
    disp(If0);
    disp(Ir0);
    disp(k*T/q);
    % Ie\Ic均为流入E\C的电流
    Gbe = -q/(k*T) * If0 * exp(q/(k*T)*VBE);
    Ie = BJTflag * ( (-If0 * (exp(q/(k*T)*VBE) - 1) + alpha_r * Ir0 *(exp(q/(k*T)*VBC) - 1)) );
    
    Rbe_k = 1 / Gbe;
    Gbc_e_k = q/(k*T) * alpha_r * Ir0 * exp(q/(k*T)*VBC);
    Ieq_k = Ie - VBE / Rbe_k - Gbc_e_k * VBC;
    
    Gbc = -q/(k*T) * Ir0 * exp(q/(k*T)*VBC);
    Ic = BJTflag * ( (-Ir0 * (exp(q/(k*T)*VBC) - 1) + alpha_f * If0 *(exp(q/(k*T)*VBE) - 1)) );
    
    Rbc_k = 1 / Gbc;
    Gbe_c_k = q/(k*T) * alpha_f * If0 * exp(q/(k*T)*VBE);
    Icq_k = Ic - VBC / Rbc_k - Gbe_c_k * VBE;
    
    fprintf("<BJT_calculator>:\n\n");
    disp(Rbe_k);
    disp(Gbc_e_k);
    disp(Ieq_k);
    disp(Ie);
    disp(Rbc_k);
    disp(Gbe_c_k);
    disp(Icq_k);
    disp(Ic);
end
