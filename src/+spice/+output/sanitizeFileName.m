function name = sanitizeFileName(rawName)
% SANITIZEFILENAME Replace unsupported path characters for report assets.
name = regexprep(char(string(rawName)), '[^A-Za-z0-9_\-]+', '_');
end
