function [timeParams, simArrays] = setupTimeGrid(env, particleParams)
% =========================================================================
% setupTimeGrid.m - Configure Time Grid and Initialize Arrays
% =========================================================================
% Description:
%   This function configures the time grid for the simulation and
%   pre-allocates arrays for storing simulation results. It determines
%   the simulation horizon based on the environmental data and creates
%   appropriate arrays for all output variables.
%
% Inputs:
%   env             - Environmental data table/timetable
%   particleParams  - Particle size parameters
%
% Outputs:
%   timeParams      - Structure with time parameters:
%                     - dt_ctrl: Control time step (seconds)
%                     - dt_env: Environmental data time step (seconds)
%                     - steps_per_hour: Steps per hour
%                     - num_hours: Total number of hours in simulation
%                     - total_time: Total simulation time (seconds)
%   simArrays       - Structure with pre-allocated result arrays
%
% Related files:
%   - godMode.m         - Main entry point
%   - runSimulation.m   - Uses these arrays for storing results
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[setupTimeGrid] Configuring time grid and arrays\n');

try
    % Initialize timeParams structure
    timeParams = struct();
    
    % Set time steps
    timeParams.dt_ctrl = 1;        % Control time step (seconds)
    timeParams.dt_env  = 3600;     % Environmental data time step (seconds)
    timeParams.steps_per_hour = timeParams.dt_env / timeParams.dt_ctrl;
    
    % Validate environment data
    if ~istable(env) && ~istimetable(env)
        error('Environment data (env) must be a table or timetable');
    end
    
    % Set simulation horizon based on environment data
    timeParams.num_hours = height(env); 
    timeParams.total_time = timeParams.num_hours * timeParams.dt_env; 
    
    % Report simulation time settings
    fprintf('[setupTimeGrid] Simulation horizon: %d hours (%.1f days) - %.0f inner steps total\n', ...
            timeParams.num_hours, timeParams.num_hours/24, timeParams.num_hours*timeParams.steps_per_hour);
    
    % Pre-allocate arrays for storing results
    simArrays = struct();
    
    % Control and pressure arrays
    simArrays.pressure_series         = zeros(1, timeParams.num_hours);
    simArrays.wiper_series            = zeros(1, timeParams.num_hours);
    simArrays.Qfan_series             = zeros(1, timeParams.num_hours);
    
    % Filter status arrays
    simArrays.filter_life_series      = zeros(1, timeParams.num_hours);
    simArrays.dust_total_series       = zeros(1, timeParams.num_hours);
    simArrays.clog_event              = false(1, timeParams.num_hours);
    
    % Cost arrays
    simArrays.cumulative_cost_energy  = zeros(1, timeParams.num_hours);
    simArrays.blower_cost_series      = zeros(1, timeParams.num_hours);
    simArrays.cond_cost_series        = zeros(1, timeParams.num_hours);
    simArrays.filter_cost_series      = zeros(1, timeParams.num_hours);
    
    % Air quality arrays
    if ~isfield(particleParams, 'numSizes') || particleParams.numSizes <= 0
        particleParams.numSizes = 6;
        fprintf('[setupTimeGrid] WARNING: Invalid particleParams.numSizes, using default of 6\n');
    end
    simArrays.C_indoor_PM = zeros(timeParams.num_hours, particleParams.numSizes);
    
    fprintf('[setupTimeGrid] Arrays pre-allocated successfully\n');
    
catch ME
    % Handle errors
    fprintf('[ERROR] in setupTimeGrid: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    
    % Return minimal default values to avoid crashing the simulation
    timeParams = struct('dt_ctrl', 1, 'dt_env', 3600, 'steps_per_hour', 3600, 'num_hours', 24);
    simArrays = struct('pressure_series', zeros(1, 24), 'Qfan_series', zeros(1, 24));
    simArrays.C_indoor_PM = zeros(24, 6);
    
    fprintf('[setupTimeGrid] Created minimal defaults due to error\n');
    rethrow(ME);
end
end