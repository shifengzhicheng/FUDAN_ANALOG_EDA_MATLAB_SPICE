classdef DeviceFactory
    methods (Static)
        function register(prefix, constructorFn)
            spice.model.DeviceFactory.registry("set", prefix, constructorFn);
        end

        function device = fromTokens(tokens, lineNumber)
            spice.model.DeviceFactory.bootstrap();
            name = string(tokens{1});
            prefix = upper(extractBefore(name, 2));
            registry = spice.model.DeviceFactory.registry("get");
            key = spice.model.DeviceFactory.key(prefix);
            if ~isfield(registry, key)
                error('spice:parseNetlist:UnsupportedElement', ...
                    'Unsupported element "%s" at line %d.', name, lineNumber);
            end
            device = registry.(key)(tokens, lineNumber);
        end
    end

    methods (Static, Access = private)
        function bootstrap()
            persistent bootstrapped
            if isempty(bootstrapped)
                spice.model.DeviceFactory.registry("set", "R", @(tokens, line) spice.model.Resistor.fromTokens(tokens, line));
                spice.model.DeviceFactory.registry("set", "C", @(tokens, line) spice.model.Capacitor.fromTokens(tokens, line));
                spice.model.DeviceFactory.registry("set", "L", @(tokens, line) spice.model.Inductor.fromTokens(tokens, line));
                spice.model.DeviceFactory.registry("set", "V", @(tokens, line) spice.model.VoltageSource.fromTokens(tokens, line));
                spice.model.DeviceFactory.registry("set", "I", @(tokens, line) spice.model.CurrentSource.fromTokens(tokens, line));
                spice.model.DeviceFactory.registry("set", "M", @(tokens, line) spice.model.Mosfet.fromTokens(tokens, line));
                spice.model.DeviceFactory.registry("set", "D", @(tokens, line) spice.model.Diode.fromTokens(tokens, line));
                spice.model.DeviceFactory.registry("set", "Q", @(tokens, line) spice.model.Bjt.fromTokens(tokens, line));
                bootstrapped = true;
            end
        end

        function out = registry(action, prefix, constructorFn)
            persistent store
            if isempty(store)
                store = struct();
            end

            switch action
                case "set"
                    store.(spice.model.DeviceFactory.key(prefix)) = constructorFn;
                    out = [];
                case "get"
                    out = store;
                otherwise
                    error('spice:model:DeviceFactory:UnknownAction', 'Unknown registry action %s.', action);
            end
        end

        function key = key(prefix)
            key = matlab.lang.makeValidName(char(string(prefix)));
        end
    end
end
