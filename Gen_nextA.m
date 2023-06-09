%% 文件作者：郑志宇
%% Gen_nextA分为一般矩阵格式和稀疏矩阵格式。使用稀疏矩阵格式时将上半部分注释

%% Gen_nextA生成下一轮A和b
%% ##################################### Gen_nextA(一般矩阵格式) #####################################
function [A, b] = Gen_nextA(pureA, pureb, N1, N2, dependence, Value,MOSLine,MOSCount,DiodeLine,DiodeCount,BJTLine,BJTCount)

% 初始化矩阵 因为建立MNA时先暂时引入0节点
A = [zeros(size(pureA,1),1), pureA];
A = [zeros(1,size(A, 2)); A];
b = [0; pureb];

%% MOS
% 器件顺序: RGI
for i=MOSLine:3:MOSLine+3*(MOSCount-1)
    % 考虑节点地，方程要往右往下移动一个单位
    %% 在电路上贴电阻
    % 处理RM
    pNum1 = N1(i) + 1;
    pNum2 = N2(i) + 1;
    cpValue = Value(i);
    % 方程贴电阻
    A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
    A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
    A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
    A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
    % 处理GM
    %% 压控电流源 (VCCS) - G
    % 控制端口与增益
    pNum1 = N1(i+1) + 1;
    pNum2 = N2(i+1) + 1;
    cpNum1 = dependence{i+1}(1)+1;
    cpNum2 = dependence{i+1}(2)+1;
    cpValue = Value(i+1);
    % 电压控制的电流源没有引入新的变量
    % 会给一些端口引入电流
    A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
    A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
    A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
    A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
    %% 在电路上贴电流源
    % 处理IM
    pNum1 = N1(i+2) + 1;
    pNum2 = N2(i+2) + 1;
    cpValue=Value(i+2);
    % 节点的净流出与净流入电流
    b(pNum1)=b(pNum1)-cpValue;
    b(pNum2)=b(pNum2)+cpValue;
end

%% Diode
for i=DiodeLine:2:DiodeLine+2*(DiodeCount-1)
    % 考虑节点地，方程要往右往下移动一个单位
    %% 在电路上贴电阻
    % 处理RD
    pNum1 = N1(i) + 1;
    pNum2 = N2(i) + 1;
    cpValue = Value(i);
    % 方程贴电阻
    A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
    A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
    A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
    A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
    %% 在电路上贴电流源
    % 处理ID
    pNum1 = N1(i+1) + 1;
    pNum2 = N2(i+1) + 1;
    cpValue=Value(i+1);
    % 节点的净流出与净流入电流
    b(pNum1)=b(pNum1)-cpValue;
    b(pNum2)=b(pNum2)+cpValue;
end

%% BJT
% 器件顺序: RGI
for i=BJTLine:6:BJTLine+6*(BJTCount-1)
    % 考虑节点地，方程要往右往下移动一个单位
    %% 在电路上贴电阻
    % 处理RM
    pNum1 = N1(i) + 1;
    pNum2 = N2(i) + 1;
    cpValue = Value(i);
    % 方程贴电阻
    A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
    A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
    A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
    A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
    % 处理GM
    %% 压控电流源 (VCCS) - G
    % 控制端口与增益
    pNum1 = N1(i+1) + 1;
    pNum2 = N2(i+1) + 1;
    cpNum1 = dependence{i+1}(1)+1;
    cpNum2 = dependence{i+1}(2)+1;
    cpValue = Value(i+1);
    % 电压控制的电流源没有引入新的变量
    % 会给一些端口引入电流
    A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
    A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
    A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
    A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
    %% 在电路上贴电流源
    % 处理IM
    pNum1 = N1(i+2) + 1;
    pNum2 = N2(i+2) + 1;
    cpValue=Value(i+2);
    % 节点的净流出与净流入电流
    b(pNum1)=b(pNum1)-cpValue;
    b(pNum2)=b(pNum2)+cpValue;
    % 考虑节点地，方程要往右往下移动一个单位
    %% 在电路上贴电阻
    % 处理RM
    pNum1 = N1(i+3) + 1;
    pNum2 = N2(i+3) + 1;
    cpValue = Value(i+3);
    % 方程贴电阻
    A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
    A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
    A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
    A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
    % 处理GM
    %% 压控电流源 (VCCS) - G
    % 控制端口与增益
    pNum1 = N1(i+4) + 1;
    pNum2 = N2(i+4) + 1;
    cpNum1 = dependence{i+4}(1)+1;
    cpNum2 = dependence{i+4}(2)+1;
    cpValue = Value(i+4);
    % 电压控制的电流源没有引入新的变量
    % 会给一些端口引入电流
    A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
    A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
    A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
    A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
    %% 在电路上贴电流源
    % 处理IM
    pNum1 = N1(i+5) + 1;
    pNum2 = N2(i+5) + 1;
    cpValue = Value(i+5);
    % 节点的净流出与净流入电流
    b(pNum1)=b(pNum1)-cpValue;
    b(pNum2)=b(pNum2)+cpValue;
