classdef OperatingPointSolver < handle
    % OPERATINGPOINTSOLVER Unified Newton solver for native nonlinear analyses.
    % The solver assembles device-linearized MNA systems, applies damping
    % and gmin stabilization, and returns a converged operating point plus
    % per-device linearization states reused by AC, DC sweep, and transient.
    properties (SetAccess = private)
        NativeCircuit
        Options struct
        MaxIterations (1,1) double = 200
        Gmin (1,1) double = 1e-9
        VoltageStepLimit (1,1) double = 1.0
        CurrentStepLimit (1,1) double = 0.5
    end

    methods
        function obj = OperatingPointSolver(nativeCircuit, options)
            obj.NativeCircuit = nativeCircuit;
            obj.Options = options;
            if obj.hasNonlinearDevices()
                obj.Gmin = max(1e-12, min(1e-9, options.ErrorTolerance * 1e-3));
            else
                obj.Gmin = 0;
            end
        end

        function [solution, context, stats] = solve(obj, context, initialGuess)
            if nargin < 3 || isempty(initialGuess)
                initialGuess = obj.buildInitialGuess(context);
            end

            guess = initialGuess(:);
            matrixSize = obj.NativeCircuit.matrixSize();
            if isempty(guess)
                guess = zeros(matrixSize, 1);
            end
            if numel(guess) ~= matrixSize
                guess = zeros(matrixSize, 1);
            end
            guess = obj.NativeCircuit.clampNodeVoltages(guess);

            for iteration = 1:obj.MaxIterations
                iterationContext = context.copy();
                iterationContext.OperatingPointSolution = guess;
                [matrix, rhs, iterationContext] = obj.assembleLinearized(iterationContext, guess);
                candidate = spice.solver.solveLinearSystem(matrix, rhs);
                if any(isnan(candidate)) || any(isinf(candidate))
                    error('spice:analysis:native:NonlinearDiverged', 'Native Newton iteration diverged.');
                end
                nextGuess = obj.applyDamping(guess, candidate);
                if obj.isConverged(guess, nextGuess)
                    context = obj.refreshDeviceStates(iterationContext, nextGuess);
                    context.OperatingPointSolution = nextGuess;
                    solution = nextGuess;
                    stats = struct('iterations', iteration, 'converged', true);
                    return;
                end
                guess = nextGuess;
            end

            error('spice:analysis:native:NonlinearNotConverged', ...
                'Native Newton solver failed to converge after %d iterations.', obj.MaxIterations);
        end

        function guess = buildInitialGuess(obj, context)
            analysisKind = obj.linearizedAnalysisType(context.AnalysisType);
            obj.NativeCircuit.configureAnalysis(analysisKind, 'TransientMethod', obj.Options.TransientMethod);
            assembler = obj.makeAssembler();
            obj.addGminShunts(assembler);
            for idx = 1:numel(obj.NativeCircuit.Circuit.Elements)
                obj.NativeCircuit.Circuit.Elements{idx}.initialGuessContribution(assembler, obj.NativeCircuit, context, obj);
            end
            [matrix, rhs] = assembler.build();
            try
                guess = spice.solver.solveLinearSystem(matrix, rhs);
            catch
                guess = zeros(obj.NativeCircuit.matrixSize(), 1);
            end
            guess = obj.NativeCircuit.clampNodeVoltages(guess);
        end

        function [matrix, rhs, context] = assembleLinearized(obj, context, guess)
            analysisKind = obj.linearizedAnalysisType(context.AnalysisType);
            obj.NativeCircuit.configureAnalysis(analysisKind, 'TransientMethod', obj.Options.TransientMethod);
            assembler = obj.makeAssembler();
            obj.addGminShunts(assembler);
            for idx = 1:numel(obj.NativeCircuit.Circuit.Elements)
                device = obj.NativeCircuit.Circuit.Elements{idx};
                state = device.evaluateOperatingPoint(obj.NativeCircuit, guess, context);
                context.setDeviceState(device.Name, state);
                switch context.AnalysisType
                    case {"dc", "dcsweep"}
                        device.stampDcLinearized(assembler, obj.NativeCircuit, state, context);
                    case "ac"
                        device.stampAcLinearized(assembler, obj.NativeCircuit, state, context);
                    case "trans"
                        device.stampTransientLinearized(assembler, obj.NativeCircuit, state, context);
                    otherwise
                        error('spice:analysis:native:UnsupportedAnalysisType', ...
                            'Unsupported native analysis type %s.', context.AnalysisType);
                end
            end
            [matrix, rhs] = assembler.build();
        end
    end

    methods (Access = private)
        function assembler = makeAssembler(obj)
            matrixSize = obj.NativeCircuit.matrixSize();
            elementCount = obj.NativeCircuit.Circuit.elementCount();
            estimatedEntryCount = numel(obj.NativeCircuit.NodeIds) + 16 * elementCount + 8 * matrixSize;
            assembler = spice.analysis.native.Assembler(matrixSize, estimatedEntryCount);
        end

        function tf = hasNonlinearDevices(obj)
            tf = false;
            for idx = 1:numel(obj.NativeCircuit.Circuit.Elements)
                device = obj.NativeCircuit.Circuit.Elements{idx};
                if isa(device, 'spice.model.Mosfet') || isa(device, 'spice.model.Diode') || isa(device, 'spice.model.Bjt')
                    tf = true;
                    return;
                end
            end
        end

        function context = refreshDeviceStates(obj, context, solution)
            refreshed = context.copy();
            refreshed.OperatingPointSolution = solution;
            refreshed.DeviceStates = struct();
            for idx = 1:numel(obj.NativeCircuit.Circuit.Elements)
                device = obj.NativeCircuit.Circuit.Elements{idx};
                refreshed.setDeviceState(device.Name, device.evaluateOperatingPoint(obj.NativeCircuit, solution, refreshed));
            end
            context = refreshed;
        end

        function addGminShunts(obj, assembler)
            if obj.Gmin == 0
                return;
            end
            for idx = 1:numel(obj.NativeCircuit.NodeIds)
                assembler.addConductance(idx, 0, obj.Gmin);
            end
        end

        function tf = isConverged(obj, previousSolution, nextSolution)
            delta = nextSolution - previousSolution;
            nodeCount = numel(obj.NativeCircuit.NodeIds);
            voltageDelta = delta(1:nodeCount);
            currentDelta = delta(nodeCount + 1:end);

            referenceVoltage = 0;
            if nodeCount > 0
                referenceVoltage = norm(nextSolution(1:nodeCount), inf);
            end
            voltageTol = max(obj.Options.ErrorTolerance, obj.Options.ErrorTolerance * max(1, referenceVoltage));
            if isempty(currentDelta)
                currentTol = voltageTol;
            else
                referenceCurrent = norm(nextSolution(nodeCount + 1:end), inf);
                currentTol = max(obj.Options.ErrorTolerance, obj.Options.ErrorTolerance * max(1, referenceCurrent));
            end
            tf = norm(voltageDelta, inf) <= voltageTol && (isempty(currentDelta) || norm(currentDelta, inf) <= currentTol);
        end

        function nextGuess = applyDamping(obj, previousSolution, candidateSolution)
            delta = candidateSolution - previousSolution;
            nodeCount = numel(obj.NativeCircuit.NodeIds);
            damping = 1;
            if nodeCount > 0
                nodeDelta = max(abs(delta(1:nodeCount)));
                if nodeDelta > obj.VoltageStepLimit
                    damping = min(damping, obj.VoltageStepLimit / nodeDelta);
                end
            end
            if numel(delta) > nodeCount
                branchDelta = max(abs(delta(nodeCount + 1:end)));
                if branchDelta > obj.CurrentStepLimit
                    damping = min(damping, obj.CurrentStepLimit / branchDelta);
                end
            end
            damping = max(min(damping, 1), 0.02);
            nextGuess = previousSolution + damping * delta;
            nextGuess = obj.NativeCircuit.clampNodeVoltages(nextGuess);
        end

        function analysisKind = linearizedAnalysisType(~, analysisType)
            if string(analysisType) == "dcsweep"
                analysisKind = "dc";
            else
                analysisKind = string(analysisType);
            end
        end
    end
end
