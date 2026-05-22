% TOP_MODULE Legacy script entry point.
% Edit fileName to run a single netlist from testfile/<fileName>.sp.

clear;
clc;

fileName = 'dbmixerShoot';
result = run_spice_case(fileName, EmitPlots=true, FigureVisible="on");
disp(result.summary);
