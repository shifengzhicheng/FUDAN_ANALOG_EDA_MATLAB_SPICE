%% 文件作者：郑志宇
%% 根据device以及端点从解中得到电流或者电压
% ResData包含0节点是在整个过程中产生的矩阵的解的结果
% LinerNet中网表部分不变，但是Value变为整个过程中器件的所有Value值，
% 这个矩阵的列数是绘图节点的数目，行数与器件数目一致
% NodeMap和x0是节点电压以及索引表向量
% plotnv与plotnc直接来自portMapping
function [Obj, res] = ValueCalcDC(plotnv, plotCurrent, DCres,x_0, Node_Map, LinerNet)
% 画图对象的总数量
pointNum = size(LinerNet('Value'),2);
plotnv=plotnv';
plotCurrent=plotCurrent';
tsize = size(plotnv,1)+size(plotCurrent,1);
% 初始化
Obj = cell(tsize,1);
res = zeros(tsize,pointNum);
if isempty(DCres)
    error('没有解，不能画出所需信息')
end
for i=1:size(plotnv)
    Obj(i) = {['Node_{' num2str(Node_Map(plotnv(i))) '}']};
    % 基本逻辑是在解出来的结果中找到对应的节点然后得到其电压
    res(i,:) = DCres(plotnv(i),:);
end
for j = i+1:tsize
    dname = plotCurrent{j-i}{1};
    plotport = plotCurrent{j-i}{2};
    Obj(j) = {[dname '(' plotport ')']};
    res(j,:) = getCurrentDC(dname,plotport,LinerNet,x_0,DCres);
end