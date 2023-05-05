% 将DeviceInfo中的各器件相连节点以其在NodeInfo中的索引值替换
% 同时，在NodeInfo中添加各节点相连器件信息(给初始解时用)

function [NodeInfo,DeviceInfo] = Gen_NodeInfo(Node_Map,DeviceInfo)

    NodeInfo = cell(1,length(Node_Map));

    for count = 1:length(Node_Map)
        Node_Element1.index = count-1;
        Node_Element1.node = Node_Map(count);
        Node_Element1.value = -1;  % 初始化为负数，方便初始化时判断节点是否赋过电压初值
        NodeInfo{count} = Node_Element1; 
    end

    for i = 1:numel(DeviceInfo)
        for j = 1:numel(DeviceInfo{i}.nodes)
            % 在NodeInfo中查找节点索引值
            for k = 1:numel(NodeInfo)
                if isequal(NodeInfo{k}.node, DeviceInfo{i}.nodes{j})
                    DeviceInfo{i}.nodes{j} = NodeInfo{k}.index;
                    break;
                end
            end
        end
    end


end

