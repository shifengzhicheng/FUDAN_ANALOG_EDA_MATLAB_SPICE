function backend = getBackend(action, backendValue)
persistent configuredBackend
if nargin >= 1 && string(action) == "set"
    configuredBackend = string(backendValue);
end
if isempty(configuredBackend)
    configuredBackend = "sparse";
end
backend = configuredBackend;
end
