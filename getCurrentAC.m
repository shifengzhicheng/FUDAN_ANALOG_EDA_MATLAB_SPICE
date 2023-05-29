%% 文件作者：郑志宇
%% 这个函数将在AC中获取器件对应节点的电流
function Current = getCurrentAC(Device,port,LinerNet,x,Res,freq)
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
                Current = calcCurrent(Mdevice(3),Res,x,Name,N1,N2,dependence,value,freq)...
                    +calcCurrent(Mdevice(4),Res,x,Name,N1,N2,dependence,value,freq);
            case 'g'
                Current = calcCurrent(Mdevice(1),Res,x,Name,N1,N2,dependence,value,freq)...
                    +calcCurrent(Mdevice(2),Res,x,Name,N1,N2,dependence,value,freq)...
                    +calcCurrent(Mdevice(5),Res,x,Name,N1,N2,dependence,value,freq)...
                    -calcCurrent(Mdevice(4),Res,x,Name,N1,N2,dependence,value,freq);
            case 's'
                Current = -calcCurrent(Mdevice(1),Res,x,Name,N1,N2,dependence,value,freq)  ...
                    -calcCurrent(Mdevice(2),Res,x,Name,N1,N2,dependence,value,freq) ...
                    -calcCurrent(Mdevice(3),Res,x,Name,N1,N2,dependence,value,freq) ...
                    +calcCurrent(Mdevice(6),Res,x,Name,N1,N2,dependence,value,freq);
        end
    case 'D'
        % 第一步找到含有D命名的所有线性器件
        Mdevice = find(contains(Name,Device));
        % 第二步计算这些器件的电流
        switch port
            case '+'
                Current = calcCurrent(Mdevice(1),Res,x,Name,N1,N2,dependence,value,freq)...
                    +calcCurrent(Mdevice(2),Res,x,Name,N1,N2,dependence,value,freq);
            case '-'
                Current = -calcCurrent(Mdevice(1),Res,x,Name,N1,N2,dependence,value,freq)...
                    -calcCurrent(Mdevice(2),Res,x,Name,N1,N2,dependence,value,freq);
        end
    case {'V','I','R','C','L','G','H','F','E'}
        % 第一步找到含有此命名的所有线性器件
        Mdevice = find(contains(Name,Device));
        % 第二步计算这些器件的电流
        switch port
            case '+'
                Current = calcCurrent(Mdevice,Res,x,Name,N1,N2,dependence,value,freq);
            case '-'
                Current = -calcCurrent(Mdevice,Res,x,Name,N1,N2,dependence,value,freq);
        end
end
end

