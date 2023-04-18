%{
顶层模块中调用: 
    x=caculateDC(Name,N1,N2,dependence,Value,MOSLine,Error);
输入:
    MOStype, MOSW, MOSL是经过parse_netlist得到的迭代过程中计算Mos_Calculater所需要的按原顺序排列的MOS信息
    Name,N1,N2,dependence,Value,MOSLine这些由网表建立MNA方程过程得到的初始器件信息
    Error是指定的收敛终点，两次方程解间距小于Error则结束迭代
输出:
    用初始信息迭代更新MNA方程得到收敛的电路方程解DCres
    各mos管(按网表处理后的顺序)的Ids
%}
%% 说明，x0存的是解向量的名称，mosCurrents求的是mos电流，DCres求的是电路DC解
function [DCres, mosCurrents, x0] = calculateDC(MOSMODEL, MOStype, MOSW, MOSL, ...
    Name,N1,N2,dependence,Value,MOSLine, Error)

%% 生成仅贴入"MOS衍生的伴随器件" 以外 的器件的A0矩阵和b0
%此后每次迭代更新A和b的方法是在这个A0与b0基础上贴上每轮的MOS伴随器件 - 避免记录上一轮的伴随器件信息
[A0, x0, b0] = Gen_baseA(Name, N1, N2, dependence, Value);
disp("DCres name list: "); disp(x0);

%% Gen_nextA生成下一轮A和b，在原MNA方程生成函数G_Matrix_Standard基础上修改
%所以每次更新的是argx，用新的arg用Gen_nextA和A0、b0得到下一轮A和b
%默认初值已经在预处理时得到体现在输入的Name, N1, N2, dependence, Value中
[A1, b1] = Gen_nextA(A0, b0, Name, N1, N2, dependence, Value); %用初始值得到的首轮A和b

%% 计算得到本轮的x1结果 此处直接matlab\法 或 自写LU带入

zp  = A1\b1;    %用z(数字)表示x(字符)的结果
%记上轮结果为x(z)p
%MOS个数，也即需更新的3个一组的数据组数
mosNum = size(MOStype,2);
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
Nlimit = 500; %迭代上限，可能次数太多因为初始解不收敛
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
MOSW = str2double(MOSW);
MOSL = str2double(MOSL);
DCres = [];
mosCurrents = [];
for i = 1 : Nlimit
    %% 每轮迭代 - 内部过程封装成函数 - 包含非线性器件工作区判断、矩阵更新等功能
    [zc, Value] = Gen_nextRes(MOSMODEL, Mostype, MOSW, MOSL, mosNum, mosNodeMat, MOSLine, A0, b0, Name, N1, N2, dependence, Value, zp);

    %% 迭代收敛 - 要求相邻两轮间距(Euclid范数)够小
    if norm(zc-zp) <= Error
        disp("Convergence!");
        %MNA方程解的结果
        DCres = zc;
        %为打印电流输出结果提供的输出
        tempz = [0; zp];
        vd = zeros(mosNum, 1); vg = zeros(mosNum, 1); vs = zeros(mosNum, 1);
        for mosCount = 1 : mosNum   % 1个MOS衍生出的3个伴随器件1组
            vd(mosCount) = tempz(mosNodeMat(mosCount, 1) + 1);
            vg(mosCount) = tempz(mosNodeMat(mosCount, 2) + 1);
            vs(mosCount) = tempz(mosNodeMat(mosCount, 3) + 1);
        end
        vgs = vg - vs;
        vds = vd - vs;
        finalRMs = Value(MOSLine : 3 : MOSLine + 3 * mosNum - 3).';
        finalGMs = Value(MOSLine + 1 : 3 : MOSLine + 3 * mosNum - 2).';
        finalIMs = Value(MOSLine + 2 : 3 : MOSLine + 3 * mosNum - 1).';
        mosCurrents = finalIMs + finalGMs .* vgs + (1./finalRMs) .* vds;
        %测试打印输出 - test
        display(DCres);
        display(mosCurrents);
        return;
    else
        zp = zc; %本轮结果成为'上轮'
    end
end
disp("Can not Converge!");
end






