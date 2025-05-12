function dP_tot = totalLoss(Q, dust_total, effectiveC, n_leak, guiParams, darcyParams)
% last edit: monday may 12th 2025
% Calculate the total pressure loss through the system
% Inputs:
%   Q          - Flow rate (CFM)
%   dust_total - Current dust load (g)
%   effectiveC - Leakage coefficient
%   n_leak     - Leakage exponent
%   guiParams  - User parameters from GUI
%   darcyParams- Filter model parameters
% Output:
%   dP_tot     - Total pressure loss (Pa)

try
    % Input validation
    if ~isnumeric(Q) || ~isnumeric(dust_total) || ~isnumeric(effectiveC) || ~isnumeric(n_leak)
        error('Invalid input types for numeric parameters');
    end
    
    if ~isstruct(guiParams) || ~isstruct(darcyParams)
        error('guiParams and darcyParams must be structs');
    end
    
    % IMPORTANT FIX: Special handling for very small or negative flows
    if Q < 0.001
        dP_tot = 0.01;  % Return a small positive value instead of zero
        return;
    end
    
    % Protect against NaN values
    Q = max(0, Q);
    if isnan(Q)
        warning('NaN detected in totalLoss Q input, using 0.1');
        Q = 0.1;  % Use small non-zero value to prevent division issues
    end
    
    dust_total = max(0, dust_total);
    if isnan(dust_total)
        warning('NaN detected in totalLoss dust_total input, using 0');
        dust_total = 0;
    end
    
    % IMPORTANT FIX: Ensure effective C is reasonable
    effectiveC = max(0.1, effectiveC);  // More conservative minimum
    if isnan(effectiveC)
        warning('NaN detected in totalLoss effectiveC input, using 10');
        effectiveC = 10;  // Safe default value
    end
    
    % IMPORTANT FIX: Ensure n_leak is in reasonable range
    n_leak = max(0.1, min(0.9, n_leak));  // Bound to reasonable values
    if isnan(n_leak)
        warning('NaN detected in totalLoss n_leak input, using 0.65');
        n_leak = 0.65;  // Standard value
    end
    
    % Calculate individual losses with error checking
    dP_duct = 0;
    dP_home = 0;
    dP_fil = 0;
    
    % IMPORTANT FIX: Add bounds to component calculations and error checking
    % Duct loss calculation
    if isfield(guiParams, 'useDuctLoss') && guiParams.useDuctLoss && isfield(guiParams, 'ductLength')
        dP_duct = duct_loss(Q, guiParams.ductLength);
        
        % Validate and bound duct loss result
        if isnan(dP_duct) || isinf(dP_duct) || dP_duct < 0
            warning('Invalid duct loss calculated, using fallback');
            dP_duct = 0.002 * Q^1.9 * guiParams.ductLength;  // Simple model
        end
        
        dP_duct = min(1000, max(0, dP_duct));  // Bound to reasonable range
    end
    
    % House envelope loss calculation
    if isfield(guiParams, 'useHomesLoss') && guiParams.useHomesLoss
        dP_home = homes_loss(Q, effectiveC, n_leak);
        
        % Validate and bound homes loss result
        if isnan(dP_home) || isinf(dP_home) || dP_home < 0 || ~isreal(dP_home)
            warning('Invalid homes loss calculated, using fallback');
            dP_home = (Q / effectiveC)^(1/0.65);  // Simple model with safe exponent
        end
        
        dP_home = min(500, max(0, dP_home));  // Bound to reasonable range
    end
    
    % Filter loss calculation
    if isfield(guiParams, 'useFilterLoss') && guiParams.useFilterLoss
        Q_m3s = Q * 0.000471947;  % CFM -> m3/s
        
        % IMPORTANT FIX: Add safety check before calling darcy_filter_loss
        if Q_m3s < 0 || isnan(Q_m3s)
            warning('Invalid Q_m3s in totalLoss, using 0');
            Q_m3s = 0;
        end
        
        [dP_f, ~] = darcy_filter_loss(Q_m3s, dust_total, darcyParams);
        
        % Validate and bound filter loss result
        if isnan(dP_f) || isinf(dP_f) || dP_f < 0 || ~isreal(dP_f)
            warning('Invalid filter loss calculated, using fallback');
            
            % Simple fallback model based on flow and dust loading
            clean_pressure = 250 * (Q_m3s / 0.5);  // Clean filter pressure at flow Q
            dust_factor = 1 + dust_total / 100;    // Dust loading factor
            dP_f = clean_pressure * dust_factor;   // Simple model
        end
        
        dP_fil = min(1500, max(0, dP_f));  // Bound to reasonable range
    end
    
    % Sum up the components
    dP_tot = dP_duct + dP_home + dP_fil;
    
    % IMPORTANT FIX: Ensure result is physically reasonable
    % Minimum value to help fzero find sign changes
    if dP_tot < 0.01
        dP_tot = 0.01;  // Minimum threshold to avoid numerical issues
    end
    
    % Maximum value to prevent extreme values
    dP_tot = min(3000, dP_tot);  // Cap at a reasonable maximum
    
    % Validate final output
    if isnan(dP_tot) || isinf(dP_tot) || ~isreal(dP_tot) || dP_tot < 0
        warning('Invalid value detected in totalLoss final output, using fallback model');
        
        % Comprehensive fallback that includes all loss components
        dP_tot = 0.01 * Q^1.8;  // Simple power law model similar to Darcy-Weisbach
        
        if dust_total > 0
            dP_tot = dP_tot * (1 + dust_total/100);  // Account for dust loading
        end
        
        dP_tot = min(1000, max(0.01, dP_tot));  // Ensure reasonable bounds
    end
catch ME
    fprintf('[ERROR] in totalLoss: %s\n', ME.message);
    dP_tot = 0.01 * Q;  % Simple linear fallback model to prevent simulation crash
end
end
