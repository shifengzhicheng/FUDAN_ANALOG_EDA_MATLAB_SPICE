%% 端口映射函数主体，将PLOT代码部分解析并生成所需要的
function [plotnv,plotCurrent] = portMapping(PLOT)
    plotnum=size(PLOT,2);
    for i=1:plotnum
        switch lower(PLOT{i}{1})
            case '.plotnv'
                plotnv=[plotnv, tran(PLOT{i}{2})];
            case '.plotni'
                plotCurrent={plotCurrent, {PLOT{i}{2}, tran(PLOT{i}{3})}};
        end
    end
end