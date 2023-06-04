%% 文件作者: 张润洲
%% SpM.m
% 稀疏矩阵采用MCSR存储格式
% 在LU分解时采用Markowitz排序算法代替原先的列主元消去法
% SpM的修改函数一定要返回对象，否则无法成功修改

% 稀疏矩阵类SpM有5个属性
% 属性1: rows. 记录稀疏矩阵对应的一般存储格式中的行数
% 属性2: NNZ. 记录稀疏矩阵中的非零元素个数
% 属性3: RowLength. 1个长为rows的向量，存储每行非零元素的个数
% 属性4: Value. 1个长为NNZ的向量，存储非零元素值
% 属性5: ColIndex. 1个长为NNZ的向量，存储每行非零元素的列数，与Value中同行数据的索引段相同

% 稀疏矩阵类SpM有以下方法
% 方法1: obj = SpM(rownum).                                               SpM类的构造函数
% 方法2: obj = extend(obj,num).                                           SpM的存储空间拓展函数
% 方法3: obj = extendRows(obj,num).                                       SpM扩展若干行
% 方法4: obj = renewElement(obj,RowPos,ColPos,ElementValue)               addElement和modifyElement两个函数功能的合并
% 用的最多的是renewElement函数
% 方法5: obj = addElement(obj,RowPos,ColPos,ElementValue)                 SpM添加新元素的函数
% 方法6: obj = addRowCol(obj,RowPos,ColPos)                               SpM添加1行1列，rows加1. 一般是添加第1行第1列
% 方法7: obj = modifyElement(obj,RowPos,ColPos,ElementValue)              SpM修改存储信息. 在原有值基础上加变化量. 不添加新的非零元素
% 方法8: obj = changeElement(obj,RowPos,ColPos,ElementValue)              SpM修改存储信息. 直接传入新值. 不添加新的非零元素
% 方法9: obj = deleteElement(obj,RowPos,ColPos)                           SpM删除存储信息
% 方法10: obj = deleteRowCol(obj,RowPos,ColPos)                           SpM删除1行1列，rows减1. 一般是删除第1行第1列
% 方法11: obj = exchangeRow(obj,RowPos1,RowPos2)                          SpM交换两行数据
% 方法12: value = fetchElement(obj,RowPos,ColPos)                         SpM获得某位置的数据
% 方法13: A = recover(obj)                                                SpM恢复一般存储格式
% 方法14: displayInfo(obj)                                                SpM打印存储信息. debug用的函数

% 可考虑的优化:
% 1. 在自动开新空间的时候，考虑一次开更小的数值.
% △ 2. 写以下方法: 传入一个一般格式的矩阵，得到MCSR存储格式的稀疏矩阵 (实现方式: 只要遍历各元素，调用renewElement方法即可)

% 目前还没有解决或可能存在的bug
% 1. deleteElement用exist选择执行模式的时候有时无法生成1
% 2. renewElement用mode选择执行模式的时候有时无法生成0
% 3. 用稀疏矩阵格式的求解器跑AC分析网表时，结果应该是正确的，但是会在SpM类方法中报"SpM RowPos Error."
% 4. 用稀疏矩阵格式的求解器跑瞬态分析网表时，速度太慢了

