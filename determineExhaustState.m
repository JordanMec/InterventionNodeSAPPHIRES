function [exhaust_state_fixed, Q_exhaust_fixed] = determineExhaustState(guiParams, houseParams, hr_of_day)
% =========================================================================
% determineExhaustState.m - Determine Exhaust Fan State
% =========================================================================
% Description:
%   This function determines the state of the exhaust fan based on the
%   hour of day. It simulates meal-time exhaust fan operation (breakfast,
%   lunch, dinner) when enabled in the GUI parameters.
%
% Inputs:
%   guiParams   - GUI/user parameters (contains enableExhaustFan flag)
%   houseParams - House parameters (contains exhaust_flow rate)
%   hr_of_day   - Current hour of day (0-23)
%
% Outputs:
%   exhaust_state_fixed - Boolean indicating if exhaust fan is on
%   Q_exhaust_fixed     - Exhaust fan flow rate (CFM, 0 if off)
%
% Related files:
%   - runSimulation.m: Calls this function for each simulation hour
%   - updateHousePressure.m: Uses exhaust flow in pressure calculations
%   - initHouseParams.m: Defines exhaust fan flow rate
%
% Notes:
%   - Exhaust fan operates during typical meal times:
%     * Breakfast: 7:00 AM (hour 7)
%     * Lunch: 12:00 PM (hour 12)
%     * Dinner: 6:00 PM (hour 18)
%   - Fan can be disabled by setting enableExhaustFan to false
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Determine if current hour is a meal time hour
isExhaustFanHour = (hr_of_day == 7) || (hr_of_day == 12) || (hr_of_day == 18);

% Check if exhaust fan is enabled in GUI parameters and current hour is a meal time
if isfield(guiParams, 'enableExhaustFan') && guiParams.enableExhaustFan && isExhaustFanHour
    % Set exhaust fan to on state
    exhaust_state_fixed = true;
    
    % Get flow rate from house parameters with validation
    if isfield(houseParams, 'exhaust_flow') && ~isnan(houseParams.exhaust_flow) && houseParams.exhaust_flow > 0
        Q_exhaust_fixed = houseParams.exhaust_flow;  % CFM
    else
        % Use default if exhaust flow is invalid
        fprintf('[determineExhaustState] WARNING: Invalid exhaust flow, using default\n');
        Q_exhaust_fixed = 150;  % Default exhaust flow (CFM)
    end
else
    % Exhaust fan is off
    exhaust_state_fixed = false;
    Q_exhaust_fixed = 0;
end
end