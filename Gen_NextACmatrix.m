function Af=Gen_NextACmatrix(Name,N1,N2,Value,LCline,A,freq)
Af = A;
for i=LCline:size(Af,1)
    dName = Name(i);
    pNum1 = N1(i);
    pNum2 = N2(i);
    switch dName(1)
        case 'C'
            %% 在电路上贴电容
            cpValue=Value(i)*1i*freq;
            % 方程贴电阻
            Af(pNum1,pNum1)= Af(pNum1,pNum1)+cpValue;
            Af(pNum1,pNum2)= Af(pNum1,pNum2)-cpValue;
            Af(pNum2,pNum1)= Af(pNum2,pNum1)-cpValue;
            Af(pNum2,pNum2)= Af(pNum2,pNum2)+cpValue;
        case 'L'
            %% 在电路上贴电感
            cpValue=Value(i)*1i*freq;
            % 方程贴电阻
            Af(pNum1,pNum1)= Af(pNum1,pNum1)+1/cpValue;
            Af(pNum1,pNum2)= Af(pNum1,pNum2)-1/cpValue;
            Af(pNum2,pNum1)= Af(pNum2,pNum1)-1/cpValue;
            Af(pNum2,pNum2)= Af(pNum2,pNum2)+1/cpValue;
    end
end

