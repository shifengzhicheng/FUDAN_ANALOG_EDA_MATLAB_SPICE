function [mosIndexInValues, mosIndexInmosCurrents, ...
    dioIndexInValues, dioIndexIndiodeCurrents, ...
    VIndexInValues, VIndexInDCres, ...
    IIndexInValues, IIndexInValue, ...
    RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
    CIndexInValues, CIndexInCIp,...
    LIndexInValues, LIndexInLIp,...
    Obj, Values, plotnv] = PLOTIndexInRes(x_0, PLOT, Node_Map, Times, LinerNet, MOSName, DiodeName, CName, LName)
%LinerNet
Name = LinerNet('Name');
N1 = LinerNet('N1');
N2 = LinerNet('N2');
Value = LinerNet('Value');

%要打印的序号值或者器件类型加端口名
[plotnv, plotCurrent] = portMapping(PLOT, Node_Map);
plotnv=plotnv';
plotCurrent=plotCurrent';
nvNum = size(plotnv, 1);
ncNum = size(plotCurrent, 1);
%Obj
ObjNum = ncNum + nvNum;
Obj = cell(ObjNum, 1);
for i=1 : nvNum
    Obj(i) = {['Node_{' num2str(Node_Map(plotnv(i))) '}']};
end
for j = i + 1 : ObjNum
    dname = plotCurrent{j-i}{1};
    plotport = plotCurrent{j-i}{2};
    Obj(j) = {[dname '(' plotport ')']};
end
%初始化Value
Values =  zeros(ObjNum, Times);
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
CIndexInValues = [];
CIndexInCIp = [];
LIndexInValues = [];
LIndexInLIp = [];
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
            dioIndexIndiodeCurrents = [dioIndexIndiodeCurrents; find(strcmp(DiodeName,dname))];
            switch plotport
                case '+'
                    Values(j + nvNum, :) = 1;
                case '-'
                    Values(j + nvNum, :) = -1;
            end
        case 'V'
            VIndexInValues = [VIndexInValues; j + nvNum];
            VIndexInDCres = [VIndexInDCres; find(strcmp(x_0, ['I_' dname]))];
            switch plotport
                case '+'
                    Values(j + nvNum, :) = 1;
                case '-'
                    Values(j + nvNum, :) = -1;
            end
        case 'I'
            IIndexInValues = [IIndexInValues; j + nvNum];
            IIndexInValue = [IIndexInValue; find(strcmp(Name,dname))];
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
            if plotCurrent{j}{2} == '+'
                Values(j + nvNum, :) = 1 / Value(Index);
            else
                Values(j + nvNum, :) = -1 / Value(Index);
            end
        case 'C'
            %电容电流直接从DC解中C得到的伴随器件电压源流过电流得到
            CIndexInValues = [CIndexInValues; j + nvNum];
            CIndexInCIp = [CIndexInCIp, find(strcmp(CName, dname))];
            if plotCurrent{j}{2} == '+'
                Values(j + nvNum, :) = 1;
            else
                Values(j + nvNum, :) = -1;
            end
        case 'L'
            %电感电流为当前L双端电压比上伴随器件电阻后 + 伴随器件电流源电流
            LIndexInValues = [LIndexInValues; j + nvNum];
            LIndexInLIp = [LIndexInLIp, find(strcmp(LName, dname))];
            if plotCurrent{j}{2} == '+'
                Values(j + nvNum, :) = 1;
            else
                Values(j + nvNum, :) = -1;
            end
    end
end
VIndexInDCres = VIndexInDCres + 1;
RNodeIndexInDCresN1 = RNodeIndexInDCresN1 + 1;
RNodeIndexInDCresN2 = RNodeIndexInDCresN2 + 1;
end
