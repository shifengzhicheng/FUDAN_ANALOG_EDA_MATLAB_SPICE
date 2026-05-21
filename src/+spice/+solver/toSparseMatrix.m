function matrix = toSparseMatrix(inputMatrix)
if isa(inputMatrix, 'SpM')
    matrix = sparse(recover(inputMatrix));
elseif issparse(inputMatrix)
    matrix = inputMatrix;
else
    matrix = sparse(inputMatrix);
end
end
