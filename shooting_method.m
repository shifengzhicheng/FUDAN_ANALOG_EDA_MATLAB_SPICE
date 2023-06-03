%% 文件作者：郑志宇
%% shooting method求解电路稳态响应
function [ResData,DeviceValues, printTimePoint] = shooting_method(LinerNet,MOSINFO,DIODEINFO,BJTINFO,CINFO,LINFO,SinINFO,Node_Map, Error, stepTime,TotalTime,PLOT)
%% 获取数据
LinerNet('Value') = LinerNet('Value')';
%% 首先处理一下L，C器件的一些生成参数
CValue = CINFO('Value')';
LValue = LINFO('Value')';
CINFO('R') = 0.5 ./ CValue;
LINFO('R') = 2 * LValue;
LINFO('Value') = LINFO('Value')';
CINFO('Value') = CINFO('Value')';

%% 生成一个简单的初始解
[x0,DeviceValue] = TranInit(LinerNet,MOSINFO,DIODEINFO,BJTINFO,CINFO,LINFO, Error, stepTime);
LinerNet('Value') = DeviceValue;
% 零时刻输出结果记为x0
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
printTimePoint = 0:stepTime:TotalTime;
% 定义初始解x0, xT = x0 时说明电路找到稳态解，返回稳态解;
% 开始迭代过程
% 从初始迭代结果生成一个xT
[ResData,DeviceValues] =...
    Trans(LinerNet,MOSINFO,DIODEINFO,BJTINFO,CINFO,LINFO,SinINFO,...
    Error,x0, stepTime, T);
xT = ResData(:,end);
CurError = norm(x0 - xT);
delta_t = 5*stepTime;
ErrorIt = 1e4*Error;
%% 牛顿迭代法开始迭代
while(CurError>ErrorIt)
    %% 利用某个关系来对搜索的步长与搜索起点进行调整
    %% 利用DeviceValues的末尾值更新LinerNet
    x0 = xT;
    %     [IteratorStep, x0] = DynamicStep(IteratorStep,CurError,xT,x0,T,stepTime);
    LinerNet('Value') = DeviceValues(:,end);
    %% Trans函数，从x0出发，找到电路到xT的稳态解
    [ResData,DeviceValues] =...
        Trans(LinerNet,MOSINFO,DIODEINFO,BJTINFO,CINFO,LINFO,SinINFO,...
        Error,x0, delta_t, T);
    xT = ResData(:,end);
    CurError = norm(x0-xT);
end
x0 = xT;
[ResData,DeviceValues] =...
    Trans(LinerNet,MOSINFO,DIODEINFO,BJTINFO,CINFO,LINFO,SinINFO,...
    Error,x0, stepTime, 2*T);
% l = size(ResData,2);
% ResData = ResData(:,ceil(l/2):end);
x0 = ResData(:,end);
LinerNet('Value') = DeviceValues(:,end);
[ResData,DeviceValues] =...
    Trans(LinerNet,MOSINFO,DIODEINFO,BJTINFO,...
    CINFO,LINFO,SinINFO, Error,...
    x0, stepTime, TotalTime);
end