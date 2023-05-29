%% 文件作者：郑志宇
%% 函数实现了根据初始解和步长计算出一个周期的瞬态结果
function [ResData,DeviceDatas] = ...
    Trans(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO, Error, init, delta_t, T)
%% 数据接口
CLine = CINFO('CLine');
LLine = LINFO('LLine');
CNum = size(CINFO('Name'), 2);
LNum = size(LINFO('Name'), 2);
CNodeMat = CINFO('NodeMap');
LNodeMat = LINFO('NodeMat');
%建立对SourceINFO的索引
SINLine = SinINFO('SinLine');  %LinerNet中的可变源开始行
SINAcValues = SinINFO('AcValue');
SINDcValues = SinINFO('DcValue');
SINPhase = SinINFO('Phase');
SINFreq = SinINFO('Freq');
SINNum = size(SINAcValues, 2);  %都为行向量
%% 取出上次迭代时得到的所有器件的线性值
DeviceValue = LinerNet('Value');
RC = CINFO('R').*delta_t;
RL = LINFO('R')./delta_t;

%% 根据init的值以及DeviceValue生成电容与电感的伴随器件的值
% 上一轮结束的时候产生的线性网表
if(~isempty(LNodeMat))
    LVp = init(LNodeMat(:, 1)) - init(LNodeMat(:, 2));
end
if(~isempty(CNodeMat))
    CVp = init(CNodeMat(:, 1)) - init(CNodeMat(:, 2));
end
% 接着上一轮没有替换的给换完
VC = DeviceValue(CLine + 2 * (1 : CNum) - 1);
IL = DeviceValue(LLine + 2 * (1 : LNum) - 2);
LIp = IL + LVp ./ RL;
CIp = (CVp - VC) ./ RC;
DeviceValue(CLine + 2 * (1 : CNum) - 2) = RC;
DeviceValue(LLine + 2 * (1 : LNum) - 1) = RL;
LinerNet('Value') = DeviceValue;

%% 这次取出来的所有迭代结果中器件的值以及所需要的返回解的结果
TotalSize = round(T/delta_t);

DeviceDatas = [DeviceValue,zeros(size(DeviceValue,1),TotalSize)];
ResData = [init,zeros(size(init,1),TotalSize)];

%% 开始推进 - 固定推进时间步长delta_t情况 - 迭代次数确定
% 因为固定时间步长伴随电阻器件值固定
curTime = 0;    %当前推进到的时间
t = 1;
while(t <= TotalSize)
    curTime = curTime + delta_t;
    t = t + 1;
    % 利用上轮电容电感的电流电压得到当前时刻伴随器件值
    VC = CVp + RC .* CIp;
    IL = LIp + LVp ./ RL;
    % 当前时刻可变SIN电源值
    SINV = Sin_Calculator(SINDcValues, SINAcValues, SINFreq, curTime, SINPhase); 
    LinerValue = LinerNet('Value');
    % LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
    % LinerNet中C伴随器件按R, V的顺序
    LinerValue(CLine + 2 * (1 : CNum) - 1) = VC;
    % LinerNet中L伴随器件按I, R的顺序
    LinerValue(LLine + 2 * (1 : LNum) - 2) = IL;
    % LinerNet中SINLine之后是SIN电源
    LinerValue(SINLine + (1 : SINNum) - 1) = SINV;
    LinerNet('Value') = LinerValue;
    [curTimeRes, ~, Valuep] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);

    % tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
    LinerNet('Value') = Valuep;
    % 当前结果作下一轮前值
    curTimeResData = [0; curTimeRes];

    % 记录当前响应
    ResData(:,t) = curTimeResData;
    DeviceDatas(:,t) = Valuep;
    % 因为原网表CL的端点在res靠前，索引不用变，伴随器件新增节点不关心
    if(~isempty(LNodeMat))
        LVp = curTimeResData(LNodeMat(:, 1)) - curTimeResData(LNodeMat(:, 2));
    end
    if(~isempty(CNodeMat))
        CVp = curTimeResData(CNodeMat(:, 1)) - curTimeResData(CNodeMat(:, 2));
    end
    LIp = IL + LVp ./ RL;
    CIp = (CVp - VC) ./ RC;
end
end