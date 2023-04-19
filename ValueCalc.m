%% 根据device以及端点从解中得到电流或者电压
function [Obj,Values] = ValueCalc(plotnv,plotcurrent, ...
    x, Moscurrent, Value, ...
    x_0,Node_Map, Name, N1, N2, MOSName)
% 画图对象的总数量
tsize = size(plotnv)+size(plotcurrent);
% 初始化
Obj = cell(tsize);
Values = zeros(tsize);
for i=1:size(plotnv)
    Obj(i) = ['Node_Voltage: ' Node_Map(plotnv)];
    % 基本逻辑是在解出来的结果中找到对应的节点然后得到其电压
    Values(i) = x(plotnv);
end
for j= i+1:tsize
    dname = plotcurrent{j-i}{1};
    plotport = lower(Node_Map(plotcurrent{j-i}{2}));
    Obj(j) = [dname '_Current: ' plotport];
    switch dname(1)
        case M
            % 基本逻辑是在解出来的结果中找到对应的器件然后得到其电流
            Index = find(MOSName,dname);            
            switch plotport
                case 'd' 
                    Values(j) = Moscurrent(Index);
                case 'g' 
                    Values(j) = 0;
                case 's' 
                    Values(j) = -Moscurrent(Index);
            end

        case V
            % 基本逻辑是在解出来的结果中找到对应的器件然后得到其电流
            Index = find(x_0,['I_' plotcurrent{j-i}{1}]);          
            switch plotport
                case '+'
                    Values(j) = x(Index);
                case '-'
                    Values(j) = -x(Index);
            end
        case I
            % 找电流源的结果就直接到
            Index = find(Name,dname);          
            switch plotport
                case '+'
                    Values(j) = Value(Index);
                case '-'
                    Values(j) = -Value(Index);
            end
        case R
            % 找两端节点然后计算出电流
            Index = find(Name,dname);
            if plotcurrent{j-i}{2} == N1(Index)
                Values(j) = Value(Index)*(x(N1(Index)) - x(N2(Index)));
            else
                Values(j) = -Value(Index)*(x(N1(Index)) - x(N2(Index)));
            end
    end
end
end