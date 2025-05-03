function guiParams = initGuiParams()
% Initialize GUI parameters with default values

fprintf('[initGuiParams] Initializing GUI parameters\n');
try
    guiParams = struct();
    guiParams.blowerDoor        = 1150;      % [CFM @ 50 Pa]  - house leakage
    guiParams.targetPressure    = 1;         % [Pa]           - set-point (max 8 Pa)
    guiParams.filterSlope       = 1.2136;    % [Pa/CFM]       - legacy linear model
    guiParams.ductLength        = 130;       % [ft]           - total round-duct length
    
    guiParams.useDuctLoss       = true;
    guiParams.useHomesLoss      = true;
    guiParams.useFilterLoss     = true;      % will be overridden by Darcy model
    guiParams.useNaturalRemoval = true;      % surface/grav. deposition in PM model
    guiParams.enableExhaustFan  = true;      % master toggle for meal-time exhaust
    guiParams.enableStackEffect = true;      % buoyancy infiltration
    
    fprintf('[initGuiParams] GUI parameters initialized successfully\n');
catch ME
    fprintf('[ERROR] in initGuiParams: %s\n', ME.message);
    % Create minimal default parameters
    guiParams = struct('blowerDoor', 1150, 'targetPressure', 1, 'ductLength', 130);
end
end