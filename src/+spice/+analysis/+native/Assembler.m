classdef Assembler < handle
    % ASSEMBLER Build one MNA system matrix incrementally.
    % This helper owns sparse triplet accumulation plus RHS injection so
    % device classes can stamp contributions without knowing matrix layout.
    properties (SetAccess = private)
        Size (1,1) double
        Rhs
    end

    properties (Access = private)
        RowIndices double = zeros(0, 1)
        ColIndices double = zeros(0, 1)
        Values = zeros(0, 1)
        EntryCount (1,1) double = 0
    end

    methods
        function obj = Assembler(matrixSize, initialCapacity)
            if nargin < 2
                initialCapacity = max(32, 8 * matrixSize);
            end
            obj.Size = matrixSize;
            obj.Rhs = zeros(matrixSize, 1);
            obj.reserve(initialCapacity);
        end

        function addConductance(obj, node1, node2, value)
            if value == 0
                return;
            end
            if node1 > 0
                obj.addEntry(node1, node1, value);
            end
            if node2 > 0
                obj.addEntry(node2, node2, value);
            end
            if node1 > 0 && node2 > 0
                obj.addEntry(node1, node2, -value);
                obj.addEntry(node2, node1, -value);
            end
        end

        function addCurrentSource(obj, node1, node2, value)
            if node1 > 0
                obj.Rhs(node1) = obj.Rhs(node1) - value;
            end
            if node2 > 0
                obj.Rhs(node2) = obj.Rhs(node2) + value;
            end
        end

        function addVccs(obj, outNode1, outNode2, controlNode1, controlNode2, value)
            if value == 0
                return;
            end
            if outNode1 > 0 && controlNode1 > 0
                obj.addEntry(outNode1, controlNode1, value);
            end
            if outNode1 > 0 && controlNode2 > 0
                obj.addEntry(outNode1, controlNode2, -value);
            end
            if outNode2 > 0 && controlNode1 > 0
                obj.addEntry(outNode2, controlNode1, -value);
            end
            if outNode2 > 0 && controlNode2 > 0
                obj.addEntry(outNode2, controlNode2, value);
            end
        end

        function addRhsCurrentInjection(obj, node1, node2, value)
            if node1 > 0
                obj.Rhs(node1) = obj.Rhs(node1) + value;
            end
            if node2 > 0
                obj.Rhs(node2) = obj.Rhs(node2) - value;
            end
        end

        function addBranchKcl(obj, node1, node2, branchIndex)
            if node1 > 0
                obj.addEntry(node1, branchIndex, 1);
            end
            if node2 > 0
                obj.addEntry(node2, branchIndex, -1);
            end
        end

        function addBranchEquation(obj, node1, node2, branchIndex, branchCoeff, rhsValue)
            if node1 > 0
                obj.addEntry(branchIndex, node1, 1);
            end
            if node2 > 0
                obj.addEntry(branchIndex, node2, -1);
            end
            if branchCoeff ~= 0
                obj.addEntry(branchIndex, branchIndex, -branchCoeff);
            end
            obj.Rhs(branchIndex) = obj.Rhs(branchIndex) + rhsValue;
        end

        function [matrix, rhs] = build(obj)
            usedEntries = 1:obj.EntryCount;
            matrix = sparse(obj.RowIndices(usedEntries), obj.ColIndices(usedEntries), obj.Values(usedEntries), obj.Size, obj.Size);
            rhs = obj.Rhs;
        end
    end

    methods (Access = private)
        function reserve(obj, capacity)
            capacity = max(0, ceil(double(capacity)));
            obj.RowIndices = zeros(capacity, 1);
            obj.ColIndices = zeros(capacity, 1);
            obj.Values = zeros(capacity, 1);
        end

        function addEntry(obj, rowIndex, colIndex, value)
            nextIndex = obj.EntryCount + 1;
            if nextIndex > numel(obj.Values)
                obj.grow();
            end
            obj.RowIndices(nextIndex, 1) = rowIndex;
            obj.ColIndices(nextIndex, 1) = colIndex;
            obj.Values(nextIndex, 1) = value;
            obj.EntryCount = nextIndex;
        end

        function grow(obj)
            oldCapacity = numel(obj.Values);
            newCapacity = max(32, max(1, oldCapacity) * 2);
            obj.RowIndices(newCapacity, 1) = 0;
            obj.ColIndices(newCapacity, 1) = 0;
            obj.Values(newCapacity, 1) = 0;
        end
    end
end
