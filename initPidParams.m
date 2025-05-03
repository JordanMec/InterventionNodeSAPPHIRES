function pidParams = initPidParams()
% Initialize PID controller parameters

fprintf('[initPidParams] Initializing PID parameters\n');
try
    pidParams = struct();
    pidParams.Kp = 30;          % proportional [PWM/Pa]
    pidParams.Ki = 0.05;        % integral     [PWM/(Pa*s)]
    pidParams.Kd = 1;           % derivative   [PWM*s/Pa]
    
    pidParams.min_wiper = 0;    % PWM lower limit
    pidParams.max_wiper = 128;  % PWM upper limit (100 %)
    
    fprintf('[initPidParams] PID parameters initialized successfully\n');
catch ME
    fprintf('[ERROR] in initPidParams: %s\n', ME.message);
    % Create minimal default parameters
    pidParams = struct('Kp', 30, 'Ki', 0.05, 'Kd', 1);
end
end