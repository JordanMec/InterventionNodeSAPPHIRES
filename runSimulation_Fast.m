function [simArrays, simState] = runSimulation_Fast(env, guiParams, darcyParams, economicParams, houseParams, particleParams, timeParams, simArrays)
% =========================================================================
% runSimulation_Fast.m - Optimized Digital Twin HVAC Simulation Loop
% =========================================================================
% Description:
%   This is an optimized version of runSimulation that uses performance
%   improvements to speed up the simulation while maintaining accuracy
%   for critical dynamics. It's especially useful for long simulation
%   periods with hourly environmental data.
%
% Inputs:
%   [Same as runSimulation.m]
%
% Outputs:
%   [Same as runSimulation.m]
%
% Performance improvements:
%   - Uses a multi-rate inner loop that preserves critical dynamics
%   - Caches calculations that don't need to be updated every second
%   - Optimizes memory usage and computation time
%   - Reduces logging frequency for better performance
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[runSimulation_Fast] Starting optimized simulation\n');

try
    % Initialize simulation state and arrays
    [simState, simArrays] = initSimulation(timeParams, particleParams, simArrays);
    
    % Set up progress tracking
    progressBar = waitbar(0, 'Simulation starting...', 'Name', 'Digital Twin Progress (Fast Mode)');
    progressStepSize = max(1, round(timeParams.num_hours / 20));  % Update less frequently
    updateTimes = [];  % For tracking execution time
    
    % Initialize time estimation variables
    startTime = tic;
    total_hours = timeParams.num_hours;
    
    % Run the simulation for each hour
    fprintf('[runSimulation_Fast] Starting main loop for %d hours\n', timeParams.num_hours);
    for h = 1:timeParams.num_hours
        loopStartTime = tic;
        
        % Update progress bar with time estimate
        if mod(h, progressStepSize) == 0 || h == 1 || h == timeParams.num_hours
            if h > 1
                elapsed = toc(startTime);
                estTotal = elapsed * (total_hours / h);
                estRemaining = estTotal - elapsed;
                
                waitbarMsg = sprintf('Hour %d of %d (%.1f%%) - Est. %d min remaining', ...
                    h, total_hours, 100*h/total_hours, round(estRemaining/60));
                
                if ishandle(progressBar)
                    try
                        waitbar(h/total_hours, progressBar, waitbarMsg);
                    catch
                        % If waitbar fails, just continue simulation
                    end
                end
                
                % Provide occasional progress updates to console
                if mod(h, progressStepSize*5) == 0 || h == 1 || h == total_hours
                    fprintf('[runSimulation_Fast] %s\n', waitbarMsg);
                end
            end
        end
        
        % Get environmental conditions for this hour
        [T_outdoor_F, RH_outdoor, C_out_PM_hr, hr_of_day] = getHourlyEnvironment(env, h, particleParams);
        
        % Determine exhaust fan state for this hour (breakfast/lunch/dinner)
        [exhaust_state_fixed, Q_exhaust_fixed] = determineExhaustState(guiParams, houseParams, hr_of_day);
        
        % Calculate air properties
        [rho_out, T_out_K, T_out_C] = calculateAirProperties(T_outdoor_F);
        
        % Initialize hourly accumulators
        hourlyAccumulators = initHourlyAccumulators();
        
        % Run optimized inner loop (seconds within the hour)
        [simState, hourlyAccumulators] = innerLoop_Fast(simState, guiParams, darcyParams, ...
                                                     houseParams, particleParams, timeParams, ...
                                                     T_out_K, T_out_C, rho_out, ...
                                                     C_out_PM_hr, exhaust_state_fixed, ...
                                                     Q_exhaust_fixed, hourlyAccumulators, ...
                                                     economicParams);
        
        % Calculate hourly costs
        [cost_blower_hour, cost_cond_hour] = calculateHourlyCosts(hourlyAccumulators, ...
                                                                economicParams, ...
                                                                hr_of_day, simState);
        
        % Update simulation state with accumulated costs
        simState.cum_cost = simState.cum_cost + cost_blower_hour + cost_cond_hour + hourlyAccumulators.cost_filter_hour;
        
        % Log hourly data to arrays
        simArrays = logHourlyData(simArrays, simState, cost_blower_hour, cost_cond_hour, ...
                                hourlyAccumulators.cost_filter_hour, ...
                                hourlyAccumulators.clog_event_hour, h);
        
        % Store loop execution time for progress estimation
        updateTimes(end+1) = toc(loopStartTime);
        if length(updateTimes) > 10
            updateTimes = updateTimes(end-9:end);  % Keep last 10 measurements
        end
    end
    
    % Clean up
    if ishandle(progressBar)
        close(progressBar);
    end
    
    % Report simulation completion and performance
    totalTime = toc(startTime);
    fprintf('[runSimulation_Fast] Simulation completed successfully: %d hours\n', timeParams.num_hours);
    fprintf('[runSimulation_Fast] Filter replacements: %d, Final pressure: %.2f Pa\n', ...
           simState.num_replacements, simState.actual_pressure);
    fprintf('[runSimulation_Fast] Total execution time: %.1f seconds (%.1f ms per simulated hour)\n', ...
           totalTime, 1000*totalTime/timeParams.num_hours);
    
catch ME
    % Handle errors
    [simArrays, simState] = handleSimulationError(ME, simArrays, simState, timeParams, progressBar);
    rethrow(ME);
end
end

% Helper function to initialize hourly accumulators
function hourlyAccumulators = initHourlyAccumulators()
    % Initialize hourly accumulator variables
    hourlyAccumulators = struct();
    hourlyAccumulators.E_blower_hour = 0;      % Blower energy (J)
    hourlyAccumulators.E_cond_hour = 0;        % Conditioning energy (J)
    hourlyAccumulators.cost_filter_hour = 0;   % Filter replacement cost ($)
    hourlyAccumulators.clog_event_hour = false; % Flag for filter replacement
end