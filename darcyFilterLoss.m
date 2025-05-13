function [dP, k_media] = darcyFilterLoss(Q_m3s, dust_total, params)
% =========================================================================
% darcyFilterLoss.m - Calculate Filter Pressure Drop Using Darcy Model
% =========================================================================
% Description:
%   This function calculates the pressure drop across a filter using the
%   Darcy model, accounting for both clean media resistance and additional
%   resistance from dust loading. It models both depth filtration and cake
%   filtration phases.
%
% Inputs:
%   Q_m3s       - Volumetric flow rate (m³/s)
%   dust_total  - Total accumulated dust mass (g)
%   params      - Structure with Darcy filter parameters:
%                 - mu_air: Air dynamic viscosity (Pa·s)
%                 - A_filter: Filter face area (m²)
%                 - DeltaP_0: Initial pressure drop (Pa)
%                 - beta: Depth filtration coefficient
%                 - M_c: Critical mass for cake formation (g)
%                 - alpha_cake: Specific cake resistance
%                 - k_media_clean: Clean filter permeability (m²)
%
% Outputs:
%   dP         - Pressure drop across filter (Pa)
%   k_media    - Current filter permeability (m²)
%
% Related files:
%   - solveFlowBalance.m: Uses this function to calculate system losses
%   - totalLoss.m: Includes filter loss in total system losses
%   - initDarcyParams.m: Defines filter parameters
%
% Notes:
%   - Depth filtration: dP increases exponentially with dust loading
%   - Cake filtration: dP increases linearly after critical mass M_c
%   - Filter becomes more restrictive (higher dP) as dust accumulates
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

try
    % Input validation
    if ~isnumeric(Q_m3s) || ~isnumeric(dust_total) || ~isstruct(params)
        error('Invalid input types');
    end
    
    % Check for required fields
    required_fields = {'mu_air', 'A_filter', 'DeltaP_0', 'beta', 'M_c', 'alpha_cake'};
    for i = 1:length(required_fields)
        if ~isfield(params, required_fields{i})
            error('Missing required field in params: %s', required_fields{i});
        end
    end
    
    % Validate flow rate
    Q_m3s = max(0, Q_m3s);
    if isnan(Q_m3s)
        warning('NaN detected in darcyFilterLoss Q_m3s input, using 0');
        Q_m3s = 0;
    end
    
    % Validate dust loading
    dust_total = max(0, dust_total);
    if isnan(dust_total)
        warning('NaN detected in darcyFilterLoss dust_total input, using 0');
        dust_total = 0;
    end
    
    % Extract parameters with validation
    mu_air = params.mu_air;
    if isnan(mu_air) || mu_air <= 0
        warning('Invalid mu_air value, using default');
        mu_air = 1.81e-5;  % Air viscosity at standard conditions
    end
    
    A = max(0.01, params.A_filter);  % Filter face area
    if isnan(A)
        warning('Invalid filter area, using default');
        A = 10;  % Default value (m²)
    end
    
    DeltaP_0 = max(1, params.DeltaP_0);  % Initial pressure drop
    if isnan(DeltaP_0)
        warning('Invalid DeltaP_0, using default');
        DeltaP_0 = 250;  % Default value (Pa)
    end
    
    beta = max(0.001, min(1, params.beta));  % Depth filtration coefficient
    if isnan(beta)
        warning('Invalid beta, using default');
        beta = 0.1;  % Default value
    end
    
    M_c = max(1, params.M_c);  % Critical mass for cake formation
    if isnan(M_c)
        warning('Invalid M_c, using default');
        M_c = 25;  % Default value (g)
    end
    
    alpha_cake = max(1e8, params.alpha_cake);  % Specific cake resistance
    if isnan(alpha_cake)
        warning('Invalid alpha_cake, using default');
        alpha_cake = 1e10;  % Default value
    end
    
    % Handle very small flow case
    if Q_m3s < 1e-6
        dP = 0;
        k_media = params.k_media_clean;
        return;
    end
    
    % Calculate face velocity
    v = Q_m3s / A;  % m/s
    
    % Pressure drop calculation based on filtration phase
    if dust_total < M_c
        % Depth filtration phase - exponential increase
        dP = DeltaP_0 * exp(beta * dust_total);
    else
        % Combined depth and cake filtration
        dP_depth = DeltaP_0 * exp(beta * M_c);
        dP_cake = (mu_air * v / alpha_cake) * (dust_total - M_c);
        dP = dP_depth + dP_cake;
    end
    
    % Calculate effective permeability
    if dP > 0
        k_media = (mu_air * Q_m3s) / (A * dP);
    else
        k_media = params.k_media_clean;
    end
    
    % Final validation
    if isnan(dP) || isinf(dP) || ~isreal(dP) || dP < 0
        warning('Invalid pressure drop calculated, using fallback model');
        dP = DeltaP_0 * (1 + 0.05 * dust_total);
        k_media = (mu_air * Q_m3s) / (A * dP);
    end
    
    % Cap pressure drop at a realistic maximum
    dP = min(5000, dP);
    
catch ME
    % Handle all errors
    fprintf('[ERROR] in darcyFilterLoss: %s\n', ME.message);
    dP = 0;
    k_media = 1e-11;  % Default clean filter permeability
end
end