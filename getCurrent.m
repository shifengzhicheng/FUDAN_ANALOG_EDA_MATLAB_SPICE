%% 这个函数将获取器件对应节点的电流
function Current = getCurrent(Device,Node,LinerNet,x,Res)
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
value = LinerNet('Value');
switch Device(1)
    case 'M'
        switch Node
            case 'd'
                % 第一步找到含有M命名的所有线性器件
                Mdvice = find(contains(Name,Device));
                % 第二步计算这些器件的电流
                Current = sum(calcCurrent(Mdevice,Res,x,Name,N1,N2,value));
            case 'g'
                % 第一步找到含有M命名的所有线性器件
                Mdvice = find(contains(Name,Device));
                % 第二步计算这些器件的电流
                Current = sum(calcCurrent(Mdevice,Res,x,Name,N1,N2,value));
            case 's'
                % 第一步找到含有M命名的所有线性器件
                Mdvice = find(contains(Name,Device));
                % 第二步计算这些器件的电流
                Current = sum(calcCurrent(Mdevice,Res,x,Name,N1,N2,value));
        end
    case 'D'
        % 第一步找到含有D命名的所有线性器件
        Mdvice = find(contains(Name,Device));
        % 第二步计算这些器件的电流
        Current = sum(calcCurrent(Mdevice,Res,x,Name,N1,N2,value));
    case {'V','I','R','C','L'}
        % 第一步找到含有此命名的所有线性器件
        Mdvice = find(contains(Name,Device));
        % 第二步计算这些器件的电流
        Current = calcCurrent(Mdevice,Res,x,Name,N1,N2,value);
end
end

function StandardCurrent = calcCurrent(Mdevice,Res,x,Name,N1,N2,value)
dName = Name(Mdevice);
switch dName(1)
    case 'V'
        StandardCurrent = Res(find(strcmp(x,['I_' dName])));
    case 'I'
        Index = find(strcmp(Name,dName));
        StandardCurrent = value(Index);
    case 'R'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index))-Res(N2(Index)))/value(Index);
    case 'C'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index))-Res(N2(Index)))*(value(Index)*1i);
    case 'L'
        Index = find(strcmp(Name,dName));
        StandardCurrent = (Res(N1(Index))-Res(N2(Index)))/(value(Index)*1i);
end
end

