function value = toSerializable(inputValue)
% TOSERIALIZABLE Convert MATLAB values into JSON-safe data recursively.
% Reports and emitted artifacts reuse this one helper so native, legacy,
% and audit structs can be written without each caller re-implementing its
% own string/complex/struct normalization rules.
value = serializeValue(inputValue);
end

function value = serializeValue(inputValue)
if isstruct(inputValue)
    if isempty(inputValue)
        value = struct([]);
        return;
    end
    if numel(inputValue) > 1
        value = cell(size(inputValue));
        for itemIdx = 1:numel(inputValue)
            value{itemIdx} = serializeValue(inputValue(itemIdx));
        end
    else
        value = struct();
        fields = fieldnames(inputValue);
        if isempty(fields)
            return;
        end
        fieldValues = struct2cell(inputValue);
        for idx = 1:numel(fields)
            fieldValue = fieldValues{idx};
            value.(fields{idx}) = serializeValue(fieldValue);
        end
    end
elseif iscell(inputValue)
    value = cell(size(inputValue));
    for idx = 1:numel(inputValue)
        value{idx} = serializeValue(inputValue{idx});
    end
elseif isnumeric(inputValue) || islogical(inputValue)
    if ~isreal(inputValue)
        value = struct('real', real(inputValue), 'imag', imag(inputValue));
    else
        value = inputValue;
    end
elseif isstring(inputValue)
    if isscalar(inputValue)
        value = char(inputValue);
    else
        value = cellstr(inputValue);
    end
else
    value = inputValue;
end
end
