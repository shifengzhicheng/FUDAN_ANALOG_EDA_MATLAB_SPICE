function audit = parseHspiceTr0(tr0Path)
% PARSEHSPICETR0 Parse a minimal HSPICE transient waveform .tr0 file.
% The parser only implements the subset needed by the repository's
% regression fixtures: little-endian Fortran-style records containing one
% fixed-width ASCII header and one or more float32 data blocks.
arguments
    tr0Path {mustBeTextScalar}
end

tr0Path = string(tr0Path);
records = readFortranRecords(tr0Path);
if numel(records) < 4
    error('spice:regression:BadHspiceTr0', 'HSPICE .tr0 file %s is truncated.', tr0Path);
end

header = records{2};
[variableNames, variableKinds] = parseHeaderVariables(header);
dataValues = parseDataBlocks(records(3:end));
variableCount = numel(variableNames);
rowCount = floor(numel(dataValues) / variableCount);
if rowCount < 1
    error('spice:regression:BadHspiceTr0', 'HSPICE .tr0 file %s does not contain waveform rows.', tr0Path);
end

usableCount = rowCount * variableCount;
rows = reshape(dataValues(1:usableCount), variableCount, rowCount).';
timeAxis = double(rows(:, 1));
if any(diff(timeAxis) < 0)
    error('spice:regression:BadHspiceTr0', 'HSPICE .tr0 file %s has a non-monotonic time axis.', tr0Path);
end

signalTemplate = struct('name', "", 'kind', "", 'values', zeros(0, 1));
signals = repmat(signalTemplate, 0, 1);
for idx = 2:variableCount
    signals(end + 1, 1) = struct( ... %#ok<AGROW>
        'name', string(variableNames(idx)), ...
        'kind', string(variableKinds(idx)), ...
        'values', double(rows(:, idx)));
end

audit = struct( ...
    'sourcePath', tr0Path, ...
    'time', timeAxis, ...
    'variableNames', string(variableNames(:)), ...
    'variableKinds', string(variableKinds(:)), ...
    'signals', signals, ...
    'rowCount', rowCount, ...
    'columnCount', variableCount, ...
    'trailingValueCount', numel(dataValues) - usableCount);
end

function records = readFortranRecords(filePath)
fid = fopen(filePath, 'rb', 'ieee-le');
if fid == -1
    error('spice:regression:OpenHspiceTr0Failed', 'Failed to open HSPICE .tr0 file %s.', filePath);
end
cleanup = onCleanup(@() fclose(fid));

records = {};
while true
    lead = fread(fid, 1, 'int32=>double');
    if isempty(lead)
        break;
    end
    body = fread(fid, lead, 'uint8=>uint8').';
    tail = fread(fid, 1, 'int32=>double');
    if isempty(tail) || tail ~= lead
        error('spice:regression:BadHspiceTr0', ...
            'HSPICE .tr0 file %s has mismatched Fortran record markers.', filePath);
    end
    records{end + 1, 1} = body; %#ok<AGROW>
end
end

function [variableNames, variableKinds] = parseHeaderVariables(headerBytes)
headerLength = numel(headerBytes);
variableCount = (headerLength - 272) / 24;
if variableCount < 2 || abs(variableCount - round(variableCount)) > 1e-9
    error('spice:regression:BadHspiceTr0Header', ...
        'Unsupported HSPICE .tr0 header layout with %d bytes.', headerLength);
end
variableCount = round(variableCount);
namesStart = 264 + 8 * variableCount;

variableNames = strings(variableCount, 1);
variableKinds = strings(variableCount, 1);
for idx = 1:variableCount
    offset = namesStart + (idx - 1) * 16 + 1;
    name = strtrim(string(native2unicode(headerBytes(offset:offset + 15), 'latin1')));
    if name == "$&%#"
        error('spice:regression:BadHspiceTr0Header', ...
            'Unexpected header terminator before all variables were read.');
    end
    variableNames(idx) = name;
    if idx == 1
        variableKinds(idx) = "time";
    elseif ~isempty(regexp(char(name), '^\d+$', 'once'))
        variableKinds(idx) = "nodeVoltage";
    else
        variableKinds(idx) = "deviceCurrent";
    end
end
end

function dataValues = parseDataBlocks(records)
values = zeros(0, 1, 'single');
recordIndex = 1;
while recordIndex <= numel(records)
    countRecord = records{recordIndex};
    if numel(countRecord) ~= 4
        error('spice:regression:BadHspiceTr0', ...
            'Expected a 4-byte waveform-count record in the HSPICE .tr0 payload.');
    end
    sampleCount = typecast(countRecord, 'int32');
    if recordIndex + 1 > numel(records)
        error('spice:regression:BadHspiceTr0', ...
            'Missing waveform block after count record in HSPICE .tr0 payload.');
    end
    block = records{recordIndex + 1};
    if numel(block) ~= 4 * double(sampleCount)
        error('spice:regression:BadHspiceTr0', ...
            'Waveform block length does not match the declared float count.');
    end
    values(end + 1:end + double(sampleCount), 1) = typecast(block, 'single').'; %#ok<AGROW>
    recordIndex = recordIndex + 2;
end
dataValues = values;
end
