%{
顶层模块中调用: 
    x=calculateDC(MOSMODEL, MOStype, MOSW, MOSL, ...
    Name,N1,N2,dependence,Value,MOSLine, Error)
输入:
    MOStype, MOSW, MOSL, MOSMODEL是经过parse_netlist得到的迭代过程中计算Mos_Calculator所需要的按原顺序排列的MOS信息
    MOSMODEL是1*n的cell,每个元素是double型列向量存一种mos器件的参数
    测试程序中MOStype, MOSW, MOSL均为行向量，如更改注意后续第35行mosNum的读取
    Name,N1,N2,dependence,Value,MOSLine这些由网表建立MNA方程过程得到的初始器件信息
    Error是指定的收敛终点，两次方程解间距小于Error则结束迭代
输出:
    用初始信息迭代更新MNA方程得到收敛的电路方程解DCres
    各mos管(按网表处理后的顺序)的Ids
%}

%function [DCres, mosCurrents, diodeCurrents, x0, Value] = calculateDC(Name, N1, N2, dependence, Value, varargin)
function [DCres, x0, Value] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error)

%% 读出线性网表信息
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
dependence = LinerNet('dependence');
Value = LinerNet('Value');

%% 生成仅贴入"MOS衍生的伴随器件" 以外 的器件的A0矩阵和b0
%此后每次迭代更新A和b的方法是在这个A0与b0基础上贴上每轮的MOS伴随器件 - 避免记录上一轮的伴随器件信息
[A0, x0, b0] = Gen_baseA(Name, N1, N2, dependence, Value);
disp("DCres name list: "); disp(x0);

%% 判断是否是纯线性网络，如果是，则baseA就是正确的A，直接得结果，否则读线性器件输入信息
if isempty(MOSINFO) || isempty(DIODEINFO) 
    DCres = A0 \ b0;
    mosCurrents = [];
    diodeCurrents = [];
    return;
else
%     %需要的MOS相关信息
%     MOSMODEL = MOSINFO{1};
%     MOStype = MOSINFO{2};
%     MOSW = MOSINFO{3};
%     MOSL = MOSINFO{4};
%     MOSID = MOSINFO{5};
%     MOSLine = MOSINFO{6};
%     %需要的DIODE相关信息
%     Is = DIODEINFO{1};
%     diodeLine = DIODEINFO{2};
    %需要的MOS相关信息
    MOSMODEL = MOSINFO('MODEL');
    MOStype = MOSINFO('type');
    MOSW = MOSINFO('W');
    MOSL = MOSINFO('L');
    MOSID = MOSINFO('ID');
    MOSLine = MOSINFO('MOSLine');
    %需要的DIODE相关信息
    Is = DIODEINFO('Is');
    diodeLine = DIODEINFO('DiodeLine');
end

%% Gen_nextA生成下一轮A和b，在原MNA方程生成函数G_Matrix_Standard基础上修改
%默认初值已经在预处理时得到体现在输入的Name, N1, N2, dependence, Value中
[A1, b1] = Gen_nextA(A0, b0, Name, N1, N2, dependence, Value); %用初始值得到的首轮A和b
% 计算得到本轮的x1结果 此处直接matlab\法 或 自写LU带入
zp = A1\b1;    %用z(数字)表示x(字符)的结果 - 记上轮结果为x(z)p

%MOS个数，也即需更新的3个一组的数据组数
mosNum = size(MOStype,2);
%% 用mosNum*3的矩阵mosNodeMat存储DGS三端节点序号 - GM的端点信息可以读到
mosNodeMat = zeros(mosNum, 3);
for mosCount = 0 : mosNum-1
    %三列按D、G、S的顺序 
    %得到的DGS是忠实反映最初网表的DGS三端的未考虑任何源漏交换
    mosNodeMat(mosCount+1, 1) = N1(MOSLine + 3*mosCount);   %D - R第一个端口
    mosNodeMat(mosCount+1, 2) = dependence{MOSLine + 3*mosCount + 1}(1);   %G - GM第一个控制端口绝对是G
    mosNodeMat(mosCount+1, 3) = N2(MOSLine + 3*mosCount);    %S - R第二个端口
