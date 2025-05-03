function darcyParams = initDarcyParams()
% Initialize Darcy filter model parameters

fprintf('[initDarcyParams] Initializing Darcy filter parameters\n');
try
    darcyParams = struct();
    darcyParams.mu_air        = 1.81e-5;   % Pa-s   (dynamic viscosity @ 20 C)
    darcyParams.A_filter      = 10.92;     % m2     (total pleated media area)
    darcyParams.k_media_clean = 6e-11;     % m2     (clean-media permeability)
    darcyParams.rho_cake      = 700;       % kg/m3  (bulk density of dust cake)
    darcyParams.k_cake        = 1e-12;     % m2     (permeability of dust cake)
    darcyParams.P0_media      = 250;       % Pa     (dP across clean media at Q_test)
    
    fprintf('[initDarcyParams] Darcy filter parameters initialized successfully\n');
catch ME
    fprintf('[ERROR] in initDarcyParams: %s\n', ME.message);
    % Create minimal default parameters
    darcyParams = struct('mu_air', 1.81e-5, 'A_filter', 10.92, 'k_media_clean', 6e-11);
end
end