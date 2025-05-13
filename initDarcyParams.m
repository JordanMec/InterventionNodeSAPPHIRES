function darcyParams = initDarcyParams()
% =========================================================================
% initDarcyParams.m - Initialize Darcy Filter Parameters
% =========================================================================
% Description:
%   This function initializes the parameters for the Darcy filter model,
%   which simulates filter pressure drop and dust loading effects.
%   These parameters control filter performance, dust accumulation,
%   and pressure-flow relationships.
%
% Inputs:
%   None
%
% Outputs:
%   darcyParams - Structure containing Darcy filter parameters:
%     - mu_air: Air dynamic viscosity (Pa·s)
%     - A_filter: Filter face area (m²)
%     - k_media_clean: Clean filter permeability (m²)
%     - rho_cake: Dust cake density (kg/m³)
%     - k_cake: Dust cake permeability (m²)
%     - P0_media: Clean filter pressure drop at reference flow (Pa)
%     - DeltaP_0: Initial pressure drop coefficient (Pa)
%     - beta: Depth filtration coefficient
%     - M_c: Critical mass for cake formation (g)
%     - alpha_cake: Specific cake resistance
%     - total_capacity: Filter dust capacity (g)
%
% Related files:
%   - darcyFilterLoss.m: Uses these parameters to calculate filter pressure drop
%   - evaluateFilterLife.m: Uses total_capacity to determine filter replacement
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[initDarcyParams] Initializing Darcy filter parameters\n');

try
    % Create the parameters structure
    darcyParams = struct();
    
    % Air properties
    darcyParams.mu_air = 1.81e-5;       % Air dynamic viscosity (Pa·s)
    
    % Filter geometry
    darcyParams.A_filter = 10.92;        % Filter face area (m²)
    
    % Filter media properties
    darcyParams.k_media_clean = 6e-11;   % Clean filter permeability (m²)
    darcyParams.rho_cake = 700;          % Dust cake density (kg/m³)
    darcyParams.k_cake = 1e-12;          % Dust cake permeability (m²)
    darcyParams.P0_media = 250;          % Clean filter pressure drop at reference flow (Pa)
    
    % Darcy-model specific parameters
    darcyParams.DeltaP_0 = 250;          % Initial pressure drop coefficient (Pa)
    darcyParams.beta = 0.1;              % Depth filtration coefficient
    darcyParams.M_c = 25;                % Critical mass for cake formation (g)
    darcyParams.alpha_cake = 1e10;       % Specific cake resistance
    
    % Filter lifecycle parameters
    darcyParams.total_capacity = 100;    % Filter dust capacity (g)
    
    fprintf('[initDarcyParams] Darcy filter parameters initialized successfully\n');
catch ME
    % Handle errors
    fprintf('[ERROR] in initDarcyParams: %s\n', ME.message);
    
    % Return minimal default values to allow simulation to continue
    darcyParams = struct('mu_air', 1.81e-5, 'A_filter', 10.92, 'k_media_clean', 6e-11);
    darcyParams.total_capacity = 100;
    darcyParams.DeltaP_0 = 250;
    darcyParams.beta = 0.1;
    darcyParams.M_c = 25;
    darcyParams.alpha_cake = 1e10;
    
    fprintf('[initDarcyParams] Created minimal defaults due to error\n');
end
end