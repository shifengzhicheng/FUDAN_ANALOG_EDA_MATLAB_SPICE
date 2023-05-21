function Values = updateValues( DCresData, LinerValue, mosCurrents, diodeCurrents, CIp, LIp,...
    plotnv,...
    mosIndexInValues, mosIndexInmosCurrents, ...
    dioIndexInValues, dioIndexIndiodeCurrents, ...
    VIndexInValues, VIndexInDCres, ...
    IIndexInValues, IIndexInValue, ...
    RIndexInValues, RNodeIndexInDCresN1, RNodeIndexInDCresN2, ...
    CIndexInValues, CIndexInCIp,...
    LIndexInValues, LIndexInLIp,...
    Values, nvNum)
%% 节点电压信息
Values((1 : nvNum), :) = DCresData(plotnv,:);
%% 节点电流信息
%mosIndexInValues\mosIndexInmosCurrents都是列向量 - 更改Values结果里要的mos管电流
if(~isempty(mosIndexInValues))
    Values(mosIndexInValues, :) = Values(mosIndexInValues, :) .* mosCurrents(mosIndexInmosCurrents);
end
%更改Values结果里要的diode管电流
if(~isempty(dioIndexInValues))
    Values(dioIndexInValues, :) = Values(dioIndexInValues, :) .* diodeCurrents(dioIndexIndiodeCurrents);
end
%更改Values结果里要的电源电压V
if(~isempty(VIndexInValues))
    Values(VIndexInValues, :) = Values(VIndexInValues, :) .* DCresData(VIndexInDCres);
end
%更改Values结果里要的电源电流Is
if(~isempty(IIndexInValues))
    Values(IIndexInValues, :) = Values(IIndexInValues, :) .* LinerValue(IIndexInValue);
end
%更改Values结果里要的电阻电流
if(~isempty(RIndexInValues))
    Values(RIndexInValues, :) = Values(RIndexInValues, :) .* (DCresData(RNodeIndexInDCresN1,:) - DCresData(RNodeIndexInDCresN2,:));
end
%更改Values结果里要的电容电流
if(~isempty(CIndexInValues))
    Values(CIndexInValues, :) = Values(CIndexInValues, :) .* CIp(CIndexInCIp,:);  %因为CIp为行向量, Values看每列
end
%更改Values结果里要的电感电流
if(~isempty(LIndexInValues))
    Values(LIndexInValues, :) = Values(LIndexInValues, :) .* LIp(LIndexInLIp,:);
end
end
