function [v] = LU_solve(Y, J)
v = spice.solver.solveLinearSystem(Y, J);
end
