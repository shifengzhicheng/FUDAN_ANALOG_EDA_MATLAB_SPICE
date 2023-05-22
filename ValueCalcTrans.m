function [Obj,res] = ValueCalcTrans(ResData,LinerNet,Node_Map,x_0,plotnv,plotnc)
% 画图对象的总数量
pointNum = size(LinerNet('Value'),2);
plotnv=plotnv';
plotCurrent=plotnc';
tsize = size(plotnv,1)+size(plotCurrent,1);
% 初始化
Obj = cell(tsize);
res = zeros(tsize,pointNum);
if isempty(ResData)
    error('没有解，不能画出所需信息')
end
for i=1:size(plotnv)
    Obj(i) = {['Node_{' num2str(Node_Map(plotnv(i))) '}']};
    % 基本逻辑是在解出来的结果中找到对应的节点然后得到其电压
    res(i,:) = ResData(plotnv(i),:);
end
for j = i+1:tsize
    dname = plotCurrent{j-i}{1};
    plotport = plotCurrent{j-i}{2};
    Obj(j) = {[dname '(' plotport ')']};
    res(j,:) = getCurrentTrans(dname,plotport,LinerNet,x_0,ResData);
end
end