function simState = updateSimulationState(simState, cost_blower_hour, cost_cond_hour, cost_filter_hour)
% =========================================================================
% updateSimulationState.m - Update Simulation State with Costs
% =========================================================================
% Description:
%   This function updates the simulation state with accumulated costs
%   from blower operation, air conditioning/heating, and filter replacements.
%   It serves as a central location for tracking total costs.
%
% Inputs:
%   simState         - Current simulation state
%   cost_blower_hour - Blower energy cost for this hour ($)
%   cost_cond_hour   - Conditioning energy cost for this hour ($)
%   cost_filter_hour - Filter replacement cost for this hour ($)
%
% Outputs:
%   simState         - Updated simulation state with accumulated costs
%
% Related files:
%   - runSimulation.m: Calls this function after each inner loop
%   - calculateHourlyCosts.m: Calculates costs used here
%   - logHourlyData.m: Logs the updated state
%
% Notes:
%   - Accumulates total costs over the simulation period
%   - Tracks the most recent cost for each component
%   - Provides validation for numerical stability
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Store individual costs for the current hour
simState.previous_blower_cost = cost_blower_hour;
simState.previous_cond_cost = cost_cond_hour;
simState.previous_filter_cost = cost_filter_hour;

% Calculate total cost for this hour
total_hour_cost = cost_blower_hour + cost_cond_hour + cost_filter_hour;

% Update cumulative cost
simState.cum_cost = simState.cum_cost + total_hour_cost;

% Validate cumulative cost
if isnan(simState.cum_cost)
    warning('NaN detected in cumulative cost, resetting to previous value');
    simState.cum_cost = simState.cum_cost - total_hour_cost;  % Revert to previous value
elseif simState.cum_cost < 0
    warning('Negative cumulative cost detected, resetting to 0');
    simState.cum_cost = 0;
elseif simState.cum_cost > 1e6
    warning('Unrealistic cumulative cost detected (>$1M), capping');
    simState.cum_cost = 1e6;
end
end