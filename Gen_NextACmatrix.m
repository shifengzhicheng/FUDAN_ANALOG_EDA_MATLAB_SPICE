%% 文件作者：郑志宇
%% 这个函数实现了AC中矩阵的更新
function Af=Gen_NextACmatrix(N1,N2,CValue,LValue,Cline,Cnum,Lline,Lnum,A,freq)
% *************** 不需要加BJT端口 ***************

Af=[zeros(size(A,1),1),A];
Af=[zeros(1,size(A,1)+1);Af];
for i=1:Cnum
    Index = Cline + i - 1;
    pNum1 = N1(Index) + 1;
    pNum2 = N2(Index) + 1;
    %% 在电路上贴电容
    cpValue=CValue(i)*1i*freq*2*pi;
    % 方程贴电阻
    Af(pNum1,pNum1)= Af(pNum1,pNum1)+cpValue;
    Af(pNum1,pNum2)= Af(pNum1,pNum2)-cpValue;
    Af(pNum2,pNum1)= Af(pNum2,pNum1)-cpValue;
    Af(pNum2,pNum2)= Af(pNum2,pNum2)+cpValue;

end
for i = 1:Lnum
    Index = Lline + i - 1;
    pNum1 = N1(Index) + 1;
    pNum2 = N2(Index) + 1;
    %% 在电路上贴电感
    cpValue=LValue(i)*1i*freq*2*pi;
    % 方程贴电阻
    Af(pNum1,pNum1)= Af(pNum1,pNum1)+1/cpValue;
    Af(pNum1,pNum2)= Af(pNum1,pNum2)-1/cpValue;
    Af(pNum2,pNum1)= Af(pNum2,pNum1)-1/cpValue;
    Af(pNum2,pNum2)= Af(pNum2,pNum2)+1/cpValue;
end
Af(1,:)=[];
Af(:,1)=[];

