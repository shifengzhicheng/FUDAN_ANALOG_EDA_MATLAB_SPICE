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
%display(stopTime);
%display(stepTime);
%最后要打印输出的时间点，打印步长不是瞬态仿真内部推进步长
printTimePoint = 0 : stepTime : stopTime;
printTimeNum = size(printTimePoint, 2);
%初始化
delta_t = stepTime * 0.5;

%提取一些CL信息

%RCL 拆开
%RINFO = RCLINFO('RINFO');
CINFO = RCLINFO('CINFO');
LINFO = RCLINFO('LINFO');   %Node(原网表) Name Value - 全string
CN1 = str2double(CINFO('N1'));
CN2 = str2double(CINFO('N2'));
LN1 = str2double(LINFO('N1'));
LN2 = str2double(LINFO('N2'));
CValue = str2double(CINFO('Value'));
LValue = str2double(LINFO('Value'));
CName = CINFO('Name');
LName = LINFO('Name');
CNum = size(CN1, 2);
LNum = size(LN1, 2);
CNodeMat = zeros(CNum, 2);
LNodeMat = zeros(LNum, 2);


%Node_Map 虽然同DC但是因为新增节点在最后，只在线性网表中处理，不需要与原网表节点对应
[LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map]=...
    Generate_transnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
% 注意LinerNet与LinerNet_DC顺序不同 但原线性器件端点序号一样, 可以利用
LinerNetName = LinerNet('Name');
CLine = CINFO('CLine');
LLine = LINFO('LLine');
%display(CLine)
%display(LLine)
%建立对SourceINFO的索引
SINLine = SinINFO('SinLine');  %LinerNet中的可变源开始行
SINAcValues = SinINFO('AcValue');
SINDcValues = SinINFO('DcValue');
SINPhase = SinINFO('Phase');
SINFreq = SinINFO('Freq');
SINNum = size(SINAcValues, 2);  %都为行向量
%display(LinerNet('Name'))
%CL节点 - 线性网表中节点
for i = 1 : CNum
    CNodeMat(i, 1) = find(Node_Map == CN1(i));
    CNodeMat(i, 2) = find(Node_Map == CN2(i));    %相当于已经考虑零节点，不再加1
end
for i = 1 : LNum
    LNodeMat(i, 1) = find(Node_Map == LN1(i));
    LNodeMat(i, 2) = find(Node_Map == LN2(i));    %相当于已经考虑零节点，不再加1
end

%% 获取每轮所需对DC结果的索引 以及Obj
%随意跑一次伴随器件模型的Gen_baseA，只为获得x_0方便索引
[~, x_0, ~] = Gen_Matrix(LinerNetName, LinerNet('N1'), LinerNet('N2'), LinerNet('dependence'), LinerNet('Value'));
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

% %% 零时刻值 - 可优化
%% 初始值方法一: 电路DC模型解
% [LinerNet_DC, MOSINFO_DC, DIODEINFO_DC, Node_Map]=...     %为DC解瞬态零时刻值
%     Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
% %待优化 - 若一开始DC电路无法解 - 做不了(是否可以零值DC就用伴随模型)
% [DCres, x0, LinerValueDC] = calculateDC(LinerNet_DC, MOSINFO_DC, DIODEINFO_DC, Error);
% %此时是C视为零电流源,L视为零电压源，以此为trans零时刻值
% LIndexInDCres = zeros(LNum, 1);
% tempCount = 1;
% for i = 1 : size(x0, 1)
%     curResName = x0{i};
%     if(size(curResName, 2) >= 4 && strcmp(curResName(3:4), 'VL'))
%             LIndexInDCres(tempCount) = i;
%             tempCount = tempCount + 1;
%     end
% end
% LIndexInDCres = LIndexInDCres + 1;
% DCresData = [0; DCres('x')];
% %统一行向量
% %开始瞬态推进初始各电容电感两端电压电流
% LIp = DCresData(LIndexInDCres).';
% LVp = zeros(1, LNum);
% CIp = zeros(1, CNum);
% if(~isempty(CNodeMat))
%     CVp = DCresData(CNodeMat(:, 1)) - DCresData(CNodeMat(:, 2));
%     CVp = CVp.';
% else
%     CVp = [];
% end
% % display(LIp)
% % display(CVp)
% % 零时刻DC模型解作为瞬态模型零时刻初始解 - 初始化非线性器件参数
%     LinerNetDCName = LinerNet_DC('Name');
%     LinerNetName = LinerNet('Name');
%     LinerValue = LinerNet('Value');
%     for i = 1 : size(LinerValueDC, 2)
%         ind = find(strcmp(LinerNetName, LinerNetDCName{i}));
%         if(~isempty(ind))
%             LinerValue(ind) = LinerValueDC(i);
%         end
%     end
%     LinerNet('Value') = LinerValue;
% %加入零时刻值到输出Values(:, 1)
% Values = updateValues( DCresData, LinerNet_DC('Value'), DCres('MOS'), DCres('Diode'), CIp, LIp,...
%                                 plotnv,...
%                                 mosIndexInValues, mosIndexInmosCurrents, ...
%                                 dioIndexInValues, dioIndexIndiodeCurrents, ...
%                                 VIndexInValues, VIndexInDCres, ...
%                                 IIndexInValues, IIndexInValue, ...
%                                 RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
%                                 CIndexInValues, CIndexInCIp,...
%                                 LIndexInValues, LIndexInLIp,...
%                                 Values, nvNum, 1);

