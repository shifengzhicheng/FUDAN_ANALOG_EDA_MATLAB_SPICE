%{
顶层模块中调用: 
    x=caculateDC(MOSMODEL, MOStype, MOSW, MOSL, Name,N1,N2,dependence,Value,MOSLine,Error);
输入:
    MOStype, MOSW, MOSL是经过parse_netlist得到的迭代过程中计算Mos_Calculater所需要的按原顺序排列的MOS信息
    Name,N1,N2,dependence,Value,MOSLine这些由网表建立MNA方程过程得到的初始器件信息
    Error是指定的收敛终点，两次方程解间距小于Error则结束迭代
输出:
    用初始信息迭代更新MNA方程得到收敛的电路方程解
%}

function DCres = calculateDC(MOSMODEL, MOStype, MOSW, MOSL, ...
    Name,N1,N2,dependence,Value,MOSLine, Error)

%% 生成仅贴入"MOS衍生的伴随器件" 以外 的器件的A0矩阵和b0
%此后每次迭代更新A和b的方法便是在这个A0与b0基础上贴上每轮的MOS伴随器件
%这样可以避免记录上一轮的伴随器件信息
[A0, x0, b0] = Gen_baseA(Name, N1, N2, dependence, Value);
disp("DCres name list: "); disp(x0);

%% Gen_nextA生成下一轮A和b，在原MNA方程生成函数G_Matrix_Standard基础上修改
%所以每次更新的是argx，用新的arg用Gen_nextA和A0、b0得到下一轮A和b
%默认初值已经在预处理时得到体现在输入的Name, N1, N2, dependence, Value中
[A1, b1] = Gen_nextA(A0, b0, Name, N1, N2, dependence, Value); %用初始值得到的首轮A和b

%% 计算得到本轮的x1结果 此处直接matlab\法 后续可能用自写LU等带入
zp  = A1\b1;    %用z(数字)表示x(字符)的结果
%记上轮结果为x(z)p

%MOS个数，也即需更新的3个一组的数据组数
mosNum = size(MOStype,1);
%每个MOS得到的GM的端点信息其实已经可以看到dsg三端了 
%% 用mosNum*3的矩阵mosNodeMat存储DGS三端节点序号
mosNodeMat = zeros(mosNum, 3);
for mosCount = 0 : mosNum-1
    %三列按D、G、S的顺序 
    %得到的DGS是忠实反映最初网表的DGS三端的未考虑任何源漏交换
    mosNodeMat(mosCount+1, 1) = N1(MOSLine + 3*mosCount);   %D - R第一个端口
    mosNodeMat(mosCount+1, 2) = dependence{MOSLine + 3*mosCount + 1}(1);   %G - GM第一个控制端口绝对是G
    mosNodeMat(mosCount+1, 3) = N2(MOSLine + 3*mosCount);    %S - R第二个端口
end

%% 开迭！
Nlimit = 1000; %迭代上限，可能次数太多因为初始解不收敛
%把字符表示的MOStype直接换1、2表示的Mostype方便直接选MOSMODEL
Mostype = zeros(mosNum, 1);
for i = 1 : mosNum
    if MOStype{i} == 'n'
        Mostype(i) = 2;
    else
        Mostype(i) = 1;
    end
end

%MOSW MOSL作格式修改，由str - cell改成double - mat
MOSW = str2double(cell2mat(MOSW));
MOSL = str2double(cell2mat(MOSL));

for i = 1 : Nlimit
    %已经得到了按顺序的每个MOS管的三端的节点序号，带入x(z)p结果得到上轮具体三端电压
    for mosCount = 1 : mosNum   % 1个MOS衍生出的3个伴随器件1组

%% (未完成)可能出现源漏端交换的情况，我们固定初始GDS的物理位置，源漏交换只体现在伴随器件的数值正负上
        vd = zp(mosNodeMat(mosCount, 1));
        vg = zp(mosNodeMat(mosCount, 2));
        vs = zp(mosNodeMat(mosCount, 3));
%         if vd < vs
%             %源漏交换，此为实际交换后的vds\vgs
%             vds = vs - vd;
%             vgs = vg - vd;
%             %用上一轮x(z)p结果的到的三端电压计算得到新的伴随器件参数(MOS合法判断在Mos_Calculater中)
%             [Itemp, nextIeq, nextGM, nextGDS] = Mos_Calculater(vds, vgs, MOSMODEL(:, Mostype(mosCount)), str2double(cell2mat(MOSW(mosCount))), str2double(cell2mat(MOSL(mosCount))));
%             nextIeq = -nextIeq;
%             nextGM = -nextGM;
%             %源漏交互换后GM的控制电压端口也要改变为原来的栅漏端 - 原GM的第二个控制端由S改D
%             dependence{MOSLine + 3*mosCount + 1}(2) = mosNodeMat(mosCount, 1);
%         else
            %正常情况
            vds = vd - vs;
            vgs = vg - vs;
            [nextIeq, nextGM, nextGDS] = Mos_Calculater(vds, vgs, MOSMODEL(:, Mostype(mosCount)), MOSW(mosCount), MOSL(mosCount));
            %源漏换回来，正常vgs控制
