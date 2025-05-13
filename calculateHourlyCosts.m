function [cost_blower_hour, cost_cond_hour] = calculateHourlyCosts(hourlyAccumulators, economicParams, hr_of_day, simState)
% =========================================================================
% calculateHourlyCosts.m - Calculate Hourly Energy and Operation Costs
% =========================================================================
% Description:
%   This function calculates the hourly costs for blower operation and
%   air conditioning/heating based on accumulated energy usage and 
%   time-of-use electricity rates.
%
% Inputs:
%   hourlyAccumulators - Structure with hourly energy accumulations
%   economicParams     - Structure with economic parameters
%   hr_of_day          - Hour of day (0-23) for time-of-use rates
%   simState           - Current simulation state
%
% Outputs:
%   cost_blower_hour   - Blower energy cost for this hour ($)
%   cost_cond_hour     - Conditioning energy cost for this hour ($)
%
% Related files:
%   - runSimulation.m: Calls this function after each inner loop
%   - initEconomicParams.m: Defines the economic parameters used here
%   - logHourlyData.m: Uses the calculated costs for logging
%
% Notes:
%   - Applies time-of-use electricity rates (on-peak vs. off-peak)
%   - On-peak hours: 12:00-20:00 (hours 12-19)
%   - Off-peak hours: All other hours
%   - Converts energy from J to kWh for cost calculations
%   - Heating uses gas cost model, cooling uses electricity
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Convert energy from J to kWh
E_blower_kWh = hourlyAccumulators.E_blower_hour / 3600000;  % J to kWh
E_cond_kWh = hourlyAccumulators.E_cond_hour / 3600000;      % J to kWh

% Determine electricity rate based on time of day (on-peak vs. off-peak)
% On-peak hours: 12:00-20:00 (hours 12-19)
is_peak_hour = (hr_of_day >= 12 && hr_of_day < 20);

if is_peak_hour
    elec_rate = economicParams.on_peak_rate;  % On-peak rate ($/kWh)
else
    elec_rate = economicParams.off_peak_rate; % Off-peak rate ($/kWh)
end

% Calculate blower cost (always uses electricity)
cost_blower_hour = E_blower_kWh * elec_rate;

% Calculate conditioning cost
% Heating (needs energy) when indoor temp > outdoor temp
% Cooling (needs energy) when indoor temp < outdoor temp
if isfield(simState, 'is_heating') && simState.is_heating
    % Heating mode - use gas cost model
    % Convert electrical equivalent to gas energy considering efficiency
    gas_energy = E_cond_kWh / economicParams.gas_efficiency;
    cost_cond_hour = gas_energy * economicParams.gas_cost_per_J * 3600000;
else
    % Cooling mode - use electricity with COP
    % COP = cooling output / electrical input
    electricity_energy = E_cond_kWh / economicParams.COP_cooling;
    cost_cond_hour = electricity_energy * elec_rate;
end

% Validate outputs (ensure non-negative, non-NaN)
if isnan(cost_blower_hour) || cost_blower_hour < 0
    cost_blower_hour = 0;
end

if isnan(cost_cond_hour) || cost_cond_hour < 0
    cost_cond_hour = 0;
end
end