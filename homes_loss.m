function dP = homes_loss(Q, C_eff, n_leak)
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
    
    C_eff = max(0.001, C_eff);  % Avoid division by zero
    if isnan(C_eff)
        warning('NaN detected in homes_loss C_eff input, using 1');
        C_eff = 1;
    end
    
    n_leak = max(0.01, min(1, n_leak));  % Keep in reasonable range
    if isnan(n_leak)
        warning('NaN detected in homes_loss n_leak input, using 0.65');
        n_leak = 0.65;
    end
    
    dP = (Q ./ C_eff).^(1./n_leak);
    
    % Validate output
    if isnan(dP) || isinf(dP)
        warning('Invalid value detected in homes_loss output, using 0');
        dP = 0;
    end
catch ME
    fprintf('[ERROR] in homes_loss: %s\n', ME.message);
    dP = 0;  % Default to 0 pressure loss to prevent simulation crash
end
end