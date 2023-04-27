%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Gen_nextA%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Gen_nextA生成下一轮A和b
function [A, b] = Gen_nextA(pureA, pureb, Name, N1, N2, dependence, Value)
CellCount = length(Name);% 元件数量
% 初始化矩阵 因为建立MNA时先暂时引入0节点
A = [zeros(size(pureA,1),1), pureA];
A = [zeros(1,size(A, 2)); A];
b = [0; pureb];
%x=compose('v_%d',(0:nodeNums)'); %不必要了

%% 只处理MOS相关伴随器件
for i=1:CellCount
    CellName=Name{i};
    % 考虑节点地，方程要往右往下移动一个单位
    pNum1=N1(i)+1;
    pNum2=N2(i)+1;
    %% MOS
    if CellName(2) == 'M'
        switch CellName(1)
            case 'R'
                %% 在电路上贴MOS得到的伴随电阻
                cpValue=Value(i);
                % 方程贴电阻
                A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
                A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
                A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
                A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
            case 'I'
                %% 在电路上贴MOS得到的伴随电流源
                cpValue=Value(i);
                % 节点的净流出与净流入电流
                b(pNum1)=b(pNum1)-cpValue;
                b(pNum2)=b(pNum2)+cpValue;
            case 'G'
                %% MOS得到的伴随压控电流源 (VCCS) - G
                % 控制端口与增益
                cpNum1=dependence{i}(1)+1;
                cpNum2=dependence{i}(2)+1;
                cpValue=Value(i);
                % 压控电流源 (VCCS) - G
                % 电压控制的电流源没有引入新的变量
                % 会给一些端口引入电流
                A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
                A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
                A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
                A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
        end
    elseif CellName(2) == 'D'
        switch CellName(1)
            case 'R'
                %% 在电路上贴DIODE得到的伴随电阻
                cpValue=Value(i);
                % 方程贴电阻
                A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
                A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
                A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
                A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
            case 'I'
                %% 在电路上贴DIODE得到的伴随电流源
                cpValue=Value(i);
                % 节点的净流出与净流入电流
                b(pNum1)=b(pNum1)-cpValue;
                b(pNum2)=b(pNum2)+cpValue;
        end    
    end
end
A(1,:)=[];
A(:,1)=[];
b(1)=[];
end