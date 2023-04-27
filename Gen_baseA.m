%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Gen_baseA%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 只处理MOS伴随器件以外的原网表中线性器件生成A0、b0
function [A,x,b]=Gen_baseA(Name, N1, N2, dependence, Value)
% Name是一个cell，里面的元素应该是'Name'
% N1与N2为double数组
% dependence应该是一个cell，cell里面是数组[cp1 cp2]或者字符串'CdName'
% Value是一个double数组

B = unique([N1,N2]);
nodeNum = numel(B); %结点总数
CellCount = length(Name);% 元件数量
% 默认电流数为0
INum=0;
% nodeNum 等于矩阵初始维数，之后我们会尝试去修改这个
nodeNums = nodeNum;
% 初始化矩阵
A = zeros(nodeNums);
b = zeros(nodeNums,1);
x=compose('v_%d',(0:nodeNums)');
%% 遍历所有的元件
% 先考虑引入地为节点，最后去掉就行
for i=1:CellCount
    CellName=Name{i};
    % 考虑节点地，方程要往右往下移动一个单位
    pNum1=N1(i)+1;
    pNum2=N2(i)+1;
    if CellName(2) ~= 'M'
    switch CellName(1)
        case 'R'

            %% 在电路上贴电阻
            cpValue=Value(i);
            % 方程贴电阻
            A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
            A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
            A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
            A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
        case 'I'
            %% 在电路上贴电流源
            cpValue=Value(i);
            % 节点的净流出与净流入电流
            b(pNum1)=b(pNum1)-cpValue;
            b(pNum2)=b(pNum2)+cpValue;

        case 'V'
            %% 在电路上贴电压源
            cpValue=Value(i);
            % 扩展矩阵，引入新的变量
            INum=INum+1;
            x{nodeNums+INum}=['I_' CellName];
            A(nodeNums+INum,nodeNums+INum)= 0;
            b(nodeNums+INum)=0;
            % 电压源贴入矩阵，影响两个节点电压，
            % 引入的电流影响两个节点电流
            A(pNum1,nodeNums+INum)= A(pNum1,nodeNums+INum) + 1;
            A(pNum2,nodeNums+INum)= A(pNum2,nodeNums+INum) - 1;
            A(nodeNums+INum,pNum1)= A(nodeNums+INum,pNum1) + 1;
            A(nodeNums+INum,pNum2)= A(nodeNums+INum,pNum2) - 1;
            % 更新对应的b向量，即一个电压方程
            b(nodeNums+INum)=b(nodeNums+INum)+cpValue;
        case{'G','E'}
            % 压控电压源 (VCVS) - E
            % 压控电流源 (VCCS) - G

            % 控制端口与增益
            cpNum1=dependence{i}(1)+1;
            cpNum2=dependence{i}(2)+1;
            cpValue=Value(i);

            %% 压控电流源 (VCCS) - G
            if CellName(1)== 'G'
                % 电压控制的电流源没有引入新的变量
                % 会给一些端口引入电流
                A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
                A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
                A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
                A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
            end

            %% 压控电压源 (VCVS) - E
            if CellName(1)== 'E'
                % 电压源引入电流
                INum=INum+1;
                x{nodeNums+INum}=['I_' CellName];
                % 扩展矩阵
                A(nodeNums+INum,nodeNums+INum)= 0;
                b(nodeNums+INum)=0;
                % 两个节点引入电压
                % 两个节点引入电流
                A(pNum1,nodeNums+INum)= A(pNum1,nodeNums+INum) + 1;
                A(pNum2,nodeNums+INum)= A(pNum2,nodeNums+INum) - 1;
                A(nodeNums+INum,pNum1)= A(nodeNums+INum,pNum1) + 1;
                A(nodeNums+INum,pNum2)= A(nodeNums+INum,pNum2) - 1;
                % 两个节点引入受控电流
                A(nodeNums+INum,cpNum1)= A(nodeNums+INum,cpNum1) - cpValue;
                A(nodeNums+INum,cpNum2)= A(nodeNums+INum,cpNum2) + cpValue;
            end

        case {'H','F'}
            % 电流控制电压源 (CCVS) - H
            % 电流控制电流源 (CCCS) - F

            CdName=dependence{i};
            cpIndex=find(contains(Name,CdName));
            cpValue=Value(i);

            %% 电流控制电流源 (CCCS) - F
            if CellName(1)== 'F'
                % 电流控制的电流源需要引入一个电流
                % 作为控制元件的电流
                INum=INum+1;
                x{nodeNums+INum}=['Icontrol_' CellName];
                % Icontrol指的是控制CellName的输出的电流
                % 扩展矩阵
                A(nodeNums+INum,nodeNums+INum)= 0;
                b(nodeNums+INum)=0;
                % 自身的两个节点引入受控电流
                A(pNum1,nodeNums+INum)= A(pNum1,nodeNums+INum) + cpValue;
                A(pNum2,nodeNums+INum)= A(pNum2,nodeNums+INum) - cpValue;

                % 这里缺失一个方程
                % 根据这里的器件是什么决定如何增添方程
                A(nodeNums+INum,nodeNums+INum)=A(nodeNums+INum,nodeNums+INum) + 1;
                % 要找的是Icontrol电流的方程
                switch CdName(1)
                    case 'R'
                        % 如果为器件为电阻则
                        A(nodeNums+INum,N1(cpIndex))=A(nodeNums+INum,N1(cpIndex)) - 1/Value(cpIndex);
                        A(nodeNums+INum,N2(cpIndex))=A(nodeNums+INum,N2(cpIndex)) + 1/Value(cpIndex);
                        % 电导与电流的关系
                    case {'V','E','H'}
                        % 如果为电压源，这里应该去寻找电压源对应的电流
                        % 如果是其他源的电流，很可能在这里还没有生成，所以还需要另外的步骤去寻找这样一个电流
                        % 考虑重新引入一个队列去在这个循环之后特别处理这样的源
                        ICdName_Index=find(contains(x, ['I_' CdName]));
                        A(nodeNums+INum, ICdName_Index) = A(nodeNums+INum, ICdName_Index) - 1;
                    case {'I','G','F'}
                        % 如果为电流源、受控电流源，则会有一个电流相等的关系
                        ICdName_Index=find(contains(x, ['I_' CdName]));
                        if CdName(1) == 'I'
                            A(nodeNums+INum, ICdName_Index) = A(nodeNums+INum, ICdName_Index) - 1;
                        elseif CdName(1) == 'F'
                            % 还得找控制G,F的电流
                            IcontrolCS_Index=find(contains(x,['Icontrol_' CdName{1}]));
                            A(nodeNums+INum, IcontrolCS_Index) = A(nodeNums+INum, IcontrolCS_Index) - Value(cpIndex);
                        elseif CdName(1) == 'G'
                            A(pNum1,cpNum1)= A(pNum1,cpNum1) - cpValue;
                            A(pNum1,cpNum2)= A(pNum1,cpNum2) + cpValue;
                        end

                end
            end
        end
    end
    %% 电流控制电压源 (CCVS) - H
    if CellName(1)== 'H'
        m=nodeNums+INum+1;
        x{m}=['I_' CellName];
        % 方程二序号
        k=nodeNums+INum+2;
        x{k}=['Icontrol_' CellName];
        % 矩阵拓展
        A(k,k)= 0;
        b(m)=0;
        b(k)=0;
        % 电流电压关系更新
        A(pNum1,m)= A(pNum1,m) + 1;
        A(pNum2,m)= A(pNum2,m) - 1;
        A(m,pNum1)= A(m,pNum1) + 1;
        A(m,pNum2)= A(m,pNum2) - 1;
        A(m,k)=A(m,k)-cpValue;

        % 这里缺失一个方程
        A(k,k)=A(k,k) + 1;
        % 第k行是新的等式
        switch CdName(1)
            case 'R'
                % 如果为电阻则
                A(k,N1(cpIndex))=A(k,N1(cpIndex)) - 1/Value(cpIndex);
                A(k,N2(cpIndex))=A(k,N2(cpIndex)) + 1/Value(cpIndex);
                % 电导与电流的关系
            case {'V','E','H'}
                % 如果为电压源，这个时候这条支路上一定会引入一个电流
                % 如果是其他源的电流，很可能在这里还没有生成，所以还需要另外的步骤去寻找这样一个电流
                % 考虑重新引入一个队列去在这个循环之后特别处理这样的源
                ICdName_Index=find(contains(x, ['I_' CdName]));
                A(k, ICdName_Index) = A(k, ICdName_Index) - 1;
            case {'I','G','F'}
                % 如果为电流源、受控电流源，则会有一个电流相等的关系
                ICdName_Index = find(contains(x, ['I_' CdName]));
                if CdName(1) == 'I'
                    A(k, ICdName_Index) = A(k, ICdName_Index) - 1;
                elseif CdName(1) == 'F'
                    % 还得找控制G,F的电流
                    IcontrolCS_Index=find(contains(x,['Icontrol_' CdName]));
                    A(k, IcontrolCS_Index) = A(k, IcontrolCS_Index) - Value(cpIndex);
                elseif CdName(1) == 'G'
                    A(pNum1,cpNum1)= A(pNum1,cpNum1) - cpValue;
                    A(pNum1,cpNum2)= A(pNum1,cpNum2) + cpValue;
                end
        end
        % 更新系数
        INum=INum+2;
    end
end
A(1,:)=[];
A(:,1)=[];
b(1)=[];
x(1)=[];
end
