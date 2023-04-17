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

function [DCres, x0] = calculateDC(MOSMODEL, MOStype, MOSW, MOSL, ...
    Name, N1, N2, dependence, Value, MOSLine, Error)

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
    DCres=[];
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







