* bjt amplifier circuit

Vcc 101 0 dc 9
Vbb 102 0 dc 4.0
R1 103 0 1.0e4
R2 101 104 0.2e4
R3 105 0 0.9e4
R4 101 106 1.0e4
R5 107 0 1.0e4
R6 101 108 1.0e4
Rb1 102 109 2.8e6
Rb2 108 110 1.9e5
Rb3 105 111 5.4e6

* bjt
Q1 103 109 108 pnp 2.0 1
Q2 105 110 104 pnp 2.0 1
Q3 107 111 106 pnp 2.0 1

* bjt models
.BIPOLAR 1 Js 1e-16 alpha_f 0.99 alpha_r 1 Cje 1e-11 Cjc 0.5e-11

.dc
.plotnv  111
.plotnv  110

.plotnv  108
.plotnv  107
.plotnv  106
.plotnv  105
.plotnv  104
.plotnv  103
.plotnv  102
.plotnc Q1(c)
.plotnc Q1(b)
.plotnc Q1(e)
.plotnc Q2(c)
.plotnc Q2(b)
.plotnc Q2(e)
.plotnc Q3(c)
.plotnc Q3(b)
.plotnc Q3(e)
.end