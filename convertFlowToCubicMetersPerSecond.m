function Q_m3s = convertFlowToCubicMetersPerSecond(Q_cfm)
% =========================================================================
% convertFlowToCubicMetersPerSecond.m - Convert Flow Units
% =========================================================================
% Description:
%   This function converts volumetric flow rate from cubic feet per minute
%   (CFM) to cubic meters per second (m³/s). It also validates the result
%   to ensure it's within a physically reasonable range.
%
% Inputs:
%   Q_cfm - Volumetric flow rate in cubic feet per minute (CFM)
%
% Outputs:
%   Q_m3s - Volumetric flow rate in cubic meters per second (m³/s)
%
% Related files:
%   - innerLoop.m: Calls this function for unit conversion
%   - accumulateDust.m: Uses the converted flow rate
%   - darcyFilterLoss.m: Uses the converted flow rate
%
% Notes:
%   - Conversion factor: 1 CFM = 0.000471947 m³/s
%   - Validation ensures flow rate is:
%     * Not NaN
%     * Non-negative
%     * Below a reasonable maximum (1 m³/s)
%   - Provides a fallback if validation fails
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Define conversion factor from CFM to m³/s
cfm_to_m3s = 0.000471947;  

% Perform the conversion
Q_m3s = Q_cfm * cfm_to_m3s;

% Validate the result
if isnan(Q_m3s) || Q_m3s < 0 || Q_m3s > 1
    % Log warning message
    warning('Invalid Q_m3s: %.6f, using safe value', Q_m3s);
    
    % Apply bound constraints to original value and convert again
    Q_m3s = max(0, min(1/cfm_to_m3s, Q_cfm)) * cfm_to_m3s;
end
end