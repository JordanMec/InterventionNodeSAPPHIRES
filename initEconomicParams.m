function economicParams = initEconomicParams()
% =========================================================================
% initEconomicParams.m - Initialize Economic Parameters
% =========================================================================
% Description:
%   This function initializes the economic parameters used for calculating
%   operation costs in the simulation. These include energy rates, 
%   equipment efficiencies, and maintenance costs.
%
% Inputs:
%   None
%
% Outputs:
%   economicParams - Structure containing economic parameters:
%     - filter_replacement_cost: Cost to replace a filter ($)
%     - on_peak_rate: On-peak electricity rate ($/kWh)
%     - off_peak_rate: Off-peak electricity rate ($/kWh)
%     - gas_efficiency: Heating system efficiency (fraction)
%     - gas_cost_per_J: Natural gas cost per Joule ($/J)
%     - COP_cooling: Coefficient of performance for cooling system
%
% Related files:
%   - calculateHourlyCosts.m: Uses these parameters to calculate operating costs
%   - evaluateFilterLife.m: Uses filter_replacement_cost for maintenance costs
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[initEconomicParams] Initializing economic parameters\n');

try
    % Create the parameters structure
    economicParams = struct();
    
    % Maintenance costs
    economicParams.filter_replacement_cost = 100;  % Cost to replace a filter ($)
    
    % Electricity rates
    economicParams.on_peak_rate = 0.3047;   % On-peak electricity rate ($/kWh)
    economicParams.off_peak_rate = 0.0846;  % Off-peak electricity rate ($/kWh)
    
    % Heating parameters
    economicParams.gas_efficiency = 0.90;   % Heating system efficiency (fraction)
    economicParams.gas_cost_per_J = 1e-8;   % Natural gas cost per Joule ($/J)
    
    % Cooling parameters
    economicParams.COP_cooling = 3.0;       % Coefficient of performance for cooling
    
    fprintf('[initEconomicParams] Economic parameters initialized successfully\n');
catch ME
    % Handle errors
    fprintf('[ERROR] in initEconomicParams: %s\n', ME.message);
    
    % Return minimal default values to allow simulation to continue
    economicParams = struct('filter_replacement_cost', 100, 'on_peak_rate', 0.3047);
    economicParams.off_peak_rate = 0.0846;
    economicParams.gas_efficiency = 0.90;
    economicParams.gas_cost_per_J = 1e-8;
    economicParams.COP_cooling = 3.0;
    
    fprintf('[initEconomicParams] Created minimal defaults due to error\n');
end
end