%% 初始值方法二 斜坡源模拟电源打开
%初始节点电压全置0 - 本组实现中体现在器件值上
LIp = zeros(1, LNum);
LVp = zeros(1, LNum);
CIp = zeros(1, CNum);
CVp = zeros(1, CNum);
%Generate_transnetlist中CL伴随电源器件本来就为0

%梯形法时 - 固定步长
 RC = 0.5 * delta_t ./ CValue;
 RL = 2 .* LValue ./ delta_t;
%后向欧拉时 - 动态步长
% RC = delta_t ./ CValue;
% RL = LValue ./ delta_t;

%Generate_transnetlist中使用全0为初值 - mos全截止不用改
%获得电源信息 改斜坡源方法瞬态
SourceName = SourceINFO('Name');
SourceNum = size(SourceName, 2);
SourceDcValue = str2double(SourceINFO('DcValue'));  %斜坡源终点
%设100个Δt电源打开到DC初始值 得到格点斜坡源值 顺便生成要改的源在LinerNet中索引
SourceRampValues = zeros(SourceNum, 100);
SourceIndexInLinerNet = zeros(1, SourceNum);
for i = 1 : SourceNum
    SourceIndexInLinerNet(i) = find(strcmp(LinerNetName, SourceName{i}));
    SourceRampValues(i, :) = linspace(0, SourceDcValue(i), 100);
end
%开始模拟电源打开
for i = 1 : 100
    %利用上轮电容电感的电流电压得到当前时刻伴随器件值
    
    %梯形法时 - 固定步长
    VC = CVp + RC .* CIp;
    IL = LIp + delta_t * 0.5 * (LVp ./ LValue);
