filename = 'dbmixerDC.sp';
 [RLCName,RLCN1,RLCN2,RLCarg1,...
    SourceName,SourceN1,SourceN2,...
    Sourcetype,SourceValue,...
    SourceFreq,SourcePhase,...
    MOSName,MOSN1,MOSN2,MOSN3,...
    MOStype,MOSW,MOSL,...
    MOSMODEL,PLOT,SPICEOperation]= parse_netlist(filename);
% 这里是这个文件能够获得的数据
fprintf("MOS Recorded:\n\n")
disp(MOSName);
fprintf("RLC Recorded:\n\n")
disp(RLCName);
fprintf("Source Recorded:\n\n")
disp(SourceName);
fprintf("MODEL Recorded:\n\n")
disp(MOSMODEL);
fprintf("Operation Recorded:\n\n")
disp(SPICEOperation);
fprintf("Plot Recorded:\n\n")
disp(PLOT);