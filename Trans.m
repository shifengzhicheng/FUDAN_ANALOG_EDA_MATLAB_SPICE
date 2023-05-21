function [ResData,CData,LData] = ...
    Trans(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map, Error, init, CIp, LIp, stepTime, T)
%RCL 拆开
delta_t = stepTime*0.5;

%Node_Map 虽然同DC但是因为新增节点在最后，只在线性网表中处理，不需要与原网表节点对应

% 注意LinerNet与LinerNet_DC顺序不同 但原线性器件端点序号一样, 可以利用
CLine = CINFO('CLine');
LLine = LINFO('LLine');
CValue = CINFO('Value');
LValue = LINFO('Value');
CN1 = CINFO('N1');
CN2 = CINFO('N2');
LN1 = LINFO('N1');
LN2 = LINFO('N2');
CNum = size(CN1, 2);
LNum = size(LN1, 2);
CNodeMat = zeros(CNum, 2);
LNodeMat = zeros(LNum, 2);
%建立对SourceINFO的索引
SINLine = SinINFO('SinLine');  %LinerNet中的可变源开始行
SINAcValues = SinINFO('AcValue');
SINDcValues = SinINFO('DcValue');
SINPhase = SinINFO('Phase');
SINFreq = SinINFO('Freq');
SINNum = size(SINAcValues, 2);  %都为行向量

RC = 0.5 * delta_t ./ CValue;
RL = 2 .*  LValue ./ delta_t;

%CL节点 - 线性网表中节点
for i = 1 : CNum
    CNodeMat(i, 1) = find(Node_Map == CN1(i));
    CNodeMat(i, 2) = find(Node_Map == CN2(i));    %相当于已经考虑零节点，不再加1
end
for i = 1 : LNum
    LNodeMat(i, 1) = find(Node_Map == LN1(i));
    LNodeMat(i, 2) = find(Node_Map == LN2(i));    %相当于已经考虑零节点，不再加1
end

%% 根据init生成矩阵
tempValue = init('x');
if(~isempty(LNodeMat))
    LVp = tempValue(LNodeMat(:, 1)) - tempValue(LNodeMat(:, 2));
    LVp = LVp.';
end
if(~isempty(CNodeMat))
    CVp = tempValue(CNodeMat(:, 1)) - tempValue(CNodeMat(:, 2));
    CVp = CVp.';
end
VC = CVp + RC .* CIp;
IL = LIp + delta_t * 0.5 * (LVp ./ LValue);
LIp = IL + LVp ./ RL;
CIp = (CVp - VC) ./ RC;
%Generate_transnetlist中CL伴随电源器件本来就为0
%Generate_transnetlist中使用全0为初值 - mos全截止不用改
%获得电源信息 改斜坡源方法瞬态

%加入零时刻输出结果
tempValue = [tempValue,zeros(size(tempValue,1),round(T/stepTime))];
mosCurrents = [init('MOS'),zeros(size(init('MOS'),1),round(T/stepTime))];
diodeCurrents = [init('Diode'),zeros(size(init('Diode'),1),round(T/stepTime))];
LData=[LIp',zeros(LNum,round(T/stepTime))];
CData=[CIp',zeros(CNum,round(T/stepTime))];
%% 开始推进 - 固定推进时间步长delta_t情况 - 迭代次数确定
%因为固定时间步长伴随电阻器件值固定
curPlotTime = stepTime; %下次要打印的时间
%前已加入零时刻值Values(:, 1)
plotCount = 1;
curTime = 0;    %当前推进到的时间

while(curPlotTime <= T)
    curTime = curTime + delta_t;
    %利用上轮电容电感的电流电压得到当前时刻伴随器件值
    %    display(curTime)
    VC = CVp + RC .* CIp;
    IL = LIp + delta_t * 0.5 * (LVp ./ LValue);
    %当前时刻可变SIN电源值
    SINV = Sin_Calculator(SINDcValues, SINAcValues, SINFreq, curTime, SINPhase);  %行
    LinerValue = LinerNet('Value');
    %LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
    %LinerNet中C伴随器件按R, V的顺序
    LinerValue(CLine + 2 * (1 : CNum) - 2) = RC.';
    LinerValue(CLine + 2 * (1 : CNum) - 1) = VC.';
    %LinerNet中L伴随器件按I, R的顺序
    LinerValue(LLine + 2 * (1 : LNum) - 2) = IL.';
    LinerValue(LLine + 2 * (1 : LNum) - 1) = RL.';
    %LinerNet中SINLine之后是SIN电源
    LinerValue(SINLine + (1 : SINNum) - 1) = SINV.';

    LinerNet('Value') = LinerValue;

    [curTimeRes, ~, Valuep] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);

    %tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
    LinerNet('Value') = Valuep;
    %当前结果作下一轮前值
    curTimeResData = [0; curTimeRes('x')];
    %    display(curTimeResData)
    %因为原网表CL的端点在res靠前，索引不用变，伴随器件新增节点不关心
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
        tempValue(:,plotCount) = curTimeResData;
        mosCurrents(:,plotCount) = curTimeRes('MOS');
        diodeCurrents(:,plotCount) = curTimeRes('Diode');
        LData(:,plotCount) = LIp';
        CData(:,plotCount) = CIp';
        %更新下次需打印时间
        curPlotTime = curPlotTime + stepTime;
    end
end
ResData = containers.Map();
ResData('x') = tempValue;
ResData('MOS') = mosCurrents;
ResData('Diode') = diodeCurrents;
end