%{
    输入:
        paser解析结果，注意晶体管考虑寄生电容
        trans打印信息
        待打印对象信息，避免额外存储
    输出:
        打印对象名obj(纵轴标签们)
        打印对象值Value(纵轴)
        打印时间点向量printTimePoint(横轴)
%}

function [Obj, Values, printTimePoint] = CalculateTrans(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, Error, stopTime, stepTime, PLOT)
%最后要打印输出的时间点，打印步长不是瞬态仿真内部推进步长
printTimePoint = 0 : stepTime : stopTime;
printTimeNum = size(printTimePoint, 2);
%初始化
delta_t = stepTime * 0.01;

%提取一些CL信息
[LinerNet_DC,MOSINFO_DC,DIODEINFO_DC, Node_Map]=...     %为DC解瞬态零时刻值
    Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
RCLName = RCLINFO('Name');
RCLN1 = str2double(RCLINFO('N1'));
RCLN2 = str2double(RCLINFO('N2'));
CNum = 0;
LNum = 0;
CNodeMat = [];
LNodeMat = [];
for i = 1 : size(RCLName, 2)
    curRCLName = RCLName{i};
    switch curRCLName(1)
        case 'C'
            CNum = CNum + 1;
            CNodeMat(CNum, 1) = find(Node_Map == RCLN1(i));
            CNodeMat(CNum, 2) = find(Node_Map == RCLN2(i));
        case 'L'
            LNum = LNum + 1;
            LNodeMat(LNum, 1) = find(Node_Map == RCLN1(i));
            LNodeMat(LNum, 2) = find(Node_Map == RCLN2(i));
    end
    %相当于已经考虑零节点，不再加1
end
%Node_Map 虽然同DC但是因为新增节点在最后，只在线性网表中处理，不需要与原网表节点对应
[LinerNet,MOSINFO,DIODEINFO,LCINFO,SinINFO,Node_Map]=...
    Generate_transnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
% 注意LinerNet与LinerNet_DC顺序不同 但原线性器件端点序号一样, 可以利用
% LinerNetDC跑过一次DC后MD伴随器件不同于起始LinerNet？
%提取所需信息
LCName = LCINFO('Name');    %行
LCValue = LCINFO('Value');   
LCLine = LCINFO('LCLine');
%建立对LCINFO的索引
CIndex = zeros(1, CNum);
LIndex = zeros(1, LNum);
countC = 1; countL = 1;
for i = 1 : size(LCName, 2)
    curLCName = LCName{i};
    switch(curLCName(1))
        case 'C'
            CIndex(countC) = i;
            countC = countC + 1;
        case 'L'
            LIndex(countL) = i;
            countL = countL + 1;
    end
end
CName = LCName(CIndex);
LName = LCName(LIndex);
CValue = LCValue(CIndex);
LValue = LCValue(LIndex);

%建立对SourceINFO的索引
SINLine = SinINFO('SinLine');  %LinerNet中的可变源开始行
SINAcValues = SinINFO('AcValue');
SINDcValues = SinINFO('DcValue');
SINPhase = SinINFO('Phase');
SINFreq = SinINFO('Freq');
SINNum = size(SINAcValues, 2);  %都为行向量
%display(LinerNet('Name'))

%% 获取每轮所需对DC结果的索引 以及Obj
%随意跑一次伴随器件模型的Gen_baseA，只为获得x_0方便索引
[~, x_0, ~] = Gen_baseA(LinerNet('Name'), LinerNet('N1'), LinerNet('N2'), LinerNet('dependence'), LinerNet('Value')); 
%因为伴随器件都放最后，不允许打印伴随器件值，故复用PLOTIndexInRes 
[mosIndexInValues, mosIndexInmosCurrents, ...
            dioIndexInValues, dioIndexIndiodeCurrents, ... 
            VIndexInValues, VIndexInDCres, ...
            IIndexInValues, IIndexInValue, ...
            RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
            CIndexInValues, CIndexInCIp,...
            LIndexInValues, LIndexInLIp,...
            Obj, Values, plotnv] = PLOTIndexInRes(x_0, PLOT, Node_Map, printTimeNum, LinerNet, MOSINFO('Name'), DIODEINFO('Name'), CName ,LName);
