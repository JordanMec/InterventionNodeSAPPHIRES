function dP_tot = totalLoss(Q, dust_total, effectiveC, n_leak, guiParams, darcyParams)
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
    
    % Initialize to zero (safe default)
    dP_tot = 0;
    
    % Protect against NaN values
    Q = max(0, Q);
    if isnan(Q)
        warning('NaN detected in totalLoss Q input, using 0');
        Q = 0;
    end
    
    dust_total = max(0, dust_total);
    if isnan(dust_total)
        warning('NaN detected in totalLoss dust_total input, using 0');
        dust_total = 0;
    end
    
    % Calculate individual losses with error checking
    if isfield(guiParams, 'useDuctLoss') && guiParams.useDuctLoss && isfield(guiParams, 'ductLength')
        dP_duct = duct_loss(Q, guiParams.ductLength);
    else
        dP_duct = 0;
    end
    
    if isfield(guiParams, 'useHomesLoss') && guiParams.useHomesLoss
        dP_home = homes_loss(Q, max(0.001, effectiveC), max(0.01, n_leak));
    else
        dP_home = 0;
    end
    
    if isfield(guiParams, 'useFilterLoss') && guiParams.useFilterLoss
        Q_m3s = Q * 0.000471947;  % CFM -> m3/s
        [dP_f, ~] = darcy_filter_loss(Q_m3s, dust_total, darcyParams);
        dP_fil = dP_f;
    else
        dP_fil = 0;
    end
    
    % Sum up the components
    dP_tot = dP_duct + dP_home + dP_fil;
    
    % Validate output
    if isnan(dP_tot) || isinf(dP_tot)
        warning('Invalid value detected in totalLoss output, using 0');
        dP_tot = 0;
    end
catch ME
    fprintf('[ERROR] in totalLoss: %s\n', ME.message);
    dP_tot = 0;  % Default to 0 pressure loss to prevent simulation crash
end
end