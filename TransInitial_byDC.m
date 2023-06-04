%% 初始值方法一 DC模型解
function [InitRes, InitDeviceValue, CVi, CIi, LVi, LIi] = TransInitial_byDC(LinerNet_Trans, MOSINFO_Trans, DIODEINFO_Trans, ...
                                                                            RCLINFO, SourceINFO, MOSINFO, DIODEINFO, BJTINFO ...
                                                                            CINFO_Trans, LINFO_Trans, Error, delta_t0, TransMethod)
                                                                        
% RCL 拆开
CValue = CINFO_Trans('Value');
LValue = LINFO_Trans('Value');

CNum = size(CValue, 2);
LNum = size(LValue, 2);
% 注意LinerNet与LinerNet_DC顺序不同 但原线性器件端点序号一样, 可以利用
CLine = CINFO_Trans('CLine');
LLine = LINFO_Trans('LLine');

% 以真正的DC模型解，目的是方便获取这种初始解法的CV、LI等
[LinerNet_DC,MOSINFO_DC,DIODEINFO_DC,BJTINFO_DC,Node_Map_DC]=...
    Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO,BJTINFO);
[DCres, ~, DCDeviceValue] = calculateDC(LinerNet_DC,MOSINFO_DC,DIODEINFO_DC,BJTINFO_DC, Error);
DCres = [0; DCres];
CINFO_DC = RCLINFO('CINFO');

CNodeMat_DC = [str2double(CINFO_DC('N1')).' , str2double(CINFO_DC('N2')).'];
for i = 1 : CNum
    for j = 1:2
        CNodeMat_DC(i, j) = find(Node_Map_DC == CNodeMat_DC(i, j));
    end
end

CIi = zeros(1, CNum);
LVi = zeros(1, LNum);
CVi = DCres(CNodeMat_DC(:, 1)) - DCres(CNodeMat_DC(:, 2));
CVi = CVi.';
LIi = zeros(1, LNum);
for i = 1 : LNum
    LIi(i) = DCres(i + size(Node_Map_DC, 2) - 1);
end

% 梯形法时 - 固定步长
if(TransMethod == "TR")
    RC = 0.5 * delta_t0 ./ CValue;
    RL = 2 .* LValue ./ delta_t0;
elseif(TransMethod == "BE")
    % 后向欧拉时 - 动态步长时
    RC = delta_t0 ./ CValue;
    RL = LValue ./ delta_t0;
else
    return;
end
% 梯形法时 - 固定步长
if(TransMethod == "TR")
    VC = CVi + RC .* CIi;
    IL = LIi + delta_t0 * 0.5 * (LVi ./ LValue);
elseif(TransMethod == "BE")
    % 后向欧拉时 - 动态步长
    VC = CVi;
    IL = LIi;
else
    return;
end

% 以DC模型的解初始化Trans初始解
InitDeviceValue = LinerNet_Trans('Value');
% LinerNet中C伴随器件按R, V的顺序
InitDeviceValue(CLine + 2 * (1 : CNum) - 2) = RC.';
InitDeviceValue(CLine + 2 * (1 : CNum) - 1) = VC.';
% LinerNet中L伴随器件按I, R的顺序
InitDeviceValue(LLine + 2 * (1 : LNum) - 2) = IL.';
InitDeviceValue(LLine + 2 * (1 : LNum) - 1) = RL.';
MOSLine_DC = MOSINFO_DC('MOSLine');
MOSLine_Trans = MOSINFO_Trans('MOSLine');
MOSNum = size(MOSINFO_Trans('L'), 1);
InitDeviceValue(MOSLine_Trans : MOSLine_Trans + MOSNum * 3 - 1) = DCDeviceValue(MOSLine_DC : MOSLine_DC + MOSNum * 3 - 1);
BJTLine_DC = BJTINFO_DC('BJTLine');
BJTLine_Trans = BJTINFO_Trans('BJTLine');
BJTNum = size(BJTINFO_Trans('L'), 1);
InitDeviceValue(BJTLine_Trans : BJTLine_Trans + BJTNum * 6 - 1) = DCDeviceValue(BJTLine_DC : BJTLine_DC + BJTNum * 6 - 1);
LinerNet_Trans('Value') = InitDeviceValue;
[InitRes, ~, ~] = calculateDC(LinerNet_Trans, MOSINFO_Trans, DIODEINFO_Trans, BJTINFO_Trans, Error);
InitRes = [0;InitRes];
end


