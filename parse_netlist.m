% 此函数由郑志宇完成，读取网表文件并提取所有的有效信息
%% 函数主体
% 这个函数获得的数据来自网表
function [RCLINFO,SourceINFO,MOSINFO,...
    DIODEINFO,BJTINFO,PLOT,SPICEOperation]...
    =parse_netlist(filename)
%% 读取网表文件
fid = fopen(filename, 'r');
Count=0;
MCount=0;
DCount=0;
% #############################################################################
Qcount=0;
% ################################# end #######################################
SourceCount=0;
MOSMODELCount=0;
DIODEMODELCount=0;
BJTMODELCount=0;
PlotCount=0;
OperationCount=0;
%% 数据初始化
RLCName=cell(0);
SourceName=cell(0);
RLCN1=cell(0);
RLCN2=cell(0);
RLCValue=cell(0);
SourceN1=cell(0);
SourceN2=cell(0);
Sourcetype=cell(0);
SourceDcValue=cell(0);
SourceAcValue=cell(0);
SourceFreq=cell(0);
SourcePhase=cell(0);
MOSName=cell(0);
MOSN1=cell(0);
MOSN2=cell(0);
MOSN3=cell(0);
MOStype=cell(0);
MOSW=cell(0);
MOSL=cell(0);
MOSID=cell(0);
MOSMODEL= cell(0);
PLOT=cell(0);
SPICEOperation=cell(0);
Diodes=cell(0);
DiodeN1=cell(0);
DiodeN2=cell(0);
DiodeID=cell(0);
DIODEMODEL=cell(0);
% #############################################################################
BJTName=cell(0);
BJTN1=cell(0);
BJTN2=cell(0);
BJTN3=cell(0);
BJTtype=cell(0);
BJTJunctionarea=cell(0);
BJTID=cell(0);
BJTMODEL=cell(0);
% ################################## end ######################################
%% 解析每一行
while ~feof(fid)
    % 读取一行
    line = fgets(fid);
    % 匹配开头的关键字母
    tokens_Device = regexp(line, '^(\w+)', 'tokens');
    % 匹配MODEL
    tokens_MODEL = regexp(line, '^(\.MODEL)', 'tokens');
    tokens_DIODEMODEL = regexp(line, '^(\.DIODE)', 'tokens');
    % #############################################################################
    tokens_BJTMODEL = regexp(line, '^(\.BIPOLAR)', 'tokens');
    % ################################## end ######################################
    % 匹配作图节点数据
    tokens_Plot = regexp(line, '^(\.plot)', 'tokens', 'ignorecase');
    % 匹配操作
    tokens_Operation = regexp(line, '^[(\.hb)(\.trans)(\.dc)(\.dcsweep)]', 'tokens', 'ignorecase');
    if ~isempty(tokens_Device)
        % 提取关键字符
        keyword = tokens_Device{1}{1}(1);
        Device = strsplit(strtrim(line));
        switch keyword
            case {'R','L','C'}
                % RLC处理
                Count = Count + 1;
                [RLCName{Count},RLCN1{Count},RLCN2{Count},RLCValue{Count}]=Device{:};
            case {'V','I'}
                % 直流交流源处理
                SourceCount = SourceCount + 1;
                % 这里要对交流直流进行讨论处理
                Sourcetype{SourceCount}=Device(4);
                switch Sourcetype{SourceCount}{1}
                    case 'SIN'
                        [SourceName{SourceCount},SourceN1{SourceCount},SourceN2{SourceCount},...
                            Sourcetype{SourceCount},SourceDcValue{SourceCount},SourceAcValue{SourceCount},...
                            SourceFreq{SourceCount},SourcePhase{SourceCount}]=Device{:};

                    case {'DC','dc'}
                        [SourceName{SourceCount},SourceN1{SourceCount},SourceN2{SourceCount},...
                            Sourcetype{SourceCount},SourceDcValue{SourceCount}]=Device{:};
                end
            case {'M'}
                % MOS管处理
                MCount = MCount+1;
                [MOSName{MCount},MOSN1{MCount},MOSN2{MCount},MOSN3{MCount},...
                    MOStype{MCount},MOSW{MCount},MOSL{MCount},MOSID{MCount}]=Device{:};
            case {'D'}
                % 二极管处理
                DCount = DCount+1;
                [Diodes{DCount},DiodeN1{DCount},DiodeN2{DCount},DiodeID{DCount}]=Device{:};
            % #############################################################################
            case {'Q'}
                % ############# 认为网表文件中: 先写MOS，再写Diode，最后写BJT #############
                % ################### 三极管在网表中的输入格式如下 ########################
                % #################### Q1 103 104 105 npn 900 1 #########################
                % ################# 上面的900指的是900um^2的结面积 #######################
                % 三极管处理
                Qcount = Qcount+1;
                [BJTName{Qcount},BJTN1{Qcount},BJTN2{Qcount},BJTN3{Qcount},BJTtype{Qcount},BJTJunctionarea{Qcount},BJTID{Qcount}]=Device{:};
            % ################################## end ######################################
        end

    elseif ~isempty(tokens_MODEL)
        % 匹配的正则表达式
        expr = ['\.MODEL\s+(\d+)\s+VT\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)' ...
            '\s+MU\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)\s+COX\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)\s+' ...
            'LAMBDA\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)\s+CJ0\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)'];
        % 在这里已经匹配到了模型数据
        % 按照标准的格式进行模型的数据赋值
        tokens = regexp(line, expr, 'tokens');
        MOSMODELCount = MOSMODELCount + 1;
        MOSMODEL{MOSMODELCount}=[str2double(tokens{1}{1}); ...
            str2double(tokens{1}{2}); ...
            str2double(tokens{1}{3}); ...
            str2double(tokens{1}{4}); ...
            str2double(tokens{1}{5}); ...
            str2double(tokens{1}{6})];
    elseif ~isempty(tokens_DIODEMODEL)
        % 匹配的正则表达式
        expr = ['\.DIODE\s+(\d+)\s+Is\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)'];
        % 在这里已经匹配到了模型数据
        % 按照标准的格式进行模型的数据赋值
        tokens = regexp(line, expr, 'tokens');
        DIODEMODELCount = DIODEMODELCount + 1;
        DIODEMODEL{DIODEMODELCount} = [str2double(tokens{1}{1}); ...
            str2double(tokens{1}{2})];
    % #############################################################################
    elseif ~isempty(tokens_BJTMODEL)
        % 匹配的正则表达式
        % ########################## BJTModel的格式如下 ############################
        % ########### .BIPOLAR 1 Js 1e-16 alpha_f 0.995 alpha_r 0.05 #############
        % ####################### Js 1e-16 的单位是A/um^2 ########################
        expr = ['\.BIPOLAR\s+(\d+)\s+Is\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)' ...
            '\s+alpha_f\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)\s+' ...
            'alpha_r\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)'];
        % 在这里已经匹配到了模型数据
        % 按照标准的格式进行模型的数据赋值
        tokens = regexp(line, expr, 'tokens');
        BJTMODELCount = BJTMODELCount + 1;
        BJTMODEL{BJTMODELCount}=[str2double(tokens{1}{1}); ...
            str2double(tokens{1}{2}); ...
            str2double(tokens{1}{3}); ...
            str2double(tokens{1}{4})];     
    % ################################# end #######################################
    elseif ~isempty(tokens_Plot)
        % 在这里已经匹配到了作图的节点
        PlotCount = PlotCount + 1;
        PLOT{PlotCount}=strsplit(strtrim(line));

    elseif ~isempty(tokens_Operation)
        % 在这里已经匹配到了操作的名称
        OperationCount = OperationCount + 1;
        SPICEOperation{OperationCount}=strsplit(strtrim(line));
    end
