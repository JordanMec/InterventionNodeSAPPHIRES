function economicParams = initEconomicParams()
% Initialize economic and utility rate parameters

fprintf('[initEconomicParams] Initializing economic parameters\n');
try
    economicParams = struct();
    economicParams.filter_replacement_cost = 100;  % [$] cost of one filter change
    economicParams.on_peak_rate  = 0.3047;         % $/kWh during on-peak
    economicParams.off_peak_rate = 0.0846;         % $/kWh off-peak
    economicParams.gas_efficiency = 0.90;          % furnace thermal efficiency
    economicParams.gas_cost_per_J = 1e-8;          % $/J for natural gas
    economicParams.COP_cooling    = 3.0;           % electric cooling coefficient of performance
    
    fprintf('[initEconomicParams] Economic parameters initialized successfully\n');
catch ME
    fprintf('[ERROR] in initEconomicParams: %s\n', ME.message);
    % Create minimal default parameters
    economicParams = struct('filter_replacement_cost', 100, 'on_peak_rate', 0.3047);
end
end