end

%% 用diodeNum*2的矩阵存储diode两端节点序号 - 从伴随器件读到
diodeNum = size(Is, 2);
diodeNodeMat = zeros(diodeNum, 2);
for diodeCount = 1 : diodeNum
    %从Gd的两端找到
    diodeNodeMat(diodeCount, 1) = N1(diodeLine + diodeCount * 2 - 2);
    diodeNodeMat(diodeCount, 2) = N2(diodeLine + diodeCount * 2 - 2);
end

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

%% 开始迭代
Nlimit = 200; %迭代上限，可能次数太多因为初始解不收敛
for i = 1 : Nlimit
    %% 每轮迭代 - 内部过程封装成函数 - 包含非线性器件工作区判断、矩阵更新等功能
    [zc, dependence, Value] = Gen_nextRes(MOSMODEL, Mostype, MOSW, MOSL, mosNum, mosNodeMat, MOSLine, MOSID, ...
                                          diodeNum, diodeNodeMat, diodeLine, Is, ...
                                          A0, b0, Name, N1, N2, dependence, Value, zp);

    %% 迭代收敛 - 要求相邻两轮间距(Euclid范数)够小
    if norm(zc-zp) <= Error
        disp("Convergence!");
        %MNA方程解的结果
        z_res = zc;

        %%  为打印MOS电流输出结果提供的输出
        tempz = [0; zp];
        %得到绝对原网表三端电压，再根据MOS一阶模型得原Ids，计算Ids函数内考虑ds交换
        vg = zeros(mosNum, 1); vs = zeros(mosNum, 1); netlistVds = zeros(mosNum, 1);
        for mosCount = 1 : mosNum   % 1个MOS衍生出的3个伴随器件1组
            %考虑源漏交换后实际的S端从GM的控制端读到      
            vg(mosCount) = tempz(mosNodeMat(mosCount, 2) + 1);
            vs(mosCount) = tempz(dependence{MOSLine + 3*mosCount - 2}(2) + 1);
            %因为RM没有调换端口故原网表Ids仍由原网表Vds看
            netlistVds(mosCount) = tempz(mosNodeMat(mosCount, 1) + 1) - tempz(mosNodeMat(mosCount, 3) + 1);
        end
        vgs = vg - vs;       
        finalRMs = Value(MOSLine : 3 : MOSLine + 3 * mosNum - 3).';
        finalGMs = Value(MOSLine + 1 : 3 : MOSLine + 3 * mosNum - 2).';
        finalIMs = Value(MOSLine + 2 : 3 : MOSLine + 3 * mosNum - 1).';
        mosCurrents = finalIMs + finalGMs .* vgs + (1./finalRMs) .* netlistVds;

        %%  打印Diode电流输出结果
        vpn = zeros(diodeNum, 1);
        for dioCount = 1 : diodeNum
            vpn(dioCount) = tempz(diodeNodeMat(dioCount, 1) + 1) - tempz(diodeNodeMat(diodeCount, 2) + 1);
        end
            finalRDs = Value(diodeLine : 2 : diodeLine + 2 * diodeNum - 2);
            finalIDs = Value(diodeLine + 1 : 2 : diodeLine + 2 * diodeNum -1);
        diodeCurrents = finalIDs + vpn ./ finalRDs;
        %或直接用双端Diode电流公式
        %diodeCurrents = Is .* (exp(vpn / 0.026) - 1);
        %打包成hash结构DCres
        DCres = containers.Map({'x', 'mosCurrents', 'diodeCurrents'}, {z_res, mosCurrents, diodeCurrents});

%         %测试打印输出 - test
%         display(z_res);
%         display(mosCurrents);
%         display(diodeCurrents);
        return;
    else
        zp = zc; %本轮结果成为'上轮'
    end
end
    disp("Can not Converge!");
    z_res = [];
    mosCurrents = [];
    diodeCurrents = [];
    %打包成hash结构DCres
    DCres = containers.Map({'x', 'mosCurrents', 'diodeCurrents'}, {z_res, mosCurrents, diodeCurrents});
end
