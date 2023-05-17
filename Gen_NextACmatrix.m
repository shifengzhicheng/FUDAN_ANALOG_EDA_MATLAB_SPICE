function Af=Gen_NextACmatrix(N1,N2,Value,Cline,Cnum,Lline,Lnum,A,freq)
Af = A;
for i=0:Cnum-1
    Index = Cline + i;
    pNum1 = N1(Index);
    pNum2 = N2(Index);
    %% 在电路上贴电容
    cpValue=Value(i)*1i*freq;
    % 方程贴电阻
    Af(pNum1,pNum1)= Af(pNum1,pNum1)+cpValue;
    Af(pNum1,pNum2)= Af(pNum1,pNum2)-cpValue;
    Af(pNum2,pNum1)= Af(pNum2,pNum1)-cpValue;
    Af(pNum2,pNum2)= Af(pNum2,pNum2)+cpValue;

end
for i = 0:Lnum -1
    Index = Lline + i;
    pNum1 = N1(Index);
    pNum2 = N2(Index);
    %% 在电路上贴电感
    cpValue=Value(i)*1i*freq;
    % 方程贴电阻
    Af(pNum1,pNum1)= Af(pNum1,pNum1)+1/cpValue;
    Af(pNum1,pNum2)= Af(pNum1,pNum2)-1/cpValue;
    Af(pNum2,pNum1)= Af(pNum2,pNum1)-1/cpValue;
    Af(pNum2,pNum2)= Af(pNum2,pNum2)+1/cpValue;
end