nvNum = size(plotnv, 1);
%% 零时刻值
%待优化 - 若一开始DC电路无法解 - 做不了(是否可以零值DC就用伴随模型)
[DCres, x0, LinerValueDC] = calculateDC(LinerNet_DC, MOSINFO_DC, DIODEINFO_DC, Error);
%此时是C视为零电流源,L视为零电压源，以此为trans零时刻值
LIndexInDCres = zeros(LNum, 1);
tempCount = 1;
for i = 1 : size(x0, 1)
    curResName = x0{i};
    if(size(curResName, 2) >= 4 && strcmp(curResName(3:4), 'VL'))
            LIndexInDCres(tempCount) = i;
            tempCount = tempCount + 1;
    end
end
LIndexInDCres = LIndexInDCres + 1;
DCresData = [0; DCres('x')];
%统一行向量
%开始瞬态推进初始各电容电感两端电压电流
LIp = DCresData(LIndexInDCres).';
LVp = zeros(1, LNum);
CIp = zeros(1, CNum);
if(~isempty(CNodeMat))
    CVp = DCresData(CNodeMat(:, 1)) - DCresData(CNodeMat(:, 2));
    CVp = CVp.';
else
    CVp = [];
end

%加入零时刻值到输出Values(:, 1)
Values = updateValues( DCresData, LinerNet_DC('Value'), DCres('MOS'), DCres('Diode'), CIp, LIp,...
                                plotnv,...
                                mosIndexInValues, mosIndexInmosCurrents, ...
                                dioIndexInValues, dioIndexIndiodeCurrents, ...
                                VIndexInValues, VIndexInDCres, ...
                                IIndexInValues, IIndexInValue, ...
                                RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
                                CIndexInValues, CIndexInCIp,...
                                LIndexInValues, LIndexInLIp,...
                                Values, nvNum, 1);
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %% 开始推进 - 可变推进时间步长delta_t情况 - 未完成
% curPlotTime = stepTime; %下次要打印的时间
% %前已加入零时刻值Values(:, 1)
% plotCount = 1;
% curTime = 0;    %当前推进到的时间
% 
% while(curTime < stopTime)
%     display(delta_t)
%     curTime = curTime + delta_t;
%     %利用变化后时间步长伴随电阻器件值固定
%     RC = 0.5 * delta_t ./ CValue;
%     RL = 2 .*  LValue ./ delta_t;
%     display(curTime)
%     %利用上轮电容电感的电流电压得到当前时刻伴随器件值
%     VC = CVp + RC .* CIp;
%     IL = LIp + delta_t * 0.5 * (LVp ./ LValue);
%     %当前时刻可变SIN电源值
%     SINV = Sin_Calculator(SINDcValues, SINAcValues, SINFreq, curTime, SINPhase);  %行
%     LinerValue = LinerNet('Value');
%     %LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
%     %LinerNet中C伴随器件按R, V的顺序
%     LinerValue(LCLine + 2 * (CIndex - 1)) = RC.';
%     LinerValue(LCLine + 2 * (CIndex - 1) + 1) = VC.';
%     %LinerNet中L伴随器件按I, R的顺序
%     LinerValue(LCLine + 2 * (LIndex - 1)) = IL.';
%     LinerValue(LCLine + 2 * (LIndex - 1) + 1) = RL.';
%     %LinerNet中SINLine之后是SIN电源
%     LinerValue(SINLine + (1 : SINNum) - 1) = SINV.';
% 
%     LinerNet('Value') = LinerValue;
% %     display(SINV.')
% %     display(LinerNet('Name'))
% %     display(LinerNet('N1'))
% %     display(LinerNet('N2'))
% %     display(LinerNet('Value'))
% %     display(keys(LinerNet))
% 
%     [curTimeRes, ~, Valuep] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
%     if(isempty(curTimeRes('x')))    %DC不收敛 减小步长再来一次
%         curTime = curTime - delta_t;
%         delta_t = delta_t / 2;
%         continue;
%     end
%     %tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
%     LinerNet('Value') = Valuep;
%     %当前结果作下一轮前值
%     curTimeResData = [0; curTimeRes('x')];
%     %因为原网表CL的端点在res靠前，索引不用变，伴随器件新增节点不关心
%     if(~isempty(LNodeMat))
%         LVp = curTimeResData(LNodeMat(:, 1)) - curTimeResData(LNodeMat(:, 2));
%         LVp = LVp.';
%     end
%     if(~isempty(CNodeMat))
%         CVp = curTimeResData(CNodeMat(:, 1)) - curTimeResData(CNodeMat(:, 2));
%         CVp = CVp.';
%     end
%     LIp = IL + LVp ./ RL;
%     CIp = (CVp - VC) ./ RC;
% 
%     %% 每到要打印的时间点才存下待打印信息
%     if(abs(curTime - curPlotTime) < delta_t / 2)    %delta_t则出bug%%%%
%         plotCount = plotCount + 1;
%         display(plotCount)
%         mosCurrents = curTimeRes('MOS');
%         diodeCurrents = curTimeRes('Diode');
% 
%         %% 尚未加入寄生电容的电流，时间瞬态三端电流要加上电容漏电 - HOW？
%         Values = updateValues( curTimeResData, Valuep, mosCurrents, diodeCurrents, CIp, LIp,...
%                                 plotnv,...
%                                 mosIndexInValues, mosIndexInmosCurrents, ...
%                                 dioIndexInValues, dioIndexIndiodeCurrents, ...
%                                 VIndexInValues, VIndexInDCres, ...
%                                 IIndexInValues, IIndexInValue, ...
%                                 RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
%                                 CIndexInValues, CIndexInCIp,...
%                                 LIndexInValues, LIndexInLIp,...
%                                 Values, nvNum, plotCount);
%         %更新下次需打印时间
%         curPlotTime = curPlotTime + stepTime;      
%     end
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 开始推进 - 固定推进时间步长delta_t情况 - 迭代次数确定
iterNum = stopTime / delta_t;
%因为固定时间步长伴随电阻器件值固定
RC = 0.5 * delta_t ./ CValue;
RL = 2 .*  LValue ./ delta_t;
curPlotTime = stepTime; %下次要打印的时间
%前已加入零时刻值Values(:, 1)
plotCount = 1;
curTime = 0;    %当前推进到的时间
%% test - 零时刻非线性器件结果做出值
    LinerNetDCName = LinerNet_DC('Name');
    LinerNetName = LinerNet('Name');
    LinerValue = LinerNet('Value');
    for i = 1 : size(LinerValueDC, 2)
        ind = find(strcmp(LinerNetName, LinerNetDCName{i}));
        if(~isempty(ind))
            LinerValue(ind) = LinerValueDC(i);
        end
    end
    LinerNet('Value') = LinerValue;

for i = 1 : iterNum
    curTime = curTime + delta_t;
    %利用上轮电容电感的电流电压得到当前时刻伴随器件值
    display(curTime)
    VC = CVp + RC .* CIp;
    IL = LIp + delta_t * 0.5 * (LVp ./ LValue);
    %当前时刻可变SIN电源值
    SINV = Sin_Calculator(SINDcValues, SINAcValues, SINFreq, curTime, SINPhase);  %行
    LinerValue = LinerNet('Value');
    %LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
    %LinerNet中C伴随器件按R, V的顺序
    LinerValue(LCLine + 2 * (CIndex - 1)) = RC.';
    LinerValue(LCLine + 2 * (CIndex - 1) + 1) = VC.';
    %LinerNet中L伴随器件按I, R的顺序
    LinerValue(LCLine + 2 * (LIndex - 1)) = IL.';
    LinerValue(LCLine + 2 * (LIndex - 1) + 1) = RL.';
    %LinerNet中SINLine之后是SIN电源
    LinerValue(SINLine + (1 : SINNum) - 1) = SINV.';

    LinerNet('Value') = LinerValue;
%   display(SINV.')
    display(LinerNet('Name'))
    display(LinerNet('N1'))
    display(LinerNet('N2'))
    display(LinerNet('Value'))
%   display(keys(LinerNet))

    [curTimeRes, ~, Valuep] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);

    %tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
    LinerNet('Value') = Valuep;
    %当前结果作下一轮前值
    curTimeResData = [0; curTimeRes('x')];
    %display(curTimeResData)
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
        mosCurrents = curTimeRes('MOS');
        diodeCurrents = curTimeRes('Diode');

        %% 尚未加入寄生电容的电流，时间瞬态三端电流要加上电容漏电 - HOW？
        Values = updateValues( curTimeResData, Valuep, mosCurrents, diodeCurrents, CIp, LIp,...
                                plotnv,...
                                mosIndexInValues, mosIndexInmosCurrents, ...
                                dioIndexInValues, dioIndexIndiodeCurrents, ...
                                VIndexInValues, VIndexInDCres, ...
                                IIndexInValues, IIndexInValue, ...
                                RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
                                CIndexInValues, CIndexInCIp,...
                                LIndexInValues, LIndexInLIp,...
                                Values, nvNum, plotCount);
        %更新下次需打印时间
        curPlotTime = curPlotTime + stepTime;      
    end
end
end
