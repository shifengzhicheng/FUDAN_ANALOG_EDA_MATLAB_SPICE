%{
输入:
    Name,N1,N2,dependence,Value, ...
    MOSINFO, MOSName,DIODEINFO, Diodes, Error, ..
    作扫描的DC量名称SweepInName(横轴)
    扫描起点start
    扫描终点end
    扫描步长step
    待打印信息PLOT(各图纵轴信息)
    x_0, Node_Map为了节点序号名字对应
输出:
    作扫描的DC向量InData
    要打印的各信息名称Obj
    与Obj顺序顺序对应的各信息在多个扫描点下的值矩阵Values
        #矩阵大小size(Obj) * [(stop-start)/step]
        #Obj里一个对象在各扫描点结果对应Values的一行
%}
function [InData, Obj, Values] = Sweep_DC(LinerNet, MOSINFO, DIODEINFO, Error, SweepInfo, PLOT, Node_Map)
    [~, x_0, ~] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
    display(x_0);
    %% 读出线性网表信息
    Name = LinerNet('Name');
    N1 = LinerNet('N1');
    N2 = LinerNet('N2');
    Value = LinerNet('Value');
    %% 扫描信息
    SweepInName = SweepInfo{1};
    start = SweepInfo{2}(1);
    stop = SweepInfo{2}(2);
    step = SweepInfo{3};
    %% MOS 二极管名
    MOSName = MOSINFO('Name');
    Diodes = DIODEINFO('Name');
    
    %要打印的序号值或者器件类型加端口名
    [plotnv, plotCurrent] = portMapping(PLOT,Node_Map);
    plotnv=plotnv';
    plotCurrent=plotCurrent';
    nvNum = size(plotnv, 1);   
    ncNum = size(plotCurrent, 1);  
    ObjNum = ncNum + nvNum;
    Obj = cell(ObjNum, 1);   
    for i=1 : nvNum
     Obj(i) = {['Node_Voltage: ' num2str(Node_Map(plotnv(i)))]};
    end
    for j = i + 1 : ObjNum
      dname = plotCurrent{j-i}{1};
      plotport = plotCurrent{j-i}{2};
      Obj(j) = {[dname '_Current: ' num2str(plotport) ' Value: ']};
    end
    %扫描的器件值
    InData = (start : step : stop);
    %扫描次数
    sweepTimes = size(InData, 2);
    %扫描器件的索引
    SweepInIndex = find(ismember(Name, SweepInName));
    %初始化
    Values =  zeros(ObjNum, sweepTimes);

    %% 得到要取mosCurrents、diodeCurrents、DCres、Value的各索引值向量
    % 以及对应Values哪些行的索引向量
    mosIndexInValues = [];
    mosIndexInmosCurrents = [];
    dioIndexInValues = [];
    dioIndexIndiodeCurrents = [];
    VIndexInValues = [];
    VIndexInDCres = [];
    IIndexInValues = [];
    IIndexInValue = [];
    RIndexInValues = [];
    RNodeIndexInDCresN1 = [];
    RNodeIndexInDCresN2 = [];
    for j = 1 : ncNum
        dname = plotCurrent{j}{1};
        plotport = plotCurrent{j}{2};
        switch dname(1)
            case 'M'
                %mosIndexInValues是表示Values中从mosCurrents得电流的位置的索引们
                mosIndexInValues = [mosIndexInValues; j + nvNum];
                %mosIndexInmosCurrents是表示mosCurrents要看的索引们
                mosIndexInmosCurrents = [mosIndexInmosCurrents; find(strcmp(MOSName,dname))];
                switch plotport
                    case 'd'
                        Values(j + nvNum, :) = 1;
                    case 'g'
                        Values(j + nvNum, :) = 0;
                    case 's'
                        Values(j + nvNum, :) = -1;
                end
            case 'D'
                dioIndexInValues = [dioIndexInValues; j + nvNum];
                dioIndexIndiodeCurrents = [dioIndexIndiodeCurrents; find(strcmp(Diodes,dname))];
                switch plotport
                    case '+'
                        Values(j + nvNum, :) = 1;
                    case '-'
                        Values(j + nvNum, :) = -1;
                end
            case 'V'
                VIndexInValues = [VIndexInValues; j + nvNum];
                VIndexInDCres = [VIndexInDCres; find(strcmp(x_0, ['I_' plotCurrent{j}{1}]))];
                switch plotport
                    case '+'
                        Values(j + nvNum, :) = 1;
                    case '-'
                        Values(j + nvNum, :) = -1;
                end
            case 'I'
                IIndexInValues = [IIndexInValues; j + nvNum];
                IIndexInValue = [IIndexInDCres; strcmp(Name,dname)];
                switch plotport
                    case '+'
                        Values(j + nvNum, :) = 1;
                    case '-'
                        Values(j + nvNum, :) = -1;
                end
            case 'R'
                % 找两端节点然后计算出电流
                Index = find(strcmp(Name,dname));
                RIndexInValues = [RIndexInValues; j + nvNum];
                % 希望可以直接x_res(RNodeIndexInDCresN1)-x_res(RNodeIndexInDCresN2)就是要观察的各个R的两端电压向量
                RNodeIndexInDCresN1 = [RNodeIndexInDCresN1; N1(Index)];
                RNodeIndexInDCresN2 = [RNodeIndexInDCresN2; N2(Index)];
                if plotCurrent{j}{2} == '+'     %%%%%%%%%%%%%%%%%%%
                    Values(j + nvNum, :) = 1 / Value(Index);
                else
                    Values(j + nvNum, :) = -1 / Value(Index);
                end
        end
    end
    VIndexInDCres = VIndexInDCres + 1;
    RNodeIndexInDCresN1 = RNodeIndexInDCresN1 + 1;
    RNodeIndexInDCresN2 = RNodeIndexInDCresN2 + 2;
%% 开始遍历要求的扫描点 每轮循环是一次正常DC 在Values中是一列
% 要被打印的与Obj顺序对应的是Values的行 Values哪几行要改索引向量由上得到 避免每轮都switch
    for i = 1 : sweepTimes
        %修改作扫描的值
        tValue = LinerNet('Value');
        tValue(SweepInIndex) = InData(i);
        LinerNet('Value') = tValue;
        %把上次DC的Value结果当作下次DC计算的初始解加速收敛
        [DCres, ~, Value] = calculateDC(LinerNet, MOSINFO, DIODEINFO, Error);
        x_res = [0; DCres('x')];
        mosCurrents = DCres('MOS');
        diodeCurrents = DCres('Diode');

        Values((1 : nvNum), i) = x_res(plotnv);
        %mosIndexInValues\mosIndexInmosCurrents都是列向量 - 更改Values结果里要的mos管电流
        Values(mosIndexInValues, i) = Values(mosIndexInValues, i) .* mosCurrents(mosIndexInmosCurrents);
        %更改Values结果里要的diode管电流
        Values(dioIndexInValues, i) = Values(dioIndexInValues, i) .* diodeCurrents(dioIndexIndiodeCurrents);
        %更改Values结果里要的电源电压V
        Values(VIndexInValues, i) = Values(VIndexInValues, i) .* x_res(VIndexInDCres);
        %更改Values结果里要的电源电流I
        Values(IIndexInValues, i) = Values(IIndexInValues, i) .* Value(IIndexInValue);
        %更改Values结果里要的电阻电流
        Values(RIndexInValues, i) = Values(RIndexInValues, i) .* (x_res(RNodeIndexInDCresN1) - x_res(RNodeIndexInDCresN2));
    end
end
