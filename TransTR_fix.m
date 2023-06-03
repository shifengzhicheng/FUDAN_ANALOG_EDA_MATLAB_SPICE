%% 文件作者: 林与正
% 梯形法固定步长瞬态推进过程
function [ResData, DeviceDatas] = TransTR_fix(InitRes, InitDeviceValue, CVp, CIp, LVp, LIp,...
                                                LinerNet, MOSINFO, DIODEINFO,BJTINFO, CINFO, LINFO, SinINFO, ...
                                                Error, delta_t, stopTime, stepTime)                                       
                                            
% CL信息
CValue = CINFO('Value');
LValue = LINFO('Value');

CNodeMat = CINFO('NodeMat');
LNodeMat = LINFO('NodeMat');

CNum = size(CValue, 2);
LNum = size(LValue, 2);
% 注意LinerNet与LinerNet_DC顺序不同 但原线性器件端点序号一样, 可以利用
CLine = CINFO('CLine');
LLine = LINFO('LLine');

% Sin信息
% 建立对SourceINFO的索引
SINLine = SinINFO('SinLine');  %LinerNet中的可变源开始行
SINAcValues = SinINFO('AcValue');
SINDcValues = SinINFO('DcValue');
SINPhase = SinINFO('Phase');
SINFreq = SinINFO('Freq');
SINNum = size(SINAcValues, 2);  %都为行向量

% 总打印次数
plotTimeNum = size((0:stepTime:stopTime), 2);
ResData = zeros(size(InitRes, 1), plotTimeNum);
DeviceDatas = zeros(plotTimeNum, size(InitDeviceValue, 2));

% t=0值
ResData(:, 1) = InitRes;
DeviceDatas(1, :) = InitDeviceValue;

%% 开始推进 - 固定推进时间步长delta_t情况 - 迭代次数确定
%因为固定时间步长伴随电阻器件值固定
RC = 0.5 * delta_t ./ CValue;
RL = 2 .*  LValue ./ delta_t;
curPlotTime = stepTime;  % 下次要打印的时间
% 前已加入零时刻值Values(:, 1)
plotCount = 1;
curTime = 0;    %当前推进到的时间

while(plotCount < plotTimeNum)
    curTime = curTime + delta_t;
    % 利用上轮电容电感的电流电压得到当前时刻伴随器件值
    %    display(curTime)
    VC = CVp + RC .* CIp;
    IL = LIp + delta_t * 0.5 * (LVp ./ LValue);
    % 当前时刻可变SIN电源值
    SINV = Sin_Calculator(SINDcValues, SINAcValues, SINFreq, curTime, SINPhase);  %行
    LinerValue = LinerNet('Value');
    % LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
    % LinerNet中C伴随器件按R, V的顺序
    LinerValue(CLine + 2 * (1 : CNum) - 2) = RC.';
    LinerValue(CLine + 2 * (1 : CNum) - 1) = VC.';
    % LinerNet中L伴随器件按I, R的顺序
    LinerValue(LLine + 2 * (1 : LNum) - 2) = IL.';
    LinerValue(LLine + 2 * (1 : LNum) - 1) = RL.';
    % LinerNet中SINLine之后是SIN电源
    LinerValue(SINLine + (1 : SINNum) - 1) = SINV.';

    LinerNet('Value') = LinerValue;

    [curTimeRes, ~, Valuep] = calculateDC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);

    % tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
    LinerNet('Value') = Valuep;
    % 当前结果作下一轮前值
    curTimeResData = [0; curTimeRes];
    %    display(curTimeResData)
    % 因为原网表CL的端点在res靠前，索引不用变，伴随器件新增节点不关心
    if(~isempty(LNodeMat))
        LVp = curTimeResData(LNodeMat(:, 1)) - curTimeResData(LNodeMat(:, 2));
        LVp = LVp.';
    end
    if(~isempty(CNodeMat))
        CVp = curTimeResData(CNodeMat(:, 1)) - curTimeResData(CNodeMat(:, 2));
        CVp = CVp.';
    end
    LIp = IL + LVp ./ RL;
    CIp = (CVp - VC) ./ RC;

    %% 每到要打印的时间点才存下待打印信息
    if(abs(curTime - curPlotTime) <= delta_t / 2)
        plotCount = plotCount + 1;
        ResData(:, plotCount) = curTimeResData;
        DeviceDatas(plotCount, :) = Valuep;
        % 更新下次需打印时间
        curPlotTime = curPlotTime + stepTime;
    end
end
DeviceDatas = DeviceDatas.';
end
