function [results, stats] = postProcessResults(simArrays, simState, guiParams, darcyParams)
% =========================================================================
% postProcessResults.m - Process Simulation Results
% =========================================================================
% Description:
%   This function processes the raw simulation results into useful metrics
%   and statistics. It transforms the hourly data stored in simArrays into
%   a more user-friendly results structure and calculates summary statistics.
%
% Inputs:
%   simArrays   - Structure with raw simulation result arrays
%   simState    - Final simulation state
%   guiParams   - GUI/user parameters
%   darcyParams - Filter parameters
%
% Outputs:
%   results     - Structure with processed results
%   stats       - Structure with summary statistics
%
% Related files:
%   - godMode.m: Calls this function after simulation completes
%   - visualizeResults.m: Uses processed results for visualization
%   - exportResults.m: Exports the processed results
%
% Notes:
%   - Processes time series data into more useful formats
%   - Calculates cumulative costs by type
%   - Identifies filter replacement events
%   - Calculates key performance metrics like average pressure
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[postProcessResults] Post-processing simulation results\n');

try
    % Initialize stats structure with summary statistics
    stats = struct();
    stats.total_replacements = simState.num_replacements;
    stats.total_operating_cost = simArrays.cumulative_cost_energy(end);
    stats.average_house_pressure = mean(simArrays.pressure_series);
    stats.average_blower_flow = mean(simArrays.Qfan_series);
    
    % Print summary to console
    fprintf('\n====================  RUN SUMMARY  ====================\n');
    fprintf(' Total filter replacements : %3d\n', stats.total_replacements);
    fprintf(' Average blower flow       : %6.1f  CFM\n', stats.average_blower_flow);
    fprintf(' Average house pressure    : %6.2f  Pa\n', stats.average_house_pressure);
    fprintf(' Cumulative operating cost : $%8.2f\n', stats.total_operating_cost);
    fprintf('=======================================================\n');
    
    % Calculate cumulative costs by component
    cum_blower_cost = cumsum(simArrays.blower_cost_series);
    cum_cond_cost = cumsum(simArrays.cond_cost_series);
    cum_filter_cost = cumsum(simArrays.filter_cost_series);
    
    % Find filter replacement events
    service_hours = find(simArrays.clog_event);
    
    % Initialize results structure
    results = struct();
    
    % Transfer time series data
    results.pressure_series = simArrays.pressure_series;
    results.Qfan_series = simArrays.Qfan_series;
    results.wiper_series = simArrays.wiper_series;
    results.cumulative_cost_energy = simArrays.cumulative_cost_energy;
    results.cum_blower_cost = cum_blower_cost;
    results.cum_cond_cost = cum_cond_cost;
    results.cum_filter_cost = cum_filter_cost;
    results.filter_life_series = simArrays.filter_life_series;
    results.dust_total_series = simArrays.dust_total_series;
    results.C_indoor_PM = simArrays.C_indoor_PM;
    results.service_hours = service_hours;
    
    % Include parameters for reference
    results.guiParams = guiParams;
    results.darcyParams = darcyParams;
    results.stats = stats;
    
    fprintf('[postProcessResults] Post-processing complete\n');
catch ME
    % Handle errors
    fprintf('[ERROR] in postProcessResults: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    
    % Create minimal results to allow continuing
    results = struct();
    results.pressure_series = simArrays.pressure_series;
    results.stats = struct('total_replacements', 0, 'total_operating_cost', 0);
    stats = results.stats;
    
    fprintf('[postProcessResults] Created minimal results due to error\n');
    rethrow(ME);
end
end