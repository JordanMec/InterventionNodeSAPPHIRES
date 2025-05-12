function dP = homes_loss(Q, C_eff, n_leak)
% Last Edit: Monday may 12th 2025
% Envelope infiltration/back-pressure (Pa) as a function of Q (CFM).
try
    % Input validation
    if ~isnumeric(Q) || ~isnumeric(C_eff) || ~isnumeric(n_leak)
        error('Invalid input types: Q, C_eff, and n_leak must be numeric');
    end
    
    % Protect against negative, zero, or NaN values
    Q = max(0, Q);
    if isnan(Q)
        warning('NaN detected in homes_loss Q input, using 0');
        Q = 0;
    end
    
    % IMPORTANT FIX: Increase the minimum allowed C_eff to prevent division issues
    % The original minimum was 0.001, but this may still cause problems
    C_eff = max(0.1, C_eff);  % Use a larger minimum value for better numerical stability
    if isnan(C_eff)
        warning('NaN detected in homes_loss C_eff input, using 1');
        C_eff = 1;
    end
    
    % IMPORTANT FIX: Ensure n_leak is in a safe range for the power operation
    n_leak = max(0.1, min(1, n_leak));  % Use a minimum of 0.1 instead of 0.01
    if isnan(n_leak)
        warning('NaN detected in homes_loss n_leak input, using 0.65');
        n_leak = 0.65;
    end
    
    % IMPORTANT FIX: Special handling for very small flow values
    if Q < 0.001
        dP = 0;  % For near-zero flow, pressure drop is zero
    else
        % Original calculation with additional safety
        dP = (Q ./ C_eff).^(1./n_leak);
        
        % IMPORTANT FIX: Add explicit check for invalid results after calculation
        if isnan(dP) || isinf(dP) || ~isreal(dP) || dP < 0
            warning('Invalid result after homes_loss calculation, applying fallback');
            dP = Q * 0.1;  % Simple linear fallback model (0.1 Pa per CFM)
        end
        
        % IMPORTANT FIX: Limit to physically reasonable range
        dP = min(1000, dP);  % Cap at 1000 Pa to prevent extreme values
    end
    
catch ME
    fprintf('[ERROR] in homes_loss: %s\n', ME.message);
    dP = 0;  % Default to 0 pressure loss to prevent simulation crash
end
end
