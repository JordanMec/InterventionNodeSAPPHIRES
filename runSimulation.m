function [simArrays, simState] = runSimulation(env, guiParams, darcyParams, economicParams, houseParams, particleParams, timeParams, simArrays)
% =========================================================================
% runSimulation.m - Core Digital Twin HVAC Simulation Loop
% =========================================================================
% Description:
%   This is the main function that coordinates the entire simulation process.
%   It runs the simulation hour by hour, calling various sub-functions to
%   handle specific aspects of the simulation.
%
% Inputs:
%   env             - Timetable/table with environmental data
%   guiParams       - Struct with GUI/user parameters
%   darcyParams     - Struct with filter parameters
%   economicParams  - Struct with cost parameters
%   houseParams     - Struct with house characteristics
%   particleParams  - Struct with particle size information
%   timeParams      - Struct with timing parameters
%   simArrays       - Struct with pre-allocated arrays (optional)
%
% Outputs:
%   simArrays       - Struct with simulation results
%   simState        - Final simulation state
%
% Related files:
%   - initSimulation.m          - Initializes simulation state
%   - getHourlyEnvironment.m    - Retrieves environmental conditions
%   - determineExhaustState.m   - Determines exhaust fan state
%   - calculateAirProperties.m  - Calculates air density and temperature
%   - innerLoop.m               - Handles second-by-second calculations
%   - calculateHourlyCosts.m    - Calculates hourly operation costs
%   - logHourlyData.m           - Logs data to arrays
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[runSimulation] Starting simulation\n');

try
    % Initialize simulation state and arrays
    [simState, simArrays] = initSimulation(timeParams, particleParams, simArrays);
    
    % Set up progress tracking
    progressBar = waitbar(0, 'Simulation starting...', 'Name', 'Digital Twin Progress');
    progressStepSize = max(1, round(timeParams.num_hours / 100));  % Update every ~1%
    updateTimes = [];  % For tracking execution time
    
    % Run the simulation for each hour
    fprintf('[runSimulation] Starting main loop for %d hours\n', timeParams.num_hours);
    for h = 1:timeParams.num_hours
        loopStartTime = tic;
        
        % Update progress bar occasionally
        updateProgress(progressBar, h, timeParams.num_hours, progressStepSize);
        
        % Get environmental conditions for this hour
        [T_outdoor_F, RH_outdoor, C_out_PM_hr, hr_of_day] = getHourlyEnvironment(env, h, particleParams);
        
        % Determine exhaust fan state for this hour (breakfast/lunch/dinner)
        [exhaust_state_fixed, Q_exhaust_fixed] = determineExhaustState(guiParams, houseParams, hr_of_day);
        
        % Calculate air properties
        [rho_out, T_out_K, T_out_C] = calculateAirProperties(T_outdoor_F);
        
        % Initialize hourly accumulators
        hourlyAccumulators = initHourlyAccumulators();
        
        % Run inner loop (seconds within the hour)
        [simState, hourlyAccumulators] = innerLoop(simState, guiParams, darcyParams, ...
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
    
    % Report simulation completion
    reportCompletion(simState, timeParams);
    
catch ME
    % Handle errors
    [simArrays, simState] = handleSimulationError(ME, simArrays, simState, timeParams, progressBar);
    rethrow(ME);
end
end

% Helper function for progress updates
function updateProgress(progressBar, h, num_hours, progressStepSize)
    if mod(h, progressStepSize) == 0 || h == 1 || h == num_hours
        if ishandle(progressBar)
            try
                waitbar(h/num_hours, progressBar, sprintf('Hour %d of %d', h, num_hours));
            catch
                % If waitbar fails, just continue simulation
            end
        end
    end
    
    % Provide occasional progress updates to console
    if mod(h, 500) == 0 || h == 1 || h == num_hours
        fprintf('[runSimulation] Completed hour %d of %d (%.1f%%)\n', ...
               h, num_hours, 100*h/num_hours);
    end
end

% Helper function for reporting completion
function reportCompletion(simState, timeParams)
    fprintf('[runSimulation] Simulation completed successfully: %d hours\n', timeParams.num_hours);
    fprintf('[runSimulation] Filter replacements: %d, Final pressure: %.2f Pa\n', ...
           simState.num_replacements, simState.actual_pressure);
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