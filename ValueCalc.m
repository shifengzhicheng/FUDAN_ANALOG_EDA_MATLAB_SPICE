%% 根据device以及端点从解中得到电流或者电压
function [Obj, res] = ValueCalc(plotnv, plotCurrent, ...
            DCres,x_0, Node_Map, LinerNet, MOSINFO, DIODEINFO)
% 画图对象的总数量
Diodecurrents = DCres('Diode');
Moscurrents = DCres('MOS');
x = DCres('x');
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
Value = LinerNet('Value');
MOSName = MOSINFO('Name');
Diodes = DIODEINFO('Name'); 

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
    Obj(j) = {[dname '(' num2str(plotport) ')']};
    switch dname(1)
        case 'M'
            % 基本逻辑是在解出来的结果中找到对应的器件然后得到其电流
            Index = find(strcmp(MOSName,dname));
            switch plotport
                case 'd'
                    res(j) = Moscurrents(Index);
                case 'g'
                    res(j) = 0;
                case 's'
                    res(j) = -Moscurrents(Index);
            end
        case 'D'
            Index = find(strcmp(Diodes,dname));
            switch plotport
                case '+'
                    res(j) = Diodecurrents(Index);
                case '-'
                    res(j) = -Diodecurrents(Index);
            end
        case 'V'
            % 基本逻辑是在解出来的结果中找到对应的器件然后得到其电流
            Index = find(strcmp(x_0,['I_' dname])) + 1;
            switch plotport
                case '+'
                    res(j) = x(Index);
                case '-'
                    res(j) = -x(Index);
            end
        case 'I'
            % 找电流源的结果就直接到
            Index = find(strcmp(Name,dname));
            switch plotport 
                case '+'
                    res(j) = Value(Index);
                case '-'
                    res(j) = -Value(Index);
            end
        case 'R'
            % 找两端节点然后计算出电流
            Index = find(strcmp(Name,dname));
            if plotCurrent{j-i}{2} == '+'
                res(j) = (x(N1(Index)+1) - x(N2(Index)+1)) / Value(Index);
            else
                res(j) = -(x(N1(Index)+1) - x(N2(Index)+1)) / Value(Index);
            end
    end
end