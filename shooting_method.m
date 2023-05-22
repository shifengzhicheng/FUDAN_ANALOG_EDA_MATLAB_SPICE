%% shooting method求解电路稳态响应
function [Obj, Values, printTimePoint] = shooting_method(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map, Error, stepTime,PLOT)
%% 模仿Trans获取数据
%初始化
delta_t = stepTime * 0.5;

[Init,CIp,LIp] = TranInit(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,Node_Map, Error, delta_t);

% 零时刻输出结果记为x0
x0 = Init('x');
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
% 定义初始解x0, xT = x0 时说明电路找到稳态解，返回稳态解;
% 开始迭代过程
% 从初始迭代结果生成一个xT
[ResData,CData,LData] =...
    Trans(LinerNet,MOSINFO,DIODEINFO,...
    CINFO,LINFO,SinINFO,Node_Map, Error,...
    Init, CIp, LIp, stepTime, T);
ResSolve = ResData('x');
xT = ResSolve(:,end);


%% 沿用CalcTrans的计算传值方式
[~, x_0, ~] = Gen_Matrix(LinerNet('Name'), LinerNet('N1'), LinerNet('N2'), LinerNet('dependence'), LinerNet('Value')); 
printTimePoint = 0 : stepTime : T;
[mosIndexInValues, mosIndexInmosCurrents, ...
    dioIndexInValues, dioIndexIndiodeCurrents, ...
    VIndexInValues, VIndexInDCres, ...
    IIndexInValues, IIndexInValue, ...
    RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
    CIndexInValues, CIndexInCIp,...
    LIndexInValues, LIndexInLIp,...
    Obj, Values, plotnv] = PLOTIndexInRes(x_0, PLOT, Node_Map, size(printTimePoint,2), LinerNet, MOSINFO('Name'), DIODEINFO('Name'),CINFO('Name') ,LINFO('Name'));
nvNum = size(plotnv, 1);

%% 牛顿迭代法开始迭代
while(var(xT - x0)>Error)
    x0 = xT;
    %% Trans函数，从x0出发，找到电路到xT的稳态解
    [ResData,CData,LData] =...
    Trans(LinerNet,MOSINFO,DIODEINFO,...
    CINFO,LINFO,SinINFO,Node_Map, Error,...
    Init, CIp, LIp, stepTime, T);
    Init('x')= x0;
    InitMOS = ResData('MOS');
    Init('MOS') = InitMOS(:,1);
    InitDiode = ResData('Diode');
    Init('Diode') = InitDiode(:,1);
    ResSolve = ResData('x');
    if(~isempty(LData))
        LIp = LData(end);
    end
    if(~isempty(CData))
        CIp = CData(end);
    end
    xT = ResSolve(:,end);
end

Values = updateValues( ResData('x'), LinerNet('Value'), ResData('MOS'), ResData('Diode'), CData, LData,...
    plotnv,...
    mosIndexInValues, mosIndexInmosCurrents, ...
    dioIndexInValues, dioIndexIndiodeCurrents, ...
    VIndexInValues, VIndexInDCres, ...
    IIndexInValues, IIndexInValue, ...
    RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
    CIndexInValues, CIndexInCIp,...
    LIndexInValues, LIndexInLIp,...
    Values, nvNum);

end