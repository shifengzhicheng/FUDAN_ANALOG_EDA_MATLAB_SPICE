%% 文件作者：林与正
%% 函数完成将MOS的信息提取出来并贴入寄生电容的功能
function transRes =  compCINFO(CINFO,MOSINFO,BJTINFO)
% NO MOS DGS INFO
MOSMODEL = MOSINFO('MODEL');
if(~isempty(MOSMODEL))
    MOSD = MOSINFO('d');
    MOSG = MOSINFO('g');
    MOSS = MOSINFO('s');
    Name = MOSINFO('Name');
    % add MOS - C
    MOSW = str2double(MOSINFO('W'));
    MOSL = str2double(MOSINFO('L'));

    MOSID = str2double(MOSINFO('ID'));

    MOSMODEL = cell2mat(MOSMODEL);
    MOSCox = MOSMODEL(4, MOSID);
    MOSCj = MOSMODEL(6, MOSID);
    CgsSet = 0.5 * MOSW .* MOSL .* MOSCox;
    CgdSet = 0.5 * MOSW .* MOSL .* MOSCox;
    CdSet = MOSCj;
    CsSet = MOSCj;
    MOSNum = size(MOSID, 2);
    MOSNameC = cell(1, MOSNum * 4);
    MOSValuesC = cell(1, MOSNum * 4);
    MOSN1C = cell(1, MOSNum * 4);
    MOSN2C = cell(1, MOSNum * 4);
    for i = 1 : MOSNum
        MOSNameC(4 * i - 3) = {['Cgs' Name{i}]};
        MOSNameC(4 * i - 2) = {['Cgd' Name{i}]};
        MOSNameC(4 * i - 1) = {['Cd' Name{i}]};
        MOSNameC(4 * i) = {['Cs' Name{i}]};
        MOSValuesC(4 * i - 3) = {[num2str(CgsSet(i))]};
        MOSValuesC(4 * i - 2) = {[num2str(CgdSet(i))]};
        MOSValuesC(4 * i - 1) = {[num2str(CdSet(i))]};
        MOSValuesC(4 * i) = {[num2str(CsSet(i))]};
        MOSN1C(4 * i - 3) = MOSG(i);  % Cgs
        MOSN2C(4 * i - 3) = MOSS(i);
        MOSN1C(4 * i - 2) = MOSG(i);  % Cgd
        MOSN2C(4 * i - 2) = MOSD(i);
        MOSN1C(4 * i - 1) = MOSD(i);  % Cd
        MOSN2C(4 * i - 1) = {[num2str(0)]};
        MOSN1C(4 * i) = MOSS(i);      % Cs
        MOSN2C(4 * i) = {[num2str(0)]};
        % Not include s=0 situation
    end
    CINFO('Name') = [CINFO('Name'), MOSNameC];
    CINFO('Value') = [CINFO('Value'), MOSValuesC];
    CINFO('N1') = [CINFO('N1'), MOSN1C];
    CINFO('N2') = [CINFO('N2'), MOSN2C];
end

% BJT寄生电容大小与电压有关，后面再具体计算
BJTMODEL = BJTINFO('MODEL');
if(~isempty(BJTMODEL))
    BJTC = BJTINFO('c');
    BJTB = BJTINFO('b');
    BJTE = BJTINFO('e');
    Name = BJTINFO('Name');
    % add BJT - C
    BJTJunctionarea = str2double(BJTINFO('Junctionarea'));

    BJTID = str2double(BJTINFO('ID'));

    BJTMODEL = cell2mat(BJTMODEL);
    BJTCje = BJTMODEL(5, BJTID);
    BJTCjc = BJTMODEL(6, BJTID);
    
%     me = 0.41;
%     mc = 0.41;
%     fy_e = 0.76;
%     fy_c = 0.76;
    CbeSet = BJTCje .* BJTJunctionarea;
    CbcSet = BJTCjc .* BJTJunctionarea;
    BJTNum = size(BJTID, 2);
    BJTNameC = cell(1, BJTNum * 2);
    BJTValuesC = cell(1, BJTNum * 2);
    BJTN1C = cell(1, BJTNum * 2);
    BJTN2C = cell(1, BJTNum * 2);
    for i = 1 : BJTNum
        BJTNameC(2 * i - 1) = {['Ce' Name{i}]};
        BJTNameC(2 * i) = {['Cc' Name{i}]};
        BJTValuesC(2 * i - 1) = {[num2str(CbeSet(i))]};
        BJTValuesC(2 * i) = {[num2str(CbcSet(i))]};
        BJTN1C(2 * i - 1) = BJTB(i);  % Cbe
        BJTN2C(2 * i - 1) = BJTE(i);
        BJTN1C(2 * i) = BJTB(i);      % Cbc
        BJTN2C(2 * i) = BJTC(i);
        % Not include s=0 situation
    end
    CINFO('Name') = [CINFO('Name'), BJTNameC];
    CINFO('Value') = [CINFO('Value'), BJTValuesC];
    CINFO('N1') = [CINFO('N1'), BJTN1C];
    CINFO('N2') = [CINFO('N2'), BJTN2C];
end

transRes = CINFO;
end
