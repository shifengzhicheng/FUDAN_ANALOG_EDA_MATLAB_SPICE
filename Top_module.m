%% 项目的顶层模块，用于实现整个项目的仿真流程
% 此文件为项目搭建的顶层架构，用于梳理和切割项目实现的功能并实现模块化
clear;
clc;
%% 读取文件，预处理阶段
file=['diftestTrans'];
filename = ['testfile\' file '.sp'];
% filename = 'testfile\buffer.sp';
[RCLINFO,SourceINFO,MOSINFO,...
    DIODEINFO,PLOT,SPICEOperation]...
    =parse_netlist(filename);

%% LinerNet
% Name cell,'Name'
% N1 double
% N2 double
% dependence cell [cp1 cp2] or 'Name'
% Value double
% MOSLine double

%% MOSINFO
% Name cell 'Name'
% MODEL cell [ID,Vth,MU,COX,LAMBDA]
% type cell 'n/p'
% W double
% L double
% ID double
% MOSLine double*1

%% DIODEINFO
% Name cell 'Name'
% IS double
% DiodeLine double*1

%% Node_Map
% double

%% 根据读到的操作选择执行任务的分支
switch lower(SPICEOperation{1}{1})
    case '.dcsweep'
        [LinerNet,MOSINFO,DIODEINFO,Node_Map]=...
            Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
        Error = 1e-6;
        DeviceName = SPICEOperation{1}{2};
        range = eval(SPICEOperation{1}{3});
        step = tranNumber(SPICEOperation{1}{4});
        OperationInfo = {DeviceName,range,step};
        [InData, Obj, Res] = Sweep_DC(LinerNet,...
            MOSINFO,DIODEINFO,Error,OperationInfo,PLOT,Node_Map);
        for i=1:size(Obj,1)
            figure('Name',Obj{i})
            plot(InData,Res(i,:));
            title(Obj{i});
            %             saveas(gcf, ['picture/' file '_' Obj{i} '.png']);
        end
    case '.ac'
        % 这里进入AC分析
        % 首先进行一次DC分析求出电路的解
        [LinerNet,MOS,DIODE,Node_Map]=...
            Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
        Error = 1e-6;
        % 到这里需要DC电路网表
        [DCres, ~] = calculateDC(LinerNet,MOS,DIODE, Error);
        DCres('x')=[0;DCres('x')];
        [LinerNet,CINFO,LINFO]=...
            Generate_ACnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO,DCres,Node_Map);
        ACMode = SPICEOperation{1}{2};
        ACPoint = str2double(SPICEOperation{1}{3});
        fstart = tranNumber(SPICEOperation{1}{4});
        fstop = tranNumber(SPICEOperation{1}{5});
        ACinfo={ACMode,ACPoint,fstart,fstop};
        [Obj,freq,Gain,Phase]=Sweep_AC(LinerNet,CINFO,LINFO,ACinfo,Node_Map,PLOT);
        % 需要时间步长，AC频率
        switch lower(ACMode)
            case 'dec'
                freq = log10(freq);
            case 'lin'
        end
        for i=1:size(Obj,1)
            figure('Name',Obj{i})
            plot(freq,Gain(i,:));
            xlabel('lg(freq)'),ylabel('|H(2\pif)|');
            title([Obj{i} 'Gain']);
            %             saveas(gcf, ['picture/' file '_' Obj{i} '_Gain.png']);
            figure('Name',Obj{i})
            plot(freq,rad2deg(Phase(i,:)));
            xlabel('lg(freq)'),ylabel('\phi(2\pif)');
            title([Obj{i} 'Phase']);
            %             saveas(gcf, ['picture/' file '_' Obj{i} '_Phase.png']);
        end
    case '.trans'
        % 设置判断解收敛的标识
        Error = 1e-6;
        % 到这里需要进行瞬态仿真
        % 瞬态仿真需要时间步长和仿真的时间
        stopTime = str2double(SPICEOperation{1}{2});
        stepTime = str2double(SPICEOperation{1}{3});
        [Obj, transRes, printTimePoint] =...
            CalculateTrans(RCLINFO, SourceINFO, MOSINFO, DIODEINFO, Error, stopTime, stepTime, PLOT);
        for i=1:size(Obj,1)
            figure('Name',Obj{i})
            plot(printTimePoint,transRes(i,:));
            title(Obj{i});
            %             saveas(gcf, ['picture/' file '_' Obj{i} '.png']);
        end
    case '.dc'
        [LinerNet,MOSINFO,DIODEINFO,Node_Map]=...
            Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
        Error = 1e-6;
        % 到这里需要DC电路网表
        [DCres, x_0] = calculateDC(LinerNet,MOSINFO,DIODEINFO, Error);
        DCres('x')=[0;DCres('x')];
        [plotnv, plotCurrent] = portMapping(PLOT,Node_Map);
        % plotcurrent需要一个device，还需要一个port
        % plotnv是序号，可以通过x(plotnv)得到
        [Obj, Values] = ValueCalc(plotnv, plotCurrent, ...
            DCres,x_0, Node_Map, LinerNet);
        for i=1:size(Obj)
            display([Obj{i} ': ' num2str(Values(i))]);
        end
    case '.pz'
        % 这里进入AC分析
        % 首先进行一次DC分析求出电路的解
        [LinerNet,MOS,DIODE,Node_Map]=...
            Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
        Error = 1e-6;
        % 到这里需要DC电路网表
        [DCres, ~] = calculateDC(LinerNet,MOS,DIODE, Error);
        DCres('x')=[0;DCres('x')];
        [LinerNet,CINFO,LINFO]=...
            Generate_ACnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO,DCres,Node_Map);
        [zeros, poles] = Gen_PZ(LinerNet,CINFO,LINFO,PLOT,Node_Map);
        for i=size(zeros,1)
            display(['零点 ' num2str(zeros(i))]);
        end
        for i=size(poles,1)
            display(['极点 ' num2str(poles(i))]);
        end
    case '.shoot'
        [LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map]=...
            Generate_transnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
        Error = 1e-6;
        stepTime = tranNumber(SPICEOperation{1}{2});
        [Obj, Values, printTimePoint] = shooting_method(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map,...
            Error,stepTime,PLOT);
        for i=1:size(Obj,1)
            figure('Name',Obj{i})
            plot(printTimePoint,Values(i,:));
            title(Obj{i});
            %             saveas(gcf, ['picture/' file '_' Obj{i} '.png']);
        end
end
