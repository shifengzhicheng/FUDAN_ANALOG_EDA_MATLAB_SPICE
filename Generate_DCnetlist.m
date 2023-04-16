%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Generate_DCnetlist%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 映射节点、生成初始解、替换mos器件
function [Name,N1,N2,dependence,Value,MOSLine,x_0] = Generate_DCnetlist(RLCName,RLCN1,RLCN2,RLCarg1,...
    SourceName,SourceN1,SourceN2,...
    Sourcetype,SourceDcValue,SourceAcValue,...
    SourceFreq,SourcePhase,...
    MOSName,MOSN1,MOSN2,MOSN3,...
    MOStype,MOSW,MOSL,...
    MOSMODEL)

%% 初始化变量
Length =  length(RLCName) + length(SourceName) + length(MOSName)*3;
Name = cell(1,Length);
N1 = zeros(1,Length);
N2 = zeros(1,Length);
dependence = cell(1,Length);
Value = zeros(1,Length);
kl = 0; %遍历变量

%% 节点映射
Node = [RLCN1,RLCN2,SourceN1,SourceN2,MOSN1,MOSN2,MOSN3];
Node_Map = zeros(length(Node),1);
for i=1:length(Node)
    Node_Map(i,1)=str2double(Node(i));
end
Node_Map = unique(Node_Map,"rows");

%% 处理RLC
for i=1:length(RLCName)
    Node1 = find(Node_Map==str2double(RLCN1(i)))-1;
    Node2 = find(Node_Map==str2double(RLCN2(i)))-1;
    kl=kl+1;
   switch RLCName{i}(1)
       case 'R'
           Name{kl} = RLCName{i};
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = str2double(RLCarg1{i});
       case 'L'
           Name{kl} = ['V',RLCName{i}];
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = 0;
       case 'C'
           Name{kl} = ['I',RLCName{i}];
           N1(kl) = Node1;
           N2(kl) = Node2;
           Value(kl) = 0;
   end
end

%% 处理Source
for i=1:length(SourceName)
    Node1 = find(Node_Map==str2double(SourceN1(i)))-1;
    Node2 = find(Node_Map==str2double(SourceN2(i)))-1;
    kl=kl+1;
    Name{kl} = SourceName{i};
    N1(kl) = Node1;
    N2(kl) = Node2;
    Value(kl) = str2double(SourceDcValue{i});
end

%% 生成初始解

% x_0 = init_value(…………)
% 同时变更下面mos_calculator的带入电压值

%% 处理mos

% 从这儿开始是mos
% MOSLine = kl+1

%处理Mos,结点顺序DGS
%Output = cell(1,length(MOSName)*3);
for i=1:length(MOSName)
    Node1 = find(Node_Map==str2double(MOSN1(i)))-1;
    Node2 = find(Node_Map==str2double(MOSN2(i)))-1;
    Node3 = find(Node_Map==str2double(MOSN3(i)))-1;
   switch MOStype{i}
       case 'n'
           Mostype = 2;
       case 'p'
           Mostype = 1;
   end
   %这里的4和2怎么根据初始解改 这个接口 也需要再看下
   [Ikk,GMk,GDSk] = Mos_Calculator(4,2,MOSMODEL(:,Mostype),str2double(MOSW(i)),str2double(MOSL(i)));
    kl = kl+1;
    Name{kl} = ['R',MOSName{i}];
    N1(kl) = Node1;
    N2(kl) = Node3;
    Value(kl) = 1/GDSk;
    kl = kl+1;
    Name{kl} = ['G',MOSName{i}];
    N1(kl) = Node1;
    N2(kl) = Node3;
    dependence{kl} = [Node2,Node3];
    Value(kl) = GMk;
    kl = kl+1;
    Name{kl} = ['I',MOSName{i}];
    N1(kl) = Node1;
    N2(kl) = Node3;
    Value(kl) = Ikk;
end
