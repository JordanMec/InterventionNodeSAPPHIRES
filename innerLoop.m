function [simState, hourlyAccumulators] = innerLoop(simState, guiParams, darcyParams, ...
                                                  houseParams, particleParams, timeParams, ...
                                                  T_out_K, T_out_C, rho_out, ...
                                                  C_out_PM_hr, exhaust_state_fixed, ...
                                                  Q_exhaust_fixed, hourlyAccumulators, ...
                                                  economicParams)
% =========================================================================
% innerLoop.m - Second-by-second HVAC Digital Twin Inner Loop
% =========================================================================
% Description:
%   This function executes the inner simulation loop that handles
%   second-by-second calculations within each hour. It updates pressure,
%   flow, filter loading, energy usage, and indoor air quality.
%
% Inputs:
%   simState            - Current simulation state struct
%   guiParams           - GUI/user parameters
%   darcyParams         - Filter parameters
%   houseParams         - House characteristics
%   particleParams      - Particle size information
%   timeParams          - Timing parameters
%   T_out_K             - Outdoor temperature (Kelvin)
%   T_out_C             - Outdoor temperature (Celsius)
%   rho_out             - Outdoor air density (kg/m³)
%   C_out_PM_hr         - Outdoor PM concentrations by size bin
%   exhaust_state_fixed - Boolean indicating if exhaust is on
%   Q_exhaust_fixed     - Exhaust flow rate (CFM)
%   hourlyAccumulators  - Struct for accumulating hourly values
%   economicParams      - Economic parameters for cost calculations
%
% Outputs:
%   simState            - Updated simulation state
%   hourlyAccumulators  - Updated hourly accumulator values
%
% Related files:
%   - calculateStackEffect.m         - Stack effect calculations
%   - solveFlowBalance.m             - Solves for flow balance
%   - updateHousePressure.m          - Updates house pressure
%   - runPidController.m             - PID controller for wiper position
%   - accumulateDust.m               - Tracks dust accumulation
%   - evaluateFilterLife.m           - Monitors filter life
%   - calculateBlowerEnergy.m        - Calculates blower energy usage
%   - calculateConditioningEnergy.m  - Calculates conditioning energy
%   - updateIndoorPM.m               - Updates indoor PM concentrations
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

% For each second in the hour
for k = 1:timeParams.steps_per_hour
    % 1. Calculate stack effect & leak flow at previous pressure
    [Q_stack, DP_buoy] = calculateStackEffect(guiParams, houseParams.T_in_K, T_out_K, rho_out, effectiveC);
    
    % 2. Solve fan-curve <-> total losses for target flow
    Q_cmd = solveFlowBalance(simState, effectiveC, guiParams, darcyParams);
    simState.Q_blower = Q_cmd;
    
    % 3. Update house pressure via continuity
    simState = updateHousePressure(simState, Q_stack, Q_exhaust_fixed, effectiveC, timeParams);
    
    % 4. PID controller adjusts wiper
    simState = runPidController(simState, guiParams, timeParams, pidParams);
    
    % 5. Accumulate Darcy dust, calculate filter life
    Q_m3s = convertFlowToCubicMetersPerSecond(simState.Q_blower);
    [simState, flux_bin] = accumulateDust(simState, Q_m3s, C_out_PM_hr, timeParams);
    
    % 6. Filter life evaluation & replacement logic
    [simState, clog_event, filter_cost] = evaluateFilterLife(simState, darcyParams, economicParams);
    if clog_event
        hourlyAccumulators.clog_event_hour = true;
        hourlyAccumulators.cost_filter_hour = hourlyAccumulators.cost_filter_hour + filter_cost;
    end
    
    % 7. Energy & cost accumulation for this second
    [E_blower_second, P_blower] = calculateBlowerEnergy(simState, Q_m3s, timeParams);
    hourlyAccumulators.E_blower_hour = hourlyAccumulators.E_blower_hour + E_blower_second;
    
    E_cond_second = calculateConditioningEnergy(Q_m3s, houseParams.T_in_C, T_out_C, rho_out, economicParams, timeParams);
    hourlyAccumulators.E_cond_hour = hourlyAccumulators.E_cond_hour + E_cond_second;
    
    % 8. Indoor PM mass-balance (well-mixed, explicit)
    C_prev = updateIndoorPM(C_prev, Q_m3s, C_out_PM_hr, houseParams, guiParams, particleParams, timeParams);
end

% Set the final PM concentration for this hour
simState.C_indoor_PM_hour = C_prev;
end

function effectiveC = calculateEffectiveLeakage(guiParams)
% Calculate effective leakage coefficient from blower door test
n_leak = 0.65;  % Typical leakage exponent

if ~isfield(guiParams, 'blowerDoor') || isnan(guiParams.blowerDoor) || guiParams.blowerDoor <= 0
    fprintf('[calculateEffectiveLeakage] WARNING: Invalid blowerDoor value, using default\n');
    guiParams.blowerDoor = 1150;
end

% Ensure n_leak is in a safe range to prevent numerical issues
n_leak = max(0.1, min(0.9, n_leak));  % Keep between 0.1 and 0.9

effectiveC = guiParams.blowerDoor / (50^n_leak);  % CFM / Pa^n

% Ensure effectiveC is reasonable
if effectiveC <= 0 || isnan(effectiveC) || isinf(effectiveC)
    fprintf('[calculateEffectiveLeakage] WARNING: Invalid effective leakage coefficient, using default\n');
    effectiveC = 20;  % Default safe value
end
end

function Q_m3s = convertFlowToCubicMetersPerSecond(Q_cfm)
% Convert flow from CFM to cubic meters per second
Q_m3s = Q_cfm * 0.000471947;  % CFM -> m3/s

% Validate
if isnan(Q_m3s) || Q_m3s < 0 || Q_m3s > 1
    warning('Invalid Q_m3s: %.6f, using safe value', Q_m3s);
    Q_m3s = max(0, min(1, Q_cfm * 0.000471947));
end
end