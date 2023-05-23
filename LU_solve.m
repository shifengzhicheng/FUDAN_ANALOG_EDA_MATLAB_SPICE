function [v] = LU_solve(Y, J)
    
    % MNA方程的变量矩阵一定是仿真
    % Y为m×m维矩阵，J为m×1维向量，v为m×1维向量
    
    % Yv = J
    %% 得到LU分解结果
    % Y = LU
    % 求出LU
    [m,n] = size(Y);
%     if (m ~= n)
%         disp("Dimension Error.");
%         return
%     end
    [L,U,P] = LU_decompose(Y);
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


% function x=LU_solve(A,b)
% %定义列选主元LU分解
% [n,n2]=size(A);
% n3=length(b);
% if n~=n2||n~=n3 %判断输入的合法性
%     error('wrong input!');
% end
% x=ones(n,1);%初始化解向量
% for k=1:n-1
%     %选出列主元
%     p=k;p_max=abs(A(k,k));
%     for i=k+1:n
%         if p_max<abs(A(i,k))
%             p_max=abs(A(i,k));
%             p=i;
%         end
%     end
%     %据选出的列主元进行换行
%     if p>k
%         for i=k:n
%            t=A(k,i);
%             A(k,i)=A(p,i);
%             A(p,i)=t;
%         end
%         t1=b(k);
%         b(k)=b(p);
%         b(p)=t1;
%     end
%     %对矩阵进行LU分解
%     if A(k,k)==0
%         break;
%     end
%     for j=k+1:n
%         m=A(j,k)/A(k,k);
%         for i=k+1:n
%             A(j,i)=A(j,i)-m*A(k,i);
%         end
%         b(j)=b(j)-m*b(k);
%     end
% end
% %回代法解方程组
% x(n)=b(n)/A(n,n);
% for k=n-1:-1:1
%     z=0;
%     for i=k+1:n
%         z=z+x(i)*A(k,i);
%     end
%     x(k)=(b(k)-z)/A(k,k);
% end
% end