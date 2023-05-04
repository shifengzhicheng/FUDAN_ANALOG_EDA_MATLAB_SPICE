* bjt amplifier circuit

Vcc 101 0 dc 9
R1 101 102 3e5
R2 102 0 5.6e4
R3 103 0 2.4e3
R4 101 104 1e4
R5 105 0 6e2

* bjt
Q1 101 102 103 npn 6.11945 1
Q2 104 103 0 npn 5.64458 1
Q3 101 104 105 npn 0.731204 1

* bjt models
.BIPOLAR 1 Js 1e-16 alpha_f 0.996 alpha_r 0.96

.dc
.plotnv  105
.plotnv  104
.plotnv  103
.plotnv  102
.plotnc Q1(c)
.plotnc Q1(b)
.plotnc Q1(e)
.end