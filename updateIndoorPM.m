function C_prev = updateIndoorPM(C_prev, Q_m3s, C_out_PM_hr, houseParams, guiParams, particleParams, timeParams)
% =========================================================================
% updateIndoorPM.m - Update Indoor PM Concentrations
% =========================================================================
% Description:
%   This function updates the indoor particulate matter (PM) concentrations
%   using a mass-balance approach. It accounts for outdoor air exchange,
%   filtration, and natural deposition processes.
%
% Inputs:
%   C_prev         - Previous indoor PM concentrations by size bin (μg/m³)
%   Q_m3s          - Volumetric airflow rate (m³/s)
%   C_out_PM_hr    - Outdoor PM concentrations by size bin (μg/m³)
%   houseParams    - House parameters (contains V_indoor)
%   guiParams      - GUI parameters (contains useNaturalRemoval flag)
%   particleParams - Particle parameters (contains particle_sizes)
%   timeParams     - Timing parameters (contains dt_ctrl)
%
% Outputs:
%   C_prev         - Updated indoor PM concentrations by size bin (μg/m³)
%
% Related files:
%   - innerLoop.m: Calls this function during simulation
%   - calculateDepositionRate.m: Calculates size-dependent deposition rates
%   - calculatePenetrationFactor.m: Calculates envelope penetration factors
%
% Notes:
%   - Uses the well-mixed assumption (indoor air is perfectly mixed)
%   - Mass balance: dC/dt = sources - sinks
%     * Sources: outdoor air infiltration
%     * Sinks: exfiltration, deposition, filtration
%   - Natural deposition rates increase with particle size
%   - Air exchange rate (1/hr) = flow (m³/s) ÷ volume (m³) × 3600
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Validate indoor volume
if ~isfield(houseParams, 'V_indoor') || houseParams.V_indoor <= 0 || isnan(houseParams.V_indoor)
    fprintf('[updateIndoorPM] WARNING: Invalid indoor volume, using default\n');
    houseParams.V_indoor = 500;  % Default volume (m³)
end

% Process each PM size bin
for i = 1:length(C_prev)
    % Get outdoor concentration with validation
    outdoor_conc = 0;
    if i <= length(C_out_PM_hr)
        outdoor_conc = max(0, C_out_PM_hr(i));
        if isnan(outdoor_conc)
            outdoor_conc = 0;
        end
    end
    
    % Calculate air exchange rate (1/s)
    air_exchange = max(0, Q_m3s) / max(1, houseParams.V_indoor);
    
    % Mass balance equation - concentration change due to air exchange
    dCdt = air_exchange * (outdoor_conc - C_prev(i));
    
    % Add natural deposition if enabled
    if isfield(guiParams, 'useNaturalRemoval') && guiParams.useNaturalRemoval
        if i <= length(particleParams.particle_sizes)
            % Calculate size-dependent deposition rate (1/s)
            % Larger particles deposit faster
            depo_rate = min(0.01, 1e-4 * particleParams.particle_sizes(i));
            
            % Add deposition term to mass balance
            dCdt = dCdt - depo_rate * max(0, C_prev(i));
        end
    end
    
    % Calculate concentration change for this time step
    delta_C = timeParams.dt_ctrl * dCdt;
    
    % Limit maximum change to prevent numerical instability
    max_delta_c = C_prev(i) * 0.1;
    if max_delta_c < 0.1
        max_delta_c = 0.1;
    end
    delta_C = max(-max_delta_c, min(max_delta_c, delta_C));
    
    % Update concentration
    C_prev(i) = max(0, C_prev(i) + delta_C);
    
    % Cap at realistic maximum
    C_prev(i) = min(1000, C_prev(i));
end
end