function [ResInit,CIp,LIp] = TranInit(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,Node_Map, Error, delta_t)
%RCL 拆开
CN1 = CINFO('N1');
CN2 = CINFO('N2');
LN1 = LINFO('N1');
LN2 = LINFO('N2');
CValue = CINFO('Value');
LValue = LINFO('Value');
CNum = size(CN1, 2);
LNum = size(LN1, 2);
CNodeMat = zeros(CNum, 2);
LNodeMat = zeros(LNum, 2);
% 注意LinerNet与LinerNet_DC顺序不同 但原线性器件端点序号一样, 可以利用
CLine = CINFO('CLine');
LLine = LINFO('LLine');
%建立对SourceINFO的索引


%CL节点 - 线性网表中节点
for i = 1 : CNum
    CNodeMat(i, 1) = find(Node_Map == CN1(i));
    CNodeMat(i, 2) = find(Node_Map == CN2(i));    %相当于已经考虑零节点，不再加1
end
for i = 1 : LNum
    LNodeMat(i, 1) = find(Node_Map == LN1(i));
    LNodeMat(i, 2) = find(Node_Map == LN2(i));    %相当于已经考虑零节点，不再加1
end

LIp = zeros(1, LNum);
LVp = zeros(1, LNum);
CIp = zeros(1, CNum);
CVp = zeros(1, CNum);
%Generate_transnetlist中CL伴随电源器件本来就为0
RC = 0.5 * delta_t ./ CValue;
RL = 2 .*  LValue ./ delta_t;
%Generate_transnetlist中使用全0为初值 - mos全截止不用改

%% 简单生成一个瞬态的初始值
VC = CVp + RC .* CIp;
IL = LIp + delta_t * 0.5 * (LVp ./ LValue);
LinerValue = LinerNet('Value');
%LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
%LinerNet中C伴随器件按R, V的顺序
LinerValue(CLine + 2 * (1 : CNum) - 2) = RC.';
LinerValue(CLine + 2 * (1 : CNum) - 1) = VC.';
%LinerNet中L伴随器件按I, R的顺序
LinerValue(LLine + 2 * (1 : LNum) - 2) = IL.';
LinerValue(LLine + 2 * (1 : LNum) - 1) = RL.';
%改为模拟斜坡源的值
LinerNet('Value') = LinerValue;
[curTimeRes, ~, ~] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
%tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
ResInit = containers.Map();
ResInit('x') = [0; curTimeRes('x')];
ResInit('MOS') = curTimeRes('MOS');
ResInit('Diode') = curTimeRes('Diode');
%因为原网表CL的端点在res靠前，索引不用变，伴随器件新增节点不关心
end