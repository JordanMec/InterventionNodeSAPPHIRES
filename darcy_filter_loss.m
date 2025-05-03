function [dP, k_media] = darcy_filter_loss(Q_m3s, dust_total, params)
% Time-varying filter dP using a composite Darcy model.
%
% Inputs
%   Q_m3s       - flow through filter, m3/s
%   dust_total  - cumulative captured mass, g
%   params      - struct with physical constants:
%                 .mu_air, .A_filter, .k_media_clean,
%                 .rho_cake, .k_cake
%
% Outputs
%   dP          - current filter pressure drop, Pa
%   k_media     - effective permeability of clean media, m2

try
    % Input validation
    if ~isnumeric(Q_m3s) || ~isnumeric(dust_total) || ~isstruct(params)
        error('Invalid input types');
    end
    
    % Check required fields in params
    required_fields = {'mu_air', 'A_filter', 'k_media_clean', 'rho_cake', 'k_cake'};
    for i = 1:length(required_fields)
        if ~isfield(params, required_fields{i})
            error('Missing required field in params: %s', required_fields{i});
        end
    end
    
    % Protect against negative or NaN values
    Q_m3s = max(0, Q_m3s);
    if isnan(Q_m3s)
        warning('NaN detected in darcy_filter_loss Q_m3s input, using 0');
        Q_m3s = 0;
    end
    
    dust_total = max(0, dust_total);
    if isnan(dust_total)
        warning('NaN detected in darcy_filter_loss dust_total input, using 0');
        dust_total = 0;
    end
    
    mu_air   = params.mu_air;
    A        = params.A_filter;
    k_media  = params.k_media_clean;
    rho_cake = params.rho_cake;
    k_cake   = params.k_cake;
    
    % Protect against division by zero
    A = max(0.001, A);
    k_media = max(1e-15, k_media);
    k_cake = max(1e-15, k_cake);
    
    % cake thickness (m)
    L_cake = (dust_total/1000) / (rho_cake * A);
    
    % resistances in series (media + cake)
    dP_media = (mu_air * Q_m3s / A) * (1 / k_media);
    dP_cake  = (mu_air * Q_m3s / A) * (L_cake / k_cake);
    
    dP = dP_media + dP_cake;
    
    % Validate output
    if isnan(dP) || isinf(dP)
        warning('Invalid value detected in darcy_filter_loss output, using 0');
        dP = 0;
    end
catch ME
    fprintf('[ERROR] in darcy_filter_loss: %s\n', ME.message);
    dP = 0;  % Default to 0 pressure loss
    k_media = 1e-11;  % Default value
end
end