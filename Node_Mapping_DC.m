%% 文件作者：朱瑞宸
%% 根据牛顿迭代公式得到MOS伴随器件信息
%% DC节点映射
% 电容不映射，电感两端合并为一个节点，可以防止浮空结点造成G不满秩，以及降维，但后面AC不能再接着用了

function [Node_Map_DC]=Node_Mapping_DC(NodeDC,NodeL,LN1,LN2)

% 建立并查集
UF = [NodeL zeros(length(NodeL),1)];    %并查集[node parent]
for i=1:length(LN1)
    k1 = find(NodeL==LN1(i));
    k2 = find(NodeL==LN2(i));
    if UF(k1,2)==0
        Place = LN1(i);  %替换的元素
    else
        Place = UF(k1,2);
    end
    if UF(k2,2)==0
        Search = LN2(i);  %替换的元素
    else
        Search = UF(k2,2);
        k0 = logical(NodeL==UF(k2,2)); %源头替换
        UF(k0,2) = Place;
    end
    col = UF(:,2);
    col(col==Search) = Place;
    UF = [UF(:,1) col];
    UF(k2,2) = Place;
end

% 根据并查集完成替换
order = 0:length(NodeDC)-1;
Node_Map_DC = [NodeDC order'];
for i=1:length(NodeL)
    if(UF(i,2) ~= 0)
        % 讨论的结点：UF(i,1);
        % 需要替换的父结点：UF(i,2);
        pk = logical(NodeDC==UF(i,2));  % 纯数值可以用logical代替find
        pnode = Node_Map_DC(pk,2);
        nk = logical(NodeDC==UF(i,1));
        Node_Map_DC(nk,2) = pnode;
    end
end

% 把序号映射为连续
Node_Map_DC_s = unique(Node_Map_DC(:,2),"rows");
for i=1:length(Node_Map_DC(:,2))
    cvalue = find(Node_Map_DC_s == Node_Map_DC(i,2))-1;
    Node_Map_DC(i,2) = cvalue;
end


end
