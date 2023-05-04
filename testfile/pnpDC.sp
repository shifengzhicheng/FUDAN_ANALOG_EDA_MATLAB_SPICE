* pnp bipolar transistor

Vcc 101 0 dc 1
Vbb 102 0 dc 0.3
RC 103 0 270
RB 102 104 3000

* bjt
Q1 103 104 101 pnp 1 1

* bjt models
.BIPOLAR 1 Js 1e-16 alpha_f 0.996 alpha_r 0.96

.dc
.plotnv  102
.plotnv  103
.plotnv  104 
.plotnc Q1(c)
.plotnc Q1(b)
.plotnc Q1(e)
.end