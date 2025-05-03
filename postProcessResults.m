function [results, stats] = postProcessResults(simArrays, simState, guiParams, darcyParams)
% Post-process simulation results to calculate statistics and prepare for visualization

fprintf('[postProcessResults] Post-processing simulation results\n');
try
    % ---------------------------------------------------------------------
    % 7-A.  Derived tallies and summary statistics
    % ---------------------------------------------------------------------
    stats = struct();
    stats.total_replacements = simState.num_replacements;
    stats.total_operating_cost = simArrays.cumulative_cost_energy(end);  % $
    stats.average_house_pressure = mean(simArrays.pressure_series);  % Pa
    stats.average_blower_flow = mean(simArrays.Qfan_series);  % CFM
    
    fprintf('\n====================  RUN SUMMARY  ====================\n');
    fprintf(' Total filter replacements : %3d\n', stats.total_replacements);
    fprintf(' Average blower flow       : %6.1f  CFM\n', stats.average_blower_flow);
    fprintf(' Average house pressure    : %6.2f  Pa\n', stats.average_house_pressure);
    fprintf(' Cumulative operating cost : $%8.2f\n', stats.total_operating_cost);
    fprintf('=======================================================\n');
    
    % ---------------------------------------------------------------------
    % 7-B.  Convert cost series to cumulative sub-totals
    % ---------------------------------------------------------------------
    cum_blower_cost = cumsum(simArrays.blower_cost_series);
    cum_cond_cost = cumsum(simArrays.cond_cost_series);
    cum_filter_cost = cumsum(simArrays.filter_cost_series);
    
    % ---------------------------------------------------------------------
    % 7-C.  Prepare a "service events" vector for plot markers
    % ---------------------------------------------------------------------
    service_hours = find(simArrays.clog_event);  % indices where replacement occurred
    
    % ---------------------------------------------------------------------
    % 7-D.  Bundle results into a struct (optional save)
    % ---------------------------------------------------------------------
    results = struct();
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
    results.guiParams = guiParams;  % capture scenario
    results.darcyParams = darcyParams;
    results.stats = stats;  % include summary stats
    
    fprintf('[postProcessResults] Post-processing complete\n');
catch ME
    fprintf('[ERROR] in postProcessResults: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    
    % Create minimal results to avoid crashing
    results = struct();
    results.pressure_series = simArrays.pressure_series;
    results.stats = struct('total_replacements', 0, 'total_operating_cost', 0);
    stats = results.stats;
    
    fprintf('[postProcessResults] Created minimal results due to error\n');
    rethrow(ME);
end
end