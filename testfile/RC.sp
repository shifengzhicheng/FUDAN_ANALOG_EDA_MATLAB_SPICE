Vin 11 0 ac 1.5 1 90

Rin 11 21 1

M1 31 21 0 n 20e-6 0.35e-6 1

.MODEL 1 VT 0.5 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14

.plotnv 21
.plotnv 31
.plotnc M1(d)
.plotnc M1(g)
.plotnc M1(s)
.ac DEC 10 1 1e20MEG