function [timeParams, simArrays] = setupTimeGrid(env, particleParams)
% Configure time grid and pre-allocate result arrays

fprintf('[setupTimeGrid] Configuring time grid and arrays\n');
try
    % ------------------- Core step sizes --------------------------------
    timeParams = struct();
    timeParams.dt_ctrl = 1;                 % inner-loop control step, seconds
    timeParams.dt_env  = 3600;              % outer-loop environment step, seconds (1 hour)
    
    timeParams.steps_per_hour = timeParams.dt_env / timeParams.dt_ctrl;   % 3 600
    
    % Validate environment input
    if ~istable(env) && ~istimetable(env)
        error('Environment data (env) must be a table or timetable');
    end
    
    timeParams.num_hours = height(env);        % 8 760 for a full calendar year
    timeParams.total_time = timeParams.num_hours * timeParams.dt_env; % 31 536 000 s
    
    fprintf('[setupTimeGrid] Simulation horizon: %d hours (%.1f days) - %.0f inner steps total\n', ...
            timeParams.num_hours, timeParams.num_hours/24, timeParams.num_hours*timeParams.steps_per_hour);
    
    % ------------------- Pre-allocate result arrays ---------------------
    simArrays = struct();
    simArrays.pressure_series         = zeros(1, timeParams.num_hours);
    simArrays.wiper_series            = zeros(1, timeParams.num_hours);
    simArrays.Qfan_series             = zeros(1, timeParams.num_hours);
    simArrays.filter_life_series      = zeros(1, timeParams.num_hours);
    simArrays.cumulative_cost_energy  = zeros(1, timeParams.num_hours);
    simArrays.dust_total_series       = zeros(1, timeParams.num_hours);
    simArrays.clog_event              = false(1, timeParams.num_hours);
    
    % Indoor PM history (hourly snapshots)
    % Ensure we handle the case where numSizes might be invalid
    if ~isfield(particleParams, 'numSizes') || particleParams.numSizes <= 0
        particleParams.numSizes = 6;  % Default fallback
        fprintf('[setupTimeGrid] WARNING: Invalid particleParams.numSizes, using default of 6\n');
    end
    simArrays.C_indoor_PM = zeros(timeParams.num_hours, particleParams.numSizes);
    
    % Arrays for detailed cost breakdowns
    simArrays.blower_cost_series = zeros(1, timeParams.num_hours);
    simArrays.cond_cost_series   = zeros(1, timeParams.num_hours);
    simArrays.filter_cost_series = zeros(1, timeParams.num_hours);
    
    fprintf('[setupTimeGrid] Arrays pre-allocated successfully\n');
catch ME
    fprintf('[ERROR] in setupTimeGrid: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    
    % Create minimal defaults if error occurs
    timeParams = struct('dt_ctrl', 1, 'dt_env', 3600, 'steps_per_hour', 3600, 'num_hours', 24);
    simArrays = struct('pressure_series', zeros(1, 24), 'Qfan_series', zeros(1, 24));
    simArrays.C_indoor_PM = zeros(24, 6);
    
    fprintf('[setupTimeGrid] Created minimal defaults due to error\n');
    rethrow(ME);
end
end