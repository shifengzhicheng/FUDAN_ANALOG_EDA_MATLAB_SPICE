%% 文件作者：郑志宇
%% 这个函数接收器件、所在频率、线性网表的标准信息该器件所有的标准电流
function StandardCurrent = calcCurrent(Mdevice,Res,x,Name,N1,N2,dependence,value,freq)
dName = Name{Mdevice};
switch dName(1)
    case 'V'
        StandardCurrent = Res(find(strcmp(x,['I_' dName]))+1,:);
    case 'I'
        Index = find(strcmp(Name,dName));
        StandardCurrent = value(Index,:);
    case 'R'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index)+1,:)-Res(N2(Index)+1,:))./value(Index,:);
    case 'C'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index)+1,:)-Res(N2(Index)+1,:)).*(2*pi*freq*1i*value(Index,:));
    case 'L'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index)+1,:)-Res(N2(Index)+1,:))./(2*pi*freq*1i*value(Index,:));
    case 'E'
        StandardCurrent = Res(find(strcmp(x,['I_' dName]))+1,:);
    case 'G'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(dependence{Index}(1)+1,:)-Res(dependence{Index}(2)+1,:)).*value(Index,:);
    case 'H'
        StandardCurrent = Res(find(strcmp(x,['I_' dName]))+1,:);
    case 'F'
        Index = find(strcmp(Name,dName));
        StandardCurrent = Res(find(strcmp(x,['Icontrol_' dependence(Index)]))+1,:).*value(Index,:);
end
end

