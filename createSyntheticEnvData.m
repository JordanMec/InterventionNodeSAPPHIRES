function env = createSyntheticEnvData()
% Create synthetic environment data for testing when actual data is unavailable

fprintf('[createSyntheticEnvData] Creating synthetic environment data\n');

try
    % Create one full year of hourly data
    numHours = 8760;  % hours in a year
    startDate = datetime('now') - days(365);
    dateVec = startDate + hours(0:(numHours-1));
    
    % Create table
    env = table();
    env.DateTime = dateVec(:);
    
    % Temperature with seasonal variation (F)
    dayOfYear = day(dateVec, 'dayofyear');
    hourOfDay = hour(dateVec);
    
    % Base temperature + seasonal variation + daily variation
    baseTemp = 60;  % F
    seasonalAmp = 30;  % F
    dailyAmp = 15;  % F
    
    seasonal = seasonalAmp * sin(2*pi*dayOfYear/365 - pi/2);  % Coldest in winter
    daily = dailyAmp * sin(2*pi*hourOfDay/24 - pi/2);  % Coldest at night
    
    env.TempF = baseTemp + seasonal + daily + 5*randn(numHours, 1);
    
    % Relative humidity (0-1)
    env.RH = 0.5 + 0.2*sin(2*pi*dayOfYear/365) + 0.1*randn(numHours, 1);
    env.RH = min(max(env.RH, 0.1), 0.95);  % Keep between 10-95%
    
    % Particulate matter concentrations (µg/m^3)
    % Base values with some daily and seasonal variations
    base_PM = [15, 10, 7, 5, 2, 1];  % Base values for each PM size
    
    % Create PM columns
    env.PM0_3 = base_PM(1) + 5*sin(2*pi*dayOfYear/365) + 2*sin(2*pi*hourOfDay/24) + 3*rand(numHours, 1);
    env.PM0_5 = base_PM(2) + 3*sin(2*pi*dayOfYear/365) + 1.5*sin(2*pi*hourOfDay/24) + 2*rand(numHours, 1);
    env.PM1   = base_PM(3) + 2*sin(2*pi*dayOfYear/365) + sin(2*pi*hourOfDay/24) + 1.5*rand(numHours, 1);
    env.PM2_5 = base_PM(4) + 1.5*sin(2*pi*dayOfYear/365) + 0.8*sin(2*pi*hourOfDay/24) + rand(numHours, 1);
    env.PM5   = base_PM(5) + sin(2*pi*dayOfYear/365) + 0.5*sin(2*pi*hourOfDay/24) + 0.5*rand(numHours, 1);
    env.PM10  = base_PM(6) + 0.5*sin(2*pi*dayOfYear/365) + 0.3*sin(2*pi*hourOfDay/24) + 0.3*rand(numHours, 1);
    
    % Ensure non-negative values
    pmCols = {'PM0_3', 'PM0_5', 'PM1', 'PM2_5', 'PM5', 'PM10'};
    for i = 1:length(pmCols)
        env.(pmCols{i}) = max(0, env.(pmCols{i}));
    end
    
    fprintf('[createSyntheticEnvData] Synthetic environment data created with %d hours\n', numHours);
catch ME
    fprintf('[ERROR] in createSyntheticEnvData: %s\n', ME.message);
    % Create minimal fallback data (24 hours)
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