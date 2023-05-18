Vin 11 0 ac 1 1 0

VDD 31 0 DC 3

Rin 11 21 10

M1 32 21 33 n 20e-6 0.35e-6 1

Rout 31 32 1000

Rs 33 0 10
.MODEL 1 VT 0.5 MU 1.5e-1 COX 0.3e-4 LAMBDA 0.05 CJ0 4.0e-14

.plotnv 21
.plotnv 32
.plotnc M1(d)
.plotnc M1(g)
.plotnc M1(s)

* .dc
.AC DEC 10 1 1e18MEG