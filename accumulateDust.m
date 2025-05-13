function [simState, flux_bin] = accumulateDust(simState, Q_m3s, C_out_PM_hr, timeParams)
% =========================================================================
% accumulateDust.m - Track Dust Accumulation on Filter
% =========================================================================
% Description:
%   This function calculates the dust accumulation on the filter based on
%   airflow and outdoor particulate matter concentrations. It tracks dust
%   by size bin and updates the total dust accumulation in the simulation
%   state.
%
% Inputs:
%   simState      - Current simulation state (contains dust array)
%   Q_m3s         - Volumetric flow rate (m³/s)
%   C_out_PM_hr   - Outdoor PM concentrations by size bin (μg/m³)
%   timeParams    - Timing parameters (contains dt_ctrl)
%
% Outputs:
%   simState      - Updated simulation state with new dust accumulation
%   flux_bin      - Dust flux by size bin (g/s)
%
% Related files:
%   - innerLoop.m: Calls this function during simulation
%   - evaluateFilterLife.m: Uses dust accumulation to determine filter life
%   - darcyFilterLoss.m: Uses dust loading for pressure drop calculation
%
% Notes:
%   - Dust flux (g/s) = Flow rate (m³/s) × Concentration (μg/m³) × Capture efficiency × 1e-6
%   - Capture efficiency varies by particle size (larger particles = higher efficiency)
%   - Dust accumulation increases over time until filter replacement
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Process based on number of available PM size bins
if length(C_out_PM_hr) >= 4
    % Standard case with at least 4 size bins
    % Typical capture efficiencies by size bin
    flux_coeffs = [0.90, 0.85, 0.95, 0.99];  % Efficiency for each size bin
    
    % Initialize dust flux array
    flux_bin = zeros(1, 4);
    
    % Calculate dust flux for each bin
    for i = 1:4
        if i <= length(C_out_PM_hr) && ~isnan(C_out_PM_hr(i)) && C_out_PM_hr(i) >= 0
            % Dust flux (g/s) = Flow (m³/s) × Concentration (μg/m³) × Efficiency × 1e-6 (μg to g)
            flux_bin(i) = Q_m3s * C_out_PM_hr(i) * flux_coeffs(i) * 1e-6;
        else
            flux_bin(i) = 0;
        end

        % Validate flux value
        if isnan(flux_bin(i)) || flux_bin(i) < 0
            flux_bin(i) = 0;
        end
    end
else
    % Limited size bin case
    numBins = length(C_out_PM_hr);
    flux_coeffs = 0.9 * ones(1, numBins);  % Use uniform 90% efficiency
    flux_bin = zeros(1, 4);
    
    % Calculate dust flux for available bins
    for i = 1:min(4, numBins)
        if ~isnan(C_out_PM_hr(i)) && C_out_PM_hr(i) >= 0
            % Dust flux (g/s) = Flow (m³/s) × Concentration (μg/m³) × Efficiency × 1e-6 (μg to g)
            flux_bin(i) = Q_m3s * C_out_PM_hr(i) * flux_coeffs(i) * 1e-6;
        end
        
        % Validate flux value
        if isnan(flux_bin(i)) || flux_bin(i) < 0
            flux_bin(i) = 0;
        end
    end
end

% Accumulate dust over time step
simState.dust = simState.dust + flux_bin * timeParams.dt_ctrl;

% Validate dust values
for i = 1:length(simState.dust)
    if isnan(simState.dust(i)) || simState.dust(i) < 0
        simState.dust(i) = 0;
    end
end

% Update total accumulated dust
simState.dust_total = sum(simState.dust);

% Final validation of dust total
if isnan(simState.dust_total) || simState.dust_total < 0
    warning('Invalid dust total, resetting to 0');
    simState.dust_total = 0;
    simState.dust = zeros(size(simState.dust));
end
end