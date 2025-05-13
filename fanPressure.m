function dP = fanPressure(Q, wiper)
% =========================================================================
% fanPressure.m - Calculate Fan Pressure
% =========================================================================
% Description:
%   This function calculates the pressure developed by the fan based on
%   flow rate and wiper position (speed control). It uses interpolation
%   of manufacturer fan curve data to determine pressure at any flow point.
%
% Inputs:
%   Q      - Flow rate (CFM)
%   wiper  - Wiper position (0-128), controlling fan speed
%
% Outputs:
%   dP     - Fan pressure (Pa)
%
% Related files:
%   - solveFlowBalance.m: Uses this to find system operating point
%   - runPidController.m: Adjusts wiper position to control pressure
%   - safeBalanceFunction.m: Compares fan pressure to system losses
%
% Notes:
%   - Fan curves typically show pressure decreasing as flow increases
%   - The wiper position (0-128) linearly scales the fan curve
%   - At wiper=0, fan is off (0 pressure)
%   - At wiper=128, fan operates at full speed
%   - Based on typical ECM blower performance data
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

try
    % Input type validation
    if ~isnumeric(Q) || ~isnumeric(wiper)
        error('Invalid input types: Q and wiper must be numeric');
    end
    
    % Flow rate validation
    Q = max(0, Q);
    if isnan(Q)
        warning('NaN detected in fan_pressure Q input, using 0');
        Q = 0;
    end
    
    % Wiper position validation
    wiper = max(0, min(128, wiper));
    if isnan(wiper)
        warning('NaN detected in fan_pressure wiper input, using 0');
        wiper = 0;
    end
    
    % Fan curve data points (flow in CFM, pressure in Pa)
    % These represent the fan curve at maximum speed (wiper = 128)
    fixed_flow_rate = [1237, 1156, 1079, 997, 900, 769, 118, 0];
    fixed_pres      = [0, 49.8, 99.5, 149, 199, 248.8, 374, 399];
    
    % Interpolate to find pressure at the specified flow rate
    dP_clean = interp1(fixed_flow_rate, fixed_pres, Q, 'linear', 'extrap');
    
    % Scale by wiper position (0-128)
    dP = (wiper/128) .* dP_clean;
    
    % Final validation
    if isnan(dP)
        warning('NaN detected in fan_pressure output, using 0');
        dP = 0;
    end
    
catch ME
    % Handle all errors
    fprintf('[ERROR] in fan_pressure: %s\n', ME.message);
    dP = 0;
end
end