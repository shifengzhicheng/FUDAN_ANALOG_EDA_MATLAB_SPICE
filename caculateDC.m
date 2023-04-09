%% 基本的DC分析的过程 
function [x_0,x] = caculateDC(DCnetlist,Error,Max_epoch)
if isempty(Max_epoch)
    Max_epoch = 500;
end
% 默认的最大迭代次数是500
% 产生一个初始解
x_0=initial_solve(DCnetlist);

%         Standard_device = Generate_Standard_device(DCnetlist,x_0);
%         [A,x,b]=G_Matrix_Standard(Standard_device{:});
% 直接修改矩阵效率更高，留到后面实现
epoch = 1;

% 开始迭代
while epoch < Max_epoch
    %             A = update_matrix(A,x_0);
    % 产生标准线性网表
    Standard_device = Generate_Standard_device(DCnetlist,x_0);
    % 产生矩阵和解
    [A,x,b]=G_Matrix_Standard(Standard_device{:});
    % 产生新的解（使用牛顿迭代法或者任何其他的方法生成新的解，加快速度）
    new_x = Generate_new_x(A,x,b);
    % 迭代次数+1
    epoch = epoch + 1;
    % 两次迭代解的误差，收敛则成功，返回x_0
    if sum((new_x-x_0).*(new_x-x_0))<Error
        break; 
    else
    % 未收敛则继续迭代
        x_0 = new_x;
    end
end
end