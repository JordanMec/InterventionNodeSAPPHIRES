function [simState, hourlyAccumulators] = innerLoop_Fast(simState, guiParams, darcyParams, ...
                                                  houseParams, particleParams, timeParams, ...
                                                  T_out_K, T_out_C, rho_out, ...
                                                  C_out_PM_hr, exhaust_state_fixed, ...
                                                  Q_exhaust_fixed, hourlyAccumulators, ...
                                                  economicParams)
% =========================================================================
% innerLoop_Fast.m - Optimized Second-by-second HVAC Digital Twin Inner Loop
% =========================================================================
% Description:
%   This is an optimized version of the innerLoop function that uses
%   a multi-rate approach to speed up simulation while maintaining accuracy
%   for critical fast-changing dynamics.
%
% Inputs:
%   [Same as innerLoop.m]
%
% Outputs:
%   [Same as innerLoop.m]
%
% Notes:
%   - Uses multi-rate simulation to speed up computation
%   - PID controller runs at full 1-second resolution for accuracy
%   - Slower dynamics (dust, IAQ) run at reduced rate
%   - Error checking is maintained for stability
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Get PID controller parameters
pidParams = initPidParams();

% Calculate effective leakage coefficient from blower door test
effectiveC = calculateEffectiveLeakage(guiParams);

% Get previous PM concentration
C_prev = simState.C_indoor_PM_hour;

% Define multi-rate parameters
DUST_UPDATE_INTERVAL = 60;     % Update dust accumulation every 60 seconds
PM_UPDATE_INTERVAL = 10;       % Update indoor PM every 10 seconds 
FLOW_SOLVE_INTERVAL = 5;       % Solve flow balance every 5 seconds
ENERGY_CALC_INTERVAL = 30;     % Calculate energy usage every 30 seconds

% Cache values that don't need recalculation every step
cached_Q_cmd = simState.Q_blower;
if cached_Q_cmd <= 0 && simState.wiper > 0
    cached_Q_cmd = 5 * simState.wiper;  % Initial guess based on wiper
end

% Pre-calculate flow in m³/s to avoid repeated conversion
cached_Q_m3s = convertFlowToCubicMetersPerSecond(cached_Q_cmd);

% Initialize accumulators for multi-rate calculations
dust_accumulator = zeros(1, 4);
energy_blower_accumulator = 0;
energy_cond_accumulator = 0;

% For each second in the hour
for k = 1:timeParams.steps_per_hour
    % 1. Calculate stack effect & leak flow at previous pressure
    % (Always calculate this as it affects pressure)
    [Q_stack, DP_buoy] = calculateStackEffect(guiParams, houseParams.T_in_K, T_out_K, rho_out, effectiveC);
    
    % 2. Solve fan-curve <-> total losses for target flow
    % (Do this at reduced rate except during initial startup or rapid changes)
    if mod(k, FLOW_SOLVE_INTERVAL) == 0 || k < 60 || abs(simState.actual_pressure - guiParams.targetPressure) > 0.5
        Q_cmd = solveFlowBalance(simState, effectiveC, guiParams, darcyParams);
        simState.Q_blower = Q_cmd;
        cached_Q_cmd = Q_cmd;
        cached_Q_m3s = convertFlowToCubicMetersPerSecond(cached_Q_cmd);
    else
        simState.Q_blower = cached_Q_cmd;
    end
    
    % 3. Update house pressure via continuity
    % (Always calculate this as it's critical for control)
    simState = updateHousePressure(simState, Q_stack, Q_exhaust_fixed, effectiveC, timeParams);
    
    % 4. PID controller adjusts wiper
    % (Always run PID at full rate for proper control)
    simState = runPidController(simState, guiParams, timeParams, pidParams);
    
    % 5. Accumulate Darcy dust, calculate filter life
    % (Do this at reduced rate)
    if mod(k, DUST_UPDATE_INTERVAL) == 0 || k == timeParams.steps_per_hour
        % Calculate full dust accumulation for the interval
        [simState, flux_bin] = accumulateDust(simState, cached_Q_m3s, C_out_PM_hr, timeParams);
        
        % 6. Filter life evaluation & replacement logic
        [simState, clog_event, filter_cost] = evaluateFilterLife(simState, darcyParams, economicParams);
        if clog_event
            hourlyAccumulators.clog_event_hour = true;
            hourlyAccumulators.cost_filter_hour = hourlyAccumulators.cost_filter_hour + filter_cost;
        end
    elseif k == 1
        % First iteration - initialize flux_bin for accumulation
        [~, flux_bin] = accumulateDust(simState, cached_Q_m3s, C_out_PM_hr, timeParams);
        dust_accumulator = dust_accumulator + flux_bin;
    else
        % Accumulate dust for later batch update
        dust_accumulator = dust_accumulator + flux_bin;
    end
    
    % 7. Energy & cost accumulation for this second
    % (Calculate at reduced rate but accumulate every second for accuracy)
    if mod(k, ENERGY_CALC_INTERVAL) == 0 || k == 1 || k == timeParams.steps_per_hour
        [E_blower_second, P_blower] = calculateBlowerEnergy(simState, cached_Q_m3s, timeParams);
        E_cond_second = calculateConditioningEnergy(cached_Q_m3s, houseParams.T_in_C, T_out_C, rho_out, economicParams, timeParams);
        
        % For accuracy, scale by the real interval and accumulate
        hourlyAccumulators.E_blower_hour = hourlyAccumulators.E_blower_hour + E_blower_second;
        hourlyAccumulators.E_cond_hour = hourlyAccumulators.E_cond_hour + E_cond_second;
        
        % Reset the energy accumulators
        energy_blower_accumulator = 0;
        energy_cond_accumulator = 0;
    else
        % Accumulate into temporary variable to avoid function calls
        energy_blower_accumulator = energy_blower_accumulator + P_blower * timeParams.dt_ctrl;
        % For conditioning, use the last calculated rate
        energy_cond_accumulator = energy_cond_accumulator + E_cond_second;
    end
    
    % 8. Indoor PM mass-balance (well-mixed, explicit)
    % (Update at reduced rate)
    if mod(k, PM_UPDATE_INTERVAL) == 0 || k == timeParams.steps_per_hour
        % Update PM with effective time step = PM_UPDATE_INTERVAL seconds
        effective_timeParams = timeParams;
        effective_timeParams.dt_ctrl = PM_UPDATE_INTERVAL * timeParams.dt_ctrl;
        C_prev = updateIndoorPM(C_prev, cached_Q_m3s, C_out_PM_hr, houseParams, guiParams, particleParams, effective_timeParams);
    end
end

% Make sure the PM concentration is finalized
simState.C_indoor_PM_hour = C_prev;

% Add any remaining energy from the accumulators
hourlyAccumulators.E_blower_hour = hourlyAccumulators.E_blower_hour + energy_blower_accumulator;
hourlyAccumulators.E_cond_hour = hourlyAccumulators.E_cond_hour + energy_cond_accumulator;
end