end
RCLINFO=containers.Map({'Name','N1','N2','Value'},...
    {RLCName,RLCN1,RLCN2,RLCValue});
%{
fprintf("<parse netlist>RCLINFO:\n\n");
disp(RLCName);
disp(RLCN1);
disp(RLCN2);
disp(RLCValue);
%}
SourceINFO=containers.Map({'Name','N1','N2',...
    'type','DcValue','AcValue',...
    'Freq','Phase'},...
    {SourceName,SourceN1,SourceN2,...
    Sourcetype,SourceDcValue,SourceAcValue,...
    SourceFreq,SourcePhase});
%{
fprintf("<parse netlist>SOURCEINFO:\n\n");
disp(SourceName);
disp(SourceN1);
disp(SourceN2);
disp(Sourcetype);
disp(SourceDcValue);
disp(SourceAcValue);
disp(SourceFreq);
disp(SourcePhase);
%}
MOSINFO=containers.Map({'Name','d','g','s',...
    'type','W','L','ID','MODEL'},...
    {MOSName,MOSN1,MOSN2,MOSN3,...
    MOStype,MOSW,MOSL,MOSID,MOSMODEL});
%{
fprintf("<parse netlist>MOSINFO:\n\n");
disp(MOSName);
disp(MOSN1);
disp(MOSN2);
disp(MOSN3);
disp(MOStype);
disp(MOSW);
disp(MOSL);
disp(MOSID);
disp(MOSMODEL);
%}
DIODEINFO=containers.Map({'Name','N1','N2','ID','MODEL'},...
    {Diodes,DiodeN1,DiodeN2,DiodeID,DIODEMODEL});
%{
fprintf("<parse netlist>DIODEINFO:\n\n");
disp(Diodes);
disp(DiodeN1);
disp(DiodeN2);
disp(DiodeID);
disp(DIODEMODEL);
%}
% #############################################################################
BJTINFO=containers.Map({'Name','N1','N2','N3','type','Junctionarea','ID','MODEL'},...
    {BJTName,BJTN1,BJTN2,BJTN3,BJTtype,BJTJunctionarea,BJTID,BJTMODEL});
%{
fprintf("<parse netlist>BJTINFO:\n\n");
disp(BJTName);
disp(BJTN1);
disp(BJTN2);
disp(BJTN3);
disp(BJTtype);
disp(BJTJunctionarea);
disp(BJTID);
disp(BJTMODEL);
%}
% ################################## end ######################################
% 关闭文件
fclose(fid);
