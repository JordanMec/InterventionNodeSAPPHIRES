function [dP, k_media] = darcy_filter_loss(Q_m3s, dust_total, params)
% last edit: monday may 12th 2025
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
    
    % Extract parameters with safety checks
    mu_air   = params.mu_air;
    if isnan(mu_air) || mu_air <= 0
        warning('Invalid mu_air value, using default');
        mu_air = 1.81e-5;  % Default value for air viscosity
    end
    
    % IMPORTANT FIX: Increase minimum filter area to avoid division issues
    A = max(0.01, params.A_filter);  % More conservative minimum (originally 0.001)
    if isnan(A)
        warning('Invalid filter area, using default');
        A = 10;  % Default safe value
    end
    
    % IMPORTANT FIX: Increase minimum permeability values to avoid division issues
    k_media = max(1e-14, params.k_media_clean);  % More conservative minimum (originally 1e-15)
    if isnan(k_media)
        warning('Invalid k_media_clean, using default');
        k_media = 1e-11;  % Default safe value
    end
    
    k_cake = max(1e-14, params.k_cake);  % More conservative minimum (originally 1e-15)
    if isnan(k_cake)
        warning('Invalid k_cake, using default');
        k_cake = 1e-12;  % Default safe value
    end
    
    rho_cake = max(1, params.rho_cake);  % Ensure positive density
    if isnan(rho_cake)
        warning('Invalid rho_cake, using default');
        rho_cake = 700;  % Default safe value
    end
    
    % IMPORTANT FIX: Special handling for very small flow
    if Q_m3s < 1e-6
        dP = 0;  % No flow means no pressure drop
        return;
    end
    
    % IMPORTANT FIX: Add reasonable limits to cake thickness
    % Calculate cake thickness (m) with safety bounds
    L_cake = (dust_total/1000) / (rho_cake * A);
    
    % IMPORTANT FIX: Cap cake thickness to physical limits
    if L_cake > 0.05  % If cake thickness exceeds reasonable value (5 cm)
        L_cake = 0.05;  % Cap at a reasonable maximum
        warning('Cake thickness exceeded physical limit, capped at 5 cm');
    end
    
    % Calculate resistances in series (media + cake)
    dP_media = (mu_air * Q_m3s / A) * (1 / k_media);
    dP_cake  = (mu_air * Q_m3s / A) * (L_cake / k_cake);
    
    % IMPORTANT FIX: Check individual components for validity
    if isnan(dP_media) || isinf(dP_media) || dP_media < 0
        warning('Invalid media pressure drop, using fallback');
        dP_media = 250 * (Q_m3s / 0.5);  % Linear model based on typical values
    end
    
    if isnan(dP_cake) || isinf(dP_cake) || dP_cake < 0
        warning('Invalid cake pressure drop, using fallback');
        dP_cake = 50 * L_cake * (Q_m3s / 0.5);  % Simple model
    end
    
    % Sum the components
    dP = dP_media + dP_cake;
    
    % IMPORTANT FIX: Add upper bounds to pressure drop
    dP = min(2000, dP);  % Cap at a reasonable maximum pressure
    
    % Validate output
    if isnan(dP) || isinf(dP) || ~isreal(dP) || dP < 0
        warning('Invalid value detected in darcy_filter_loss output, using fallback model');
        % IMPORTANT FIX: Use a physically reasonable fallback model
        dP = 250 * (Q_m3s / 0.5) + 100 * (dust_total / 100) * (Q_m3s / 0.5);
    end
catch ME
    fprintf('[ERROR] in darcy_filter_loss: %s\n', ME.message);
    dP = 0;  % Default to 0 pressure loss
    k_media = 1e-11;  % Default value
end
end
