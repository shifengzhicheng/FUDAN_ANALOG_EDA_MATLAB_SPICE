function sparcity(M,B)
[row,column]=size(M); % 获取矩阵M的行数row，列数column
fprintf('注意结算结果是基于对称矩阵情况下计算的\n')
%% 数据采用散居存储，考虑到矩阵对称性，只存储对角线和上三角元素
row_num=[]; % 用来存放非零元素的行号
column_num=[]; % 用来存放非零元素的列号
value=[]; % 用来存放非零元素的值
for i=1:row
    for j=i:column
        if(M(i,j)~=0) 
           value=[value M(i,j)];
           row_num=[row_num i];
           column_num=[column_num j];
        end
    end
end
M=[]; % 释放矩阵M占用的存储空间
% 三者组合成一个矩阵
% 第1行为非零元素值，第2行为非零元素行号，第3行为非零元素列号
Matrix=[value;row_num;column_num];
value=[];row_num=[];column_num=[]; % 释放内存
%% 因子表分解
for i=1:row
    % 输出行数=i的元素在row_num中的位置，y_r为列号
    [~,yr]=find(Matrix(2,:)==i); 
    c_yr=length(yr); % 得到yr数组的大小
    % 规格化计算
    if c_yr>=2
        for j=2:c_yr
            Matrix(1,yr(j))=Matrix(1,yr(j))/Matrix(1,yr(1));
        end
        % 自边的消去计算
        for j=2:c_yr
           % 寻找末端节点自边值的位置
           % 行号和列号相等的点即为末端节点自边值
           p=Matrix(3,yr(j)); % 得到列号
           [~,yp]=find(Matrix(2,:)==p);
           % 末端节点自边值的消去计算
           len_yp=length(yp);
           for b=1:len_yp
               if (Matrix(3,yp(b))==p)
                   Matrix(1,yp(b))=Matrix(1,yp(b))-Matrix(1,yr(j))^2*Matrix(1,yr(1));
               end
           end
        end
        % 互边的消去计算
        if c_yr>=3 % 末端节点在2个以上时，末端节点之间的互边才需要改变或者新增
            for j=2:c_yr
                for k=1:(c_yr-j)
                    % 依次取末端节点任意两条边的列号
                    p1=Matrix(3,yr(j)); 
                    p2=Matrix(3,yr(j+k)); 
                    % 保证边的方向都是编号小的指向编号大的
                    if (p1>=p2) 
                       temp=p1;
                       p1=p2;
                       p2=temp;
                    end
                    % 先查找M(p1,p2)是不是非零元素
                    % 若是非零元素，则直接在Matrix中修改值的大小
                    % 若不是非零元素，则需要新增非零元素在Matrix矩阵中
                    [~,yp1]=find(Matrix(2,:)==p1); % 找到行号为p1的所有非零元素
                    len_yp1=length(yp1); % 得到数组yp1的长度
                    flag=0; % 用来指示两个末端节点之间是否存在边
                    for a=1:len_yp1
                        if (Matrix(3,yp1(a))==p2) 
                           % 两个末端节点之间存在边，则进行修改
                           Matrix(1,yp1(a))=Matrix(1,yp1(a))-Matrix(1,yr(j))*Matrix(1,yr(j+k))*Matrix(1,yr(1));
                           flag=1; % 两个末端节点之间存在边
                           break
                        end
                    end
                    if (flag==0) % 两个末端节点之间不存在边，会新增边
                        temp2=0-Matrix(1,yr(j))*Matrix(1,yr(j+k))*Matrix(1,yr(1));
                        len=length(Matrix(1,:));
                        Matrix(1,len+1)=temp2;
                        Matrix(2,len+1)=p1;
                        Matrix(3,len+1)=p2;
                    end
                end
            end
        end
    end
end
% 得到因子分解表矩阵
D=eye(row);
U=eye(row);
L=eye(row);
temp1=[];
for i=1:length(Matrix(1,:))
    if (Matrix(2,i)==Matrix(3,i))
        temp1=[temp1 Matrix(1,i)];
    else
        U(Matrix(2,i),Matrix(3,i))=Matrix(1,i);
        L(Matrix(3,i),Matrix(2,i))=Matrix(1,i);
    end 
end
for i=1:row
    D(i,i)=temp1(i); 
end
% 对因子表结果进行显示
fprintf('D=');disp(D);
fprintf('U=');disp(U);
%% 前代计算
z=ones(row,1);
temp3=0;
for i=1:row
    for j=1:(i-1)
        [~,yj]=find(Matrix(2,:)==j); % 找到第j行的所有非零元素
        for k=1:length(yj)
            if (Matrix(3,yj(k))==i) % Matrix中存在坐标为(j,i)的非零元素，则进行计算，否则不计算
                temp3=temp3+Matrix(1,yj(k))*z(j,1); 
            end
        end
    end
    z(i,1)=B(i,1)-temp3;
    temp3=0;
end
%% 规格化计算
y=ones(row,1);
for i=1:row
    [~,yi]=find(Matrix(2,:)==i); % 找到第i行的所有非零元素
    for j=1:length(yi)
        if (Matrix(3,yi(j))==i) % 找到对角元元素
           y(i,1)=z(i,1)/Matrix(1,yi(j)); 
        end
    end
end
%% 回代计算
x=ones(row,1);
temp3=0;
for i=1:row
    j=row-i+1;
    for k=(j+1):row
        [~,yj]=find(Matrix(2,:)==j); % 找到第j行的所有非零元素
        for g=1:length(yj)
            if (Matrix(3,yj(g))==k)
                temp3=temp3+Matrix(1,yj(g))*x(k);
            end
        end
    end
    x(j,1)=y(j,1)-temp3;
    temp3=0;
end
fprintf('解x的结果为x=\n');disp(x);
end
