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

function [x_0] = init_value(NodeInfo, DeviceInfo, Vdd, Vdd_node, Gnd_node)

    %% 对电路中的各个节点赋初始值
    % 目标: 所有源极接Gnd或Vdd的MOS管尽量都在饱和区，其他所有MOS管尽量都不在截止区
    % 假设: 只有几个MOS管工作在截止区的话应该不影响电路求解?
    % 考虑1: 对于截止区的MOS管，指定一个迭代轮数n，在这n轮内可以改截止区的MOS管模型为线性区，不然这些截止区的管子可能一直跳不出截止状态
    % 考虑2: 如果考虑1有效，可以考虑在这个指定的迭代轮数n轮内，不论截止、线性，都设为饱和区，让电路状态可以更快地跳出截止区?
    % 备注1: 还没有考虑电流变量，只考虑了节点电压. 电流变量在unlinearDC.m中先直接赋为0了
    % 备注2: 允许赋>Vdd与<Gnd的电压初值
    % 备注3: 源漏交换在Generate_DCnetlist.m中考虑
    
    % 1. 先找源极接Gnd或Vdd的MOS管
    % (所有MOS管，尽量都|Vgs| = Vdd / 3, |Vds| = Vdd / 4)
    % 2. 再找普通电压源
    % 3. 再找其他与Gnd或Vdd相连的器件
    % 4. 最后更新其他所有未打标记的节点
    
    % MOS节点顺序: DGS
    % BJT节点顺序: CBE
    
    for i = 1:numel(DeviceInfo)
        Type = 0;
        if isequal(DeviceInfo{i}.type, 'nmos')
            Type = 1;
        elseif isequal(DeviceInfo{i}.type, 'pmos')
            Type = -1;
        elseif isequal(DeviceInfo{i}.type, 'npn')
            Type = 2;
        elseif isequal(DeviceInfo{i}.type, 'pnp')
            Type = -2;
        end
        for j = 1:numel(DeviceInfo{i}.nodes)
            %% 找源极接Gnd的NMOS
            % [BJT一般不会和MOS同时出现] 找发射极接Gnd的npnBJT
            if Type >= 1 && isequal(DeviceInfo{i}.nodes{3}, Gnd_node)
                DeviceInfo{i}.init = 1;
                % 源接Gnd或Vdd(Vcc)的MOS和BJT不用确认节点未赋过初值再赋值，这类器件的节点优先赋初值以保证收敛
                if Type == 1
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = Vdd / 2;
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = Vdd * 2/3;
                elseif Type == 2
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = 0.5;
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = 0.6667;
                end
                % S
                NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value = 0;
                break;
            %% 找源极接Vdd的PMOS
            % [BJT一般不会和MOS同时出现] 找发射极接Vdd(Vcc)的pnpBJT
            elseif Type <= -1 && isequal(DeviceInfo{i}.nodes{3}, Vdd_node)
                DeviceInfo{i}.init = 1;
                % 源接Gnd或Vdd(Vcc)的MOS和BJT不用确认节点未赋过初值再赋值，这类器件的节点优先赋初值以保证收敛
                if Type == -1
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = Vdd / 2;
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = Vdd / 3;
                elseif Type == -2
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = 0.5;
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = 0.3333;
                end
                % S
                NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value = Vdd;
                break;
             %% 源极未连接Vdd或Gnd的MOS
            elseif abs(Type) == 1
                DeviceInfo{i}.init = 1;
                if NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value ~= -1
                    % D赋过初值，将S赋为Vd - Vdd*2/3 * Type，将G赋为Vs + Vdd/2 * Type
                    % 确认S未赋过初值再赋值
                    if NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value == -1
                        NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value - Vdd * 2/3 * Type;
                    end
                    % 确认G未赋过初值再赋值
                    if NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value == -1
                        NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value + Vdd/2 * Type;
                    end
                elseif NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value ~= -1
                    % S赋过初值，将D赋为Vs + Vdd*2/3 * Type，将G赋为Vs + Vdd/2 * Type
                    % D一定未赋过初值
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value + Vdd * 2/3 * Type;
                    % 确认G未赋过初值再赋值
                    if NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value == -1
                        NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value + Vdd/2 * Type;
                    end
                elseif NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value ~= -1
                    % G赋过初值，将S赋为Vg - Vdd/2 * Type，将D赋为Vs + Vdd*2/3 * Type
                    % S一定未赋过初值
                    NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value - Vdd/2 * Type;
                    % D一定未赋过初值
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value + Vdd * 2/3 * Type;
                end
                break;
                %% 源极未连接Vdd(Vcc)或Gnd的BJT
            elseif abs(Type) == 2
                DeviceInfo{i}.init = 1;
                if NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value ~= -1
                    % E赋过初值，将C赋为Ve + Vdd/6 * Type/2，将B赋为Ve + Vdd/4 * Type/2
                    % E一定未赋过初值
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value + 0.6667 * Type/2;
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value + 0.5 * Type/2;
                elseif NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value ~= -1
                    % C赋过初值，将E赋为Vc - Vdd/6 * Type/2，将B赋为Ve + Vdd/4 *Type/2
                    NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value - 0.6667 * Type/2;
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value + 0.5 * Type/2;
                elseif NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value ~= -1
                    % B赋过初值，将E赋为Vb - Vdd/4 * Type/2，将C赋为Ve + Vdd/6 * Type/2
                    % E一定未赋过初值
                    NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value - 0.5 * Type/2;
                    % C一定未赋过初值
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{3}+1 }.value + 0.6667 * Type/2;
                end
                break;
            %% 找普通电压源
            elseif isequal(DeviceInfo{i}.type, 'source') && isequal(DeviceInfo{i}.name(1), 'V')
                if NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value ~= -1 && NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value == -1
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value - DeviceInfo{i}.value;
                elseif NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value ~= -1 && NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value == -1
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value + DeviceInfo{i}.value;
                elseif NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value == -1 && NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value == -1
                    if isequal(DeviceInfo{i}.nodes{1}, Gnd_node)
                        NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = 0;
                        NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = DeviceInfo{i}.value;
                    elseif isequal(DeviceInfo{i}.nodes{2}, Gnd_node)
                        NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = 0;
                        NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = DeviceInfo{i}.value;
                    end
                end
                break;
            %% 找有端口接Gnd的其他非NMOS器件 (除MOS\BJT外其他器件都是二端器件)
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
                    NodeInfo{ DeviceInfo{i}.nodes{j}+1 }.value = 0;
                    NodeInfo{ DeviceInfo{i}.nodes{j}+1 }.value = Vdd;
                else
                    % for k = 1:2
                    for k = 1:numel(DeviceInfo{i}.nodes)
                        if isequal(DeviceInfo{i}.type, 'diode')
                            if k == j
                                NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value = 0;
                            elseif NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value == -1  % 确认未赋过初值再赋值
                                NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value = Vdd / 6;  % 给二极管赋Vdd/6的正向电压
                            end
                        else
                            if NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value == -1  % 确认未赋过初值再赋值
                                NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value = 0;
                            end
                        end
                    end
                end
                break;
            %% 找有端口接Vdd的其他非PMOS器件 (除MOS\BJT外其他器件都是二端器件)    
            elseif isequal(DeviceInfo{i}.nodes{j}, Vdd_node)
                DeviceInfo{i}.init = 1;
                % for k = 1:2
                for k = 1:numel(DeviceInfo{i}.nodes)
                    if isequal(DeviceInfo{i}.type, 'diode')
                        if k ~= j && NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value = Vdd * 5/6;  % 给二极管赋Vdd/6的正向电压
                        end
                    else
                        if NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value == -1  % 确认未赋过初值再赋值
                            NodeInfo{ DeviceInfo{i}.nodes{k}+1 }.value = Vdd;
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
            if isequal(DeviceInfo{i}.type, 'diode')
                DeviceInfo{i}.init = 1;
                if NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value == -1
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = Vdd/2;
                end
                if NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value == -1
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = Vdd/3;  % 给二极管赋Vdd/6的正向电压
                end
            else
                DeviceInfo{i}.init = 1;
                if NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value == -1
                    NodeInfo{ DeviceInfo{i}.nodes{1}+1 }.value = Vdd/2;
                end
                if NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value == -1
                    NodeInfo{ DeviceInfo{i}.nodes{2}+1 }.value = Vdd/2;
                end
            end
        end
    end

    
    % 没有考虑要额外引入电流变量的情况
    % 如要考虑，所有电流变量设为0.1mA
    x_0 = zeros( numel(NodeInfo), 1);
    %{
    for i = 1:numel(NodeInfo)
        x_0(i) = NodeInfo{i}.value;
    end
    %}
    x_0(1) = 0;
    x_0(2) = 9;
    x_0(3) = 1.416;
    x_0(4) = 0.72;
    x_0(5) = 2;
    x_0(6) = 1.2;
    fprintf("InitValue: \n\n");
    disp(x_0);
end
