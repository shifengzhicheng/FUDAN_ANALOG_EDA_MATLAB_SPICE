%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Generate_DCnetlist%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 映射节点、生成初始解、替换mos器件
function [Name,N1,N2,dependence,Value,MOSLine,x_0, Node_Map, NodeInfo, DeviceInfo, MOSID_C] = Generate_DCnetlist(RLCName,RLCN1,RLCN2,RLCarg1,...
    SourceName,SourceN1,SourceN2,...
    Sourcetype,SourceDcValue,SourceAcValue,...
    SourceFreq,SourcePhase,...
    MOSName,MOSN1,MOSN2,MOSN3,...
    MOStype,MOSW,MOSL,MOSID,...
    MOSMODEL,...
    DeviceInfo)

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

%% 新建 NodeInfo并填入节点值
NodeInfo = cell(1,length(Node_Map));
% count = 0;
for count = 1:length(Node_Map)
    Node_Element1.index = count-1;
    Node_Element1.node = num2str(Node_Map(count));
    Node_Element1.devices = {};
    Node_Element1.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
    NodeInfo{count} = Node_Element1; 
end

%% MOSID类型转换cell->mat 方便后续调用
MOSID_C = str2double(MOSID);

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

%     % NodeInfo 更新
%     Node_Element1.index = Node1;
%     Node_Element1.node = RLCN1{i};
%     Node_Element1.devices = {};
%     Node_Element1.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
%     flag = 0;
%     for j = 1:numel(NodeInfo)
%         if isequal(NodeInfo{j}.node, Node_Element1.node)
%             flag = 1;
%             break;
%         end
%     end
%     if flag == 0
%         count = count + 1;
%         NodeInfo{count} = Node_Element1;        
%     end
% 
%     Node_Element2.index = Node2;
%     Node_Element2.node = RLCN2{i};
%     Node_Element2.devices = {};
%     Node_Element2.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
%     flag = 0;
%     for j = 1:numel(NodeInfo)
%         if isequal(NodeInfo{j}.node, Node_Element2.node)
%             flag = 1;
%             break;
%         end
%     end
%     if flag == 0
%         count = count + 1;
%         NodeInfo{count} = Node_Element2;        
%     end
    % NodeInfo更新结束
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

%     % NodeInfo更新
%     Node_Element1.index = Node1;
%     Node_Element1.node = SourceN1{i};
%     Node_Element1.devices = {};
%     Node_Element1.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
%     flag = 0;
%     for j = 1:numel(NodeInfo)
%         if isequal(NodeInfo{j}.node, Node_Element1.node)
%             flag = 1;
%             break;
%         end
%     end
%     if flag == 0
%         count = count + 1;
%         NodeInfo{count} = Node_Element1;        
%     end
% 
%     Node_Element2.index = Node2;
%     Node_Element2.node = SourceN2{i};
%     Node_Element2.devices = {};
%     Node_Element2.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
%     flag = 0;
%     for j = 1:numel(NodeInfo)
%         if isequal(NodeInfo{j}.node, Node_Element2.node)
%             flag = 1;
%             break;
%         end
%     end
%     if flag == 0
%         count = count + 1;
%         NodeInfo{count} = Node_Element2;        
%     end
%     % NodeInfo更新结束
end

