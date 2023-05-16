%% 函数完成将MOS的信息提取出来并贴入寄生电容的功能
function transRes =  compCINFO(CINFO, MOSINFO)
%NO MOS DGS INFO
MOSD = MOSINFO("d");
MOSG = MOSINFO("g"); 
MOSS = MOSINFO("s");
% add MOS - C
MOSW = str2double(MOSINFO('W'));
MOSL = str2double(MOSINFO('L'));
MOSMODEL = MOSINFO('MODEL');
MOSID = str2double(MOSINFO('ID'));
MOSMODEL = cell2mat(MOSMODEL);
MOSCox = MOSMODEL(4, MOSID);
MOSCj = MOSMODEL(6, MOSID);
CgsSet = 0.5 * MOSW .* MOSL .* MOSCox;
CgdSet = 0.5 * MOSW .* MOSL .* MOSCox;
CdSet = MOSCj;
CsSet = MOSCj;
MOSNum = size(MOSID, 2);
NameC = cell(1, MOSNum * 4);
ValuesC = cell(1, MOSNum * 4);
N1C = cell(1, MOSNum * 4);
N2C = cell(1, MOSNum * 4);
for i = 1 : MOSNum
    NameC(4 * i - 3) = {['Cgs' num2str(i)]};
    NameC(4 * i - 2) = {['Cgd' num2str(i)]};
    NameC(4 * i - 1) = {['Cd' num2str(i)]};
    NameC(4 * i) = {['Cs' num2str(i)]};
    ValuesC(4 * i - 3) = {[num2str(CgsSet(i))]};
    ValuesC(4 * i - 2) = {[num2str(CgdSet(i))]};
    ValuesC(4 * i - 1) = {[num2str(CdSet(i))]};
    ValuesC(4 * i) = {[num2str(CsSet(i))]};
    N1C(4 * i - 3) = MOSG(i);  %Cgs
    N2C(4 * i - 3) = MOSS(i);
    N1C(4 * i - 2) = MOSG(i);  %Cgd
    N2C(4 * i - 2) = MOSD(i);
    N1C(4 * i - 1) = MOSD(i);  %Cd
    N2C(4 * i - 1) = {[num2str(0)]};
    N1C(4 * i) = MOSS(i);      %Cs
    N2C(4 * i) = {[num2str(0)]};
    %Not include s=0 situation
end
CINFO('Name') = [CINFO('Name'), NameC];
CINFO('Value') = [CINFO('Value'), ValuesC];
CINFO('N1') = [CINFO('N1'), N1C];
CINFO('N2') = [CINFO('N2'), N2C];
transRes = CINFO;
end
