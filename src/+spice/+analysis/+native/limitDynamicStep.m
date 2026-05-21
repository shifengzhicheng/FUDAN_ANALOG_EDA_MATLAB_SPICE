function [step, hitsBreakpoint] = limitDynamicStep(step, currentTime, totalTime, controller)
% LIMITDYNAMICSTEP Clip a dynamic step to the transient horizon/breakpoints.
step = min(step, totalTime - currentTime);
hitsBreakpoint = false;
if isempty(controller.breakpoints)
    return;
end

futureBreakpoints = controller.breakpoints(controller.breakpoints > currentTime + controller.breakpointTolerance);
if isempty(futureBreakpoints)
    return;
end

distance = futureBreakpoints(1) - currentTime;
if distance < step - controller.breakpointTolerance
    step = distance;
    hitsBreakpoint = true;
elseif abs(distance - step) <= controller.breakpointTolerance
    step = distance;
    hitsBreakpoint = true;
end
end
