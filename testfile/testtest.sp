* A test circuit 

VDD 101 1 DC 3
Vb 111 0 DC 1
Rload1 104 0 10
Rload2 105 0 10

* mosfet
M1 102 112 121 n 30e-6 .5e-6 2
M2 103 112 121 n 30e-6 .5e-6 1
M3 102 111 101 p 90e-6 .5e-6 4
M4 103 111 101 p 90e-6 .5e-6 3

* diode 
D1 104 102 1
D2 103 105 1

* input 
VIN 112 0 1
Iref 121 0 0.001

RSS 121 0 100

* level 1 models
.MODEL 1 VT 0.5 MU 3e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.3 MU 3e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 3 VT -0.5 MU 1e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 4 VT -0.3 MU 1e-2 COX 6e-3 LAMBDA 0.05 CJ0 4.0e-14

* diode models
.DIODE 1 IS 1e-3

.dc

.plotnv  102
.plotnv  103 
.plotnv  104
.plotnv  105
.plotnv  121
.plotnc  D1(+)
.plotnc  M4(d)
.plotnc  R2(+)
.end