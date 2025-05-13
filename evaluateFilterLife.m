function [simState, clog_event, filter_cost] = evaluateFilterLife(simState, darcyParams, economicParams)
% =========================================================================
% evaluateFilterLife.m - Monitor Filter Life and Replacement
% =========================================================================
% Description:
%   This function evaluates the remaining filter life based on dust
%   accumulation, determines when a filter needs replacement, and handles
%   the replacement process including cost accounting.
%
% Inputs:
%   simState       - Current simulation state (contains dust_total)
%   darcyParams    - Filter parameters (contains total_capacity)
%   economicParams - Economic parameters (contains filter_replacement_cost)
%
% Outputs:
%   simState       - Updated simulation state after potential replacement
%   clog_event     - Boolean flag indicating if replacement occurred
%   filter_cost    - Cost of filter replacement ($, 0 if no replacement)
%
% Related files:
%   - innerLoop.m: Calls this function during simulation
%   - accumulateDust.m: Updates dust accumulation used here
%   - initDarcyParams.m: Defines filter capacity
%
% Notes:
%   - Filter life percentage decreases as dust accumulates
%   - Filter is replaced when dust exceeds threshold (95% of capacity)
%   - Replacement resets dust to zero and increments replacement counter
%   - Filter life is calculated as: 100% × (1 - dust_total/total_capacity)
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Initialize outputs
clog_event = false;
filter_cost = 0;

% Get filter total capacity with validation
total_capacity = darcyParams.total_capacity;
if isnan(total_capacity) || total_capacity <= 0
    total_capacity = 100;  % Default capacity (g)
end

% Calculate remaining filter life percentage
simState.filter_life_pct = max(0, 100 * (1 - simState.dust_total / total_capacity));

% Define dust threshold for filter replacement (95% of capacity)
dust_threshold = 0.95 * total_capacity;

% Check if filter needs replacement
clogged_now = (simState.dust_total >= dust_threshold);

% Handle filter replacement if needed
if clogged_now && ~simState.clog_state
    % Increment replacement counter
    simState.num_replacements = simState.num_replacements + 1;
    
    % Set filter replacement cost
    filter_cost = economicParams.filter_replacement_cost;
    
    % Reset dust accumulation
    simState.dust(:) = 0;
    simState.dust_total = 0;
    
    % Reset filter life to 100%
    simState.filter_life_pct = 100;
    
    % Set clog state (prevents multiple replacements in consecutive steps)
    simState.clog_state = true;
    
    % Set clog event flag to true
    clog_event = true;
    
    % Log replacement event
    fprintf('[evaluateFilterLife] Filter replacement #%d (dust: %.2f g)\n', ...
           simState.num_replacements, simState.dust_total);
elseif ~clogged_now
    % Reset clog state when below threshold
    simState.clog_state = false;
end
end