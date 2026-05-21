function result = run(circuit, ir, options)
% RUN Dispatch analyses to the native backend when supported.
% Native execution is attempted first for migrated analyses. When the
% native backend is unavailable or fails to converge, the legacy kernels
% remain the compatibility fallback and report a backendReason.
analysis = circuit.Analysis;
fallbackReason = "legacy_requested";

if any(analysis.Type == ["dc", "dcsweep", "ac", "trans", "shoot", "pz"])
    [canUseNative, ~, nativeReason] = spice.analysis.native.canRun(circuit, options);
    if canUseNative
        try
            result = spice.analysis.native.run(circuit, ir, options);
            return;
        catch nativeError
            fallbackReason = classifyNativeFallback(nativeError);
        end
    else
        fallbackReason = nativeReason;
    end
end

result = spice.analysis.runLegacy(circuit, ir, options, fallbackReason);
end

function reason = classifyNativeFallback(nativeError)
if startsWith(string(nativeError.identifier), "spice:analysis:native:Nonlinear")
    reason = "native_nonconverged";
elseif startsWith(string(nativeError.identifier), "spice:analysis:native:")
    reason = "native_runtime_error:" + string(nativeError.identifier);
else
    reason = "native_runtime_error:unexpected";
end
end
