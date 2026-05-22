function v = LU_solve(Y, J)
% LU_SOLVE Solve one MNA linear system.
% The simulator still assembles matrices with the legacy SpM CSR container,
% but MATLAB's sparse backslash is faster and has more robust pivoting than
% the old hand-written LU path for repeated DC/transient solves.

if isa(Y, 'SpM')
    Y = toSparse(Y);
end

v = Y \ J;
end