end

A(1,:)=[];
A(:,1)=[];
b(1)=[];
end
%% ##################################### end #####################################



%% ##################################### Gen_nextA(稀疏矩阵格式) #####################################
% function [A, b] = Gen_nextA(pureA, pureb, N1, N2, dependence, Value,MOSLine,MOSCount,DiodeLine,DiodeCount,BJTLine,BJTCount)
% % *************** 已加BJT端口 ***************
% 
% % 初始化矩阵 因为建立MNA时先暂时引入0节点
% % A = [zeros(size(pureA,1),1), pureA];
% % A = [zeros(1,size(A, 2)); A];
% A = pureA;
% A = addRowCol(A, 1, 1);
% b = [0; pureb];
% 
% %% MOS
% % 器件顺序: RGI
% for i=MOSLine:3:MOSLine+3*(MOSCount-1)
%     % 考虑节点地，方程要往右往下移动一个单位
%     %% 在电路上贴电阻
%     % 处理RM
%     pNum1 = N1(i) + 1;
%     pNum2 = N2(i) + 1;
%     cpValue = Value(i);
%     % 方程贴电阻
% %     A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
% %     A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
% %     A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
% %     A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
%     A = renewElement(A,pNum1,pNum1,1/cpValue);
%     A = renewElement(A,pNum1,pNum2,-1/cpValue);
%     A = renewElement(A,pNum2,pNum1,-1/cpValue);
%     A = renewElement(A,pNum2,pNum2,1/cpValue);
%     % 处理GM
%     %% 压控电流源 (VCCS) - G
%     % 控制端口与增益
%     pNum1 = N1(i+1) + 1;
%     pNum2 = N2(i+1) + 1;
%     cpNum1 = dependence{i+1}(1)+1;
%     cpNum2 = dependence{i+1}(2)+1;
%     cpValue = Value(i+1);
%     % 电压控制的电流源没有引入新的变量
%     % 会给一些端口引入电流
% %     A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
% %     A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
% %     A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
% %     A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
%     A = renewElement(A,pNum1,cpNum1,cpValue);
%     A = renewElement(A,pNum1,cpNum2,-cpValue);
%     A = renewElement(A,pNum2,cpNum1,-cpValue);
%     A = renewElement(A,pNum2,cpNum2,cpValue);
%     %% 在电路上贴电流源
%     % 处理IM
%     pNum1 = N1(i+2) + 1;
%     pNum2 = N2(i+2) + 1;
%     cpValue=Value(i+2);
%     % 节点的净流出与净流入电流
%     b(pNum1)=b(pNum1)-cpValue;
%     b(pNum2)=b(pNum2)+cpValue;
% end
% 
% %% Diode
% for i=DiodeLine:2:DiodeLine+2*(DiodeCount-1)
%     % 考虑节点地，方程要往右往下移动一个单位
%     %% 在电路上贴电阻
%     % 处理RD
%     pNum1 = N1(i) + 1;
%     pNum2 = N2(i) + 1;
%     cpValue = Value(i);
%     % 方程贴电阻
% %     A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
% %     A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
% %     A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
% %     A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
%     A = renewElement(A,pNum1,pNum1,1/cpValue);
%     A = renewElement(A,pNum1,pNum2,-1/cpValue);
%     A = renewElement(A,pNum2,pNum1,-1/cpValue);
%     A = renewElement(A,pNum2,pNum2,1/cpValue);
%     %% 在电路上贴电流源
%     % 处理ID
%     pNum1 = N1(i+1) + 1;
%     pNum2 = N2(i+1) + 1;
%     cpValue=Value(i+1);
%     % 节点的净流出与净流入电流
%     b(pNum1)=b(pNum1)-cpValue;
%     b(pNum2)=b(pNum2)+cpValue;
% end
% 
% % ################################### BJT start ###################################
% %% BJT
% % 器件顺序: RGI
% for i=BJTLine:6:BJTLine+6*(BJTCount-1)
%     % 考虑节点地，方程要往右往下移动一个单位
%     %% 在电路上贴电阻
%     % 处理RM
%     pNum1 = N1(i) + 1;
%     pNum2 = N2(i) + 1;
%     cpValue = Value(i);
%     % 方程贴电阻
% %     A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
% %     A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
% %     A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
% %     A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
%     A = renewElement(A,pNum1,pNum1,1/cpValue);
%     A = renewElement(A,pNum1,pNum2,-1/cpValue);
%     A = renewElement(A,pNum2,pNum1,-1/cpValue);
%     A = renewElement(A,pNum2,pNum2,1/cpValue);
%     % 处理GM
%     %% 压控电流源 (VCCS) - G
%     % 控制端口与增益
%     pNum1 = N1(i+1) + 1;
%     pNum2 = N2(i+1) + 1;
%     cpNum1 = dependence{i+1}(1)+1;
%     cpNum2 = dependence{i+1}(2)+1;
%     cpValue = Value(i+1);
%     % 电压控制的电流源没有引入新的变量
%     % 会给一些端口引入电流
% %     A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
% %     A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
% %     A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
% %     A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
%     A = renewElement(A,pNum1,cpNum1,cpValue);
%     A = renewElement(A,pNum1,cpNum2,-cpValue);
%     A = renewElement(A,pNum2,cpNum1,-cpValue);
%     A = renewElement(A,pNum2,cpNum2,cpValue);
%     %% 在电路上贴电流源
%     % 处理IM
%     pNum1 = N1(i+2) + 1;
%     pNum2 = N2(i+2) + 1;
%     cpValue=Value(i+2);
%     % 节点的净流出与净流入电流
%     b(pNum1)=b(pNum1)-cpValue;
%     b(pNum2)=b(pNum2)+cpValue;
%     % 考虑节点地，方程要往右往下移动一个单位
%     %% 在电路上贴电阻
%     % 处理RM
%     pNum1 = N1(i+3) + 1;
%     pNum2 = N2(i+3) + 1;
%     cpValue = Value(i+3);
%     % 方程贴电阻
% %     A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
% %     A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
% %     A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
% %     A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
%     A = renewElement(A,pNum1,pNum1,1/cpValue);
%     A = renewElement(A,pNum1,pNum2,-1/cpValue);
%     A = renewElement(A,pNum2,pNum1,-1/cpValue);
%     A = renewElement(A,pNum2,pNum2,1/cpValue);
%     % 处理GM
%     %% 压控电流源 (VCCS) - G
%     % 控制端口与增益
%     pNum1 = N1(i+4) + 1;
%     pNum2 = N2(i+4) + 1;
%     cpNum1 = dependence{i+4}(1)+1;
%     cpNum2 = dependence{i+4}(2)+1;
%     cpValue = Value(i+4);
%     % 电压控制的电流源没有引入新的变量
%     % 会给一些端口引入电流
% %     A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
% %     A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
% %     A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
% %     A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
%     A = renewElement(A,pNum1,cpNum1,cpValue);
%     A = renewElement(A,pNum1,cpNum2,-cpValue);
%     A = renewElement(A,pNum2,cpNum1,-cpValue);
%     A = renewElement(A,pNum2,cpNum2,cpValue);
%     %% 在电路上贴电流源
%     % 处理IM
%     pNum1 = N1(i+5) + 1;
%     pNum2 = N2(i+5) + 1;
%     cpValue = Value(i+5);
%     % 节点的净流出与净流入电流
%     b(pNum1)=b(pNum1)-cpValue;
%     b(pNum2)=b(pNum2)+cpValue;
% end
% % ################################### BJT end ###################################
% 
% % A(1,:)=[];
% % A(:,1)=[];
% A = deleteRowCol(A,1,1);
% b(1)=[];
% end

%% ##################################### end #####################################

