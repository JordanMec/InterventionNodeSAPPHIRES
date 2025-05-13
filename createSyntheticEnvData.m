function env = createSyntheticEnvData()
% =========================================================================
% createSyntheticEnvData.m - Create Synthetic Environmental Data
% =========================================================================
% Description:
%   This function creates synthetic environmental data when measured data
%   is unavailable. It generates realistic temperature, humidity, and
%   particulate matter concentration patterns with daily and seasonal
%   variations.
%
% Inputs:
%   None
%
% Outputs:
%   env - Table with synthetic environmental data including:
%         - DateTime: Date and time
%         - TempF: Temperature (°F)
%         - RH: Relative humidity (0-1)
%         - PM0_3 through PM10: PM concentrations by size (μg/m³)
%
% Related files:
%   - godMode.m: Calls this function when real data cannot be loaded
%   - getHourlyEnvironment.m: Uses the generated data during simulation
%
% Notes:
%   - Creates a full year (8760 hours) of synthetic data
%   - Includes realistic seasonal and daily patterns
%   - Temperature follows seasonal sine wave with daily fluctuations
%   - PM concentrations follow seasonal patterns with random variations
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[createSyntheticEnvData] Creating synthetic environment data\n');

try
    % Create one year of hourly data (8760 hours)
    numHours = 8760;
    
    % Create date vector starting from current date
    startDate = datetime('now') - days(365);
    dateVec = startDate + hours(0:(numHours-1));
    
    % Initialize the environment data table
    env = table();
    env.DateTime = dateVec(:);
    
    % Extract day of year and hour of day for pattern generation
    dayOfYear = day(dateVec, 'dayofyear');
    hourOfDay = hour(dateVec);
    
    % Generate synthetic temperature with seasonal and daily patterns
    baseTemp = 60;     % Annual average temperature (°F)
    seasonalAmp = 30;  % Seasonal temperature amplitude (°F)
    dailyAmp = 15;     % Daily temperature amplitude (°F)
    
    % Create temperature patterns:
    % - Seasonal cycle (sine wave with 365-day period, coldest in winter)
    % - Daily cycle (sine wave with 24-hour period, coolest before dawn)
    % - Random variation (Gaussian noise)
    seasonal = seasonalAmp * sin(2*pi*dayOfYear/365 - pi/2);  % Coldest at day 0 (Jan 1)
    daily = dailyAmp * sin(2*pi*hourOfDay/24 - pi/2);        % Coolest at hour 0 (midnight)
    env.TempF = baseTemp + seasonal + daily + 5*randn(numHours, 1);
    
    % Generate synthetic relative humidity with seasonal pattern
    env.RH = 0.5 + 0.2*sin(2*pi*dayOfYear/365) + 0.1*randn(numHours, 1);
    env.RH = min(max(env.RH, 0.1), 0.95);  % Bound between 10% and 95%
    
    % Base PM concentrations by size (μg/m³)
    base_PM = [15, 10, 7, 5, 2, 1];  % PM0_3, PM0_5, PM1, PM2_5, PM5, PM10
    
    % Generate synthetic PM concentrations with seasonal and daily patterns
    env.PM0_3 = base_PM(1) + 5*sin(2*pi*dayOfYear/365) + 2*sin(2*pi*hourOfDay/24) + 3*rand(numHours, 1);
    env.PM0_5 = base_PM(2) + 3*sin(2*pi*dayOfYear/365) + 1.5*sin(2*pi*hourOfDay/24) + 2*rand(numHours, 1);
    env.PM1   = base_PM(3) + 2*sin(2*pi*dayOfYear/365) + sin(2*pi*hourOfDay/24) + 1.5*rand(numHours, 1);
    env.PM2_5 = base_PM(4) + 1.5*sin(2*pi*dayOfYear/365) + 0.8*sin(2*pi*hourOfDay/24) + rand(numHours, 1);
    env.PM5   = base_PM(5) + sin(2*pi*dayOfYear/365) + 0.5*sin(2*pi*hourOfDay/24) + 0.5*rand(numHours, 1);
    env.PM10  = base_PM(6) + 0.5*sin(2*pi*dayOfYear/365) + 0.3*sin(2*pi*hourOfDay/24) + 0.3*rand(numHours, 1);
    
    % Ensure all PM values are non-negative
    pmCols = {'PM0_3', 'PM0_5', 'PM1', 'PM2_5', 'PM5', 'PM10'};
    for i = 1:length(pmCols)
        env.(pmCols{i}) = max(0, env.(pmCols{i}));
    end
    
    fprintf('[createSyntheticEnvData] Synthetic environment data created with %d hours\n', numHours);
catch ME
    % Create minimal 24-hour fallback data if full generation fails
    fprintf('[ERROR] in createSyntheticEnvData: %s\n', ME.message);
    
    env = table();
    env.DateTime = (datetime('now') + hours(0:23))';
    env.TempF = 70 + 10*sin((0:23)/24*2*pi)';
    env.RH = 0.5 + 0.1*sin((0:23)/24*2*pi)';
    env.PM0_3 = 10 + 5*rand(24, 1);
    env.PM0_5 = 8 + 4*rand(24, 1);
    env.PM1 = 5 + 3*rand(24, 1);
    env.PM2_5 = 3 + 2*rand(24, 1);
    env.PM5 = 1 + rand(24, 1);
    env.PM10 = 0.5 + 0.5*rand(24, 1);
    
    fprintf('[createSyntheticEnvData] Created minimal 24-hour fallback data\n');
end
end