function simState = updateHousePressure(simState, Q_stack, Q_exhaust_fixed, effectiveC, timeParams)
% =========================================================================
% updateHousePressure.m - Update House Pressure
% =========================================================================
% Description:
%   This function updates the house pressure based on the balance of
%   incoming and outgoing airflows. It uses a mass balance approach,
%   considering blower flow, stack effect, exhaust fans, and leakage.
%
% Inputs:
%   simState         - Current simulation state containing actual_pressure and Q_blower
%   Q_stack          - Stack effect flow rate (CFM)
%   Q_exhaust_fixed  - Exhaust fan flow rate (CFM)
%   effectiveC       - Effective leakage coefficient
%   timeParams       - Timing parameters including dt_ctrl
%
% Outputs:
%   simState         - Updated simulation state with new pressure
%
% Related files:
%   - innerLoop.m: Calls this function to update house pressure
%   - calculateStackEffect.m: Provides stack effect flow input
%   - solveFlowBalance.m: Updates blower flow based on previous pressure
%
% Notes:
%   - Positive pressure indicates air flowing from inside to outside
%   - Flow balance: Q_blower + Q_stack - Q_exhaust - Q_leak = net flow
%   - Pressure changes based on net flow and building air volume
%   - Rate limiting is applied to prevent numerical instability
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Constants
n_leak = 0.65;    % Leakage exponent

% Better pressure validation and limiting
if isnan(simState.actual_pressure)
    fprintf('[updateHousePressure] WARNING: NaN pressure detected. Resetting to 0.\n');
    simState.actual_pressure = 0;
end

% Calculate leak flow with protection for extreme pressure
if abs(simState.actual_pressure) > 50
    fprintf('[updateHousePressure] WARNING: Extreme pressure detected (%.1f Pa). Clamping.\n', ...
           simState.actual_pressure);
    simState.actual_pressure = sign(simState.actual_pressure) * 50;
end

% More robust leak flow calculation
try
    Q_leak = effectiveC * abs(simState.actual_pressure)^n_leak;
    
    % Validate leak flow
    if isnan(Q_leak) || isinf(Q_leak) || Q_leak < 0 || Q_leak > 5000
        warning('Invalid leak flow calculated: %.2f, using fallback', Q_leak);
        Q_leak = 20 * abs(simState.actual_pressure)^0.65;  % Simple fallback model
    end
    
    leak_effect = sign(simState.actual_pressure) * Q_leak;
catch
    warning('Error in leak flow calculation, using zero');
    leak_effect = 0;
end

% More robust flow balance calculation
Q_net_m3s = (simState.Q_blower + Q_stack - Q_exhaust_fixed - leak_effect) ...
            * 0.000471947;  % Convert CFM to m3/s

% Validate the net flow
if isnan(Q_net_m3s) || isinf(Q_net_m3s) || abs(Q_net_m3s) > 1
    warning('Invalid net flow: %.6f m3/s, using zero', Q_net_m3s);
    Q_net_m3s = 0;
end

% Update pressure with rate limiting to prevent instability
pressure_change = timeParams.dt_ctrl * Q_net_m3s * 10;  % Scale factor to convert flow to pressure rate
max_allowed_change = 0.2;  % Pa per second max (reduced from 0.5)

pressure_change = sign(pressure_change) * ...
                 min(abs(pressure_change), max_allowed_change);

simState.actual_pressure = simState.actual_pressure + pressure_change;

% Tighter limit pressure to realistic range to prevent instabilities
simState.actual_pressure = max(-30, min(30, simState.actual_pressure));
end