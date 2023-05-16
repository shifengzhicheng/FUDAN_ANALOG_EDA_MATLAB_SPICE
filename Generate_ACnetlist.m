%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Generate_DCnetlist%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 映射节点、生成初始解、替换mos器件
function [LinerNet,LCINFO]=...
    Generate_ACnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO,DCres,Node_Map,Freq_Init)

%% 初始化变量
% 器件名称
RLCName = RCLINFO('Name');
SourceName = SourceINFO('Name');
MOSName = MOSINFO('Name');
DiodeName = DIODEINFO('Name');

% 节点序号
RLCN1 = str2double(RCLINFO('N1'));
RLCN2 = str2double(RCLINFO('N2'));
SourceN1 = str2double(SourceINFO('N1'));
SourceN2 = str2double(SourceINFO('N2'));
MOSN1 = str2double(MOSINFO('d'));
MOSN2 = str2double(MOSINFO('g'));
MOSN3 = str2double(MOSINFO('s'));
DiodeN1 = str2double(DIODEINFO('N1'));
DiodeN2 = str2double(DIODEINFO('N2'));

%其他所需变量
RLCarg = str2double(RCLINFO('Value'));
MOStype = MOSINFO('type');
MOSW = str2double(MOSINFO('W'));
MOSL = str2double(MOSINFO('L'));
MOSID = str2double(MOSINFO('ID'));
MOSMODEL = MOSINFO('MODEL');
DiodeID = str2double(DIODEINFO('ID'));
%DiodeMODEL = str2double(DIODEINFO('MODEL'));
DiodeMODEL = cell2mat(DIODEINFO('MODEL'));
SourceType = SourceINFO('type');
SourceAcValue = str2double(SourceINFO('AcValue'));
SourcePhase = str2double(SourceINFO('Phase'));

%DC结果
x = DCres('x');

% 输出结果
Length =  1;  % MOS的线性化模型有3个器件
Name = cell(1,Length);
N1 = zeros(1,Length);
N2 = zeros(1,Length);
dependence = cell(1,Length);
Value = zeros(1,Length);
kl = 0; %遍历变量

%% 处理R 不变
NR = 0; %记录RLC中R数目
for t=1:length(RLCName)
   if RLCName{t}(1) == 'R'
           Node1 = find(Node_Map==RLCN1(t))-1;  % 节点索引从0开始，∴要-1
           Node2 = find(Node_Map==RLCN2(t))-1;  % 节点索引从0开始，∴要-1
           kl=kl+1;
           Name{kl} = RLCName{t};
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = RLCarg(t);
           NR = NR+1;
   end
end

%% 处理Source 仅保留ac值
for t=1:length(SourceName)
    Node1 = find(Node_Map==SourceN1(t))-1;
    Node2 = find(Node_Map==SourceN2(t))-1;
    kl=kl+1;
    Name{kl} = SourceName{t};
    N1(kl) = Node1;
    N2(kl) = Node2;
    if SourceType{t} == "ac"
       Value(kl) = SourceAcValue(t) * exp(SourcePhase(t)/360*2*pi*1i);
    else
       Value(kl) = 0;
    end
end

%% 处理mos 根据直流工作点替换为交流小信号模型

for t=1:length(MOSName)
   Node1 = find(Node_Map==MOSN1(t))-1;
   Node2 = find(Node_Map==MOSN2(t))-1;
   Node3 = find(Node_Map==MOSN3(t))-1;
   VD = x(Node1 + 1);
   VG = x(Node2 + 1);
   VS = x(Node3 + 1);
   if MOStype{t} == 'n' && VD < VS || MOStype{t} == 'p' && VD > VS  %源漏互换
        VDS = VS - VD;
        VGS = VG - VD;
        flag = -1;
   else
        VDS = VD - VS;
        VGS = VG - VS;
        flag = 1;
   end
%    VDS
%    VGS
   [~,GMk,GDSk] = Mos_Calculator(VDS,VGS,MOSMODEL(:,MOSID(t)),MOSW(t),MOSL(t)); %用不着的参数可以这么调用
%  [~,GMk,GDSk] = Mos_Calculator(4,2,MOSMODEL(:,MOSID(i)),MOSW(i),MOSL(i)); %用不着的参数可以这么调用
   GMk =  GMk * flag;   
   kl = kl+1;
   Name{kl} = ['R',MOSName{t}];
   N1(kl) = Node1;
   N2(kl) = Node3;
   Value(kl) = 1/GDSk;
   kl = kl+1;
   Name{kl} = ['G',MOSName{t}];
   N1(kl) = Node1;
   N2(kl) = Node3;
   if(flag == -1)
       dependence{kl} = [Node2,Node1];
   else
       dependence{kl} = [Node2,Node3];
   end
   Value(kl) = GMk;    
end

%% 处理Diode 根据直流工作点替换为交流小信号模型

Is = zeros(1, length(DiodeName));
for t=1:length(DiodeName)
    Node1 = find(Node_Map==DiodeN1(t))-1;
    Node2 = find(Node_Map==DiodeN2(t))-1;
    V1 = x(Node1 + 1);
    V2 = x(Node2 + 1);
    VT = V1 - V2;
    Is(t) = DiodeMODEL(2,DiodeID(t));
    [Gdk, ~] = Diode_Calculator(VT, Is(t), 27);
    % [Gdk, Ieqk] = Diode_Calculator(0.3, Is(i), 27);
    kl = kl+1;
    Name{kl} = ['R',DiodeName{t}];
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = 1/Gdk;
end

%% 处理LC
% 记录LC最后更改位置LCLine
LCLine = kl+1;
NLC = length(RLCName) - NR;
LCName = cell(1,NLC);
LCValue = zeros(1,NLC);
ncl=0;
for t=1:length(RLCName)
   if RLCName{t}(1) == 'L'
           Node1 = find(Node_Map==RLCN1(t))-1;  % 节点索引从0开始，∴要-1
           Node2 = find(Node_Map==RLCN2(t))-1;  % 节点索引从0开始，∴要-1
           ncl = ncl+1;
           LCName{ncl} = RLCName{t};
           LCValue(ncl) = RLCarg(t);
           kl=kl+1;
           Name{kl} = ['R',RLCName{t}];         %RL……形式
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = Freq_Init*2*pi*RLCarg(t)*1i;
   elseif RLCName{t}(1) == 'C'
           Node1 = find(Node_Map==RLCN1(t))-1;  % 节点索引从0开始，∴要-1
           Node2 = find(Node_Map==RLCN2(t))-1;  % 节点索引从0开始，∴要-1
           ncl = ncl+1;
           LCName{ncl} = RLCName{t};
           LCValue(ncl) = RLCarg(t);
           kl=kl+1;
           Name{kl} = ['R',RLCName{t}];         %RC……形式
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = 1/(Freq_Init*2*pi*RLCarg(t)*1i);
   end
end

LCINFO = containers.Map({'Name','Value','LCLine'},{LCName, LCValue, LCLine});

%% 打包输出
LinerNet = containers.Map({'Name','N1','N2','dependence','Value'},{Name,N1,N2,dependence,Value});

end
