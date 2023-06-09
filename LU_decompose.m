%% 文件作者: 张润洲
% LU分解函数，返回L、U、P(选出最大列主元的过程中记录的行交换方阵)
% 矩阵Y是m×n维矩阵; L是m×m维下三角矩阵，主对角元素为1; U是m×n维上三角矩阵; P是m维方阵
% 备注: 加入P前，想写的是能对一般矩阵(非方阵)做处理的LU分解，但后面看到MNA方程的变量值矩阵都是方阵，所以加入P后就按照方阵的维度来处理了
function [L,U,P] = LU_decompose(Y)

    %% 变量定义
    [m,n] = size(Y);
    if (m~=n)
        disp("<LU_decompose> Dimension Error");
        return
    end
    L = eye(m);  % 递推公式中i=j的情况后面不用再赋值
    P = eye(m);  % P记录了选择主元时候所进行的行变换

    % 根据递推公式，i<=j时计算U的值，i>j时计算L的值
    for i = 1:m
        % 每求出L的1行，相当于消去1个元素; 
        %% 在做1次消元之前，先做1次行交换，选出绝对值最大的列主元
        maxValue = abs(Y(i,i));
        maxRow = i;
        for t = i+1:m
            if abs(Y(t,i)) > maxValue
                maxValue = abs(Y(t,i));
                maxRow = t;
            end
        end
        if(maxValue == 0)
            disp("value error");
        end
        if(maxRow~=i)
            P([maxRow;i], :) = P([i;maxRow], :);
            Y([maxRow;i], :) = Y([i;maxRow], :);
            L([maxRow;i], 1:i-1) = L([i;maxRow], 1:i-1);
        end
        %% 只需要求L。U是Y最后化简完得到的结果
        if Y(i,i) ~= 0
            L(i+1:m, i) = Y(i+1:m, i) / Y(i,i);
        else
            disp("zero error");
            L(i+1:m, i) = 0;
        end
        %% 更新Y矩阵
        for j = i:m
            Y(i+1:m, j) = Y(i+1:m, j) - L(i+1:m, i) * Y(i,j);
        end
    end
    U = Y;

end

