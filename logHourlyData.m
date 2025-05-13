function simArrays = logHourlyData(simArrays, simState, cost_blower_hour, cost_cond_hour, cost_filter_hour, clog_event_hour, hour_index)
% =========================================================================
% logHourlyData.m - Log Hourly Simulation Data to Arrays
% =========================================================================
% Description:
%   This function logs hourly simulation data from simState to the
%   appropriate arrays in simArrays. It captures the state at the end
%   of each simulation hour for later analysis and visualization.
%
% Inputs:
%   simArrays         - Structure containing simulation result arrays
%   simState          - Current simulation state at end of hour
%   cost_blower_hour  - Blower energy cost for this hour ($)
%   cost_cond_hour    - Conditioning energy cost for this hour ($)
%   cost_filter_hour  - Filter replacement cost for this hour ($)
%   clog_event_hour   - Boolean flag indicating if filter was replaced
%   hour_index        - Current hour index
%
% Outputs:
%   simArrays         - Updated simulation arrays
%
% Related files:
%   - runSimulation.m: Calls this function after each hour
%   - visualizeResults.m: Uses the logged data for visualization
%   - postProcessResults.m: Processes the logged data
%
% Notes:
%   - Records key parameters at the end of each simulation hour
%   - Accumulates costs over the simulation duration
%   - Records filter replacement events
%   - Validates array dimensions before logging
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Check if hour index is within array bounds
if hour_index <= length(simArrays.pressure_series)
    % Log state variables
    simArrays.pressure_series(hour_index) = simState.actual_pressure;
    simArrays.wiper_series(hour_index) = simState.wiper;
    simArrays.Qfan_series(hour_index) = simState.Q_blower;
    simArrays.dust_total_series(hour_index) = simState.dust_total;
    simArrays.filter_life_series(hour_index) = simState.filter_life_pct;
    
    % Log cost data
    simArrays.blower_cost_series(hour_index) = cost_blower_hour;
    simArrays.cond_cost_series(hour_index) = cost_cond_hour;
    simArrays.filter_cost_series(hour_index) = cost_filter_hour;
    
    % Calculate total cost for this hour
    total_hour_cost = cost_blower_hour + cost_cond_hour + cost_filter_hour;
    
    % Calculate cumulative energy cost
    if hour_index > 1
        simArrays.cumulative_cost_energy(hour_index) = simArrays.cumulative_cost_energy(hour_index - 1) + total_hour_cost;
    else
        simArrays.cumulative_cost_energy(hour_index) = total_hour_cost;
    end
    
    % Log clog event
    simArrays.clog_event(hour_index) = clog_event_hour;
    
    % Log indoor PM concentration (if available)
    if isfield(simState, 'C_indoor_PM_hour') && isfield(simArrays, 'C_indoor_PM') && ...
       hour_index <= size(simArrays.C_indoor_PM, 1) && ...
       length(simState.C_indoor_PM_hour) <= size(simArrays.C_indoor_PM, 2)
        
        simArrays.C_indoor_PM(hour_index, 1:length(simState.C_indoor_PM_hour)) = simState.C_indoor_PM_hour;
    end
else
    % Log warning if hour index is out of bounds
    fprintf('[logHourlyData] WARNING: Hour index %d exceeds array length %d\n', ...
            hour_index, length(simArrays.pressure_series));
end
end