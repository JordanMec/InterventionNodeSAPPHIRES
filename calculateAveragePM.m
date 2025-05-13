function C_in_avg = calculateAveragePM(C_indoor_PM, hours_to_average)
% =========================================================================
% calculateAveragePM.m - Calculate Average PM Concentrations
% =========================================================================
% Description:
%   This function calculates the average particulate matter (PM)
%   concentrations over a specified time period. It is useful for
%   analyzing time-averaged exposure or comparing with air quality
%   standards that use averaging periods.
%
% Inputs:
%   C_indoor_PM     - Matrix of indoor PM concentrations [hours x sizes]
%   hours_to_average - Number of recent hours to include in average
%
% Outputs:
%   C_in_avg        - Average PM concentrations by size bin (μg/m³)
%
% Related files:
%   - postProcessResults.m: Could use this for summary statistics
%   - visualizeResults.m: Could use this for time-averaged plots
%
% Notes:
%   - Common averaging periods in air quality standards:
%     * 1-hour averages for acute exposure
%     * 8-hour averages for workday exposure
%     * 24-hour averages for daily exposure
%     * Annual averages for chronic exposure
%   - Function averages the most recent hours in the time series
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Get dimensions of the PM concentration matrix
[num_hours, num_sizes] = size(C_indoor_PM);

% Calculate the starting hour for averaging
start_hour = max(1, num_hours - hours_to_average + 1);

% Define the range of hours to include in average
hours_range = start_hour:num_hours;

% Initialize output array
C_in_avg = zeros(1, num_sizes);

% Calculate average for each size bin
for i = 1:num_sizes
    C_in_avg(i) = mean(C_indoor_PM(hours_range, i));
end

% Handle NaN values
C_in_avg(isnan(C_in_avg)) = 0;

% Ensure all values are non-negative
C_in_avg = max(0, C_in_avg);
end