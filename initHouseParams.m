function houseParams = initHouseParams()
% =========================================================================
% initHouseParams.m - Initialize House Parameters
% =========================================================================
% Description:
%   This function initializes the parameters that describe the house
%   characteristics for the simulation. These include dimensions,
%   temperature settings, and exhaust flow rates.
%
% Inputs:
%   None
%
% Outputs:
%   houseParams - Structure containing house parameters:
%     - exhaust_flow: Exhaust fan flow rate (CFM)
%     - floor_area: House floor area (m²)
%     - ceiling_height: Ceiling height (m)
%     - V_indoor: Indoor air volume (m³)
%     - T_in_F: Indoor temperature (°F)
%     - T_in_C: Indoor temperature (°C)
%     - T_in_K: Indoor temperature (K)
%
% Related files:
%   - determineExhaustState.m: Uses exhaust_flow for meal-time exhaust fans
%   - calculateStackEffect.m: Uses indoor temperature and volume 
%   - updateIndoorPM.m: Uses indoor volume for air quality calculations
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[initHouseParams] Initializing house parameters\n');

try
    % Create the parameters structure
    houseParams = struct();
    
    % Ventilation parameters
    houseParams.exhaust_flow = 150;     % Exhaust fan flow rate (CFM)
    
    % House dimensions
    houseParams.floor_area = 232.2576;      % Floor area (m²) [2500 ft²]
    houseParams.ceiling_height = 2.4384;    % Ceiling height (m) [8 ft]
    
    % Calculate indoor air volume
    houseParams.V_indoor = houseParams.floor_area * houseParams.ceiling_height; 
    
    % Indoor temperature settings
    houseParams.T_in_F = 68;                          % Indoor temperature (°F)
    houseParams.T_in_C = (houseParams.T_in_F-32)*5/9; % Indoor temperature (°C)
    houseParams.T_in_K = houseParams.T_in_C + 273.15; % Indoor temperature (K)
    
    fprintf('[initHouseParams] House parameters initialized successfully. Volume = %.1f m3\n', houseParams.V_indoor);
catch ME
    % Handle errors
    fprintf('[ERROR] in initHouseParams: %s\n', ME.message);
    
    % Return minimal default values to allow simulation to continue
    houseParams = struct('exhaust_flow', 150, 'V_indoor', 500, 'T_in_K', 293.15);
    houseParams.T_in_F = 68;
    houseParams.T_in_C = 20;
    houseParams.floor_area = 232;
    houseParams.ceiling_height = 2.4;
    
    fprintf('[initHouseParams] Created minimal defaults due to error\n');
end
end