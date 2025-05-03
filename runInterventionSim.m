function results = runInterventionSim(hepaEnabled, envData)
% RUNINTERVENTIONSIM Run a simplified HVAC intervention simulation
%
% Inputs:
%   hepaEnabled - Boolean flag for HEPA filtration (true/false)
%   envData     - Table with environment data (TempF, RH, PM10)
%
% Output:
%   results     - Struct with simulation results and metadata
%
% This function runs a simplified version of the Digital Twin model
% focused specifically on indoor PM10 concentration with/without HEPA.
% It provides compatible outputs to the runManualComparison.m script.

fprintf('Running intervention simulation (HEPA %s)\n', iif(hepaEnabled, 'ON', 'OFF'));

try
    % Initialize parameters
    simPeriod = 8760;  % hours to simulate (1 year)
    dt = 60;           % seconds per time step
    
    % Define room parameters
    V_room = 250;  % m³ room volume
    
    % Set flow rates based on HEPA state
    if hepaEnabled
        Q_base = 300;     % CFM baseline ventilation
        Q_hepa = 300;     % CFM through HEPA filter
        hepa_eff = 0.99;  % HEPA filter efficiency for PM10
    else
        Q_base = 300;     % CFM baseline ventilation
        Q_hepa = 0;       % No HEPA flow
        hepa_eff = 0;     % No HEPA filtering
    end
    
    % Initialize time and control arrays
    steps_per_hour = 3600 / dt;
    total_steps = simPeriod * steps_per_hour;
    
    % Pre-allocate arrays
    control_time = (0:total_steps-1) * dt;  % seconds
    total_PM10 = zeros(total_steps, 1);
    
    % Initialize PM10 concentration
    total_PM10(1) = 5;  % μg/m³ initial concentration
    
    % Energy consumption tracking
    energy_hepa_kwh = 0;
    energy_ventilation_kwh = 0;
    
    % Convert CFM to m³/s
    cfm_to_m3s = 0.000471947;
    Q_base_m3s = Q_base * cfm_to_m3s;
    Q_hepa_m3s = Q_hepa * cfm_to_m3s;
    
    % Base ventilation power (W)
    P_base = 75;
    
    % Additional power for HEPA (W)
    P_hepa = 100 * hepaEnabled;
    
    % Cost per kWh ($)
    cost_per_kwh = 0.15;
    
    fprintf('Simulating %d hours (%d time steps)...\n', simPeriod, total_steps);
    
    % Main simulation loop
    for t = 2:total_steps
        % Get current hour
        current_hour = floor((t-1) / steps_per_hour) + 1;
        
        % Ensure we don't exceed environment data
        if current_hour > height(envData)
            current_hour = mod(current_hour - 1, height(envData)) + 1;
        end
        
        % Get outdoor PM10 for current hour
        outdoor_PM10 = envData.PM10(current_hour);
        
        % Calculate indoor PM physics
        % 1. Ventilation (bringing in outdoor air)
        ventilation_change = Q_base_m3s * (outdoor_PM10 - total_PM10(t-1)) / V_room;
        
        % 2. HEPA filtration (cleaning indoor air)
        hepa_removal = Q_hepa_m3s * total_PM10(t-1) * hepa_eff / V_room;
        
        % 3. Natural deposition rate (surfaces, gravity)
        deposition_rate = 0.2 / 3600;  % 0.2 per hour converted to per second
        natural_removal = deposition_rate * total_PM10(t-1);
        
        % Total rate of change
        dPM10_dt = ventilation_change - hepa_removal - natural_removal;
        
        % Update PM10 concentration using explicit Euler step
        total_PM10(t) = total_PM10(t-1) + dPM10_dt * dt;
        
        % Prevent negative concentrations
        total_PM10(t) = max(0, total_PM10(t));
        
        % Update energy consumption (W * s -> kWh)
        energy_ventilation_kwh = energy_ventilation_kwh + P_base * dt / 3600000;
        energy_hepa_kwh = energy_hepa_kwh + P_hepa * dt / 3600000;
    end
    
    % Calculate key metrics
    PM10_avg = mean(total_PM10);
    PM10_max = max(total_PM10);
    PM10_final = total_PM10(end);
    
    total_energy_kwh = energy_ventilation_kwh + energy_hepa_kwh;
    total_cost_usd = total_energy_kwh * cost_per_kwh;
    
    % Create results structure matching runManualComparison.m expectations
    results = struct();
    results.total_PM10 = total_PM10;
    results.control_time = control_time;
    results.dt = dt;
    
    % Add metadata
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
    fprintf('Error in intervention simulation: %s\n', ME.message);
    fprintf('Line: %d\n', ME.stack(1).line);
    
    % Return empty results
    results = struct();
    results.total_PM10 = zeros(10, 1);
    results.control_time = 0:9;
    results.dt = 1;
    results.metadata = struct('error', ME.message);
end
end

% Helper function for inline if
function result = iif(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end