function circuit = parseNetlist(sourceText, opts)
arguments
    sourceText {mustBeTextScalar}
    opts.SourceName {mustBeTextScalar} = ""
end

parser = spice.parser.NetlistParser(SourceName=string(opts.SourceName));
circuit = parser.parse(sourceText);
end
