function validValue = ensureValidRange(value, minValue, maxValue, defaultValue, paramName)
% =========================================================================
% ensureValidRange.m - Ensure Parameter Value is Within Valid Range
% =========================================================================
% Description:
%   This function validates a numeric parameter value by ensuring it falls
%   within a specified range. If the value is invalid or out of range,
%   a default value is returned instead.
%
% Inputs:
%   value        - The parameter value to validate
%   minValue     - Minimum allowed value
%   maxValue     - Maximum allowed value
%   defaultValue - Default value to use if validation fails
%   paramName    - Name of parameter (for warning messages)
%
% Outputs:
%   validValue   - The validated parameter value
%
% Related files:
%   - Various parameter handling and initialization functions
%
% Notes:
%   - Checks if value is numeric and not NaN
%   - Checks if value is within specified range
%   - Returns default if any validation check fails
%   - Logs a warning message when default is used
%   - Useful for enforcing physical constraints on parameters
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Check if value is numeric, not NaN, and within range
if ~isnumeric(value) || isnan(value) || value < minValue || value > maxValue
    % Validation failed, log warning and use default
    fprintf('[ensureValidRange] WARNING: Invalid %s (%.2f), using default: %.2f\n', ...
            paramName, value, defaultValue);
    
    % Return the default value
    validValue = defaultValue;
else
    % Validation passed, return the original value
    validValue = value;
end
end