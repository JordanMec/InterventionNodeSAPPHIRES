function simState = runPidController(simState, guiParams, timeParams, pidParams)
% =========================================================================
% runPidController.m - PID Controller for Wiper Position
% =========================================================================
% Description:
%   This function implements a PID (Proportional-Integral-Derivative)
%   controller to adjust the wiper position based on the error between
%   target pressure and actual pressure. It aims to maintain the house
%   at the desired pressure setpoint.
%
% Inputs:
%   simState   - Current simulation state (contains actual_pressure, wiper, etc.)
%   guiParams  - GUI/user parameters (contains targetPressure)
%   timeParams - Timing parameters (contains dt_ctrl)
%   pidParams  - PID controller parameters (Kp, Ki, Kd)
%
% Outputs:
%   simState   - Updated simulation state with new wiper position
%
% Related files:
%   - innerLoop.m: Calls this function during simulation
%   - initPidParams.m: Defines PID controller parameters
%   - fanPressure.m: Uses wiper position to determine fan pressure
%
% Notes:
%   - PID control is a common feedback control method:
%     * P term: Proportional to current error
%     * I term: Integrates error over time
%     * D term: Responds to rate of change of error
%   - Anti-windup measures are implemented to limit integral term
%   - Wiper position is bounded between 0 and 128
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Extract PID gains from parameters
Kp = pidParams.Kp;  % Proportional gain
Ki = pidParams.Ki;  % Integral gain
Kd = pidParams.Kd;  % Derivative gain

% Define wiper position limits
min_wiper = 0;    % Minimum wiper position
max_wiper = 128;  % Maximum wiper position

% Calculate error (difference between target and actual pressure)
if isnan(simState.actual_pressure)
    err = guiParams.targetPressure;  % If actual pressure is NaN, use target as error
else
    err = guiParams.targetPressure - simState.actual_pressure;
end

% Bound error to prevent extreme controller reactions
err = max(-10, min(10, err));

% Update integral term with anti-windup limiting
simState.integral_error = simState.integral_error + err*timeParams.dt_ctrl;
simState.integral_error = max(-3, min(3, simState.integral_error));  % Limit integral term

% Handle initialization of previous error
if isnan(simState.previous_error)
    simState.previous_error = err;
end

% Calculate derivative term with safety checks
if timeParams.dt_ctrl > 0
    deriv = (err - simState.previous_error)/timeParams.dt_ctrl;
    deriv = max(-10, min(10, deriv));  % Bound derivative to prevent spikes
else
    deriv = 0;
end

% Calculate PID control output
wiper_change = 0.05*(Kp*err + Ki*simState.integral_error + Kd*deriv);

% Limit rate of change to prevent destabilization
max_wiper_change = 3;  % Maximum change per control step
wiper_change = sign(wiper_change) * min(abs(wiper_change), max_wiper_change);

% Update wiper position
simState.wiper = simState.wiper + wiper_change;

% Bound wiper position to valid range
simState.wiper = max(min_wiper, min(max_wiper, simState.wiper));

% Store current error for next iteration's derivative calculation
simState.previous_error = err;
end