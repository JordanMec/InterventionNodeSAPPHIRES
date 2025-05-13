function pidParams = initPidParams()
% =========================================================================
% initPidParams.m - Initialize PID Controller Parameters
% =========================================================================
% Description:
%   This function initializes the parameters for the PID controller that
%   regulates the wiper position to maintain the target house pressure.
%   These parameters determine how the controller responds to pressure
%   deviations.
%
% Inputs:
%   None
%
% Outputs:
%   pidParams - Structure containing PID controller parameters:
%     - Kp: Proportional gain
%     - Ki: Integral gain
%     - Kd: Derivative gain
%     - min_wiper: Minimum wiper position (0-128)
%     - max_wiper: Maximum wiper position (0-128)
%
% Related files:
%   - runPidController.m: Uses these parameters to adjust wiper position
%   - innerLoop.m: Calls the PID controller during simulation
%
% Notes:
%   - Higher Kp values provide faster response but may cause oscillation
%   - Ki helps eliminate steady-state error but may cause overshoot
%   - Kd helps dampen oscillations but may amplify noise
%   - Wiper position is bound between min_wiper and max_wiper
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[initPidParams] Initializing PID parameters\n');

try
    % Create the parameters structure
    pidParams = struct();
    
    % PID controller gains
    pidParams.Kp = 30;    % Proportional gain
    pidParams.Ki = 0.05;  % Integral gain
    pidParams.Kd = 1;     % Derivative gain
    
    % Wiper position limits
    pidParams.min_wiper = 0;    % Minimum wiper position (0-128)
    pidParams.max_wiper = 128;  % Maximum wiper position (0-128)
    
    fprintf('[initPidParams] PID parameters initialized successfully\n');
catch ME
    % Handle errors
    fprintf('[ERROR] in initPidParams: %s\n', ME.message);
    
    % Return minimal default values to allow simulation to continue
    pidParams = struct('Kp', 30, 'Ki', 0.05, 'Kd', 1);
    pidParams.min_wiper = 0;
    pidParams.max_wiper = 128;
    
    fprintf('[initPidParams] Created minimal defaults due to error\n');
end
end