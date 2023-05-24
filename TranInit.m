%% 这个函数为瞬态生成一个简单的初始值
function [ResInit,DeviceValue] = TranInit(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO, Error, delta_t)
CValue = CINFO('Value');
LValue = LINFO('Value');
CNum = size(CValue, 1);
LNum = size(LValue, 1);
% 注意LinerNet与LinerNet_DC顺序不同 但原线性器件端点序号一样, 可以利用
CLine = CINFO('CLine');
LLine = LINFO('LLine');

RC = CINFO('R').*delta_t;
RL = LINFO('R')./delta_t;

LIp = zeros(LNum,1);
LVp = zeros(LNum,1);
CIp = zeros(CNum,1);
CVp = zeros(CNum,1);

%% 简单生成一个瞬态的初始值
VC = CVp + RC .* CIp;
IL = LIp + delta_t * 0.5 * (LVp ./ LValue);
LinerValue = LinerNet('Value');
% LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
% LinerNet中C伴随器件按R, V的顺序
LinerValue(CLine + 2 * (1 : CNum) - 2) = RC;
LinerValue(CLine + 2 * (1 : CNum) - 1) = VC;
% LinerNet中L伴随器件按I, R的顺序
LinerValue(LLine + 2 * (1 : LNum) - 2) = IL;
LinerValue(LLine + 2 * (1 : LNum) - 1) = RL;
LinerNet('Value') = LinerValue;
[curTimeRes, ~, DeviceValue] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
% tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
ResInit = [0; curTimeRes];
end