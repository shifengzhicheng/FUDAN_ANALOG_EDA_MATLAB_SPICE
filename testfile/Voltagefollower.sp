VDD 103 0 DC 3
Vin 101 0 DC 1.5
Rin 101 102 10
M1 107 102 0 n 10e-6 0.35e-6 2
M2 107 102 103 p 30e-6 0.35e-6 1
M3 104 107 103 p 60e-6 0.35e-6 3
M4 104 107 0 n 20e-6 0.35e-6 4
C1 104 0 0.1e-12
R2 104 115 25
L1 115 116 0.5e-12
C2 116 0 0.5e-12
R3 116 117 35
L2 117 118 0.5e-12
C3 118 0 1e-12
.MODEL 1 VT -0.75 MU 5e-2 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.83 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 3 VT -0.8 MU 5e-2 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 4 VT 0.8 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.PLOTNV 101
.PLOTNV 118
.plotnc M1(d)
.plotnc M2(d)
.plotnc M3(d)
.plotnc M4(d)
.DC