classdef SpM
    properties
        rows
        NNZ
        RowLength
        Value
        ColIndex
    end
    methods
        %% 方法1: 构造函数，构造SpM类的实例
        function obj = SpM(rownum)  % 初始的rownum等于节点数量
            obj.rows = rownum;  % 记录矩阵的行数。后面在加入独立电压源等器件时需要扩展
            obj.NNZ = 0;  
            obj.RowLength = zeros(rownum,1);  % 长度与行数相等的数组
            % 一般稀疏矩阵的非零项数量总归比行数要多...先用小数值初始化Value和ColIndex向量
            obj.Value = zeros(rownum,1);  % 有效长度与NNZ相等的数组
            obj.ColIndex = zeros(rownum,1);  % 有效长度与NNZ相等的数组
        end
        
        %% 方法2: SpM的存储空间拓展函数. 建议一次扩展rownum的量，否则反复调用extend()函数很耗时
        function obj = extend(obj,num)  % num建议采用rownum
            if (nargin<2)
                num = obj.rows;
            end
            obj.Value = [obj.Value; zeros(num,1)];
            obj.ColIndex = [obj.ColIndex; zeros(num,1)];
        end
        
        %% 方法3: SpM扩展若干行 (加入独立电压源等情况)
        function obj = extendRows(obj,num)
            if (nargin<2)
                num = 1;
            end
            obj.rows = obj.rows + num;
            obj.RowLength = [obj.RowLength; zeros(num,1)];
        end
        
        %% 方法4: addElement和modifyElement两个函数功能的合并
        % 用的最多的是这个函数
        function obj = renewElement(obj,RowPos,ColPos,ElementValue)
            % 如果ElementValue等于0，不用操作
            if ElementValue == 0
                return;
            end
            % 判断是否要拓展行数
            maxIndex = max(RowPos,ColPos);
            if maxIndex > obj.rows
                obj = extendRows(obj,maxIndex-obj.rows);
            end
            % 判断是否需要开新的空间
            length = size(obj.Value,1);
            if (length == obj.NNZ)
                obj = extend(obj);
                length = size(obj.Value,1);
            end
            % 先找到obj.Value和obj.ColIndex中要插入ElementValue的位置
            InsertPosMin = sum( obj.RowLength(1:RowPos-1) );  % 第RowPos行在Value和ColIndex中第1个信息的索引的前1个位置
            InsertPos = InsertPosMin + 1;  % 不是最终的插入位置，还需要确定ColPos在第RowPos行已有非零元素中的位置
            mode = 1;  % 先添加再修改，所以mode默认值应为1
            
            for i = InsertPosMin+1 : InsertPosMin+obj.RowLength(RowPos)
                if ColPos > obj.ColIndex(i)
                    InsertPos = InsertPos + 1;
                elseif ColPos < obj.ColIndex(i)  % 该坐标之前没有加入到稀疏矩阵的存储信息中，添加新元素 (addElement)
                    mode = 1;
                    break;
                else  % 该坐标之前已是非零值，修改值 (modifyElement)
                    mode = 0;
                    break;
                end
            end
            switch(mode)
                case 0
                    % 修改元素值
                    obj.Value(InsertPos) = obj.Value(InsertPos) + ElementValue;
                    if obj.Value(InsertPos) == 0
                        obj = deleteElement(obj, RowPos, ColPos);
                    end
                case 1
                    % 插入新值
                    obj.NNZ = obj.NNZ + 1;
                    obj.RowLength(RowPos) = obj.RowLength(RowPos) + 1;
                    obj.Value = [obj.Value(1:InsertPos-1); ElementValue; obj.Value(InsertPos:length)];
                    obj.ColIndex = [obj.ColIndex(1:InsertPos-1); ColPos; obj.ColIndex(InsertPos:length)];                    
            end
            
