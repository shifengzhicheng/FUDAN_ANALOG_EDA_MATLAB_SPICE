%根据二极管反向饱和电流Is，本轮两端正向电压Vpn，温度(默认27℃=300K)
%得到伴随器件值Gdk = 1/Rk, Ieqk
function [result] = Gen_PZ(LinerNet,CINFO,LINFO,PLOT,Node_Map)
%% 读出线性网表信息
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
dependence = LinerNet('dependence');
Value = LinerNet('Value');

%% 生成线性元件矩阵G
[G,~,B]=Gen_Matrix(Name,N1,N2,dependence,Value);

%% 贴出LC矩阵C
CValue = CINFO('Value');
Cline = CINFO('CLine');
Cnum = length(CValue);
LValue = LINFO('Value');
Lline = LINFO('LLine');
Lnum = length(LValue);

C=zeros(size(G,1)+1,size(G,2)+1);
%size(A,1)行数 size(A,2)列数

for i=1:Cnum
    Index = Cline + i - 1;
    pNum1 = N1(Index) + 1;
    pNum2 = N2(Index) + 1;
    cpValue=CValue(i);
    C(pNum1,pNum1)= C(pNum1,pNum1)+cpValue;
    C(pNum1,pNum2)= C(pNum1,pNum2)-cpValue;
    C(pNum2,pNum1)= C(pNum2,pNum1)-cpValue;
    C(pNum2,pNum2)= C(pNum2,pNum2)+cpValue;
end

for i = 1:Lnum
    Index = Lline + i - 1;
    pNum1 = N1(Index) + 1;
    pNum2 = N2(Index) + 1;
    cpValue=LValue(i);
    C(pNum1,pNum1)= C(pNum1,pNum1)+1/cpValue;
    C(pNum1,pNum2)= C(pNum1,pNum2)-1/cpValue;
    C(pNum2,pNum1)= C(pNum2,pNum1)-1/cpValue;
    C(pNum2,pNum2)= C(pNum2,pNum2)+1/cpValue;
end

C(1,:)=[];
C(:,1)=[];


%% 处理G矩阵不可逆的情况
s0 = 1;     %s频移s0 rad/s
flag = 0;
if det(G)==0
    G = G + s0*C;
    flag = 1;
end


%% 特征值分解，求出所有零点
% GC = inv(G)*C;
GC=G\C; %用"\",尽量不用"inv()求逆,inv(G)*C = G\C;

[V,D]= eig(GC);
d = diag(D);    % LAMDA
% poleall = -1./nonzeros(d);  % 全部极点
di = d;
dz = d~=0;
di(dz) = 1./d(dz);   % 1/LAMDA(取非0)
p  = -di;    % 全部极点，含0

%% 输出匹配
[plotnv,~] = portMapping(PLOT,Node_Map);
node_all = zeros(1,length(plotnv));
zeros_all = cell(1,length(plotnv));
poles_all = cell(1,length(plotnv));

%% 根据具体端点，求出对应传递函数的零极点

for t=1:length(plotnv)

    n=plotnv(t)-1;
    L = zeros(1,size(G,1));
    L(n) = 1;

    P = L*V;
    Q = V\(G\B);
    r = P'.*Q;          %pn*qn

    rz = r;             %有效的根(系数不为0)
    rz(rz~=0) = 1;
    tp = rz.*p;
    ttp = nonzeros(tp);

    dz = d;             %有效的系数(lamda不为0)
    dz(dz~=0) = 1;
    tr = dz.*r;
    ttr = nonzeros(tr).*(-ttp);

    dz = d;             %lamda=0但系数不为0的加到k上
    dz(dz==0) = 1;
    dz(dz~=1) = 0;
    k = r'*dz;

    [num,den] = residue(ttr,ttp,k); %部分分式展开，求出零极点
    [zero,pole,~] = tf2zp(num,den);
    
    if(flag == 1)
        zero = zero + s0 * ones(length(zero),1);
        pole = pole + s0 * ones(length(pole),1);
    end

    zeros_all{t} = zero;    %存储结果
    poles_all{t} = pole;
    node_all(t) = Node_Map(plotnv(t));

end

result=containers.Map({'ID','zero','pole'},{node_all,zeros_all,poles_all});

end