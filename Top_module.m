%% 项目的顶层模块，用于实现整个项目的仿真流程
% 此文件为项目搭建的顶层架构，用于梳理和切割项目实现的功能并实现模块化
%% 读取文件，预处理阶段
filename = 'testfile\dbmixer.sp';
[RLCName,RLCN1,RLCN2,RLCarg1,...
    SourceName,SourceN1,SourceN2,...
    Sourcetype,SourceDcValue,SourceAcValue,...
    SourceFreq,SourcePhase,...
    MOSName,MOSN1,MOSN2,MOSN3,...
    MOStype,MOSW,MOSL,...
    MOSMODEL,PLOT,SPICEOperation]=parse_netlist(filename);
%% 根据读到的操作选择执行任务的分支
DCnetlist=Generate_DCnetlist(RLCName,RLCN1,RLCN2,RLCarg1,...
    SourceName,SourceN1,SourceN2,...
    Sourcetype,SourceDcValue,SourceAcValue,...
    SourceFreq,SourcePhase,...
    MOSName,MOSN1,MOSN2,MOSN3,...
    MOStype,MOSW,MOSL,...
    MOSMODEL);
switch SPICEOperation{1}{1}
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
        plotport=portMapping(PLOT);
        [timeseries,Values]=trans(plotport,x,transnetlist);
        plot(timeseries,Values);
    case {'.dc','.DC'}
        Error = 1e-6;
        % 到这里需要DC电路网表
        x=caculateDC(DCnetlist,Error);
        plotport=portMapping(PLOT);
        Values = DC(plotport,x);
        display(Values);
end