%             disp("<SpM> debug renewElement:\n\n");
%             displayInfo(obj);
        
        end
        
        %% 方法5: SpM添加新元素的函数
        function obj = addElement(obj,RowPos,ColPos,ElementValue)
            % 如果ElementValue等于0，不用操作
            if ElementValue == 0
                return;
            end
            % 判断是否需要开新的空间
            length = size(obj.Value,1);
            if (length == obj.NNZ)
                obj = extend(obj);
                length = size(obj.Value,1);
            end
            % 判断是否要拓展行数
            maxIndex = max(RowPos,ColPos);
            if maxIndex > obj.rows
                obj = extendRows(obj,maxIndex-obj.rows);
            end
            % 先找到obj.Value和obj.ColIndex中要插入ElementValue的位置
            InsertPosMin = sum( obj.RowLength(1:RowPos-1) );  % 第RowPos行在Value和ColIndex中第1个信息的索引的前1个位置
            InsertPos = InsertPosMin + 1;  % 不是最终的插入位置，还需要确定ColPos在第RowPos行已有非零元素中的位置
            for i = InsertPosMin+1 : InsertPosMin+obj.RowLength(RowPos)
                if ColPos > obj.ColIndex(i)  % 不可能等于
                    InsertPos = InsertPos + 1;
                elseif ColPos < obj.ColIndex(i)
                    break;
                end
            end
            % 插入新值
            obj.NNZ = obj.NNZ + 1;
            obj.RowLength(RowPos) = obj.RowLength(RowPos) + 1;
            obj.Value = [obj.Value(1:InsertPos-1); ElementValue; obj.Value(InsertPos:length)];
            obj.ColIndex = [obj.ColIndex(1:InsertPos-1); ColPos; obj.ColIndex(InsertPos:length)];
        end
        
        %% 方法6: SpM修改存储信息. 在原有值基础上加变化量. 不添加新的非零元素
        function obj = modifyElement(obj,RowPos,ColPos,ElementValue)
            % 如果ElementValue等于0，不用操作
            if ElementValue == 0
                return;
            end
            % 先找到obj.Value和obj.ColIndex中要修改的元素位置
            InsertPosMin = sum( obj.RowLength(1:RowPos-1) );  % 第RowPos行在Value和ColIndex中第1个信息的索引的前1个位置
            InsertPos = InsertPosMin + 1;  % 不是最终的插入位置，还需要确定ColPos在第RowPos行已有非零元素中的位置
            for i = InsertPosMin+1 : InsertPosMin+obj.RowLength(RowPos)
                if ColPos > obj.ColIndex(i)
                    InsertPos = InsertPos + 1;
                elseif ColPos == obj.ColIndex(i)  % 找到ColPos的位置
                    break;
                end
            end
            % 修改元素值
            obj.Value(InsertPos) = obj.Value(InsertPos) + ElementValue;
            if obj.Value(InsertPos) == 0
                obj = deleteElement(obj, RowPos, ColPos);
            end
        end
        
        %% 方法7: SpM修改存储信息. 直接传入新值. 不添加新的非零元素
        % 估计用的比较少，一般直接传入新值的坐标位置还没有加入到SpM对象里，调用的是addElement函数
        function obj = changeElement(obj,RowPos,ColPos,ElementValue)
            % 如果ElementValue等于0，不用操作
            if ElementValue == 0
                obj = deleteElement(obj, RowPos, ColPos);
            end
            % 先找到obj.Value和obj.ColIndex中要修改的元素位置
            InsertPosMin = sum( obj.RowLength(1:RowPos-1) );  % 第RowPos行在Value和ColIndex中第1个信息的索引的前1个位置
            InsertPos = InsertPosMin + 1;  % 不是最终的插入位置，还需要确定ColPos在第RowPos行已有非零元素中的位置
            for i = InsertPosMin+1: InsertPosMin+obj.RowLength(RowPos)
                if ColPos > obj.ColIndex(i)
                    InsertPos = InsertPos + 1;
                elseif ColPos == obj.ColIndex(i)  % 找到ColPos的位置
                    break;
                end
            end
            % 修改元素值
            obj.Value(InsertPos) = ElementValue;
        end
           
        %% 方法8: SpM删除信息
        function obj = deleteElement(obj,RowPos,ColPos)
            % 如果要删除的范围不在已存储的行列范围内, pass
            maxIndex = max(RowPos,ColPos);
            if maxIndex > obj.rows
                disp("SpM RowPos Error.");
                return;
            end
            % 如果要删除的节点值为0，亦即SpM没有存储，pass
            DeletePosMin = sum( obj.RowLength(1:RowPos-1) );  % 第RowPos行在Value和ColIndex中第1个信息的索引的前1个位置
            DeletePos = DeletePosMin + 1;  % 不是最终的插入位置，还需要确定ColPos在第RowPos行已有非零元素中的位置
            exist = 0;  % 默认不做删除操作
            for i = DeletePosMin+1 : DeletePosMin+obj.RowLength(RowPos)
                if ColPos > obj.ColIndex(i)
                    DeletePos = DeletePos + 1;
                elseif ColPos == obj.ColIndex(i)  % 找到ColPos的位置
                    exist = 1;
                    break;
                else
                    exist = 0;
                end
            end
            switch(exist)
                case 0
                    return;
                case 1
                    % 将节点从SpM的存储信息中删除
                    obj.NNZ = obj.NNZ - 1;
                    obj.RowLength(RowPos) = obj.RowLength(RowPos) - 1;
                    length = size(obj.Value,1);
                    obj.Value = [obj.Value(1:DeletePos-1); obj.Value(DeletePos+1:length)];
                    obj.ColIndex = [obj.ColIndex(1:DeletePos-1); obj.ColIndex(DeletePos+1:length)];
            end
        end

        %% 方法9: SpM删除1行1列，rows减1. 一般是删除第1行第1列
        function obj = deleteRowCol(obj,RowPos,ColPos)
            % 如果要删除的范围不在已存储的行列范围内, pass
            maxIndex = max(RowPos,ColPos);
            if maxIndex > obj.rows
                disp("SpM RowPos Error.");
                return;
            end
            % 先删行
            if (RowPos ~= 1) && (RowPos ~= obj.NNZ)
                obj.ColIndex = [obj.ColIndex(1: sum(obj.RowLength(1:RowPos-1)) ); obj.ColIndex(sum(obj.RowLength(1:RowPos))+1:obj.NNZ); zeros(obj.RowLength(RowPos), 1)];
                obj.Value = [obj.Value(1: sum(obj.RowLength(1:RowPos-1)) ); zeros(obj.RowLength(RowPos), 1); obj.Value(sum(obj.RowLength(1:RowPos))+1:obj.NNZ); zeros(obj.RowLength(RowPos), 1)];
                obj.NNZ = obj.NNZ - obj.RowLength(RowPos);  
                obj.RowLength = [obj.RowLength(1:RowPos-1); obj.Value(RowPos+1:obj.rows)];
            elseif RowPos == 1
                obj.ColIndex = [obj.ColIndex( obj.RowLength(1)+1 : obj.NNZ); zeros(obj.RowLength(1), 1)];
                obj.Value = [obj.Value( obj.RowLength(1)+1 : obj.NNZ); zeros(obj.RowLength(1), 1)];
                obj.NNZ = obj.NNZ - obj.RowLength(1);  
                obj.RowLength = obj.RowLength(2:obj.rows);
            else
                obj.ColIndex = [obj.ColIndex(1: sum(obj.RowLength(1:obj.rows-1)) ); zeros(obj.RowLength(RowPos), 1)];
                obj.Value = [obj.Value(1: sum(obj.RowLength(1:RowPos-1)) ); zeros(obj.RowLength(RowPos), 1)];
                obj.NNZ = obj.NNZ - obj.RowLength(RowPos);  
                obj.RowLength = obj.RowLength(1:RowPos-1);
            end
            obj.rows = obj.rows - 1;
                      
            % 再删列
            new_ColIndex = obj.ColIndex;
            new_Value = obj.Value;
            new_RowLength = obj.RowLength;
            length = size(obj.ColIndex,1);
            col_ptr = 1;
            row_ptr1 = 1;
            row_ptr2 = obj.RowLength(1);
            for i = row_ptr1 : row_ptr2
                if obj.ColIndex(i) == ColPos
                    new_RowLength(1) = new_RowLength(1) - 1;
                    obj.NNZ = obj.NNZ - 1;
                    if (i ~= 1) && (i ~= length) 
                        new_ColIndex = [new_ColIndex(1:col_ptr-1); new_ColIndex(col_ptr+1:length); zeros(1,1)];
                        new_Value = [new_Value(1:col_ptr-1); new_Value(col_ptr+1:length); zeros(1,1)];
                    elseif i == 1
                        new_ColIndex = [new_ColIndex(2:length); zeros(1,1)];
                        new_Value = [new_Value(2:length); zeros(1,1)];
                    else
                        new_ColIndex = [new_ColIndex(1:length-1); zeros(1,1)];
                        new_Value = [new_Value(1:length-1); zeros(1,1)];
                    end
                elseif obj.ColIndex(i) > ColPos
                    new_ColIndex(col_ptr) = new_ColIndex(col_ptr) - 1;
                    col_ptr = col_ptr + 1;
                end
            end
            rownum = obj.rows;
            for j = 1:rownum-1
                row_ptr1 = row_ptr1 + obj.RowLength(j);
                row_ptr2 = row_ptr2 + obj.RowLength(j+1);
                for i = row_ptr1 : row_ptr2
                    if obj.ColIndex(i) == ColPos
                        new_RowLength(j+1) = new_RowLength(j+1) - 1;
                        obj.NNZ = obj.NNZ - 1;
                        if (i ~= 1) && (i ~= length) 
                            new_ColIndex = [new_ColIndex(1:col_ptr-1); new_ColIndex(col_ptr+1:length); zeros(1,1)];
                            new_Value = [new_Value(1:col_ptr-1); new_Value(col_ptr+1:length); zeros(1,1)];
                        elseif i == 1
                            new_ColIndex = [new_ColIndex(2:length); zeros(1,1)];
                            new_Value = [new_Value(2:length); zeros(1,1)];
                        else
                            new_ColIndex = [new_ColIndex(1:length-1); zeros(1,1)];
                            new_Value = [new_Value(1:length-1); zeros(1,1)];
                        end
                    elseif obj.ColIndex(i) > ColPos
                        new_ColIndex(col_ptr) = new_ColIndex(col_ptr) - 1;
                        col_ptr = col_ptr + 1;
                    end
                end                
            end

            obj.RowLength = new_RowLength;
            obj.ColIndex = new_ColIndex;
            obj.Value = new_Value;
        end
        
        %% 方法10: SpM添加1行1列，rows加1. 一般是添加第1行第1列
        function obj = addRowCol(obj,RowPos,ColPos)
            % 先加行
            if RowPos == 1
                obj.RowLength = [zeros(1,1); obj.RowLength];
                obj.rows = obj.rows + 1;
            elseif RowPos >= obj.rows + 1
                obj.RowLength = [obj.RowLength; zeros(RowPos-obj.rows, 1)];
                obj.rows = RowPos;
            elseif (RowPos >= 2) && (RowPos <= obj.rows)
                obj.RowLength = [obj.RowLength(1:RowPos-1); zeros(1,1); obj.RowLength(RowPos:obj.rows)];
                obj.rows = obj.rows + 1;
            end
            % 再加列
            length = size(obj.ColIndex,1);
            for i = 1:length
                if obj.ColIndex(i) >= ColPos
                    obj.ColIndex(i) = obj.ColIndex(i) + 1;
                end
            end
        end
            
        %% 方法11: SpM交换两行数据。尽量按照 RowPos1 < RowPos2 输入
        function obj = exchangeRow(obj,RowPos1,RowPos2)
            if (RowPos1 < 1 && RowPos1 > obj.rows) || (RowPos2 < 1 && RowPos2 > obj.rows)
                disp("SpM RowPos Error.");
                return;
            end
            if RowPos1 == RowPos2
                return;
            end
            if RowPos1 > RowPos2
                tmp = RowPos1;
                RowPos1 = RowPos2;
                RowPos2 = tmp;
            end
            % 换 ColIndex 和 Value
            % ptr1_row1 到 ptr2_row2 依次递增
            ptr1_row1 = sum(obj.RowLength(1:RowPos1-1)) + 1;
            ptr1_row2 = sum(obj.RowLength(1:RowPos1));
            ptr2_row1 = sum(obj.RowLength(1:RowPos2-1)) + 1;
            ptr2_row2 = sum(obj.RowLength(1:RowPos2));
            obj.ColIndex = [obj.ColIndex(1:ptr1_row1-1); obj.ColIndex(ptr2_row1:ptr2_row2); ...
                obj.ColIndex(ptr1_row2+1:ptr2_row1-1); obj.ColIndex(ptr1_row1:ptr1_row2); ...
                obj.ColIndex(ptr2_row2+1:obj.NNZ)];
            obj.Value = [obj.Value(1:ptr1_row1-1); obj.Value(ptr2_row1:ptr2_row2); ...
                obj.Value(ptr1_row2+1:ptr2_row1-1); obj.Value(ptr1_row1:ptr1_row2); ...
                obj.Value(ptr2_row2+1:obj.NNZ)];
            % 换 RowLength
            obj.RowLength([RowPos1; RowPos2]) = obj.RowLength([RowPos2; RowPos1]);
        end
          
        %% 方法12: SpM获得某位置的值
        function value = fetchElement(obj,RowPos,ColPos)
            % 判断要获得值的位置是否在SpM范围内
            if (RowPos < 1) || (RowPos > obj.rows) || (ColPos < 1) || (ColPos > obj.rows)
                return;
            end
            % 先找到RowLength中第RowPos行的信息
            ptr1 = sum( obj.RowLength(1:RowPos-1) ) + 1;
            ptr2 = sum( obj.RowLength(1:RowPos) );
            % 再找到ColIndex和Value中相应的信息
            found = 0;
            
