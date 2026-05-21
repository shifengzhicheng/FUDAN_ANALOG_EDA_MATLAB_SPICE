classdef DynamicTransientTrace < handle
    % DYNAMICTRANSIENTTRACE Preallocated storage for adaptive transient runs.

    properties (Access = private)
        TimeValues
        SolutionMatrix
        StepIterations
        StepConverged
        StepModes
        StepSizes
        LteValues
        VoltageErrorNorms
        CurrentErrorNorms
        PointCount
        AttemptCount
    end

    methods
        function obj = DynamicTransientTrace(initialSolution, initialCapacity)
            if nargin < 2 || isempty(initialCapacity)
                initialCapacity = 128;
            end
            initialCapacity = max(2, ceil(double(initialCapacity)));
            variableCount = numel(initialSolution);

            obj.TimeValues = zeros(1, initialCapacity);
            obj.TimeValues(1) = 0;
            obj.SolutionMatrix = zeros(variableCount, initialCapacity);
            obj.SolutionMatrix(:, 1) = initialSolution;
            obj.StepIterations = zeros(initialCapacity, 1);
            obj.StepConverged = true(initialCapacity, 1);
            obj.StepModes = strings(initialCapacity, 1);
            obj.StepSizes = zeros(initialCapacity, 1);
            obj.LteValues = zeros(initialCapacity, 1);
            obj.VoltageErrorNorms = zeros(initialCapacity, 1);
            obj.CurrentErrorNorms = zeros(initialCapacity, 1);
            obj.PointCount = 1;
            obj.AttemptCount = 0;
        end

        function recordAttempt(obj, lteMetric, voltageErrorNorm, currentErrorNorm)
            obj.ensureAttemptCapacity(obj.AttemptCount + 1);
            obj.AttemptCount = obj.AttemptCount + 1;
            obj.LteValues(obj.AttemptCount, 1) = lteMetric;
            obj.VoltageErrorNorms(obj.AttemptCount, 1) = voltageErrorNorm;
            obj.CurrentErrorNorms(obj.AttemptCount, 1) = currentErrorNorm;
        end

        function appendAcceptedStep(obj, timePoint, solution, iterations, converged, mode, stepSize)
            obj.ensurePointCapacity(obj.PointCount + 1);
            obj.PointCount = obj.PointCount + 1;
            stepIndex = obj.PointCount - 1;
            obj.TimeValues(1, obj.PointCount) = timePoint;
            obj.SolutionMatrix(:, obj.PointCount) = solution;
            obj.StepIterations(stepIndex, 1) = iterations;
            obj.StepConverged(stepIndex, 1) = converged;
            obj.StepModes(stepIndex, 1) = string(mode);
            obj.StepSizes(stepIndex, 1) = stepSize;
        end

        function values = snapshot(obj)
            stepCount = obj.PointCount - 1;
            values = struct( ...
                'timeValues', obj.TimeValues(1, 1:obj.PointCount), ...
                'solutionMatrix', obj.SolutionMatrix(:, 1:obj.PointCount), ...
                'stepIterations', obj.StepIterations(1:stepCount, 1), ...
                'stepConverged', obj.StepConverged(1:stepCount, 1), ...
                'stepModes', obj.StepModes(1:stepCount, 1), ...
                'stepSizes', obj.StepSizes(1:stepCount, 1), ...
                'lteValues', obj.LteValues(1:obj.AttemptCount, 1), ...
                'voltageErrorNorms', obj.VoltageErrorNorms(1:obj.AttemptCount, 1), ...
                'currentErrorNorms', obj.CurrentErrorNorms(1:obj.AttemptCount, 1));
        end
    end

    methods (Access = private)
        function ensurePointCapacity(obj, requiredCapacity)
            currentCapacity = size(obj.SolutionMatrix, 2);
            if requiredCapacity <= currentCapacity
                return;
            end
            newCapacity = max(requiredCapacity, 2 * currentCapacity);
            obj.TimeValues(1, newCapacity) = 0;
            obj.SolutionMatrix(:, newCapacity) = 0;
            obj.StepIterations(newCapacity, 1) = 0;
            obj.StepConverged(newCapacity, 1) = true;
            obj.StepModes(newCapacity, 1) = "";
            obj.StepSizes(newCapacity, 1) = 0;
        end

        function ensureAttemptCapacity(obj, requiredCapacity)
            currentCapacity = numel(obj.LteValues);
            if requiredCapacity <= currentCapacity
                return;
            end
            newCapacity = max(requiredCapacity, 2 * currentCapacity);
            obj.LteValues(newCapacity, 1) = 0;
            obj.VoltageErrorNorms(newCapacity, 1) = 0;
            obj.CurrentErrorNorms(newCapacity, 1) = 0;
        end
    end
end
