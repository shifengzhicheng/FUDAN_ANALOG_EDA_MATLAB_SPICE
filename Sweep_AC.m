%{
输入:
输出:
%}
function [Obj,freq,Gain,Phase]=Sweep_AC(LinerNet,CINFO,LINFO,SweepInfo,Node_Map,PLOT)
%% AC分析的目的是得到节点的幅频响应和相频响应，需要AC源以及节点来实现这个绘制
% 整个AC过程只需要去计算矩阵的结果然后替换L、C的值即可
%% 初始化变量

%% 读出线性网表信息
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
dependence = LinerNet('dependence');
Value = LinerNet('Value');

%% AC信息
ACMode = SweepInfo{2};
ACPoint = SweepInfo{3};
fstart = SweepInfo{4};
fstop = SweepInfo{5};

%要打印的序号值或者器件类型加端口名
[plotnv, plotCurrent] = portMapping(PLOT,Node_Map);
plotnv=plotnv';
plotCurrent=plotCurrent';
nvNum = size(plotnv, 1);
ncNum = size(plotCurrent, 1);
ObjNum = ncNum + nvNum;
Obj = cell(ObjNum, 1);
for i=1 : nvNum
    Obj(i) = {['Node_' num2str(Node_Map(plotnv(i)))]};
end
Device = cell(ncNum,1);
for j = i + 1 : ObjNum
    dname = plotCurrent{j-i}{1};
    Device(j-i) = dname;
    plotport = plotCurrent{j-i}{2};
    Obj(j) = {[dname '(' num2str(plotport) ')']};
end
%% 这一步生成采样的频率点
freq = [];
switch lower(ACMode)
    case 'dec'
        sampNum = log10(fstop/fstart);
        freq = logspace(fstart,fstop,sampNum);
    case 'lin'
        freq = linerspace(fstart,fstop,ACPoint);
end

%% 这一步进行AC的扫描
length = size(freq,1);
[A,x,b]=Gen_ACmatrix(Name,N1,N2,dependence,Value);
Lline = LINFO('LLine');
Cline = CINFO('CLine');
Cnum = Lline - Cline;
Lnum = size(A,1) - Lline + 1;
Res = zeros(size(A,1),length);
for i = 1:length
    Af=Gen_NextACmatrix(N1,N2,Value,Cline,Cnum,Lline,Lnum,A,freq);
    Res(i) = [0,b\Af];
end

%% 这一步计算结果
Gain = zeros(size(Obj,1),length);
Phase = zeros(size(Obj,1),length);
for i = 1:length
    Gain(j:nvNum,i) = abs(Res(plotnv));
    Phase(j:nvNum,i) = angle(Res(plotnv));
    Gain(nvNum + 1: ncNum,i) = abs(getCurrent(Device,Node_Map,LinerNet,x,Res));
    Phase(nvNum + 1: ncNum,i) = angle(getCurrent(Device,Node_Map,LinerNet,x,Res));
end