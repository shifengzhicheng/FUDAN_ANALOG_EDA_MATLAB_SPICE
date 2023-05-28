%% 项目的顶层模块，用于实现整个项目的仿真流程
% 此文件为项目搭建的顶层架构，用于梳理和切割项目实现的功能并实现模块化
clear;
clc;
%% 读取文件，预处理阶段
file='dbmixerShoot';
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
        DCres=[0;DCres];
        [LinerNet,CINFO,LINFO]=...
            Generate_ACnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO,DCres,Node_Map);
        % 获取AC信息
        ACMode = SPICEOperation{1}{2};
        ACPoint = str2double(SPICEOperation{1}{3});
        fstart = tranNumber(SPICEOperation{1}{4});
        fstop = tranNumber(SPICEOperation{1}{5});
        ACinfo={ACMode,ACPoint,fstart,fstop};
        % AC扫描获得结果
        [Res,freq,LinerNet,x_0]=Sweep_AC(LinerNet,CINFO,LINFO,ACinfo);
        %要打印的序号值或者器件类型加端口名
        [plotnv, plotnc] = portMapping(PLOT,Node_Map);
        plotnv=plotnv';
        plotnc=plotnc';
        % 提取所需要的信息
        [Obj,freq,Gain,Phase] = ValueCalcAC(plotnc,plotnv,Res,freq,LinerNet,Node_Map,x_0);
        % 绘制AC响应图像
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
        %Trans网表得到
        [LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map]=...
            Generate_transnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
        % 瞬态仿真需要时间步长和仿真的时间
        stopTime = str2double(SPICEOperation{1}{2});
        stepTime = str2double(SPICEOperation{1}{3});
        % Δt初始值
        delta_t0 = 0.5 * stepTime;
        % 瞬态仿真模式 - "BE" or "TR"
        TransMethod = "BE";
        %瞬态推进模式 - "Fix" or "Dynamic"
        StepMethod = "Fix";

        % 生成初始解
        [InitRes, InitDeviceValue, CVi, CIi, LVi, LIi] = TransInitial(LinerNet, SourceINFO, MOSINFO, DIODEINFO, CINFO, LINFO, Error, delta_t0, TransMethod);

        % 瞬态推进过程
        if(StepMethod == "Fix")
            [ResData, DeviceDatas] = TransTR_fix(InitRes, InitDeviceValue, CVi, CIi, LVi, LIi, ...
                LinerNet, MOSINFO, DIODEINFO, CINFO, LINFO, SinINFO,...
                Error, delta_t0, stopTime, stepTime);
        elseif(StepMethod == "Dynamic")
            [ResData, DeviceDatas] = TransBE_Dynamic(InitRes, InitDeviceValue, CVi, CIi, LVi, LIi, ...
                LinerNet, MOSINFO, DIODEINFO, CINFO, LINFO, SinINFO,...
                Error, delta_t0, stopTime, stepTime);
        end

        %结果处理输出打印输出过程
        [~, x_0, ~] = Gen_Matrix(LinerNet('Name'),LinerNet('N1'),LinerNet('N2'),LinerNet('dependence'),LinerNet('Value'));
        [plotnv, plotCurrent] = portMapping(PLOT,Node_Map);
        LinerNet('Value') = DeviceDatas;
        [Obj,Res] = ValueCalcTrans(ResData,LinerNet,Node_Map,x_0,plotnv,plotCurrent);
        for i=1:size(Obj,1)
            figure('Name',Obj{i})
            plot((0 : stepTime : stopTime), Res(i,:));
            title(Obj{i});
            %             saveas(gcf, ['picture/' file '_' Obj{i} '.png']);
        end
    case '.dc'
        [LinerNet,MOSINFO,DIODEINFO,Node_Map]=...
            Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
        Error = 1e-6;
        % 到这里需要DC电路网表
        [DCres, x_0, newValue] = calculateDC(LinerNet,MOSINFO,DIODEINFO, Error);
        DCres=[0;DCres];
        LinerNet('Value') = newValue';
        [plotnv, plotCurrent] = portMapping(PLOT,Node_Map);
        % plotcurrent需要一个device，还需要一个port
        % plotnv是序号，可以通过x(plotnv)得到
        [Obj, Values] = ValueCalcDC(plotnv, plotCurrent, ...
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
        DCres=[0;DCres];
        [LinerNet,CINFO,LINFO]=...
            Generate_ACnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO,DCres,Node_Map);
        [result] = Gen_PZ(LinerNet,CINFO,LINFO,PLOT,Node_Map);
        nodes = result('ID');
        zeros = result('zero');
        poles = result('pole');
        for i = 1:length(nodes)
            fprintf('Node %d : \n',nodes(i));
            fprintf('Zeros: \n');
            display(zeros{i});
            fprintf('Poles: \n');
            display(poles{i});
        end
    case '.shoot'
        [LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map]=...
            Generate_transnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO);
        Error = 1e-6;
        stepTime = tranNumber(SPICEOperation{1}{3});
        TotalTime = tranNumber(SPICEOperation{1}{2});
        [Obj, PlotValues, printTimePoint] = shooting_method(LinerNet,MOSINFO,DIODEINFO,CINFO,LINFO,SinINFO,Node_Map,...
            Error,stepTime,TotalTime,PLOT);
        for i=1:size(Obj,1)
            figure('Name',Obj{i})
            plot(printTimePoint,PlotValues(i,:));
            title(Obj{i});
            %             saveas(gcf, ['picture/' file '_' Obj{i} '.png']);
        end
end
