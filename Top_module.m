%% 项目的顶层模块，用于实现整个项目的仿真流程
% 此文件为项目搭建的顶层架构，用于梳理和切割项目实现的功能并实现模块化
clear;
clc;
%% 读取文件，预处理阶段
filename = 'testfile\dbmixerDC.sp';
% filename = 'testfile\buffer.sp';
[RCLINFO,SourceINFO,MOSINFO,...
    DIODEINFO,PLOT,SPICEOperation]...
    =parse_netlist(filename);

%% 根据读到的操作选择执行任务的分支

[Name,N1,N2,dependence,Value,MOSINFO,DIODEINFO,Node_Map, NodeInfo, DeviceInfo]=...
    Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);

% Name cell,'Name'
% N1 double
% N2 double
% dependence cell [cp1 cp2] or 'Name'
% Value double
% MOSLine double
switch lower(SPICEOperation{1}{1})
    case '.dcsweep'

    case '.hb'
        % 这里进入AC分析
        % 需要时间步长，AC频率
    case '.trans'
        % 设置判断解收敛的标识
        Error = 1e-6;
        timestep = 1e-3;
        % 到这里需要进行瞬态仿真
        % 瞬态仿真需要时间步长
        x=caculateDC(DCnetlist,Error);
        plotnv=portMapping(PLOT);
        [timeseries,Values]=trans(plotnv,x,transnetlist);
        plot(timeseries,Values);
    case '.dc'
        Error = 1e-6;
        % 到这里需要DC电路网表
        [x, Moscurrent,diodecurrents, x_0] = ...
        calculateDC(Name, N1, N2, dependence, Value,...
        MOSINFO,DIODEINFO, Error);

        [plotnv, plotCurrent] = portMapping(PLOT,Node_Map);
        % plotcurrent需要一个device，还需要一个port
        % plotnv是序号，可以通过x(plotnv)得到
        [Obj, Values] = ValueCalc(plotnv, plotCurrent, ...
            x, Moscurrent, diodecurrents, Value, ...
            x_0, Node_Map, Name, N1, N2, MOSName, Diodes);
        for i=1:size(Obj)
            display([Obj{i}, num2str(Values(i))]);
        end
end
