function [simState, simArrays] = initSimulation(timeParams, particleParams, simArrays)
% =========================================================================
% initSimulation.m - Initialize Simulation State and Arrays
% =========================================================================
% Description:
%   This function initializes the simulation state and ensures all necessary
%   arrays are properly allocated. It sets up the initial conditions for the
%   simulation and prepares arrays for storing results.
%
% Inputs:
%   timeParams      - Structure with time parameters
%   particleParams  - Structure with particle size parameters
%   simArrays       - (Optional) Pre-allocated arrays from setupTimeGrid
%
% Outputs:
%   simState        - Initialized simulation state structure
%   simArrays       - Verified and completed arrays structure
%
% Related files:
%   - setupTimeGrid.m   - Usually called before this to pre-allocate arrays
%   - runSimulation.m   - Uses the state and arrays created here
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[initSimulation] Initializing simulation state and arrays\n');

% Initialize simulation state with default values
simState = struct();
simState.actual_pressure   = 0;        % Initial house pressure (Pa)
simState.wiper             = 0;        % Initial wiper position (0-128)
simState.Q_blower          = 0;        % Initial blower flow rate (CFM)
simState.dust              = zeros(1,4); % Dust accumulation by size bin (g)
simState.dust_total        = 0;        % Total dust accumulated (g)
simState.filter_life_pct   = 100;      % Initial filter life (%)
simState.previous_filter_cost = 0;     % Tracking for filter costs
simState.cum_cost          = 0;        % Cumulative operating cost ($)
simState.clog_state        = false;    % Filter clog state
simState.num_replacements  = 0;        % Counter for filter replacements
simState.integral_error    = 0;        % PID controller integral term
simState.previous_error    = 0;        % PID controller previous error

% Validate particleParams for indoor PM modeling
if ~isfield(particleParams, 'numSizes') || isempty(particleParams.numSizes) || particleParams.numSizes <= 0
    fprintf('[initSimulation] WARNING: Invalid particleParams.numSizes, using default of 6\n');
    particleParams.numSizes = 6;
end

% Initialize indoor PM concentration array
simState.C_indoor_PM_hour = zeros(1, particleParams.numSizes);

% Check if simArrays exists and is a valid structure
if isempty(simArrays) || ~isstruct(simArrays)
    fprintf('[initSimulation] Creating new simArrays structure\n');
    simArrays = struct();
end

% Validate timeParams.num_hours
if ~isfield(timeParams, 'num_hours') || timeParams.num_hours <= 0
    error('[initSimulation] Invalid number of simulation hours: %d', timeParams.num_hours);
end

% Define required array fields and ensure they exist with correct dimensions
requiredArrays = {'pressure_series', 'wiper_series', 'Qfan_series', ...
                 'dust_total_series', 'filter_life_series', ...
                 'cumulative_cost_energy', 'blower_cost_series', ...
                 'cond_cost_series', 'filter_cost_series', 'clog_event'};

% Check and create each required array field
for i = 1:length(requiredArrays)
    arrName = requiredArrays{i};
    
    if ~isfield(simArrays, arrName) || length(simArrays.(arrName)) < timeParams.num_hours
        if strcmp(arrName, 'clog_event')
            % Boolean array for filter replacement events
            simArrays.(arrName) = false(1, timeParams.num_hours);
        else
            % Numeric arrays for other time series
            simArrays.(arrName) = zeros(1, timeParams.num_hours);
        end
        fprintf('[initSimulation] Created array: %s (%d elements)\n', arrName, timeParams.num_hours);
    end
end

% Check and create indoor PM concentration array
if ~isfield(simArrays, 'C_indoor_PM') || ...
   size(simArrays.C_indoor_PM, 1) < timeParams.num_hours || ...
   size(simArrays.C_indoor_PM, 2) < particleParams.numSizes
    simArrays.C_indoor_PM = zeros(timeParams.num_hours, particleParams.numSizes);
    fprintf('[initSimulation] Created C_indoor_PM array (%d hours, %d sizes)\n', ...
           timeParams.num_hours, particleParams.numSizes);
end

% Validate steps_per_hour
if ~isfield(timeParams, 'steps_per_hour') || timeParams.steps_per_hour <= 0
    fprintf('[initSimulation] WARNING: Invalid steps_per_hour, using default of 3600\n');
    timeParams.steps_per_hour = 3600;  % Default to 1-second resolution
end

% Validate dt_ctrl
if ~isfield(timeParams, 'dt_ctrl') || timeParams.dt_ctrl <= 0
    timeParams.dt_ctrl = 1;
    fprintf('[initSimulation] WARNING: Using default dt_ctrl of 1 second\n');
end

fprintf('[initSimulation] Simulation initialized successfully\n');
end