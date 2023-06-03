%% 文件作者: 张润洲
%% LU_solve分为一般矩阵格式和稀疏矩阵格式。使用稀疏矩阵格式时将上半部分注释

%% LU_solve(一般矩阵格式)
function [v] = LU_solve(Y, J)
    
    % MNA方程的变量矩阵一定是仿真
    % Y为m×m维矩阵，J为m×1维向量，v为m×1维向量
    
    % Yv = J
    %% 得到LU分解结果
    % Y = LU
    % 求出LU
    m = Y.rows;
    
%     [L,U,P] = LU_decompose(Y);
    [L,U,P] = sparse_LU_decompose(Y);
%     [L,U,P] = lu(Y);
    J = P*J;  % 需要乘行交换矩阵，因为LU分解的结果其实是LU=PY
    
    %% 前向替换
    % Lx = J
    % 求出x. [m,m] * [m,1] = [m,1]
    x = zeros(m,1);
    x(1,1) = J(1,1);
    for i = 2:m
        x(i,1) = J(i,1) - sum( L(i,1:i-1) .* x(1:i-1,1)' );
    end
    
    %% 后向替换
    % Uv = x
    % 求出v. [m,m] * [m,1] = [m,1]
    v = zeros(m,1);
    v(m,1) = x(m,1) / U(m,m);
    for i = m-1:-1:1
        v(i,1) = ( x(i,1) - sum( U(i,i+1:m) .* v(i+1:m,1)' ) ) / U(i,i);
    end    

end

