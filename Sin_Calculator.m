%计算正弦源瞬态值 需要初相和时间
function [Vt] = Sin_Calculator(Vdc, Vac, Freq, t, Phase)
    CurPhase = (t.*Freq + Phase./360).*2.*pi;
    Vt = Vdc + Vac .* sin(CurPhase);
end
