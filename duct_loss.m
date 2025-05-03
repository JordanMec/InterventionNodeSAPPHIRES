function dP = duct_loss(Q, L_ft)
% Darcy-Weisbach based duct loss for a round trunk.
% Q in CFM, L_ft in feet -> dP in Pa
%
% Empirical fit from CFD-derived exponent 1.9 and constant 0.2717287.
try
    % Input validation
    if ~isnumeric(Q) || ~isnumeric(L_ft)
        error('Invalid input types: Q and L_ft must be numeric');
    end
    
    % Protect against negative or NaN values
    Q = max(0, Q);
    if isnan(Q)
        warning('NaN detected in duct_loss Q input, using 0');
        Q = 0;
    end
    
    L_ft = max(0, L_ft);
    if isnan(L_ft)
        warning('NaN detected in duct_loss L_ft input, using 0');
        L_ft = 0;
    end
    
    dP = 0.2717287 .* (Q.^1.9) ./ (10^5.02) .* L_ft;
    
    % Validate output
    if isnan(dP)
        warning('NaN detected in duct_loss output, using 0');
        dP = 0;
    end
catch ME
    fprintf('[ERROR] in duct_loss: %s\n', ME.message);
    dP = 0;  % Default to 0 pressure loss to prevent simulation crash
end
end