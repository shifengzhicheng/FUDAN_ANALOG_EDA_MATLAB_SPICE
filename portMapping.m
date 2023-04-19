%% 端口映射函数主体，将PLOT代码部分解析并生成所需要的
function [plotnv,plotCurrent] = portMapping(PLOT,Node_Map)
plotnum=size(PLOT,2);
plotnv = [];
plotCurrent = {};
for i=1:plotnum
    switch lower(PLOT{i}{1})
        case '.plotnv'
            Index = find(Node_Map,str2double(PLOT{i}{2}));
            if ~isvector(Index) && ~isscalar(Index)
                plotnv = [plotnv, Index];
            else
                error(['plotnv匹配不到电压端口',PLOT{i}{2}]);
            end
        case '.plotnc'
            % 从字符串中匹配括号前的内容和括号内的内容
            str = PLOT{i}{2};
            expr = '(\w+)\((\w+)\)';
            match = regexp(str, expr, 'tokens', 'once');
            % 如果匹配成功，则将匹配结果存储到 device 和 num 变量中
            if ~isempty(match)
                device = match{1};
                Index = match{2};
                plotCurrent = {plotCurrent, {device, Index}};
            else
                error(['plotnc格式错误',PLOT{i}{2}]);
            end
    end
end
end