function [sourceText, sourceName, sourcePath] = readInput(netlistSource, inputKind)
netlistSource = string(netlistSource);
sourcePath = "";

switch inputKind
    case "file"
        sourcePath = string(netlistSource);
        if ~isfile(sourcePath)
            error('spice:readInput:FileNotFound', 'Netlist file not found: %s', sourcePath);
        end
        sourceText = string(fileread(sourcePath));
        sourceName = string(sourcePath);
    case "text"
        sourceText = string(netlistSource);
        sourceName = "inline-netlist";
    otherwise
        error('spice:readInput:UnsupportedInputKind', 'Unsupported input kind: %s', inputKind);
end
end
