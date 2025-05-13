function remaining_capacity = calculateRemainingCapacity(dust_total, darcyParams)
% =========================================================================
% calculateRemainingCapacity.m - Calculate Remaining Filter Capacity
% =========================================================================
% Description:
%   This function calculates the remaining filter capacity based on the
%   total accumulated dust and filter capacity parameters. It provides
%   the absolute remaining capacity in grams.
%
% Inputs:
%   dust_total  - Total accumulated dust mass (g)
%   darcyParams - Filter parameters (contains total_capacity)
%
% Outputs:
%   remaining_capacity - Remaining filter capacity (g)
%
% Related files:
%   - evaluateFilterLife.m: Similar function that calculates filter life percentage
%   - accumulateDust.m: Updates dust accumulation used here
%   - initDarcyParams.m: Defines total filter capacity
%
% Notes:
%   - Remaining capacity = total_capacity - dust_total
%   - Used for advanced filter status reporting and predictive maintenance
%   - Can be used to estimate time until next replacement
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Get total filter capacity with validation
if isfield(darcyParams, 'total_capacity') && darcyParams.total_capacity > 0
    total_capacity = darcyParams.total_capacity;
else
    total_capacity = 100;
    fprintf('[calculateRemainingCapacity] WARNING: Using default capacity of 100g\n');
end

% Calculate remaining capacity
remaining_capacity = max(0, total_capacity - dust_total);

% Validate the result
if isnan(remaining_capacity) || remaining_capacity < 0
    remaining_capacity = 0;
elseif remaining_capacity > total_capacity
    remaining_capacity = total_capacity;
end
end