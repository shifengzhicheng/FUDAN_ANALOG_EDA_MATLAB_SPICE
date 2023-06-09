* Diftest

VDD 101 0 DC 2
Vb 111 0 DC 1
Rload1 104 0 1e5
Rload2 105 0 5

* mosfet
M1 102 112 121 n 30e-6 .5e-6 2
M2 103 112 121 n 30e-6 .5e-6 1
M3 102 111 101 p 30e-6 .5e-6 4
M4 103 111 101 p 30e-6 .5e-6 3

* diode 
D1 104 102 1
D2 103 105 1

* input 
VIN 112 0 DC 1.5
Iref 121 0 DC 0.001

RSS 121 0 1e5

* level 1 models
.MODEL 1 VT 0.5 MU 3e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.3 MU 3e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 3 VT -0.5 MU 1e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 4 VT -0.3 MU 1e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14

* diode models
.DIODE 1 Is 1e-5

.plotnv 102
.plotnv 103 
.plotnv 104
.plotnv 105
.plotnv 121
.plotnv 112
.plotnc D1(+)
.plotnc D2(+)
.plotnc M4(d)
.plotnc M2(d)
.plotnc M1(d)
.plotnc M3(d)
.plotnc Rload2(+)
.plotnc RSS(+)
.plotnc Iref(+)

.dcsweep VIN [1,2] 0.01
