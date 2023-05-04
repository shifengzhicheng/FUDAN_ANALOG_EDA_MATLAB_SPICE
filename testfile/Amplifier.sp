* Amplifier
VDD 10 0 DC 3
Vin 13 0 DC 0
Rin 13 12 10

Rout 16 0 1000

VB1 18 0 DC 1.8
VB2 17 0 DC 1.2 

M1   15 10 10 p 30e-6 0.35e-6 1
M2   16 15 15 p 60e-6 0.35e-6 1
M3   16 11 11 n 20e-6 0.35e-6 2
M4   11 12 0  n 10e-6 0.35e-6 2
* M5   12 10 10 p 60e-6 0.35e-6 1
* M6   12 13 0  n 20e-6 0.35e-6 2

.MODEL 1 VT -0.75 MU 5e-2 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14
.MODEL 2 VT 0.83 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14

.plotnv 12
.plotnv 16


.dcsweep Vin [0,3] 0.01