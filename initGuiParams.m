function guiParams = initGuiParams()
% =========================================================================
% initGuiParams.m - Initialize GUI/User Parameters
% =========================================================================
% Description:
%   This function initializes the parameters that would typically be
%   controlled by the user through the GUI. These parameters control
%   various aspects of the simulation including pressure targets,
%   building characteristics, and which physical effects to include.
%
% Inputs:
%   None
%
% Outputs:
%   guiParams - Structure containing GUI/user parameters:
%     - blowerDoor: Blower door test result (CFM @ 50 Pa)
%     - targetPressure: Target house pressure (Pa)
%     - filterSlope: Filter performance parameter
%     - ductLength: Length of ductwork (ft)
%     - useDuctLoss: Include duct pressure loss (true/false)
%     - useHomesLoss: Include house envelope loss (true/false)
%     - useFilterLoss: Include filter pressure loss (true/false)
%     - useNaturalRemoval: Include natural PM deposition (true/false)
%     - enableExhaustFan: Enable exhaust fan during meals (true/false)
%     - enableStackEffect: Enable stack effect modeling (true/false)
%
% Related files:
%   - launchGUI.m: GUI that can override these default parameters
%   - godMode.m: Main script that uses these parameters
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[initGuiParams] Initializing GUI parameters\n');

try
    % Create the parameters structure
    guiParams = struct();
    
    % Building envelope characteristics
    guiParams.blowerDoor = 1150;      % Blower door test result (CFM @ 50 Pa)
                                      % Lower values = tighter house
    
    % Pressure control parameters
    guiParams.targetPressure = 1;     % Target house pressure (Pa)
    
    % Filter characteristics
    guiParams.filterSlope = 1.2136;   % Filter performance parameter
    
    % Duct system
    guiParams.ductLength = 130;       % Length of ductwork (ft)
    
    % Feature enables/disables
    guiParams.useDuctLoss = true;       % Include duct pressure loss
    guiParams.useHomesLoss = true;      % Include house envelope loss
    guiParams.useFilterLoss = true;     % Include filter pressure loss
    guiParams.useNaturalRemoval = true; % Include natural PM deposition
    guiParams.enableExhaustFan = true;  % Enable exhaust fan during meals
    guiParams.enableStackEffect = true; % Enable stack effect modeling
    
    fprintf('[initGuiParams] GUI parameters initialized successfully\n');
catch ME
    % Handle errors
    fprintf('[ERROR] in initGuiParams: %s\n', ME.message);
    
    % Return minimal default values to allow simulation to continue
    guiParams = struct('blowerDoor', 1150, 'targetPressure', 1, 'ductLength', 130);
    
    % Add minimal feature enables
    guiParams.useDuctLoss = true;
    guiParams.useHomesLoss = true;
    guiParams.useFilterLoss = true;
    guiParams.useNaturalRemoval = true;
    guiParams.enableExhaustFan = true;
    guiParams.enableStackEffect = true;
    
    fprintf('[initGuiParams] Created minimal defaults due to error\n');
end
end