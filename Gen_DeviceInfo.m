%{
输入：
1. parser得到的预处理数据
输出：
1. DeviceInfo元胞数组
%}

%{
Function: 将parser得到的预处理数据整合为DeviceInfo元胞数组
Test Pass: Y (no separate test file)
%}

function [DeviceInfo] = Gen_DeviceInfo(RLCName,RLCN1,RLCN2,...
    SourceName,SourceN1,SourceN2,SourceDcValue,...
    MOSName,MOSN1,MOSN2,MOSN3,MOStype,...
    DiodeName,DiodeN1,DiodeN2)

    DeviceInfo = cell(1, numel(RLCName) + numel(SourceName) + numel(MOSName) + numel(DiodeName));
    count = 0;
    % 添加RLC器件信息
    for i = 1:numel(RLCName)
        count = count + 1;
        Device.name = RLCName{i};
        Device.type = 'RLC';
        Device.nodes = {RLCN1(i), RLCN2(i)};
        Device.init = 0;
        Device.value = -1;  % 表示不需要存该器件的value
        DeviceInfo{count} = Device;
    end
    % 添加电压源\电流源信息
    for i = 1:numel(SourceName)
        count = count + 1;
        Device.name = SourceName{i};
        Device.type = 'source';
        Device.nodes = {SourceN1(i), SourceN2(i)};
        Device.init = 0;
        Device.value = SourceDcValue(i);
        DeviceInfo{count} = Device;
    end
    % 添加MOS管信息
    for i = 1:numel(MOSName)
        count = count + 1;
        Device.name = MOSName{i};
        if MOStype{i} == 'n'
            Device.type = 'nmos';
        elseif MOStype{i} == 'p'
            Device.type = 'pmos';
        end
        Device.nodes = {MOSN1(i), MOSN2(i), MOSN3(i)};
        Device.init = 0;
        Device.value = -1;  % 表示不需要存该器件的value
        DeviceInfo{count} = Device;
    end
    % 添加Diode信息
    for i = 1:numel(DiodeName)
        count = count + 1;
        Device.name = DiodeName{i};
        Device.type = 'diode';
        Device.nodes = {DiodeN1(i), DiodeN2(i)};
        Device.init = 0;
        Device.value = -1;  % 表示不需要存该器件的value
        DeviceInfo{count} = Device;        
    end
end

