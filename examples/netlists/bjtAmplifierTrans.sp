* bjt amplifier circuit

Vcc 101 0 dc 9
Vbb 102 0 SIN 1.5 2 10e6 0
R1 103 0 1.0e4
R2 101 104 2.7e4
R3 105 0 0.2e4
R4 101 106 1.0e4
R5 107 0 1.0e4
R6 101 108 1.0e4
Rb1 102 109 1.9e6
Rb2 103 110 1.9e5
Rb3 104 111 3.7e6

* bjt
Q1 108 109 103 npn 2.0 1
Q2 104 110 105 npn 2.0 1
Q3 106 111 107 npn 2.0 1

* bjt models
.BIPOLAR 1 Js 1e-16 alpha_f 0.99 alpha_r 0.98 Cje 1e-11 Cjc 0.5e-11

.plotnv 108
.plotnv 106
.plotnv 104
.plotnc Q2(e)
.plotnc Q3(c)
* .end

.trans 1e-6 1e-9