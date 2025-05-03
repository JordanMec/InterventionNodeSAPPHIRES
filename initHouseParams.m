function houseParams = initHouseParams()
% Initialize house geometry and temperature parameters

fprintf('[initHouseParams] Initializing house parameters\n');
try
    houseParams = struct();
    houseParams.exhaust_flow   = 150;       % CFM fixed exhaust when fan is on
    houseParams.floor_area     = 232.2576;  % m2
    houseParams.ceiling_height = 2.4384;    % m
    
    % Calculate volume
    houseParams.V_indoor = houseParams.floor_area * houseParams.ceiling_height;   % room volume, m3
    
    % Add consistent temperature definitions
    houseParams.T_in_F = 68;                % F indoor setpoint
    houseParams.T_in_C = (houseParams.T_in_F-32)*5/9;  % C
    houseParams.T_in_K = houseParams.T_in_C + 273.15;  % K
    
    fprintf('[initHouseParams] House parameters initialized successfully. Volume = %.1f m3\n', houseParams.V_indoor);
catch ME
    fprintf('[ERROR] in initHouseParams: %s\n', ME.message);
    % Create minimal default parameters
    houseParams = struct('exhaust_flow', 150, 'V_indoor', 500, 'T_in_K', 293.15);
end
end