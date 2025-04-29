function appendMetadataToTable(results, csvFile)
% =========================================================================
% appendMetadataToTable
%
% Flattens the `results.metadata` into a row and appends it to a CSV file.
% Adds a header if the file doesn't exist yet.
%
% INPUTS:
%   results  - struct with a 'metadata' field
%   csvFile  - output filename (e.g., 'run_summary.csv')
% =========================================================================

if ~isfield(results, 'metadata')
    error('The results struct must include a metadata field.');
end

% Flatten metadata
rowStruct = flattenMetadata(results.metadata);

% Convert to table
rowTable = struct2table(rowStruct);

% If file exists, append
if isfile(csvFile)
    existing = readtable(csvFile);
    
    % Ensure headers match
    if ~isequal(existing.Properties.VariableNames, rowTable.Properties.VariableNames)
        warning('CSV header mismatch. Writing to a new file with suffix.');
        csvFile = addTimestampSuffix(csvFile);
    end
    
    newTable = [existing; rowTable];
else
    newTable = rowTable;
end

% Save
writetable(newTable, csvFile);
fprintf('Appended metadata to "%s"\n', csvFile);
end

%% --- Flatten metadata including guiParams
function flatStruct = flattenMetadata(meta)
flatStruct = struct();
fields = fieldnames(meta);

for i = 1:numel(fields)
    fieldName = fields{i};
    val = meta.(fieldName);
    
    if isstruct(val)
        subFields = fieldnames(val);
        for j = 1:numel(subFields)
            subName = subFields{j};
            fullName = sprintf('%s__%s', fieldName, subName);  % use double underscore for nested keys
            flatStruct.(fullName) = extractValue(val.(subName));
        end
    else
        flatStruct.(fieldName) = extractValue(val);
    end
end
end

function valOut = extractValue(val)
    if islogical(val)
        valOut = double(val);  % convert logical to 0/1
    elseif isnumeric(val)
        if isscalar(val)
            valOut = val;
        else
            valOut = string(mat2str(val));  % store vector as string
        end
    elseif ischar(val)
        valOut = string(val);
    else
        valOut = "<unsupported>";
    end
end

function newName = addTimestampSuffix(oldName)
[tPath, tBase, tExt] = fileparts(oldName);
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
newName = fullfile(tPath, [tBase '_' timestamp tExt]);
end
