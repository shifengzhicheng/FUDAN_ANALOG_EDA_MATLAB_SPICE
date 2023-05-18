%% 根据device以及端点从解中得到电流或者电压
function [Obj, res] = ValueCalc(plotnv, plotCurrent, ...
            DCres,x_0, Node_Map, LinerNet)
% 画图对象的总数量
Diodecurrents = DCres('Diode');
Moscurrents = DCres('MOS');
x = DCres('x');
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
Value = LinerNet('Value');

plotnv=plotnv';
plotCurrent=plotCurrent';
tsize = size(plotnv)+size(plotCurrent);
% 初始化
Obj = cell(tsize);
res = zeros(tsize);
if isempty(x)
    error('没有解，不能画出所需信息')
end
for i=1:size(plotnv)
    Obj(i) = {['Node_' num2str(Node_Map(plotnv(i)))]};
    % 基本逻辑是在解出来的结果中找到对应的节点然后得到其电压
    res(i) = x(plotnv(i));
end
for j = i+1:tsize
    dname = plotCurrent{j-i}{1};
    plotport = plotCurrent{j-i}{2};
    Obj(j) = {[dname '(' plotport ')']};
    freq = 0;
    res(j) = getCurrent(dname,plotport,LinerNet,x_0,x,freq);
end