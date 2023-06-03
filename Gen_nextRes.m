%% 文件作者: 林与正
%% Gen_nextRes
% 如果需要采用稀疏矩阵格式，将Gen_nextRes中涉及矩阵求解的地方全部改成LU_solve实现
function [zc, dependence, Value] = Gen_nextRes(MOSMODEL, Mostype, MOSW, MOSL, mosNum, mosNodeMat, MOSLine, MOSID, ...
                                               diodeNum, diodeNodeMat, diodeLine, Is, ...
                                               BJTMODEL, BJTtype, BJTJunctionarea, bjtNum, bjtNodeMat, BJTLine, BJTID, ...
                                               A0, b0, N1, N2, dependence, Value, zp)
% *************** 已加BJT端口 ***************
    
%% 处理MOS
    % 已经得到了按顺序的每个MOS管的三端的节点序号，带入x(z)p结果得到上轮具体三端电压
    for mosCount = 1 : mosNum   % 1个MOS衍生出的3个伴随器件1组
    % 可能出现源漏端交换的情况，我们固定初始GDS的物理位置，源漏交换只体现在伴随器件的数值正负上
        tempz = [0; zp];
        vd = tempz(mosNodeMat(mosCount, 1) + 1);
        vg = tempz(mosNodeMat(mosCount, 2) + 1);
        vs = tempz(mosNodeMat(mosCount, 3) + 1);
                        % NMOS源漏交换                  % PMOS源漏交换
        if Mostype(mosCount) == 2 && vd < vs && vs ~= 0 || Mostype(mosCount) == 1 && vd > vs  
            % 源漏交换，此为实际交换后的vds\vgs
            vds = vs - vd;
            vgs = vg - vd;
            % 用上一轮x(z)p结果的到的三端电压计算得到新的伴随器件参数(MOS合法判断在Mos_Calculator中)
            [nextIeq, nextGM, nextGDS] = Mos_Calculator(vds, vgs,  MOSMODEL(:, MOSID(mosCount)), MOSW(mosCount), MOSL(mosCount));
            nextIeq = -nextIeq;
            nextGM = -nextGM;
            % 源漏交互换后GM的控制电压端口也要改变为原来的栅漏端 - 原GM的第二个控制端由S改D
            dependence{MOSLine + 3*mosCount - 2}(2) = mosNodeMat(mosCount, 1);
        else
            % 正常情况
            vds = vd - vs;
            vgs = vg - vs;
            [nextIeq, nextGM, nextGDS] = Mos_Calculator(vds, vgs, MOSMODEL(:, MOSID(mosCount)), MOSW(mosCount), MOSL(mosCount));
            % 源漏换回来，正常vgs控制
           dependence{MOSLine + 3*mosCount - 2}(2) = mosNodeMat(mosCount, 3);
        end

        tempCount = MOSLine + 3 * (mosCount - 1);
        Value(tempCount) = 1 / nextGDS;  % 更新RM
        Value(tempCount+2) = nextIeq;  % 更新IM
        Value(tempCount+1) = nextGM;  % 更新GM
    end

%% 处理二极管
    for diodeCount = 1 : diodeNum
        tempz = [0; zp];
        Vpn = tempz(diodeNodeMat(diodeCount, 1) + 1) - tempz(diodeNodeMat(diodeCount, 2) + 1);
        [Gdk, Ieqk] = Diode_Calculator(Vpn, Is(diodeCount), 27);  % 室温
        Value(diodeLine + diodeCount * 2 - 2) = 1 / Gdk;
        Value(diodeLine + diodeCount * 2 - 1) = Ieqk;
    end

%% 处理BJT
    % 已经得到了按顺序的每个BJT管的三端的节点序号，带入x(z)p结果得到上轮具体三端电压
    for bjtCount = 1 : bjtNum   % 1个BJT衍生出的6个伴随器件1组
        tempz = [0; zp];
        vc = tempz(bjtNodeMat(bjtCount, 1) + 1);
        vb = tempz(bjtNodeMat(bjtCount, 2) + 1);
        ve = tempz(bjtNodeMat(bjtCount, 3) + 1);
        BJTflag = 0;
        if isequal(BJTtype(bjtCount), 2)  % 在calculateDC等函数里做过转化. npn
            BJTflag = 1;
        elseif isequal(BJTtype(bjtCount), 1)  % 在calculateDC等函数里做过转化. pnp
            BJTflag = -1;
        end
        vbe = vb - ve;
        vbc = vb - vc;
        
        T = 300;
        [next_Rbe, next_Gbc_e, next_Ieq, next_Rbc, next_Gbe_c, next_Icq] = BJT_Calculator(vbe, vbc, BJTMODEL(:, BJTID(bjtCount)), BJTJunctionarea(bjtCount), BJTflag, T);
        tempCount = BJTLine + 6 * (bjtCount - 1);
        Value(tempCount) = next_Rbe;  % 更新Rbe
        Value(tempCount+1) = next_Gbc_e;  % 更新Gbc_e
        Value(tempCount+2) = next_Ieq;  % 更新Ieq
        Value(tempCount+3) = next_Rbc;  % 更新Rbc
        Value(tempCount+4) = next_Gbe_c;  % 更新Gbe_c
        Value(tempCount+5) = next_Icq;  % 更新Icq
    end    
    
%% 将得到的新器件数据结合A0、b0得到新的矩阵
    [Ac, bc] = Gen_nextA(A0, b0, N1, N2, dependence, Value,MOSLine,mosNum,diodeLine,diodeNum,BJTLine,bjtNum);
    % 解得新一轮的x(z)cur
%     zc = Ac \ bc;
    zc = LU_solve(Ac, bc);
end


