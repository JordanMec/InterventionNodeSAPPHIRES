function [rho_out, T_out_K, T_out_C] = calculateAirProperties(T_outdoor_F)
% =========================================================================
% calculateAirProperties.m - Calculate Air Properties
% =========================================================================
% Description:
%   This function calculates various air properties based on the outdoor
%   temperature. It converts temperature between different units and
%   calculates air density using the ideal gas law.
%
% Inputs:
%   T_outdoor_F - Outdoor temperature (°F)
%
% Outputs:
%   rho_out    - Outdoor air density (kg/m³)
%   T_out_K    - Outdoor temperature (K)
%   T_out_C    - Outdoor temperature (°C)
%
% Related files:
%   - runSimulation.m: Calls this function for each simulation hour
%   - calculateStackEffect.m: Uses air density and temperature in calculations
%   - calculateConditioningEnergy.m: Uses temperature for energy calculations
%
% Notes:
%   - Uses the ideal gas law to calculate air density
%   - Assumes standard atmospheric pressure (101325 Pa)
%   - Specific gas constant for dry air: 287 J/(kg·K)
%   - Converting between temperature units:
%     * °C = (°F - 32) × 5/9
%     * K = °C + 273.15
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Convert temperature from Fahrenheit to Celsius
T_out_C = (T_outdoor_F - 32) * 5/9;

% Convert temperature from Celsius to Kelvin
T_out_K = T_out_C + 273.15;

try
    % Calculate air density using the ideal gas law: ρ = P/(R·T)
    % P = 101325 Pa (standard atmospheric pressure)
    % R = 287 J/(kg·K) (specific gas constant for dry air)
    % T = temperature in Kelvin
    rho_out = 101325 ./ (287 * T_out_K);
    
    % Validate the result
    if isnan(rho_out) || rho_out <= 0 || rho_out > 2
        fprintf('[calculateAirProperties] WARNING: Invalid air density calculated. Using default.\n');
        rho_out = 1.2;  % Default air density at standard conditions (kg/m³)
    end
catch
    % Use default air density if calculation fails
    rho_out = 1.2;  % Default air density at standard conditions (kg/m³)
    fprintf('[calculateAirProperties] ERROR in density calculation. Using default.\n');
end
end