%% shooting method求解电路稳态响应
% 代码作者：郑志宇
% 代码重构自CalculateTrans
function [Obj, PlotValues, printTimePoint] = shooting_method(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map, Error, stepTime,PLOT)
%% 模仿Trans获取数据
%初始化
delta_t = stepTime * 0.5;

LinerNet('Value') = LinerNet('Value')';
%% 首先处理一下L，C器件的一些生成参数
CValue = CINFO('Value')';
LValue = LINFO('Value')';
CN1 = CINFO('N1');
CN2 = CINFO('N2');
LN1 = LINFO('N1');
LN2 = LINFO('N2');
CNum = size(CN1, 2);
LNum = size(LN1, 2);
CNodeMat = zeros(CNum, 2);
LNodeMat = zeros(LNum, 2);
CINFO('R') = 0.5 * delta_t ./ CValue;
LINFO('R') = 2 .*  LValue ./ delta_t;

% CL节点 - 线性网表中节点
for i = 1 : CNum
    CNodeMat(i, 1) = find(Node_Map == CN1(i));
    CNodeMat(i, 2) = find(Node_Map == CN2(i));    %相当于已经考虑零节点，不再加1
end
for i = 1 : LNum
    LNodeMat(i, 1) = find(Node_Map == LN1(i));
    LNodeMat(i, 2) = find(Node_Map == LN2(i));    %相当于已经考虑零节点，不再加1
end

CINFO('NodeMap') = CNodeMat;

LINFO('NodeMat') = LNodeMat;
%%
[Init,DeviceValue] = TranInit(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO, Error, delta_t);
LinerNet('Value') = DeviceValue;
% 零时刻输出结果记为x0
x0 = Init;
%% 首先获取电路的周期T
% 这个周期通过遍历所有的瞬态源来确定
SINFreq = SinINFO('Freq');
result = SINFreq(1);
for i = 2:length(SINFreq)
    % 使用gcd函数计算当前元素与当前最大公约数的最大公约数
    result = gcd(result, SINFreq(i));
end
% 找到频率的最大公约数，此为电路实际的周期
T = 1/result;

printTimePoint = 0:delta_t:T;

% 定义初始解x0, xT = x0 时说明电路找到稳态解，返回稳态解;
% 开始迭代过程
% 从初始迭代结果生成一个xT
[ResData,DeviceValues] =...
    Trans(LinerNet,MOSINFO,DIODEINFO,...
    CINFO,LINFO,SinINFO, Error,...
    Init, stepTime, T);

xT = ResData(:,end);

%% 牛顿迭代法开始迭代
while(var(xT - x0)>Error)
    %% 利用DeviceValues的末尾值更新LinerNet
    x0 = xT;
    LinerNet('Value') = DeviceValues(:,end);
    %% Trans函数，从x0出发，找到电路到xT的稳态解
    [ResData,DeviceValues] =...
    Trans(LinerNet,MOSINFO,DIODEINFO,...
    CINFO,LINFO,SinINFO, Error,...
    x0, delta_t, T);
    xT = ResData(:,end);
end

[~,x_0,~] = Gen_Matrix(LinerNet('Name'),LinerNet('N1'),LinerNet('N2'),LinerNet('dependence'),LinerNet('Value'));
[plotnv,plotnc] = portMapping(PLOT,Node_Map);
LinerNet('Value') = DeviceValues;
[Obj,PlotValues] = ValueCalcTrans(ResData,LinerNet,Node_Map,x_0,plotnv,plotnc);
end