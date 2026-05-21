function backend = getBackend()
persistent configuredBackend
if isempty(configuredBackend)
    configuredBackend = "sparse";
end
backend = configuredBackend;
end
