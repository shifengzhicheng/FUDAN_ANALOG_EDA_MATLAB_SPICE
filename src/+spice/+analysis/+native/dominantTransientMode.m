function mode = dominantTransientMode(modes)
% DOMINANTTRANSIENTMODE Collapse per-step solver modes for reporting.
if any(modes == "relaxed")
    mode = "relaxed";
elseif any(modes == "failed")
    mode = "failed";
else
    mode = "strict";
end
end
