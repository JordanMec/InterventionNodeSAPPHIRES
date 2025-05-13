function [T_outdoor_F, RH_outdoor, C_out_PM_hr, hr_of_day] = getHourlyEnvironment(env, h, particleParams)
% =========================================================================
% getHourlyEnvironment.m - Retrieve Hourly Environmental Conditions
% =========================================================================
% Description:
%   This function retrieves the environmental conditions (temperature,
%   humidity, particulate matter concentrations) for a specific hour from
%   the environment data. It handles data validation and provides defaults
%   for missing or invalid values.
%
% Inputs:
%   env            - Table/timetable with environmental data
%   h              - Hour index to retrieve
%   particleParams - Structure with particle size parameters
%
% Outputs:
%   T_outdoor_F    - Outdoor temperature (°F)
%   RH_outdoor     - Outdoor relative humidity (0-1)
%   C_out_PM_hr    - Outdoor PM concentrations by size bin (μg/m³)
%   hr_of_day      - Hour of day (0-23)
%
% Related files:
%   - runSimulation.m: Calls this function for each simulation hour
%   - createSyntheticEnvData.m: Creates env data if not loaded from file
%
% Notes:
%   - The particleParams.numSizes determines the length of C_out_PM_hr
%   - If data is missing or invalid, reasonable defaults are provided
%   - Hour of day is used for determining exhaust fan operation
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Define default values in case of missing or invalid data
default_temp = 70;       % Default temperature (°F)
default_RH = 0.5;        % Default relative humidity (50%)
default_PM_base = 10;    % Default base PM concentration (μg/m³)

try
    % Check if requested hour is within available data range
    if h <= height(env) && width(env) >= 3
        % Get outdoor temperature
        T_outdoor_F = env.TempF(h);
        if isnan(T_outdoor_F) || T_outdoor_F < -100 || T_outdoor_F > 150
            fprintf('[getHourlyEnvironment] WARNING: Invalid outdoor temperature at hour %d: %.1f F\n', h, T_outdoor_F);
            T_outdoor_F = default_temp;
        end
        
        % Get relative humidity
        RH_outdoor = env.RH(h);
        if isnan(RH_outdoor) || RH_outdoor < 0 || RH_outdoor > 1
            fprintf('[getHourlyEnvironment] WARNING: Invalid RH at hour %d: %.2f\n', h, RH_outdoor);
            RH_outdoor = default_RH;
        end
        
        % Get PM concentrations
        C_out_PM_hr = extractPMConcentrations(env, h, particleParams.numSizes, default_PM_base);
        
        % Determine hour of day
        hr_of_day = determineHourOfDay(env, h);
    else
        % Hour is beyond available data range, use defaults
        fprintf('[getHourlyEnvironment] WARNING: Hour %d is beyond available data. Using defaults.\n', h);
        T_outdoor_F = default_temp;
        RH_outdoor = default_RH;
        C_out_PM_hr = ones(1, particleParams.numSizes) * 5;
        hr_of_day = mod(h-1, 24);
    end
catch ME
    % Handle any errors with defaults
    fprintf('[getHourlyEnvironment] ERROR: %s\n', ME.message);
    T_outdoor_F = default_temp;
    RH_outdoor = default_RH;
    C_out_PM_hr = ones(1, particleParams.numSizes) * 5;
    hr_of_day = mod(h-1, 24);
end
end

% Helper function to extract PM concentrations from environment data
function C_out_PM_hr = extractPMConcentrations(env, h, numSizes, default_PM_base)
    C_out_PM_hr = zeros(1, numSizes);
    
    for i = 1:numSizes
        colIdx = 3 + i;  % PM columns assumed to start after DateTime, TempF, RH
        
        if colIdx <= width(env)
            try
                % Handle cell array or direct value
                if iscell(env{h, colIdx})
                    val = env{h, colIdx}{1}; 
                else
                    val = env{h, colIdx};
                end
                
                % Validate the value
                if isnumeric(val) && isscalar(val) && ~isnan(val) && val >= 0
                    C_out_PM_hr(i) = val;
                else
                    C_out_PM_hr(i) = default_PM_base / (i + 0.1);
                    fprintf('[extractPMConcentrations] WARNING: Invalid PM data for size %d, using default\n', i);
                end
            catch
                C_out_PM_hr(i) = default_PM_base / (i + 0.1);
                fprintf('[extractPMConcentrations] ERROR reading PM data for size %d, using default\n', i);
            end
        else
            C_out_PM_hr(i) = default_PM_base / (i + 0.1);
        end
    end
end

% Helper function to determine the hour of day
function hr_of_day = determineHourOfDay(env, h)
    try
        if isdatetime(env.DateTime(h))
            hr_of_day = hour(env.DateTime(h));
        else
            hr_of_day = mod(h-1, 24);
        end
    catch
        hr_of_day = mod(h-1, 24);
    end
end