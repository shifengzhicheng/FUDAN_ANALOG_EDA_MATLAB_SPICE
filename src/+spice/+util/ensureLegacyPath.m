function legacyPath = ensureLegacyPath()
persistent initialized cachedLegacyPath

if isempty(initialized) || ~initialized
    thisFile = mfilename('fullpath');
    repoRoot = fileparts(fileparts(fileparts(fileparts(thisFile))));
    cachedLegacyPath = fullfile(repoRoot, 'legacy');
    if isfolder(cachedLegacyPath)
        addpath(cachedLegacyPath);
    else
        error('spice:ensureLegacyPath:MissingLegacy', 'Legacy directory not found: %s', cachedLegacyPath);
    end
    initialized = true;
end

legacyPath = cachedLegacyPath;
end
