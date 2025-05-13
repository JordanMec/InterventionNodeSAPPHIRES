function inputStruct = validateInputStruct(structName, inputStruct, requiredFields, defaultValues)
% =========================================================================
% validateInputStruct.m - Validate Input Structure
% =========================================================================
% Description:
%   This function validates an input structure by checking for required
%   fields and supplying default values for missing or invalid fields.
%   It ensures that structures have all necessary fields before they are
%   used in the simulation.
%
% Inputs:
%   structName     - Name of the structure (for error messages)
%   inputStruct    - Structure to validate
%   requiredFields - Cell array of required field names
%   defaultValues  - Cell array of default values for each field
%
% Outputs:
%   inputStruct    - Validated structure with all required fields
%
% Related files:
%   - Various parameter initialization functions
%   - Simulation functions that need validated input structures
%
% Notes:
%   - Checks if the structure exists and is a proper struct
%   - Verifies that all required fields are present
%   - Replaces missing or empty fields with default values
%   - Logs warnings when defaults are used
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Verify that required fields and default values arrays match in length
if length(requiredFields) ~= length(defaultValues)
    error('Field and default value arrays must be the same length');
end

% Check if inputStruct is a valid structure
if ~isstruct(inputStruct)
    fprintf('[validateInputStruct] WARNING: %s is not a valid structure. Initializing.\n', structName);
    inputStruct = struct();
end

% Check each required field
for i = 1:length(requiredFields)
    fieldName = requiredFields{i};
    defaultValue = defaultValues{i};
    
    % Check if field exists, is not empty, and is not NaN
    if ~isfield(inputStruct, fieldName) || ...
       isempty(inputStruct.(fieldName)) || ...
       (isnumeric(inputStruct.(fieldName)) && isnan(inputStruct.(fieldName)))
        
        % Field is missing or invalid - use default
        inputStruct.(fieldName) = defaultValue;
        
        % Log a warning
        fprintf('[validateInputStruct] WARNING: Using default value for %s.%s: %s\n', ...
                structName, fieldName, mat2str(defaultValue));
    end
end
end