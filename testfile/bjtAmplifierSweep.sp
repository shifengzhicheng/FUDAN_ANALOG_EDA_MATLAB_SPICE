* bjt amplifier circuit

Vcc 101 0 dc 9
Vbb 102 0 dc 4.0
* R1 101 102 3e5
* R2 102 0 6.5e4
R1 103 0 1.0e3
R2 101 104 1.0e4
R3 105 0 3e4
R4 101 106 5e2
R5 107 0 5e4
R6 101 108 6e3
Rb1 102 109 5e5
Rb2 103 110 5e5
Rb3 104 111 5e5

* bjt
Q1 106 109 103 npn 6.1285 1
Q2 104 110 107 npn 5.64458 1
Q3 108 111 105 npn 0.732447 1
* Q1 101 102 103 npn 6.1285 1
* Q2 104 103 0 npn 5.64458 1
* Q3 101 104 105 npn 0.732447 1

* bjt models
* .BIPOLAR 1 Js 1e-16 alpha_f 0.9982 alpha_r 0.96
.BIPOLAR 1 Js 1e-16 alpha_f 0.9981 alpha_r 0.981

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
* .end

.dcsweep Vbb [2,4] 0.01