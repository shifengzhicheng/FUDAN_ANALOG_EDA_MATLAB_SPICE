%% 这个函数将获取器件对应节点的电流
function Current = getCurrent(Device,port,LinerNet,x,Res,freq)
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
dependence = LinerNet('dependence');
value = LinerNet('Value');
switch Device(1)
    case 'M'
        % 第一步找到含有M命名的所有线性器件
        Mdevice = find(contains(Name,Device));
        % 第二步计算这些器件的电流
        switch port
            case 'd'
                Current = calcCurrent(Mdevice(3),Res,x,Name,N1,N2,value,freq)...
                    +calcCurrent(Mdevice(4),Res,x,Name,N1,N2,value,freq);
            case 'g'
                Current = calcCurrent(Mdevice(1),Res,x,Name,N1,N2,value,freq)...
                    +calcCurrent(Mdevice(2),Res,x,Name,N1,N2,value,freq)...
                    +calcCurrent(Mdevice(5),Res,x,Name,N1,N2,value,freq)...
                    -calcCurrent(Mdevice(4),Res,x,Name,N1,N2,value,freq);
            case 's'
                Current = -calcCurrent(Mdevice(1),Res,x,Name,N1,N2,value,freq)  ...
                    -calcCurrent(Mdevice(2),Res,x,Name,N1,N2,value,freq) ...
                    -calcCurrent(Mdevice(3),Res,x,Name,N1,N2,value,freq) ...
                    +calcCurrent(Mdevice(6),Res,x,Name,N1,N2,value,freq);
        end
    case 'D'
        % 第一步找到含有D命名的所有线性器件
        Mdevice = find(contains(Name,Device));
        % 第二步计算这些器件的电流
        Current = sum(calcCurrent(Mdevice,Res,x,Name,N1,N2,value,freq));
    case {'V','I','R','C','L','G','H','F','E'}
        % 第一步找到含有此命名的所有线性器件
        Mdevice = find(contains(Name,Device));
        % 第二步计算这些器件的电流
        Current = calcCurrent(Mdevice,Res,x,Name,N1,N2,value,freq);
end
end

function StandardCurrent = calcCurrent(Mdevice,Res,x,Name,N1,N2,value,freq)
dName = Name{Mdevice};
switch dName(1)
    case 'V'
        StandardCurrent = Res(find(strcmp(x,['I_' dName]))-1,:);
    case 'I'
        Index = find(strcmp(Name,dName));
        StandardCurrent = value(Index);
    case 'R'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index)+1,:)-Res(N2(Index)+1,:))/value(Index);
    case 'C'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index)+1,:)-Res(N2(Index)+1,:)).*(2*pi*freq*1i*value(Index));
    case 'L'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index)+1,:)-Res(N2(Index)+1,:))./(2*pi*freq*1i*value(Index));
    case 'E'
        StandardCurrent = Res(find(strcmp(x,['I_' dName]))-1,:);
    case 'G'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index)+1,:)-Res(N2(Index)+1,:)).*value(Index);
    case 'H'
        StandardCurrent = Res(find(strcmp(x,['I_' dName]))-1,:);
    case 'F'
        Index = find(strcmp(Name,dName));
        StandardCurrent = Res(find(strcmp(x,['I_' dName]))-1,:).*value(Index);
end
end

