%% 初始值方法二 斜坡源模拟电源打开
function [InitRes, InitDeviceValue, CVi, CIi, LVi, LIi] = TransInitial(LinerNet, SourceINFO, MOSINFO, DIODEINFO, BJTINFO, CINFO, LINFO, Error, delta_t0, TransMethod)
% *************** 已加BJT端口 ***************

%RCL 拆开
CValue = CINFO('Value');
LValue = LINFO('Value');

CNodeMat = CINFO('NodeMat');
LNodeMat = LINFO('NodeMat');

CNum = size(CValue, 2);
LNum = size(LValue, 2);
% 注意LinerNet与LinerNet_DC顺序不同 但原线性器件端点序号一样, 可以利用
CLine = CINFO('CLine');
LLine = LINFO('LLine');

%初始节点电压全置0 - 本组实现中体现在器件值上
LIp = zeros(1, LNum);
LVp = zeros(1, LNum);
CIp = zeros(1, CNum);
CVp = zeros(1, CNum);
%Generate_transnetlist中CL伴随电源器件本来就为0

%梯形法时 - 固定步长
if(TransMethod == "TR")
    RC = 0.5 * delta_t0 ./ CValue;
    RL = 2 .* LValue ./ delta_t0;
elseif(TransMethod == "BE")
%后向欧拉时 - 动态步长时
    RC = delta_t0 ./ CValue;
    RL = LValue ./ delta_t0;
else
    return;
end

%Generate_transnetlist中使用全0为初值 - mos全截止不用改
%获得电源信息 改斜坡源方法瞬态
SourceName = SourceINFO('Name');
SourceNum = size(SourceName, 2);
%设300个Δt电源打开到DC初始值 得到格点斜坡源值 
SourceRampValues = zeros(SourceNum, 300);
SourceIndexInLinerNet = zeros(1, SourceNum);
%生成要改的源在LinerNet中索引
LinerNetName = LinerNet('Name');
for i = 1 : SourceNum 
    SourceIndexInLinerNet(i) = find(strcmp(LinerNetName, SourceName{i}));
end
%Generate的器件结果就是t=0值
InputLinerNetValue = LinerNet('Value');
SourceDcValue = InputLinerNetValue(SourceIndexInLinerNet);
for i = 1 : SourceNum
    SourceRampValues(i, :) = linspace(0, SourceDcValue(i), 300);
end


%开始模拟电源打开
for i = 1 : 300
    %利用上轮电容电感的电流电压得到当前时刻伴随器件值

    %梯形法时 - 固定步长
    if(TransMethod == "TR")
        VC = CVp + RC .* CIp;
        IL = LIp + delta_t0 * 0.5 * (LVp ./ LValue);
    elseif(TransMethod == "BE")
        %后向欧拉时 - 动态步长
        VC = CVp;
        IL = LIp;
    else
        return;
    end

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
    [curTimeRes, ~, Valuep] = calculateDC(LinerNet, MOSINFO, DIODEINFO, BJTINFO, Error);
    % *************** 已加BJT端口 ***************
    if(isempty(curTimeRes))
        break;
    end
    %tn非线性电路DC解结果作下轮tn+1非线性电路初始解 - 针对非线性器件 - 第一轮无此
    LinerNet('Value') = Valuep;    %当前结果作下一轮前值
    curTimeResData = [0; curTimeRes];
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
InitRes = curTimeResData;
InitDeviceValue = Valuep;
CVi = CVp;
CIi = CIp;
LVi = LVp;
LIi = LIp;
% disp("瞬态初值:")
% display(curTimeResData)
if(i ~= 300)
    disp('Generate Trans Initial Value Error');
end