%            dependence{MOSLine + 3*mosCount + 1}(2) = mosNodeMat(mosCount, 3);
%         end

        tempCount = MOSLine + 3 * (mosCount - 1);
        Value(tempCount) = 1 / nextGDS; %更新RM
        Value(tempCount+2) = nextIeq; %更新IM
        Value(tempCount+1) = nextGM; %更新GM
    end
    %将得到的新器件数据结合A0、b0得到新的矩阵
    [Ac, bc] = Gen_nextA(A0, b0, Name, N1, N2, dependence, Value);
    %解得新一轮的x(z)cur
    zc = Ac \ bc;
    %迭代收敛要求相邻两轮间距(Euclid范数)够小
    if norm(zc-zp) <= Error
        disp("Convergence!");
        DCres = zc;
        display(DCres);
        return;
    else
        zp = zc; %本轮结果成为'上轮'
    end
end
disp("Can not Converge!");
end


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
    switch CellName(1)
        case 'R'
            if CellName(2) ~= 'M'
                %% 在电路上贴电阻
                cpValue=Value(i);
                % 方程贴电阻
                A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
                A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
                A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
                A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
            end
        case 'I'
            if CellName(2) ~= 'M'
                %% 在电路上贴电流源
                cpValue=Value(i);
                % 节点的净流出与净流入电流
                b(pNum1)=b(pNum1)-cpValue;
                b(pNum2)=b(pNum2)+cpValue;
            end

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
            if CellName(1)== 'G' && CellName(2) ~= 'M'
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
end
A(1,:)=[];
A(:,1)=[];
b(1)=[];
x(1)=[];
end

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
    switch CellName(1)
        case 'R'
            if CellName(2) == 'M'
                %% 在电路上贴MOS得到的伴随电阻
                cpValue=Value(i);
                % 方程贴电阻
                A(pNum1,pNum1)= A(pNum1,pNum1)+1/cpValue;
                A(pNum1,pNum2)= A(pNum1,pNum2)-1/cpValue;
                A(pNum2,pNum1)= A(pNum2,pNum1)-1/cpValue;
                A(pNum2,pNum2)= A(pNum2,pNum2)+1/cpValue;
            end
        case 'I'
            if CellName(2) == 'M'
                %% 在电路上贴MOS得到的伴随电流源
                cpValue=Value(i);
                % 节点的净流出与净流入电流
                b(pNum1)=b(pNum1)-cpValue;
                b(pNum2)=b(pNum2)+cpValue;
            end
        case 'G'
            %% MOS得到的伴随压控电流源 (VCCS) - G
            % 控制端口与增益
            cpNum1=dependence{i}(1)+1;
            cpNum2=dependence{i}(2)+1;
            cpValue=Value(i);
            % 压控电流源 (VCCS) - G
            if CellName(2) == 'M'
                % 电压控制的电流源没有引入新的变量
                % 会给一些端口引入电流
                A(pNum1,cpNum1)= A(pNum1,cpNum1) + cpValue;
                A(pNum1,cpNum2)= A(pNum1,cpNum2) - cpValue;
                A(pNum2,cpNum1)= A(pNum2,cpNum1) - cpValue;
                A(pNum2,cpNum2)= A(pNum2,cpNum2) + cpValue;
            end
    end
end
A(1,:)=[];
A(:,1)=[];
b(1)=[];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Mos_Calculater%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 根据牛顿迭代公式得到MOS伴随器件信息
function [Ikk,GMk,GDSk]=Mos_Calculater(VDSk,VGSk,Mosarg,W,L)
    Mosarg = cell2mat(Mosarg);
    Type = power(-1,Mosarg(1,1)); %-1是PMOS,1是NMOS
    Vth = Mosarg(2,1);
    MU = Mosarg(3,1);
    COX = Mosarg(4,1);
    LAMBDA = Mosarg(5,1);
%根据P、NMOS不同Vth有正负，迭代公式完全是ids推导，PMOS注意也是ids方向
    if VGSk*Type < Vth*Type           %截止区
%       Ik = 0;
        GMk = 0;
        GDSk = 0;
        Ikk = 0;
    elseif (VGSk-VDSk)*Type > Vth*Type  %线性区
        Ik = Type*MU*COX*(W/L)*(VGSk-Vth-(1/2)*VDSk)*VDSk;
        GMk = Type*MU*COX*(W/L)*VDSk;
        GDSk = Type*MU*COX*(W/L)*(VGSk-Vth-VDSk);
        Ikk = Ik - GMk*VGSk -GDSk*VDSk;
    else                    %饱和区
        Ik = Type*(1/2)*MU*COX*(W/L)*(VGSk-Vth)*(VGSk-Vth)*(1+LAMBDA*VDSk*Type);
        GMk = Type*MU*COX*(W/L)*(VGSk-Vth)*(1+LAMBDA*VDSk*Type);
        GDSk = 1/2*MU*COX*(W/L)*(VGSk-Vth)*(VGSk-Vth)*LAMBDA;
        Ikk = Ik - GMk*VGSk -GDSk*VDSk;
    end

end
