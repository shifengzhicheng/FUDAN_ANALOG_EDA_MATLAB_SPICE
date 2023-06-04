%% 文件作者: 张润洲
%% BJT_Calculator
%% 根据牛顿迭代公式得到BJT伴随器件信息
function [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(VBE, VBC, BJTarg, BJTJunctionarea, BJTflag, T)

    % ########################## BJT模型定义格式如下 ##########################
    % ###### .BIPOLAR 1 Js 1e-16 alpha_f 0.995 alpha_r 0.05 Cje 1e-11 Cjc 1e-11 #######
    % ############# Js 1e-16 的单位是A/um^2, 对应BJT定义中Junctionarea的单位是um^2 ####################
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

    % Ie\Ic均为流入E\C的电流
    Ve = 0;
    Vc = 0;
    
    % 下面各个伴随器件的正负，最好根据实际的受控关系推一遍
    % 没有将受控关系写成直接简单的*BJTflag的形式。后续可以简化代码，现在为了debug便利先不改
    if BJTflag == 1
        Ve = VBE;
        Vc = VBC;
        
        Ie =  -If0*(exp(Ve/Vt) - 1) + Is*(exp(Vc/Vt) - 1) ;
        Gbe = -If0/Vt * exp(Ve/Vt);
        Rbe_k = -1/Gbe ;
        Gbc_e_k = Is/Vt * exp(Vc/Vt);
        Ieq_k = Ie - Gbe * Ve - Gbc_e_k * Vc;

        Ic = -Ir0*(exp(Vc/Vt) - 1) + Is*(exp(Ve/Vt) - 1);
        Gbc = -Ir0/Vt * exp(Vc/Vt);
        Rbc_k = -1/Gbc;
        Gbe_c_k = Is/Vt * exp(Ve/Vt);
        Icq_k = Ic - Gbc * Vc - Gbe_c_k * Ve;        
    elseif BJTflag == -1
        Ve = -VBE;
        Vc = -VBC;

        Ie = If0*(exp(Ve/Vt) - 1) - Is*(exp(Vc/Vt) - 1);
        Gbe = If0/Vt * exp(Ve/Vt);
        Rbe_k = 1/Gbe;
        Gbc_e_k = Is/Vt * exp(Vc/Vt);  % 根据实际电路中的受控关系调整了正负
        Ieq_k = Ie - Gbe * Ve + Gbc_e_k * Vc;  % Gbc_e_k相应调整

        Ic = Ir0*(exp(Vc/Vt) - 1) - Is*(exp(Ve/Vt) - 1);
        Gbc = Ir0/Vt * exp(Vc/Vt);
        Rbc_k = 1/Gbc;
        Gbe_c_k = Is/Vt * exp(Ve/Vt);  % 根据实际电路中的受控关系调整了正负
        Icq_k = Ic - Gbc * Vc + Gbe_c_k * Ve;  % Gbe_c_k相应调整  
    end
end