%    %后向欧拉时 - 动态步长
%    VC = CVp;
%    IL = LIp;

    LinerValue = LinerNet('Value');
    %LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
    %LinerNet中C伴随器件按R, V的顺序
    LinerValue(CLine + 2 * (1 : CNum) - 2) = RC.';
    LinerValue(CLine + 2 * (1 : CNum) - 1) = VC.';
    %LinerNet中L伴随器件按I, R的顺序
    LinerValue(LLine + 2 * (1 : LNum) - 2) = IL.';
    LinerValue(LLine + 2 * (1 : LNum) - 1) = RL.';
    %改为模拟斜坡源的值
    LinerValue(SourceIndexInLinerNet) = SourceRampValues(:, i).';
    LinerNet('Value') = LinerValue;
    [curTimeRes, ~, Valuep] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
    if(isempty(curTimeRes('x')))
        break;
    end
    %tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
    LinerNet('Value') = Valuep;    %当前结果作下一轮前值
    curTimeResData = [0; curTimeRes('x')];
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
end
disp("瞬态初值:")
display(curTimeResData)
%加入零时刻输出结果
mosCurrents = curTimeRes('MOS');
diodeCurrents = curTimeRes('Diode');
%% 初始化获取的电流值
ResData = [curTimeResData,zeros(size(x_0,1)+1,round(stopTime/stepTime))];
mosCurrents = [mosCurrents,zeros(size(mosCurrents,1),round(stopTime/stepTime))];
diodeCurrents = [diodeCurrents,zeros(size(diodeCurrents,1),round(stopTime/stepTime))];
LData=[LIp',zeros(size(LName,2),round(stopTime/stepTime))];
CData=[CIp',zeros(size(CName,2),round(stopTime/stepTime))];
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %% 开始推进 - 可变推进时间步长delta_t情况
% curPlotTime = stepTime; %下次要打印的时间
% %前已加入零时刻值Values(:, 1)
% plotCount = 1;
% curTime = 0;    %当前推进到的时间
% delta_t_max = stepTime;
% delta_t_min = stepTime * 0.1;
% 
% %改用后向欧拉有现成的误差公式
% while(plotCount < printTimeNum)
%     display(delta_t)
%     curTime = curTime + delta_t;
%     %利用变化后时间步长伴随电阻器件值固定
%     RC = delta_t ./ CValue;
%     RL = LValue ./ delta_t;
%     display(curTime)
%     %利用上轮电容电感的电流电压得到当前时刻伴随器件值
%     VCp = VC;
%     ILp = IL;
%     VC = CVp;
%     IL = LIp;
%     %当前时刻可变SIN电源值
%     SINV = Sin_Calculator(SINDcValues, SINAcValues, SINFreq, curTime, SINPhase);  %行
%     LinerValue = LinerNet('Value');
%     %LinerNet中C与L顺序不分类,要依据索引找对应伴随器件
%     %LinerNet中C伴随器件按R, V的顺序
%     LinerValue(CLine + 2 * (1 : CNum) - 2) = RC.';
%     LinerValue(CLine + 2 * (1 : CNum) - 1) = VC.';
%     %LinerNet中L伴随器件按I, R的顺序
%     LinerValue(LLine + 2 * (1 : LNum) - 2) = IL.';
%     LinerValue(LLine + 2 * (1 : LNum) - 1) = RL.';
%     %LinerNet中SINLine之后是SIN电源
%     LinerValue(SINLine + (1 : SINNum) - 1) = SINV.';
% 
%     LinerNet('Value') = LinerValue;
% 
%     [curTimeRes, ~, Valuep] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
%     %动态步长调整
%     if(isempty(curTimeRes('x')) && delta_t ~= delta_t_min)    %DC不收敛 减小步长再来一次
%         curTime = curTime - delta_t;
%         if(delta_t / 2 > delta_t_min)
%             delta_t = delta_t / 2;
%         else
%             delta_t = delta_t_min;
%         end
%         continue;
%     elseif(isempty(curTimeRes('x')) && delta_t == delta_t_min) %可能出现跳变临界需要次大步长以达到DC收敛
%         curTime = curTime - delta_t;
%         delta_t = delta_t_max;
%         continue;
%     else    %收敛没问题根据误差调步长
% 
%         %tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
%         LinerNet('Value') = Valuep;
%         %当前结果作下一轮前值
%         curTimeResData = [0; curTimeRes('x')];
%         %因为原网表CL的端点在res靠前，索引不用变，伴随器件新增节点不关心
%         LVpp = LVp;
%         LIpp = LIp;
%         CVpp = CVp;
%         CIpp = CIp; %计算误差用
%         if(~isempty(LNodeMat))
%             LVp = curTimeResData(LNodeMat(:, 1)) - curTimeResData(LNodeMat(:, 2));
%             LVp = LVp.';
%         end
%         if(~isempty(CNodeMat))
%             CVp = curTimeResData(CNodeMat(:, 1)) - curTimeResData(CNodeMat(:, 2));
%             CVp = CVp.';
%         end
%         LIp = IL + LVp ./ RL;
%         CIp = (CVp - VC) ./ RC;
%         %误差计算 abs
%         epsilonC = - RC .* (CIp - CIpp);
%         epsilonL = - (LVpp - LVp) ./ RL;
%         epsilon = [epsilonC, epsilonL];
%         tnInfo = [CVpp - VCp, LIpp - ILp];
%         if(norm(epsilon) / norm(tnInfo) > 0.1)
%             if(delta_t/2 <= delta_t_min)
%                 delta_t = delta_t_min;
%             else
%                 delta_t = delta_t / 2;
%             end
%         else
%             if(delta_t*2 >= delta_t_max)
%                 delta_t = delta_t_max;
%             else
%                 delta_t = delta_t * 2;
%             end
%         end
% 
%     end
% 
%     %% 每到要打印的时间点才存下待打印信息
%     if(abs(curTime - curPlotTime) < delta_t )    %delta_t则出bug%%%%
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
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 开始推进 - 固定推进时间步长delta_t情况 - 迭代次数确定
%因为固定时间步长伴随电阻器件值固定
RC = 0.5 * delta_t ./ CValue;
RL = 2 .*  LValue ./ delta_t;
curPlotTime = stepTime; %下次要打印的时间
%前已加入零时刻值Values(:, 1)
plotCount = 1;
curTime = 0;    %当前推进到的时间

while(plotCount < printTimeNum)
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
    %     display(SINV.')
    %      display(LinerNet('Name'))
    %      display(LinerNet('N1'))
    %      display(LinerNet('N2'))
    %     display(LinerNet('Value'))
    %     display(keys(LinerNet))

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
        mosCurrents(:,plotCount) = curTimeRes('MOS');
        diodeCurrents(:,plotCount) = curTimeRes('Diode');
        ResData(:,plotCount) = curTimeResData;
        LData(:,plotCount) = LIp';
        CData(:,plotCount) = CIp';
        %更新下次需打印时间
        curPlotTime = curPlotTime + stepTime;
    end
end
%     if(printTimeNum ~= plotCount)
%         for i=1:size(Obj,1)
%             figure('Name',Obj{i})
%             plot(printTimePoint(1:plotCount), Values(i,(1:plotCount)));
%             title(Obj{i});
%         end
%     end
%% 尚未加入寄生电容的电流，时间瞬态三端电流要加上电容漏电 - HOW？
% 在外面同一获取所有需要的电流
Values = updateValues( ResData, Valuep, mosCurrents, diodeCurrents, CData, LData,...
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
