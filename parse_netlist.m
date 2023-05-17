% 此函数由郑志宇完成，读取网表文件并提取所有的有效信息
%% 函数主体
% 这个函数获得的数据来自网表
function [RCLINFO,SourceINFO,MOSINFO,...
    DIODEINFO,PLOT,SPICEOperation]...
    =parse_netlist(filename)
%% 读取网表文件
fid = fopen(filename, 'r');
CountR=0;
CountC=0;
CountL=0;
MCount=0;
DCount=0;
SourceCount=0;
MOSMODELCount=0;
DIODEMODELCount=0;
PlotCount=0;
OperationCount=0;
%% 数据初始化
RName=cell(0);
RN1=cell(0);
RN2=cell(0);
RValue=cell(0);
CName=cell(0);
CN1=cell(0);
CN2=cell(0);
CValue=cell(0);
LName=cell(0);
LN1=cell(0);
LN2=cell(0);
LValue=cell(0);
SourceName=cell(0);
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
%% 解析每一行
while ~feof(fid)
    % 读取一行
    line = fgets(fid);
    % 匹配开头的关键字母
    tokens_Device = regexp(line, '^(\w+)', 'tokens');
    % 匹配MODEL
    tokens_MODEL = regexp(line, '^(\.MODEL)', 'tokens');
    tokens_DiodeModel = regexp(line, '^(\.DIODE)', 'tokens');
    % 匹配作图节点数据
    tokens_Plot = regexp(line, '^(\.plot)', 'tokens', 'ignorecase');
    % 匹配操作
    tokens_Operation = regexp(line, '^[(\.ac)(\.trans)(\.dc)(\.dcsweep)]', 'tokens', 'ignorecase');
    if ~isempty(tokens_Device)
        % 提取关键字符
        keyword = tokens_Device{1}{1}(1);
        Device = strsplit(strtrim(line));
        switch keyword
            case 'R'
                % R处理
                CountR = CountR + 1;
                [RName{CountR},RN1{CountR},RN2{CountR},RValue{CountR}]=Device{:};
            case 'C'
                % C处理
                CountC = CountC + 1;
                [CName{CountC},CN1{CountC},CN2{CountC},CValue{CountC}]=Device{:};
            case 'L'
                % L处理
                CountL = CountL + 1;
                [LName{CountL},LN1{CountL},LN2{CountL},LValue{CountL}]=Device{:};
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
                    case {'AC','ac'}
                        [SourceName{SourceCount},SourceN1{SourceCount},SourceN2{SourceCount},...
                            Sourcetype{SourceCount},SourceDcValue{SourceCount},SourceAcValue{SourceCount},...
                            SourcePhase{SourceCount}]=Device{:};
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
    elseif ~isempty(tokens_DiodeModel)
        % 匹配的正则表达式
        expr = ['\.DIODE\s+(\d+)\s+Is\s+([\+\-]?\d*\.?\d+(?:[eE][\+\-]?\d+)?)'];
        % 在这里已经匹配到了模型数据
        % 按照标准的格式进行模型的数据赋值
        tokens = regexp(line, expr, 'tokens');
        DIODEMODELCount = DIODEMODELCount + 1;
        DIODEMODEL{DIODEMODELCount} = [str2double(tokens{1}{1});str2double(tokens{1}{2})];
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

RINFO=containers.Map({'Name','N1','N2','Value'},...
    {RName,RN1,RN2,RValue});
CINFO=containers.Map({'Name','N1','N2','Value'},...
    {CName,CN1,CN2,CValue});
LINFO=containers.Map({'Name','N1','N2','Value'},...
    {LName,LN1,LN2,LValue});
RCLINFO=containers.Map({'RINFO','CINFO','LINFO'},{RINFO,CINFO,LINFO});
SourceINFO=containers.Map({'Name','N1','N2',...
    'type','DcValue','AcValue',...
    'Freq','Phase'},...
    {SourceName,SourceN1,SourceN2,...
    Sourcetype,SourceDcValue,SourceAcValue,...
    SourceFreq,SourcePhase});
MOSINFO=containers.Map({'Name','d','g','s',...
    'type','W','L','ID','MODEL'},...
    {MOSName,MOSN1,MOSN2,MOSN3,...
    MOStype,MOSW,MOSL,MOSID,MOSMODEL});
DIODEINFO=containers.Map({'Name','N1','N2','ID','MODEL'},...
    {Diodes,DiodeN1,DiodeN2,DiodeID,DIODEMODEL});
RCLINFO('CINFO') = compCINFO(RCLINFO('CINFO'),MOSINFO);
% 关闭文件
fclose(fid);
