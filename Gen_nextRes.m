%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Gen_nextRes%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [zc, dependence, Value] = Gen_nextRes(MOSMODEL, Mostype, MOSW, MOSL, mosNum, mosNodeMat, MOSLine, A0, b0, Name, N1, N2, dependence, Value, zp)
%已经得到了按顺序的每个MOS管的三端的节点序号，带入x(z)p结果得到上轮具体三端电压
    for mosCount = 1 : mosNum   % 1个MOS衍生出的3个伴随器件1组
%% 可能出现源漏端交换的情况，我们固定初始GDS的物理位置，源漏交换只体现在伴随器件的数值正负上
        tempz = [0; zp];
        vd = tempz(mosNodeMat(mosCount, 1) + 1);
        vg = tempz(mosNodeMat(mosCount, 2) + 1);
        vs = tempz(mosNodeMat(mosCount, 3) + 1);
                        %NMOS源漏交换                  %PMOS源漏交换
        if Mostype(mosCount) == 2 && vd < vs || Mostype(mosCount) == 1 && vd > vs  
            %源漏交换，此为实际交换后的vds\vgs
            vds = vs - vd;
            vgs = vg - vd;
            %用上一轮x(z)p结果的到的三端电压计算得到新的伴随器件参数(MOS合法判断在Mos_Calculater中)
            [nextIeq, nextGM, nextGDS] = Mos_Calculater(vds, vgs,  MOSMODEL(:, Mostype(mosCount)), MOSW(mosCount), MOSL(mosCount));
            nextIeq = -nextIeq;
            nextGM = -nextGM;
            %源漏交互换后GM的控制电压端口也要改变为原来的栅漏端 - 原GM的第二个控制端由S改D
            dependence{MOSLine + 3*mosCount - 2}(2) = mosNodeMat(mosCount, 1);
        else
            %正常情况
            vds = vd - vs;
            vgs = vg - vs;
            [nextIeq, nextGM, nextGDS] = Mos_Calculater(vds, vgs, MOSMODEL(:, Mostype(mosCount)), MOSW(mosCount), MOSL(mosCount));
            %源漏换回来，正常vgs控制
           dependence{MOSLine + 3*mosCount - 2}(2) = mosNodeMat(mosCount, 3);
        end

        tempCount = MOSLine + 3 * (mosCount - 1);
        Value(tempCount) = 1 / nextGDS; %更新RM
        Value(tempCount+2) = nextIeq; %更新IM
        Value(tempCount+1) = nextGM; %更新GM
    end
    %将得到的新器件数据结合A0、b0得到新的矩阵
    [Ac, bc] = Gen_nextA(A0, b0, Name, N1, N2, dependence, Value);
    %解得新一轮的x(z)cur
    zc = Ac \ bc;
end
