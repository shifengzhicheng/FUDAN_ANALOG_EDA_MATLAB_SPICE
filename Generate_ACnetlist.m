%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Generate_ACnetlist%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 文件作者：朱瑞宸
%% 映射节点、生成初始解、替换mos器件
function [LinerNet,CINFO,LINFO]=...
    Generate_ACnetlist(RCLINFO,SourceINFO,MOSINFO,DIODEINFO,BJTINFO,DCres,Node_Map)
% *************** 已加BJT端口 ***************

%% 初始化变量
%RCL 拆开
RINFO = RCLINFO('RINFO');
CINFO = RCLINFO('CINFO');
LINFO = RCLINFO('LINFO');

% 器件名称
RName = RINFO('Name');
CName = CINFO('Name');
LName = LINFO('Name');
SourceName = SourceINFO('Name');
MOSName = MOSINFO('Name');
DiodeName = DIODEINFO('Name');
% ################################### BJT start ###################################
BJTName = BJTINFO('Name');
% ################################### BJT end ###################################

% 节点序号
RN1 = str2double(RINFO('N1'));
RN2 = str2double(RINFO('N2'));
CN1 = str2double(CINFO('N1'));
CN2 = str2double(CINFO('N2'));
LN1 = str2double(LINFO('N1'));
LN2 = str2double(LINFO('N2'));
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
Rarg = str2double(RINFO('Value'));
Carg = str2double(CINFO('Value'));
Larg = str2double(LINFO('Value'));
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
SourceType = SourceINFO('type');
SourceAcValue = str2double(SourceINFO('AcValue'));
SourcePhase = str2double(SourceINFO('Phase'));

%DC结果
x = DCres;

% 输出结果
Length =  1;  % MOS的线性化模型有3个器件
Name = cell(1,Length);
N1 = zeros(1,Length);
N2 = zeros(1,Length);
dependence = cell(1,Length);
Value = zeros(1,Length);
kl = 0; %遍历变量

%% 处理R 不变
for t=1:length(RName)
    Node1 = find(Node_Map==RN1(t))-1;  % 节点索引从0开始，∴要-1
    Node2 = find(Node_Map==RN2(t))-1;  % 节点索引从0开始，∴要-1
    kl=kl+1;
    Name{kl} = RName{t};
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = Rarg(t);
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

% ########################################### BJT start ###########################################
% 修改 BJT 电容值
BJTNum = size(BJTID, 2);
if(~isempty(BJTMODEL))
    % add BJT - C
    BJTMODEL1 = cell2mat(BJTMODEL);
    BJTCje = BJTMODEL1(5, BJTID);
    BJTCjc = BJTMODEL1(6, BJTID);
    CbeSet = BJTCje .* BJTJunctionarea;
    CbcSet = BJTCjc .* BJTJunctionarea;
end



%% 处理BJT 替换BJT器件
% 记录BJT最后更改位置Is，BJTLine
me = 0.41;
mc = 0.41;
fy_e = 0.76;
fy_c = 0.70;
Clength_all = length(CINFO('Name'));
Clength_bjt = 2 * BJTNum;
for i = 1:length(BJTName)
    Node1 = find(Node_Map==BJTN1(i))-1;  % C
    Node2 = find(Node_Map==BJTN2(i))-1;  % B
    Node3 = find(Node_Map==BJTN3(i))-1;  % E
    VC = x(Node1 + 1);
    VB = x(Node2 + 1);
    VE = x(Node3 + 1);
    BJTflag = 0;
    if isequal(BJTtype{i}, 'npn')
        BJTflag = 1;
    elseif isequal(BJTtype{i}, 'pnp')
        BJTflag = -1;
    end
    VBE = BJTflag * (VB - VE);
    VBC = BJTflag * (VB - VC);
    
    T = 300;
%     [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(VBE,VBC,BJTMODEL(:,BJTID(i)), BJTJunctionarea(i), BJTflag, T);
    [Rbe_k, Gbc_e_k, Ieq_k, Rbc_k, Gbe_c_k, Icq_k] = BJT_Calculator(0.7,0.1,BJTMODEL(:,BJTID(i)), BJTJunctionarea(i), BJTflag, T);
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
    
    % 修改BJT寄生电容大小
    for j = Clength_all - Clength_bjt + 1 : 2 : Clength_all
        order = fix((j+1-Clength_all+Clength_bjt) / 2);
        Carg(j) = CbeSet(order) / ( (1 - (abs(VBE)/fy_e))^me );
        Carg(j+1) = CbcSet(order) / ( (1 - (abs(VBC)/fy_c))^mc );
    end
end



% ########################################### BJT end ###########################################

%% 处理C
% 记录C最后更改位置CLine
CLine = kl+1;
for t=1:length(CName)
    Node1 = find(Node_Map==CN1(t))-1;  % 节点索引从0开始，∴要-1
    Node2 = find(Node_Map==CN2(t))-1;  % 节点索引从0开始，∴要-1
    kl=kl+1;
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = 0;
end

CINFO = containers.Map({'Name','Value','CLine'},{CName, Carg, CLine});

%% 处理L
% 记录L最后更改位置LLine
LLine = kl+1;
for t=1:length(LName)
    Node1 = find(Node_Map==LN1(t))-1;  % 节点索引从0开始，∴要-1
    Node2 = find(Node_Map==LN2(t))-1;  % 节点索引从0开始，∴要-1
    kl=kl+1;
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = 0;
end

LINFO = containers.Map({'Name','Value','LLine'},{LName, Larg, LLine});

%% 打包输出
LinerNet = containers.Map({'Name','N1','N2','dependence','Value'},{Name,N1,N2,dependence,Value});

end
