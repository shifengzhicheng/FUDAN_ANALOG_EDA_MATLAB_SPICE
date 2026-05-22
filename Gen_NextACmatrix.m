function Af = Gen_NextACmatrix(N1, N2, CValue, LValue, Cline, Cnum, Lline, Lnum, A, freq)
% GEN_NEXTACMATRIX Build the AC MNA matrix for one frequency point.
% Gen_Matrix removes the ground row/column for DC.  AC stamping temporarily
% restores that row/column so capacitor and inductor node indexes still match
% the original netlist, then removes it again before solving.

Af = addRowCol(A, 1, 1);
omega = 2 * pi * freq;

for idx = 1:Cnum
    elementIndex = Cline + idx - 1;
    nodeA = N1(elementIndex) + 1;
    nodeB = N2(elementIndex) + 1;
    admittance = 1i * omega * CValue(idx);
    Af = stampAdmittance(Af, nodeA, nodeB, admittance);
end

for idx = 1:Lnum
    elementIndex = Lline + idx - 1;
    nodeA = N1(elementIndex) + 1;
    nodeB = N2(elementIndex) + 1;
    admittance = 1 / (1i * omega * LValue(idx));
    Af = stampAdmittance(Af, nodeA, nodeB, admittance);
end

Af = deleteRowCol(Af, 1, 1);

% Sweep_AC uses MATLAB's backslash solver; convert the custom CSR container
% directly to a built-in sparse matrix instead of materializing a dense copy.
if isa(Af, 'SpM')
    Af = toSparse(Af);
end
end

function A = stampAdmittance(A, nodeA, nodeB, admittance)
% Stamp a two-terminal admittance into the MNA matrix.
A = renewElement(A, nodeA, nodeA, admittance);
A = renewElement(A, nodeA, nodeB, -admittance);
A = renewElement(A, nodeB, nodeA, -admittance);
A = renewElement(A, nodeB, nodeB, admittance);
end
