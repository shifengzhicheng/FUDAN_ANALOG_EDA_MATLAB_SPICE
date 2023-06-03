%% 文件作者: 张润洲
% LU分解函数的稀疏矩阵版本，返回L、U、P(选出最大列主元的过程中记录的行交换方阵)
function [L,U,P] = sparse_LU_decompose(Y)

    %% 变量定义
    m = Y.rows;
    L = eye(m);  % 递推公式中i=j的情况后面不用再赋值
    P = eye(m);  % P记录了选择主元时候所进行的行变换

    % 根据递推公式，i<=j时计算U的值，i>j时计算L的值
    for i = 1:m
        % 每求出L的1行，相当于消去1个元素; 
        %% 在做1次消元之前，先做1次行交换，选出绝对值最大的列主元
        Y_ii = fetchElement(Y,i,i);
        maxValue = abs(Y_ii);
        maxRow = i;
        for t = i+1:m
            Y_ti = fetchElement(Y,t,i);
            if abs( Y_ti ) > maxValue
                maxValue = abs( Y_ti );
                maxRow = t;
            end
        end
        if(maxValue == 0)
            disp("value error");
        end
        if(maxRow~=i)
            P([maxRow;i], :) = P([i;maxRow], :);
            Y = exchangeRow(Y, i, maxRow);
            L([maxRow;i], 1:i-1) = L([i;maxRow], 1:i-1);
        end
        %% 只需要求L。U是Y最后化简完得到的结果
        Y_ii = fetchElement(Y,i,i);  % 由于做了行交换，稀疏矩阵值要重新读
        if Y_ii ~= 0
            for j = i+1:m
                L(j, i) = fetchElement(Y,j,i) / Y_ii;
            end
        else
            disp("zero error");
            L(i+1:m, i) = 0;
        end
        %% 更新Y矩阵
        for j = i:m
            Y_ij = fetchElement(Y,i,j);
            for k = i+1:m
                Y = renewElement(Y,k,j,-L(k,i)*Y_ij);
            end
        end
    end
    U = recover(Y);
end

