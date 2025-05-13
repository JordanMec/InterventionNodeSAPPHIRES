function dP_tot = totalLoss(Q, dust_total, effectiveC, n_leak, guiParams, darcyParams)
% =========================================================================
% totalLoss.m - Calculate Total System Pressure Loss
% =========================================================================
% Description:
%   This function calculates the total pressure loss in the HVAC system,
%   combining losses from the filter, ducts, and building envelope.
%   It serves as the system resistance curve in determining the
%   operating point.
%
% Inputs:
%   Q           - Flow rate (CFM)
%   dust_total  - Total accumulated dust mass (g)
%   effectiveC  - Effective leakage coefficient
%   n_leak      - Leakage exponent
%   guiParams   - GUI/user parameters structure
%   darcyParams - Filter parameters structure
%
% Outputs:
%   dP_tot      - Total system pressure loss (Pa)
%
% Related files:
%   - solveFlowBalance.m: Uses this to find system operating point
%   - darcyFilterLoss.m: Called to calculate filter losses
%   - ductLoss.m: Called to calculate duct losses
%   - homesLoss.m: Called to calculate envelope losses
%
% Notes:
%   - System resistance increases with flow rate
%   - Filter dust loading increases system resistance over time
%   - Individual components can be enabled/disabled via guiParams
%   - Total loss determines intersection with fan curve
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Input validation with stricter bounds
if ~isnumeric(Q) || ~isnumeric(dust_total) || ~isnumeric(effectiveC) || ~isnumeric(n_leak)
    fprintf('[totalLoss] Invalid input types for numeric parameters\n');
    % Return simple fallback
    dP_tot = 0.01 * Q + 0.0001 * Q^2;
    return;
end

if ~isstruct(guiParams) || ~isstruct(darcyParams)
    fprintf('[totalLoss] guiParams and darcyParams must be structs\n');
    % Return simple fallback
    dP_tot = 0.01 * Q + 0.0001 * Q^2;
    return;
end

% Near-zero flow handling
if Q < 0.001
    dP_tot = 0.01;  % Minimum threshold to avoid numerical issues
    return;
end

% Flow rate validation with stricter bounds
Q = max(0.01, min(1800, Q));
if isnan(Q)
    fprintf('[totalLoss] NaN detected in Q input, using 0.1\n');
    Q = 0.1;
end

% Dust total validation with stricter bounds
dust_total = max(0, min(1000, dust_total));
if isnan(dust_total)
    fprintf('[totalLoss] NaN detected in dust_total input, using 0\n');
    dust_total = 0;
end

% Leakage coefficient validation with stricter bounds
effectiveC = max(0.1, min(100, effectiveC));
if isnan(effectiveC)
    fprintf('[totalLoss] NaN detected in effectiveC input, using 10\n');
    effectiveC = 10;  % Safe default value
end

% Leakage exponent validation with stricter bounds
n_leak = max(0.2, min(0.8, n_leak));
if isnan(n_leak)
    fprintf('[totalLoss] NaN detected in n_leak input, using 0.65\n');
    n_leak = 0.65;  % Standard value
end

% Initialize component losses
dP_duct = 0;
dP_home = 0;
dP_fil = 0;

% Calculate duct losses if enabled - with extra protection
if isfield(guiParams, 'useDuctLoss') && guiParams.useDuctLoss
    % Add default duct length if not provided
    duct_length = 100; % Default length (ft)
    if isfield(guiParams, 'ductLength')
        duct_length = guiParams.ductLength;
    end
    
    % Ensure duct length is within reasonable bounds
    duct_length = max(1, min(500, duct_length));
    
    % Calculate duct loss or use fallback
    try
        dP_duct = ductLoss(Q, duct_length);
        
        % Validate duct loss result
        if isnan(dP_duct) || isinf(dP_duct) || dP_duct < 0
            % Simple model fallback
            dP_duct = 0.002 * Q^1.9 * duct_length;
        end
    catch
        % Fallback calculation
        dP_duct = 0.002 * Q^1.9 * duct_length;
    end
    
    % Bound to reasonable range
    dP_duct = min(1000, max(0, dP_duct));
end

% Calculate house envelope losses if enabled - with extra protection
if isfield(guiParams, 'useHomesLoss') && guiParams.useHomesLoss
    try
        % Calculate homes loss
        dP_home = homesLoss(Q, effectiveC, n_leak);
        
        % Validate homes loss result
        if isnan(dP_home) || isinf(dP_home) || dP_home < 0 || ~isreal(dP_home)
            % Fallback calculation
            dP_home = (Q / effectiveC)^(1/n_leak);
        end
    catch
        % Fallback calculation
        dP_home = (Q / effectiveC)^(1/0.65);
    end
    
    % Bound to reasonable range
    dP_home = min(500, max(0, dP_home));
end

% Calculate filter losses if enabled - with extra protection
if isfield(guiParams, 'useFilterLoss') && guiParams.useFilterLoss
    try
        % Convert flow to m³/s for darcyFilterLoss function
        Q_m3s = Q * 0.000471947;
        
        if Q_m3s < 0 || isnan(Q_m3s)
            Q_m3s = 0.001; % Small positive value
        end
        
        % Try to use darcyFilterLoss
        try
            [dP_f, ~] = darcyFilterLoss(Q_m3s, dust_total, darcyParams);
            
            % Validate result
            if isnan(dP_f) || isinf(dP_f) || dP_f < 0 || ~isreal(dP_f)
                % Simple model fallback
                dP_f = 250 * (Q_m3s / 0.5) * (1 + dust_total/100);
            end
        catch
            % Simple model fallback
            dP_f = 250 * (Q_m3s / 0.5) * (1 + dust_total/100);
        end
        
        % Bound to reasonable range
        dP_fil = min(1500, max(0, dP_f));
    catch
        % Final fallback
        dP_fil = 250 * (Q/500)^2 * (1 + dust_total/100);
        dP_fil = min(1500, max(0, dP_fil));
    end
end

% Calculate total pressure loss by summing components
dP_tot = dP_duct + dP_home + dP_fil;

% Ensure minimum threshold to avoid numerical issues
if dP_tot < 0.01
    dP_tot = 0.01;
end

% Cap at a reasonable maximum
dP_tot = min(3000, dP_tot);

% Final validation
if isnan(dP_tot) || isinf(dP_tot) || ~isreal(dP_tot) || dP_tot < 0
    % Simple power law model
    dP_tot = 0.01 * Q^1.8 * (1 + dust_total/100);
    dP_tot = min(1000, max(0.01, dP_tot));
end
end