%             disp("<SpM> debug fetchElement:\n\n");
%             disp( size(obj.ColIndex,1) );
%             disp(ptr1);
%             disp(ptr2);
%             disp(RowPos);
%             disp(ColPos);
            
            for i = ptr1:ptr2
                if obj.ColIndex(i) == ColPos
                    value = obj.Value(i);
                    found = 1;
                    break;
                end
            end
            if found == 0
                value = 0;
            end
        end
        
        %% 方法13: SpM恢复一般存储格式
        function A = recover(obj)
            m = obj.rows;
            A = zeros(m,m);
            ptr1 = 1;  % ColIndex中每行信息的起始位置
            ptr2 = obj.RowLength(1);  % ColIndex中每行信息的终止位置
            % 第1行的非零元素单独恢复
            for j = ptr1:ptr2
                A(1,obj.ColIndex(j)) = obj.Value(j);
            end
            % 其他行的非零元素恢复
            for i = 1:m-1
                ptr1 = ptr1 + obj.RowLength(i);
                ptr2 = ptr2 + obj.RowLength(i+1);
                for j = ptr1:ptr2
                    if obj.ColIndex(j) == 0
                        break;
                    end
                    A(i+1,obj.ColIndex(j)) = obj.Value(j);
                end
            end
        end
            
        %% 方法14: SpM打印存储信息. debug用的函数
        function displayInfo(obj)
            disp("SpM infomation:\n\n");
            disp(obj.rows);
            disp(obj.NNZ);
            disp(obj.RowLength);
            disp(obj.Value);
            disp(obj.ColIndex);
        end
    end
end
