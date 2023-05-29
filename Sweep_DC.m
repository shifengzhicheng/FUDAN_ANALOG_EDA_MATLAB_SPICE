%% 文件作者：林与正
% 文件重构人：郑志宇
%{
输入:
    Name,N1,N2,dependence,Value, ...
    MOSINFO, MOSName,DIODEINFO, Diodes, Error, ..
    作扫描的DC量名称SweepInName(横轴)
    扫描起点start
    扫描终点end
    扫描步长step
    待打印信息PLOT(各图纵轴信息)
    x_0, Node_Map为了节点序号名字对应
输出:
    作扫描的DC向量InData
    要打印的各信息名称Obj
    与Obj顺序顺序对应的各信息在多个扫描点下的值矩阵Values
        #矩阵大小size(Obj) * [(stop-start)/step]
        #Obj里一个对象在各扫描点结果对应Values的一行
%}
function [InData, Obj, ResPlotData] = Sweep_DC(LinerNet, MOSINFO, DIODEINFO, Error, SweepInfo, PLOT, Node_Map)
[~, x_0, ~] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
display(x_0);
Name = LinerNet('Name');
%% 读出线性网表信息
%% 扫描信息
SweepInName = SweepInfo{1};
start = SweepInfo{2}(1);
stop = SweepInfo{2}(2);
step = SweepInfo{3};
%% MOS 二极管名
%要打印的序号值或者器件类型加端口名
[plotnv, plotCurrent] = portMapping(PLOT,Node_Map);
%扫描的器件值
InData = (start : step : stop);
%扫描次数
sweepTimes = size(InData, 2);
%扫描器件的索引
SweepInIndex = find(ismember(Name, SweepInName));
%初始化

%% 开始遍历要求的扫描点 每轮循环是一次正常DC 在Values中是一列
% 要被打印的与Obj顺序对应的是Values的行 Values哪几行要改索引向量由上得到 避免每轮都switch
DeviceValue = zeros(size(Name,2),sweepTimes);
x_res = zeros(size(x_0,1)+1,sweepTimes);
for i = 1 : sweepTimes
    %修改作扫描的值
    tValue = LinerNet('Value');
    tValue(SweepInIndex) = InData(i);
    LinerNet('Value') = tValue;
    %把上次DC的Value结果当作下次DC计算的初始解加速收敛
    [DCres, ~, Value] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
    DeviceValue(:,i) = Value';
    x_res(:,i) = [0; DCres];
end
LinerNet('Value') = DeviceValue;
[Obj,ResPlotData] = ValueCalcDC(plotnv,plotCurrent,x_res,x_0,Node_Map,LinerNet);
%mosIndexInValues\mosIndexInmosCurrents都是列向量 - 更改Values结果里要的mos管电流
end
