* bjt amplifier circuit
.OPTIONS LIST NODE POST 
.OP 
.PRINT DC I1(Q1)  I2(Q1)  I3(Q1)  I1(Q3)  I2(Q3)  I3(Q3) 
.DC Vbb 2 6 0.01

Vcc 101 0 dc 9
Vbb 102 0 dc 5.0
R1 103 0 1.0e4
R2 101 104 2.7e4
R3 105 0 0.2e4
R4 101 106 1.0e4
R5 107 0 1.0e4
R6 101 108 1.0e4
Rb1 102 109 1.9e6
Rb2 103 110 1.9e5
Rb3 104 111 3.7e6

* bjt
Q1 108 109 103 MOD1
Q2 104 110 105 MOD1
Q3 106 111 107 MOD1

.MODEL MOD1 NPN IS = 2e-16 BF=100 CJE= 1e-11 CJC= 0.5e-11

.end