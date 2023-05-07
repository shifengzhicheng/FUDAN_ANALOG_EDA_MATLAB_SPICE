* Amplifier
VDD 9 0 DC 3
Vin 10 0 DC 0

Rin 10 11 100

Rout 16 0 1000

Vb1 12 0 DC 1

M1   13 13 9 p 30e-6 0.35e-6 1
M2   16 12 13 p 60e-6 0.35e-6 1
M3   16 12 14 n 20e-6 0.35e-6 2
M4   14 11 0  n 10e-6 0.35e-6 2

.MODEL 1 VT -0.5 MU 5e-2 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.5 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14

.plotnv 12
.plotnv 16
.plotnc Rout(+)
.plotnc M3(d)

.dcsweep Vin [0,3] 0.01