* RC
.OPTIONS LIST NODE POST 
.OP 
*.PRINT AC I1(M1) I2(M1) I(M2)  I(M3)  I(M4) I(Rin) I(R2) I(R3) 
.pz V(21) Vin
*.AC DEC 10 10 1e18MEG

Vin 11 0 DC=1 AC=1,0
VDD 31 0 3
Rin 11 21 10

*M1 32 21 33 0 MODN W=20e-6 L=0.35e-6
RM1 32 33 6.231403950062208e+05
GM1 32 33 cur='v(21,33)*1.475090858166613e-04'

Rout 31 32 1000
Rs 33 0 10

CgsM1  21   33  1.05e-16
CgdM1 21   32   1.05e-16
CdM1   32    0    4e-14	
CsM1    33   0    4e-14

.end
