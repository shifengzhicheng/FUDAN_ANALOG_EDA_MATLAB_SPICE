%根据二极管反向饱和电流Is，本轮两端正向电压Vpn，温度(默认27℃=300K)
%得到伴随器件值Gdk = 1/Rk, Ieqk
function [Gdk, Ieqk] = Diode_Calculator(Vpn, Is, T)
    Vt = 8.6173e-5 * (273.15 + T);
    Gdk = (Is / Vt) * exp(Vpn / Vt);
    Icur = Is * (exp(Vpn / Vt) - 1);
    Ieqk = Icur - Gdk * Vpn;
end
