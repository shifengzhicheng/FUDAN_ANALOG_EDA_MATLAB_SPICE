%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Generate_DCnetlist%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 映射节点、生成初始解、替换mos器件
function [LinerNet,MOSINFO,DIODEINFO,BJTINFO,Node_Map]=...
    Generate_DCnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO,BJTINFO)
% *************** 已加BJT端口 ***************

%% 初始化变量
%RCL 拆开
RINFO = RCLINFO('RINFO');
CINFO = RCLINFO('CINFO');
LINFO = RCLINFO('LINFO');

% 器件名称
RLCName = [RINFO('Name'),CINFO('Name'),LINFO('Name')];
SourceName = SourceINFO('Name');
MOSName = MOSINFO('Name');
DiodeName = DIODEINFO('Name');
% ################################### BJT start ###################################
BJTName = BJTINFO('Name');
% ################################### BJT end ###################################

% 节点序号
RN1 = str2double(RINFO('N1'));
LN1 = str2double(LINFO('N1'));
RN2 = str2double(RINFO('N2'));
LN2 = str2double(LINFO('N2'));
RLCN1 = str2double([RINFO('N1'),CINFO('N1'),LINFO('N1')]);
RLCN2 = str2double([RINFO('N2'),CINFO('N2'),LINFO('N2')]);
SourceN1 = str2double(SourceINFO('N1'));
SourceN2 = str2double(SourceINFO('N2'));
MOSN1 = str2double(MOSINFO('d'));
MOSN2 = str2double(MOSINFO('g'));
MOSN3 = str2double(MOSINFO('s'));
DiodeN1 = str2double(DIODEINFO('N1'));
DiodeN2 = str2double(DIODEINFO('N2'));
% ################################### BJT start ###################################
BJTN1 = str2double(BJTINFO('c'));
BJTN2 = str2double(BJTINFO('b'));
BJTN3 = str2double(BJTINFO('e'));
% ################################### BJT end ###################################

%其他所需变量
SourceDcValue = str2double(SourceINFO('DcValue'));
RLCarg = str2double([RINFO('Value'),CINFO('Value'),LINFO('Value')]);
MOStype = MOSINFO('type');
MOSW = str2double(MOSINFO('W'));
MOSL = str2double(MOSINFO('L'));
MOSID = str2double(MOSINFO('ID'));
MOSMODEL = cell2mat(MOSINFO('MODEL'));
DiodeID = str2double(DIODEINFO('ID'));
%DiodeMODEL = str2double(DIODEINFO('MODEL'));
DiodeMODEL = cell2mat(DIODEINFO('MODEL'));
% ################################### BJT start ###################################
BJTtype = BJTINFO('type');
BJTJunctionarea = str2double(BJTINFO('Junctionarea'));
BJTID = str2double(BJTINFO('ID'));
BJTMODEL = BJTINFO('MODEL');
% ################################### BJT end ###################################

% 输出结果
Length =  1;  % MOS的线性化模型有3个器件
Name = cell(1,Length);
N1 = zeros(1,Length);
N2 = zeros(1,Length);
dependence = cell(1,Length);
Value = zeros(1,Length);
kl = 0; %遍历变量

%% 生成DeviceInfo
[DeviceInfo] = Gen_DeviceInfo(RLCName,RLCN1,RLCN2,...
    SourceName,SourceN1,SourceN2,SourceDcValue,...
    MOSName,MOSN1,MOSN2,MOSN3,MOStype,...
    DiodeName, DiodeN1, DiodeN2,...
    BJTName,BJTN1,BJTN2,BJTN3,BJTtype);
% *************** 已加BJT端口 ***************

%% 节点映射
Node = [RLCN1,RLCN2,SourceN1,SourceN2,MOSN1,MOSN2,MOSN3,DiodeN1,DiodeN2,BJTN1,BJTN2,BJTN3];
% *************** 已加BJT端口 ***************
Node_Map = zeros(length(Node),1);
for i = 1:length(Node)
    Node_Map(i,1) = Node(i);
end
Node_Map = unique(Node_Map,"rows");

