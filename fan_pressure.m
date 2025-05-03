function dP = fan_pressure(Q, wiper)
% Return the blower's static-pressure capability (Pa) at flow Q (CFM)
% for the current wiper (0-128). Linear interpolation of a measured
% eight-point fan curve, then scaled by PWM duty-cycle.
%
% Inputs
%   Q      - volumetric flow, CFM
%   wiper  - PWM duty-cycle (0-128)
%
% Output
%   dP     - fan static pressure, Pa

try
    % Input validation
    if ~isnumeric(Q) || ~isnumeric(wiper)
        error('Invalid input types: Q and wiper must be numeric');
    end
    
    % Protect against negative or NaN values
    Q = max(0, Q);
    if isnan(Q)
        warning('NaN detected in fan_pressure Q input, using 0');
        Q = 0;
    end
    
    wiper = max(0, min(128, wiper));
    if isnan(wiper)
        warning('NaN detected in fan_pressure wiper input, using 0');
        wiper = 0;
    end
    
    fixed_flow_rate = [1237,1156,1079,997,900,769,118,0];   % CFM
    fixed_pres      = [0,49.8,99.5,149,199,248.8,374,399];  % Pa

    dP_clean = interp1(fixed_flow_rate, fixed_pres, Q, 'linear', 'extrap');
    dP       = (wiper/128) .* dP_clean;
    
    % Validate output
    if isnan(dP)
        warning('NaN detected in fan_pressure output, using 0');
        dP = 0;
    end
catch ME
    fprintf('[ERROR] in fan_pressure: %s\n', ME.message);
    dP = 0;  % Default to 0 pressure to prevent simulation crash
end
end