function [Q_stack, DP_buoy] = calculateStackEffect(guiParams, T_in_K, T_out_K, rho_out, effectiveC)
% =========================================================================
% calculateStackEffect.m - Calculate Stack-Driven Airflow
% =========================================================================
% Description:
%   This function calculates the stack effect (buoyancy-driven airflow)
%   based on indoor and outdoor temperature differences. Stack effect
%   causes warm air to rise and exit through upper leaks in a building,
%   drawing in cooler air through lower leaks.
%
% Inputs:
%   guiParams   - Structure with GUI parameters, must include enableStackEffect
%   T_in_K      - Indoor temperature (Kelvin)
%   T_out_K     - Outdoor temperature (Kelvin)
%   rho_out     - Outdoor air density (kg/m³)
%   effectiveC  - Effective leakage coefficient
%
% Outputs:
%   Q_stack     - Stack-driven airflow (CFM)
%   DP_buoy     - Buoyancy pressure (Pa)
%
% Related files:
%   - innerLoop.m: Calls this function to calculate stack-driven flow
%   - updateHousePressure.m: Uses the stack flow in pressure calculations
%
% Notes:
%   - Stack effect is strongest when indoor-outdoor temperature difference is large
%   - Positive flow indicates air entering the building
%   - Negative flow indicates air leaving the building
%   - Stack effect is disabled if guiParams.enableStackEffect is false
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Initialize outputs
Q_stack = 0;
DP_buoy = 0;

% Constants
n_leak = 0.65;   % Leakage exponent
g = 9.81;        % Gravity (m/s²)

% Only proceed if stack effect is enabled
if isfield(guiParams, 'enableStackEffect') && guiParams.enableStackEffect
    % Validate T_in_K
    if isnan(T_in_K) || T_in_K <= 0
        T_in_K = 293.15;  % Default 20°C if invalid
    end
    
    % Check for temperature division by zero
    if T_out_K <= 0
        T_out_K = 273.15;  % Use freezing point as a safe default
    end
    
    % Calculate buoyancy pressure with validation
    try
        % Buoyancy pressure based on density difference
        % Assuming 3 meters for effective stack height
        DP_buoy = rho_out * g * 3 * (T_in_K/T_out_K - 1); % Pa
        
        % Validate the result
        if isnan(DP_buoy) || isinf(DP_buoy) || abs(DP_buoy) > 50
            DP_buoy = 0;  % Use zero for unrealistic values
        end
        
        % Calculate stack-driven flow rate
        Q_stack = sign(DP_buoy) * effectiveC * abs(DP_buoy)^n_leak;  % CFM
        
        % Validate stack flow
        if isnan(Q_stack) || isinf(Q_stack) || abs(Q_stack) > 1000
            Q_stack = 0;  % Use zero for unrealistic values
        end
    catch ME
        fprintf('[calculateStackEffect] Error: %s\n', ME.message);
        DP_buoy = 0;
        Q_stack = 0;
    end
end
end