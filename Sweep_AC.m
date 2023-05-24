%{
输入:
线性网表，C，L，扫描参数，节点映射的结果，绘图信息
输出:
绘图所需参数，包括绘制对象，频率坐标轴，增益以及相位
%}
function [Obj,freq,Gain,Phase]=Sweep_AC(LinerNet,CINFO,LINFO,SweepInfo,Node_Map,PLOT)
%% AC分析的目的是得到节点的幅频响应和相频响应，需要AC源以及节点来实现这个绘制
% 整个AC过程只需要去计算矩阵的结果然后替换L、C的值即可

%% 读出线性网表信息
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
dependence = LinerNet('dependence');
Value = LinerNet('Value');

%% AC信息
ACMode = SweepInfo{1};
ACPoint = SweepInfo{2};
fstart = SweepInfo{3};
fstop = SweepInfo{4};

%要打印的序号值或者器件类型加端口名
[plotnv, plotCurrent] = portMapping(PLOT,Node_Map);
plotnv=plotnv';
plotCurrent=plotCurrent';
nvNum = size(plotnv, 1);
ncNum = size(plotCurrent, 1);
ObjNum = ncNum + nvNum;
Obj = cell(ObjNum, 1);
for i=1 : nvNum
    Obj(i) = {['Node_' '{' num2str(Node_Map(plotnv(i))) '}']};
end
Device = cell(ncNum,1);
port=cell(ncNum,1);
for j = i + 1 : ObjNum
    dname = plotCurrent{j-i}{1};
    Device{j-i} = dname;
    plotport = plotCurrent{j-i}{2};
    port{j-i}=plotport;
    Obj(j) = {[dname '(' num2str(plotport) ')']};
end
%% 这一步生成采样的频率点
freq = [];
switch lower(ACMode)
    case 'dec'
        start=log10(fstart);
        stop=log10(fstop);
        sampNum = (stop-start)*ACPoint;
        freq = logspace(start,stop,sampNum);
    case 'lin'
        freq = linspace(fstart,fstop,ACPoint);
end

%% 这一步进行AC的扫描
length = size(freq,2);
Lline = LINFO('LLine');
LValue=LINFO('Value');
LName = LINFO('Name');
Cline = CINFO('CLine');
CValue=CINFO('Value');
CName = CINFO('Name');
LinerNet('Value')=[Value(1:size(Name,2)),CValue,LValue]';
Name = [Name,CName,LName];
LinerNet('Name')=Name;
[A,x,b]=Gen_Matrix(Name,N1,N2,dependence,Value);

Cnum = size(CName,2);
Lnum = size(LName,2);
Res = zeros(size(b,1)+1,length);
for i = 1:length
    Af=Gen_NextACmatrix(N1,N2,CValue,LValue,Cline,Cnum,Lline,Lnum,A,freq(i));
    Res(:,i) = [0;Af\b];
end

%% 这一步计算结果
Gain = zeros(size(Obj,1),length);
Phase = zeros(size(Obj,1),length);
for j = 1:nvNum
    Voltage=Res(plotnv(j),:);
    Gain(j,:) = abs(Voltage);
    Phase(j,:) = angle(Voltage);
end
for j = nvNum+1:nvNum + ncNum
    Current=getCurrentAC(Device{j-nvNum},port{j-nvNum},LinerNet,x,Res,freq);
    Gain(j,:) = abs(Current);
    Phase(j,:) = angle(Current);
end
