%% 文件作者：郑志宇
%% 根据device以及端点从解中得到电流或者电压
% ResData包含0节点是在整个过程中产生的矩阵的解的结果
% LinerNet中网表部分不变，但是Value变为整个过程中器件的所有Value值，
% 这个矩阵的列数是绘图节点的数目，行数与器件数目一致
% NodeMap和x0是节点电压以及索引表向量
% plotnv与plotnc直接来自portMapping
function [Obj,freq,Gain,Phase] = ValueCalcAC(plotnc,plotnv,Res,freq,LinerNet,Node_Map,x_0)
%% 这一步完成生成作图名称
nvNum = size(plotnv, 1);
ncNum = size(plotnc, 1);
ObjNum = ncNum + nvNum;
Obj = cell(ObjNum, 1);
for i=1 : nvNum
    Obj(i) = {['Node_' '{' num2str(Node_Map(plotnv(i))) '}']};
end
Device = cell(ncNum,1);
port=cell(ncNum,1);
for j = i + 1 : ObjNum
    dname = plotnc{j-i}{1};
    Device{j-i} = dname;
    plotport = plotnc{j-i}{2};
    port{j-i}=plotport;
    Obj(j) = {[dname '(' num2str(plotport) ')']};
end

%% 这一步计算结果
l = length(freq);
Gain = zeros(size(Obj,1),l);
Phase = zeros(size(Obj,1),l);
for j = 1:nvNum
    Voltage=Res(plotnv(j),:);
    Gain(j,:) = abs(Voltage);
    Phase(j,:) = angle(Voltage);
end
for j = nvNum+1:nvNum + ncNum
    Current=getCurrentAC(Device{j-nvNum},port{j-nvNum},LinerNet,x_0,Res,freq);
    Gain(j,:) = abs(Current);
    Phase(j,:) = angle(Current);
end