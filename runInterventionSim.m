function results = runInterventionSim(hepaEnabled, envData)
% =========================================================================
% runInterventionSim.m - Simplified Intervention Simulation
% =========================================================================
% Description:
%   This function implements a simplified model for evaluating HVAC
%   interventions, particularly HEPA filtration. It uses a more streamlined
%   approach than the full Digital Twin simulation for faster evaluation
%   of basic scenarios.
%
% Inputs:
%   hepaEnabled - Boolean flag indicating whether HEPA filtration is enabled
%   envData     - Table with environmental data
%
% Outputs:
%   results     - Structure with simulation results:
%                 - total_PM10: PM10 concentration time series
%                 - control_time: Time vector (seconds)
%                 - dt: Time step (seconds)
%                 - metadata: Additional metrics and simulation details
%
% Related files:
%   - runManualComparison.m: Calls this function for quick comparisons
%   - runScenarioComparison.m: More comprehensive comparison approach
%
% Notes:
%   - Simplified model focusing primarily on PM10 concentrations
%   - Uses basic mass balance approach with fewer parameters
%   - Calculates energy usage and costs for basic economic comparison
%   - Much faster than full Digital Twin simulation
%   - Useful for quick evaluations and sensitivity analyses
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('Running intervention simulation (HEPA %s)\n', iif(hepaEnabled, 'ON', 'OFF'));

try
    % Start timing for runtime calculation
    tic;
    
    % -------------------------------------------------------------------------
    % Simulation parameters
    % -------------------------------------------------------------------------
    simPeriod = 8760;        % Simulation period (hours)
    dt = 60;                 % Time step (seconds)
    V_room = 250;            % Room volume (m³)
    
    % Set flow rates and efficiencies based on HEPA setting
    if hepaEnabled
        Q_base = 300;        % Base ventilation flow rate (CFM)
        Q_hepa = 300;        % HEPA flow rate (CFM)
        hepa_eff = 0.99;     % HEPA efficiency (fraction)
    else
        Q_base = 300;        % Base ventilation flow rate (CFM)
        Q_hepa = 0;          % No HEPA flow
        hepa_eff = 0;        % No HEPA efficiency
    end
    
    % -------------------------------------------------------------------------
    % Pre-allocate arrays
    % -------------------------------------------------------------------------
    steps_per_hour = 3600 / dt;              % Steps per hour
    total_steps = simPeriod * steps_per_hour; % Total simulation steps
    control_time = (0:total_steps-1) * dt;   % Time vector (seconds)
    total_PM10 = zeros(total_steps, 1);      % PM10 concentrations
    total_PM10(1) = 5;                       % Initial PM10 concentration
    
    % Energy tracking
    energy_hepa_kwh = 0;         % HEPA energy consumption (kWh)
    energy_ventilation_kwh = 0;  % Ventilation energy consumption (kWh)
    
    % Unit conversion constants
    cfm_to_m3s = 0.000471947;    % CFM to m³/s conversion
    
    % Convert flow rates to m³/s
    Q_base_m3s = Q_base * cfm_to_m3s;
    Q_hepa_m3s = Q_hepa * cfm_to_m3s;
    
    % Power consumption (W)
    P_base = 75;                 % Base ventilation power
    P_hepa = 100 * hepaEnabled;  % HEPA power (0 if disabled)
    
    % -------------------------------------------------------------------------
    % Cost parameters
    % -------------------------------------------------------------------------
    cost_per_kwh = 0.15;  % Electricity cost ($/kWh)
    
    % -------------------------------------------------------------------------
    % Run simulation
    % -------------------------------------------------------------------------
    fprintf('Simulating %d hours (%d time steps)...\n', simPeriod, total_steps);
    
    for t = 2:total_steps
        % Get current hour and handle wraparound for repeating environment data
        current_hour = floor((t-1) / steps_per_hour) + 1;
        if current_hour > height(envData)
            current_hour = mod(current_hour - 1, height(envData)) + 1;
        end
        
        % Get outdoor PM10 concentration for current hour
        outdoor_PM10 = envData.PM10(current_hour);
        
        % Calculate concentration changes
        
        % Change due to ventilation (outdoor air coming in)
        ventilation_change = Q_base_m3s * (outdoor_PM10 - total_PM10(t-1)) / V_room;
        
        % Change due to HEPA filtration (if enabled)
        hepa_removal = Q_hepa_m3s * total_PM10(t-1) * hepa_eff / V_room;
        
        % Change due to natural deposition
        deposition_rate = 0.2 / 3600;  % 0.2 per hour converted to per second
        natural_removal = deposition_rate * total_PM10(t-1);
        
        % Calculate net change in PM10
        dPM10_dt = ventilation_change - hepa_removal - natural_removal;
        
        % Update PM10 concentration
        total_PM10(t) = total_PM10(t-1) + dPM10_dt * dt;
        
        % Ensure non-negative concentration
        total_PM10(t) = max(0, total_PM10(t));
        
        % Accumulate energy usage (J to kWh conversion included: /3600000)
        energy_ventilation_kwh = energy_ventilation_kwh + P_base * dt / 3600000;
        energy_hepa_kwh = energy_hepa_kwh + P_hepa * dt / 3600000;
    end
    
    % -------------------------------------------------------------------------
    % Calculate summary statistics
    % -------------------------------------------------------------------------
    PM10_avg = mean(total_PM10);
    PM10_max = max(total_PM10);
    PM10_final = total_PM10(end);
    
    total_energy_kwh = energy_ventilation_kwh + energy_hepa_kwh;
    total_cost_usd = total_energy_kwh * cost_per_kwh;
    
    % -------------------------------------------------------------------------
    % Prepare results structure
    % -------------------------------------------------------------------------
    results = struct();
    results.total_PM10 = total_PM10;
    results.control_time = control_time;
    results.dt = dt;
    
    % Store metadata
    results.metadata = struct();
    results.metadata.hepa_enabled = hepaEnabled;
    results.metadata.PM10_avg_ugm3 = PM10_avg;
    results.metadata.PM10_max_ugm3 = PM10_max;
    results.metadata.PM10_final_ugm3 = PM10_final;
    results.metadata.energy_ventilation_kwh = energy_ventilation_kwh;
    results.metadata.energy_hepa_kwh = energy_hepa_kwh;
    results.metadata.total_energy_kwh = total_energy_kwh;
    results.metadata.total_cost_usd = total_cost_usd;
    results.metadata.total_time_s = control_time(end);
    results.metadata.simulation_runtime_s = toc;
    
    fprintf('Simulation completed. Avg PM10: %.2f μg/m³, Total cost: $%.2f\n', ...
           PM10_avg, total_cost_usd);
catch ME
    % Handle errors
    fprintf('Error in intervention simulation: %s\n', ME.message);
    fprintf('Line: %d\n', ME.stack(1).line);
    
    % Return minimal results structure
    results = struct();
    results.total_PM10 = zeros(10, 1);
    results.control_time = 0:9;
    results.dt = 1;
    results.metadata = struct('error', ME.message);
end
end

% Helper function for conditional text
function result = iif(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end