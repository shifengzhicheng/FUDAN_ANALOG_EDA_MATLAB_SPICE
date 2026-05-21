function solution = solveLinearSystem(systemMatrix, rhs)
backend = spice.solver.getBackend();

switch backend
    case "legacySpM"
        if isa(systemMatrix, 'SpM')
            [L, U, P] = sparse_LU_decompose(systemMatrix);
            rhsPermuted = P * rhs;
            dimension = systemMatrix.rows;
            forward = zeros(dimension, 1);
            forward(1, 1) = rhsPermuted(1, 1);
            for row = 2:dimension
                forward(row, 1) = rhsPermuted(row, 1) - sum(L(row, 1:row-1) .* forward(1:row-1, 1)');
            end
            solution = zeros(dimension, 1);
            solution(dimension, 1) = forward(dimension, 1) / U(dimension, dimension);
            for row = dimension-1:-1:1
                solution(row, 1) = (forward(row, 1) - sum(U(row, row+1:dimension) .* solution(row+1:dimension, 1)')) / U(row, row);
            end
        else
            solution = full(systemMatrix) \ rhs;
        end
    case "dense"
        solution = full(spice.solver.toSparseMatrix(systemMatrix)) \ rhs;
    otherwise
        solution = spice.solver.toSparseMatrix(systemMatrix) \ rhs;
end
end
