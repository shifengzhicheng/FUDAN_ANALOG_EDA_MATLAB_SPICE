%% 端口映射函数主体，将PLOT代码部分解析并生成所需要的
function [plotnv,plotCurrent] = portMapping(PLOT,Node_Map)
    plotnum=size(PLOT,2);
    for i=1:plotnum
        switch lower(PLOT{i}{1})
            case '.plotnv'
                plotnv=[plotnv, find(Node_Map,PLOT{i}{2})];
            case '.plotni'
                plotCurrent={plotCurrent, {PLOT{i}{2}, find(Node_Map,PLOT{i}{3})}};
        end
    end
end