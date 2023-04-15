%{
输入：
1. DeviceInfo元胞数组
输出：
1. DeviceInfo元胞数组(更新了各个节点.v的初始值)
%}

%{
Function: 给电路的每个节点电压赋初始值
Test Pass: N (no separate test file)
%}

function [zp] = init_value(NodeInfo, DeviceInfo, Vdd, Vdd_node, Gnd_node)

    fprintf("Vdd: \n\n");
    disp(Vdd);

    %% 对电路中的各个节点赋初始值
    % 目标: 所有源极接Gnd或Vdd的MOS管尽量都在饱和区，其他所有MOS管尽量都在线性区
    % 假设: 只有几个MOS管工作在截止区的话应该不影响电路求解?
    % 考虑1: 对于截止区的MOS管，指定一个迭代轮数n，在这n轮内可以改截止区的MOS管模型为线性区，不然这些截止区的管子可能一直跳不出截止状态
    % 考虑2: 如果考虑1有效，可以考虑在这个指定的迭代轮数n轮内，不论截止、线性，都设为饱和区，让电路状态可以更快地跳出截止区?
    % 备注1: 还没有考虑电流变量，只考虑了节点电压. 电流变量在unlinerDC.m中先直接赋为0了
    % 备注2: 要不要考虑负电压? 现在还没有考虑
    
    % 1. 先找源极接Gnd或Vdd的MOS管
    % (所有MOS管，尽量都|Vgs| = Vdd / 3, |Vds| = Vdd / 4)
    % 2. 再找其他与Gnd或Vdd相连的器件
    % 3. 最后更新其他所有未打标记的节点
    
    for i = 1:numel(DeviceInfo)
        for j = 1:numel(DeviceInfo{i}.nodes)
            % fprintf("Nodes of each device: \n\n");
            % disp(DeviceInfo{i}.nodes{j});
            % 找源极接Gnd的NMOS
            if isequal(DeviceInfo{i}.nodes{j}, Gnd_node) && isequal(DeviceInfo{i}.type, 'nmos')
                DeviceInfo{i}.init = 1;
                if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1  % 确认未赋过初值再赋值
                    NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = Vdd / 4;  % D
                end
                if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value == -1  % 确认未赋过初值再赋值
                    NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value = Vdd / 3;  % G
                end
                NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value = 0;  % S
                break;
            % 找源极接Vdd的PMOS
            elseif isequal(DeviceInfo{i}.nodes{j}, Vdd_node) && isequal(DeviceInfo{i}.type, 'pmos')
                DeviceInfo{i}.init = 1;
                if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1  % 确认未赋过初值再赋值
                    NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = Vdd * 3/4;  % D
                    %{
                    fprintf("Test 4 value: \n\n");
                    disp( Vdd/4 );
                    %}
                end
                if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value == -1  % 确认未赋过初值再赋值
                    NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value = Vdd * 2/3;  % G
                end
                NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value = Vdd;  % S
                break;
            % 找有端口接Gnd的非NMOS器件 (除MOS外其他器件都是二端器件)
            elseif isequal(DeviceInfo{i}.nodes{j}, Gnd_node)
                DeviceInfo{i}.init = 1;
                Vdd_and_Gnd = 0;
                for k = 1:numel(DeviceInfo{i}.nodes)
                    if k ~= j && isequal(DeviceInfo{i}.nodes{k}, Vdd_node)
                        Vdd_and_Gnd = 1;
                        break;
                    end
                end
                if Vdd_and_Gnd == 1
                    NodeInfo{ str2double(DeviceInfo{i}.nodes{j})+1 }.value = 0;
                    NodeInfo{ str2double(DeviceInfo{i}.nodes{j})+1 }.value = Vdd;
                else
                    for k = 1:numel(DeviceInfo{i}.nodes)
                        if k == j
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{k})+1 }.value = 0;
                        elseif NodeInfo{ str2double(DeviceInfo{i}.nodes{k})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{k})+1 }.value = 0;
                        end
                    end
                end
                break;
            % 找有端口接Vdd的非NMOS器件 (除MOS外其他器件都是二端器件)    
            elseif isequal(DeviceInfo{i}.nodes{j}, Vdd_node)
                DeviceInfo{i}.init = 1;
                for k = 1:numel(DeviceInfo{i}.nodes)
                    if k == j
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{k})+1 }.value = Vdd;
                    elseif NodeInfo{ str2double(DeviceInfo{i}.nodes{k})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{k})+1 }.value = Vdd;
                    end
                end
                break;
            % 未连接Vdd或Gnd的NMOS，不区分D\S，按Vd=Vs的线性区赋值
            elseif isequal(DeviceInfo{i}.type, 'nmos')
                DeviceInfo{i}.init = 1;
                if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value ~= -1  % D赋过初值，将S赋为相同值，将G赋为Vs + Vdd/3
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value;
                    end
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value + Vdd/3;
                    end
                elseif NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value ~= -1  % S赋过初值，将D赋为相同值，将G赋为Vs + Vdd/3
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value;
                    end
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value + Vdd/3;
                    end
                elseif NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value ~= -1  % G赋过初值
                    DeviceInfo{i}.init = 1;
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value - Vdd/3 >= 0
                        if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value - Vdd/3;
                        end
                        if NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value - Vdd/3;
                        end
                    else
                        if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = 0;
                        end
                        if NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value = 0;
                        end
                    end
                end
                break;
            % 未连接Vdd或Gnd的NMOS，不区分D\S，按Vd=Vs的线性区赋值
            elseif isequal(DeviceInfo{i}.type, 'pmos')
                DeviceInfo{i}.init = 1;
                if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value ~= -1  % D赋过初值，将S赋为相同值，将G赋为Vs - Vdd/3
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value;
                    end
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value - Vdd/3;
                    end
                elseif NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value ~= -1  % S赋过初值，将D赋为相同值，将G赋为Vs - Vdd/3
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value;
                    end
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value == -1  % 确认未赋过初值再赋值
                        NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value - Vdd/3;
                    end
                elseif NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value ~= -1  % G赋过初值
                    if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value + Vdd/3 <= Vdd
                        if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value + Vdd/3;
                        end
                        if NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value = NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value + Vdd/3;
                        end
                    else
                        if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = Vdd;
                        end
                        if NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ str2double(DeviceInfo{i}.nodes{3})+1 }.value = Vdd;
                        end
                    end
                end
                break;
            % 其他没有任何连接Gnd\Vdd节点的非MOS器件 (除MOS外其他器件都是二端器件)
            % 这些器件DeviceInfo{i}.init = 0; 下一个循环处理
            end
        end
    end
    
    for i = 1:numel(DeviceInfo)
        if DeviceInfo{i}.init == 0
            DeviceInfo{i}.init = 1;
            if NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value == -1
                NodeInfo{ str2double(DeviceInfo{i}.nodes{1})+1 }.value = Vdd/2;
            end
            if NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value == -1
                NodeInfo{ str2double(DeviceInfo{i}.nodes{2})+1 }.value = Vdd/2;
            end
        end
    end

    
    % 没有考虑要额外引入电流变量的情况
    % 如要考虑，所有电流变量设为0.1mA
    zp = zeros( numel(NodeInfo), 1); 
    for i = 1:numel(NodeInfo)
        zp(i) = NodeInfo{i}.value;
    end
    
    fprintf("InitValue: \n\n");
    disp(zp);
    
end