%% DC 节点映射
NodeDC = [RN1,RN2,LN1,LN2,SourceN1,SourceN2,MOSN1,MOSN2,MOSN3,DiodeN1,DiodeN2,BJTN1,BJTN2,BJTN3];
% *************** 已加BJT端口 ***************
NodeDC = unique(NodeDC',"rows");
NodeL = unique([LN1,LN2])';
[Node_Map_DC] = Node_Mapping_DC(NodeDC,NodeL,LN1,LN2);

%% 新建 NodeInfo 优化DeviceInfo的值
[NodeInfo,DeviceInfo] = Gen_NodeInfo(Node_Map,DeviceInfo);

%% 处理RLC
for i=1:length(RLCName)
    Node1 = find(Node_Map==RLCN1(i))-1;  % 节点索引从0开始，∴要-1
    Node2 = find(Node_Map==RLCN2(i))-1;  % 节点索引从0开始，∴要-1
    kl=kl+1;
   switch RLCName{i}(1)
       case 'R'
           Name{kl} = RLCName{i};
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = RLCarg(i);
       case 'L'
           Name{kl} = ['V',RLCName{i}];  % 电感DC时等价为1个电压为0的电压源
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = 0;
       case 'C'
           Name{kl} = ['I',RLCName{i}];  % 电容DC时等价为1个电流为0的电流源
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = 0;
   end

end

%% 处理Source
for i=1:length(SourceName)
    Node1 = find(Node_Map==SourceN1(i))-1;
    Node2 = find(Node_Map==SourceN2(i))-1;
    kl=kl+1;
    Name{kl} = SourceName{i};
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = SourceDcValue(i);
end

%% 生成初始解
% Index = find(contains({'Vdd'},SourceName));
Vdd = SourceDcValue(1);

for i = 1:numel(NodeInfo)
    if isequal(NodeInfo{i}.node, SourceN1(1))
        Vdd_node = NodeInfo{i}.index;
        break;
    end
end

for i = 1:numel(NodeInfo)
    if isequal(NodeInfo{i}.node, SourceN2(1))
        Gnd_node = NodeInfo{i}.index;
        break;
    end
end

%Vdd_node = SourceN1{1};
%Gnd_node = SourceN2{1};
%Vdd = Value(Index);
%Vdd_node = SourceN1(Index);
%Gnd_node = 0;

x_0 = init_value(NodeInfo,DeviceInfo,Vdd,Vdd_node,Gnd_node);

%% 处理mos 替换mos器件
% 记录mos最后更改位置
MOSLine = kl+1;

for i=1:length(MOSName)
    Node1 = find(Node_Map==MOSN1(i))-1;
    Node2 = find(Node_Map==MOSN2(i))-1;
    Node3 = find(Node_Map==MOSN3(i))-1;
   VD = x_0(Node1 + 1);
   VG = x_0(Node2 + 1);
   VS = x_0(Node3 + 1);
   if MOStype{i} == 'n' && VD < VS || MOStype{i} == 'p' && VD > VS  %源漏互换
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
   [Ikk,GMk,GDSk] = Mos_Calculator(VDS,VGS,MOSMODEL(:,MOSID(i)),MOSW(i),MOSL(i));
   % [Ikk,GMk,GDSk] = Mos_Calculator(4,2,MOSMODEL(:,MOSID_C(i)),str2double(MOSW(i)),str2double(MOSL(i)));
   Ikk = Ikk * flag;
   GMk =  GMk * flag;
    kl = kl+1;
    Name{kl} = ['R',MOSName{i}];
    N1(kl) = Node1;
    N2(kl) = Node3;
    Value(kl) = 1/GDSk;
    kl = kl+1;
    Name{kl} = ['G',MOSName{i}];
    N1(kl) = Node1;
    N2(kl) = Node3;
    if(flag == -1)
        dependence{kl} = [Node2,Node1];
    else
        dependence{kl} = [Node2,Node3];
    end
    Value(kl) = GMk;
    kl = kl+1;
    Name{kl} = ['I',MOSName{i}];
    N1(kl) = Node1;
    N2(kl) = Node3;
    Value(kl) = Ikk;
    
end

MOSINFO = containers.Map({'Name','MODEL','type','W','L','ID','MOSLine'},{MOSName,MOSMODEL,MOStype,MOSW,MOSL,MOSID,MOSLine});

%% 处理Diode 替换Diode器件
% 记录Diode最后更改位置Is，diodeLine
DiodeLine = kl+1;
Is = zeros(1, length(DiodeName));
for i=1:length(DiodeName)
    Node1 = find(Node_Map==DiodeN1(i))-1;
    Node2 = find(Node_Map==DiodeN2(i))-1;

    V1 = x_0(Node1 + 1);
    V2 = x_0(Node2 + 1);
    VT = V1 - V2;
    Is(i) = DiodeMODEL(2,DiodeID(i));
%     [Gdk, Ieqk] = Diode_Calculator(VT, Is(i), 27);
    [Gdk, Ieqk] = Diode_Calculator(0.66, Is(i), 27);
    kl = kl+1;
    Name{kl} = ['R',DiodeName{i}];
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = 1/Gdk;
    kl = kl+1;
    Name{kl} = ['I',DiodeName{i}];
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = Ieqk;
    
end

DIODEINFO = containers.Map({'Name','Is','DiodeLine'},{DiodeName, Is, DiodeLine});

% ########################################### BJT start ###########################################

%% 处理BJT 替换BJT器件
% 记录BJT最后更改位置Is，BJTLine
BJTLine = kl+1;

for i = 1:length(BJTName)
    Node1 = find(Node_Map==BJTN1(i))-1;  % C
    Node2 = find(Node_Map==BJTN2(i))-1;  % B
    Node3 = find(Node_Map==BJTN3(i))-1;  % E
    VC = x_0(Node1 + 1);
    VB = x_0(Node2 + 1);
    VE = x_0(Node3 + 1);
    BJTflag = 0;
    if isequal(BJTtype{i}, 'npn')
        BJTflag = 1;
    elseif isequal(BJTtype{i}, 'pnp')
        BJTflag = -1;
    end
    VBE = VB - VE;
    VBC = VB - VC;
    
    T = 300;
%     [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(VBE,VBC,BJTMODEL(:,BJTID(i)), BJTJunctionarea(i), BJTflag, T);
    if BJTflag == 1
        [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(0.7,0.1,BJTMODEL(:,BJTID(i)), BJTJunctionarea(i), BJTflag, T);
    elseif BJTflag == -1
        [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(-0.7,-0.1,BJTMODEL(:,BJTID(i)), BJTJunctionarea(i), BJTflag, T);
    end
    % 在E-B节点间贴电阻Rbe
    kl = kl+1;
    Name{kl} = ['R',BJTName{i},'_E'];
    N1(kl) = Node3;
    N2(kl) = Node2;
    Value(kl) = Rbe_k;
    % 在E-B节点间贴1个Vbc控制的VCCS
    kl = kl+1;
    Name{kl} = ['G',BJTName{i}, '_E'];
    N1(kl) = Node3;
    N2(kl) = Node2;
    dependence{kl} = [Node2,Node1];
    Value(kl) = Gbc_e_k;    
    % 在E-B节点间贴电流源Ieq
    kl = kl+1;
    Name{kl} = ['I', BJTName{i}, '_E'];
    N1(kl) = Node3;
    N2(kl) = Node2;
    Value(kl) = Ieq_k;    
    
    % 在C-B节点间贴电阻Rbc
    kl = kl+1;
    Name{kl} = ['R',BJTName{i}, '_C'];
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = Rbc_k; 
    % 在C-B节点间贴1个Vbe控制的VCCS
    kl = kl+1;
    Name{kl} = ['G',BJTName{i}, '_C'];
    N1(kl) = Node1;
    N2(kl) = Node2;
    dependence{kl} = [Node2,Node3];
    Value(kl) = Gbe_c_k;   
    % 在C-B节点间贴电流源Icq
    kl = kl+1;
    Name{kl} = ['I', BJTName{i}, '_C'];
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = Icq_k;    
end

BJTINFO = containers.Map({'Name','MODEL','type','Junctionarea','ID','BJTLine'},{BJTName,BJTMODEL,BJTtype,BJTJunctionarea,BJTID,BJTLine});

% ########################################### BJT end ###########################################


%% 打包输出
LinerNet = containers.Map({'Name','N1','N2','dependence','Value'},{Name,N1,N2,dependence,Value});

end