% 从这儿开始是mos
%处理Mos,结点顺序DGS 这里暂时先不替换进去，只是遍历Node信息
%Output = cell(1,length(MOSName)*3);
% for i=1:length(MOSName)
%     Node1 = find(Node_Map==str2double(MOSN1(i)))-1;
%     Node2 = find(Node_Map==str2double(MOSN2(i)))-1;
%     Node3 = find(Node_Map==str2double(MOSN3(i)))-1;
%     
%     % NodeInfo更新
%     Node_Element1.index = Node1;
%     Node_Element1.node = MOSN1{i};
%     Node_Element1.devices = {};
%     Node_Element1.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
%     flag = 0;
%     for j = 1:numel(NodeInfo)
%         if isequal(NodeInfo{j}.node, Node_Element1.node)
%             flag = 1;
%             break;
%         end
%     end
%     if flag == 0
%         count = count + 1;
%         NodeInfo{count} = Node_Element1;        
%     end
% 
%     Node_Element2.index = Node2;
%     Node_Element2.node = MOSN2{i};
%     Node_Element2.devices = {};
%     Node_Element2.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
%     flag = 0;
%     for j = 1:numel(NodeInfo)
%         if isequal(NodeInfo{j}.node, Node_Element2.node)
%             flag = 1;
%             break;
%         end
%     end
%     if flag == 0
%         count = count + 1;
%         NodeInfo{count} = Node_Element2;        
%     end
%     
%     Node_Element3.index = Node3;
%     Node_Element3.node = MOSN3{i};
%     Node_Element3.devices = {};
%     Node_Element3.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
%     flag = 0;
%     for j = 1:numel(NodeInfo)
%         if isequal(NodeInfo{j}.node, Node_Element3.node)
%             flag = 1;
%             break;
%         end
%     end
%     if flag == 0
%         count = count + 1;
%         NodeInfo{count} = Node_Element3;        
%     end
%     % NodeInfo更新结束
% end

%% 对NodeInfo按节点索引值(0-21的节点序数)排序
% 上面已经排过序了
% for i = 1:numel(NodeInfo)
%     for j = i:numel(NodeInfo)
%         if NodeInfo{j}.index == i-1
%             tmp = NodeInfo{j};
%             NodeInfo{j} = NodeInfo{i};
%             NodeInfo{i} = tmp;
%         end
%     end
% end

%% 将DeviceInfo中的各器件相连节点以其在NodeInfo中的索引值替换
%% 同时，在NodeInfo中添加各节点相连器件信息(给初始解时用)
for i = 1:numel(DeviceInfo)
    for j = 1:numel(DeviceInfo{i}.nodes)
        % 在NodeInfo中查找节点索引值
        for k = 1:numel(NodeInfo)
            if isequal(NodeInfo{k}.node, DeviceInfo{i}.nodes{j})
                DeviceInfo{i}.nodes{j} = NodeInfo{k}.index;
                max_index = numel(NodeInfo{k}.devices) + 1;
                NodeInfo{k}.devices{max_index} = DeviceInfo{i}.name;
                break;
            end
        end
    end
end


%{
fprintf("DeviceInfo的数据如下: \n\n");
for i = 1:numel(DeviceInfo)
    disp(DeviceInfo{i});
end

fprintf("NodeInfo的数据如下: \n\n");
for i = 1:numel(NodeInfo)
    disp(NodeInfo{i});
end
%}


%% 生成初始解
%Index = find(contains({'Vdd'},SourceName));
Vdd = SourceDcValue{1};
Vdd = str2double(Vdd);

%输入格式假定第一个输入的电压源为Vdd？
for i = 1:numel(NodeInfo)
    if isequal(NodeInfo{i}.node, SourceN1{1})
        Vdd_node = NodeInfo{i}.index;
        break;
    end
end

for i = 1:numel(NodeInfo)
    if isequal(NodeInfo{i}.node, SourceN2{1})
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
    Node1 = find(Node_Map==str2double(MOSN1(i)))-1;
    Node2 = find(Node_Map==str2double(MOSN2(i)))-1;
    Node3 = find(Node_Map==str2double(MOSN3(i)))-1;
   %这里的4和2怎么根据初始解改 这个接口 也需要再看下
   VD = x_0(Node1 + 1);
   VG = x_0(Node2 + 1);
   VS = x_0(Node3 + 1);
   VDS = VD - VS;
   VGS = VG - VS;
   % [Ikk,GMk,GDSk] = Mos_Calculator(VDS,VGS,MOSMODEL(:,MOSID_C(i)),str2double(MOSW(i)),str2double(MOSL(i)));
   [Ikk,GMk,GDSk] = Mos_Calculator(4,2,MOSMODEL(:,MOSID_C(i)),str2double(MOSW(i)),str2double(MOSL(i)));
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


end
