function E_cond_second = calculateConditioningEnergy(Q_m3s, T_in_C, T_out_C, rho_out, economicParams, timeParams)
% =========================================================================
% calculateConditioningEnergy.m - Calculate Conditioning Energy Usage
% =========================================================================
% Description:
%   This function calculates the energy required for heating or cooling
%   the incoming outdoor air to the indoor setpoint temperature. It accounts
%   for air density, temperature difference, and specific heat capacity.
%
% Inputs:
%   Q_m3s          - Volumetric flow rate (m³/s)
%   T_in_C         - Indoor temperature setpoint (°C)
%   T_out_C        - Outdoor temperature (°C)
%   rho_out        - Outdoor air density (kg/m³)
%   economicParams - Economic parameters (includes efficiency factors)
%   timeParams     - Timing parameters (time step, etc.)
%
% Outputs:
%   E_cond_second  - Conditioning energy for this time step (J)
%
% Related files:
%   - innerLoop.m: Calls this function for energy calculations
%   - calculateHourlyCosts.m: Uses the accumulated energy for cost calculation
%
% Notes:
%   - Energy required = mass flow × specific heat × temperature difference
%   - Specific heat of air = 1005 J/(kg·K)
%   - Heating mode when indoor temp > outdoor temp
%   - Cooling mode when indoor temp < outdoor temp
%   - Accounts for system efficiency/COP in cost calculations
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Constants
cp_air = 1005;  % Specific heat capacity of air (J/(kg·K))

% Calculate mass flow rate
mass_flow = Q_m3s * rho_out;  % kg/s

% Calculate temperature difference
deltaT = T_in_C - T_out_C;  % °C or K (same units for difference)

% Calculate power needed for air conditioning
% Power = mass flow × specific heat × temperature difference
P_cond = mass_flow * cp_air * abs(deltaT);  % Watts

% Determine if heating or cooling is needed
is_heating = (deltaT > 0);  % Heating when indoor > outdoor
is_cooling = (deltaT < 0);  % Cooling when indoor < outdoor

% Apply system efficiency based on mode
if is_heating
    % For heating, apply gas furnace efficiency
    if isfield(economicParams, 'gas_efficiency')
        P_cond = P_cond / max(0.1, economicParams.gas_efficiency);
    end
elseif is_cooling
    % For cooling, apply coefficient of performance (COP)
    if isfield(economicParams, 'COP_cooling')
        P_cond = P_cond / max(1, economicParams.COP_cooling);
    end
end

% Calculate energy for this time step
E_cond_second = P_cond * timeParams.dt_ctrl;  % Energy = Power × Time

% Update simulation state (could be used in calling function)
if is_heating
    is_heating_mode = true;
else
    is_heating_mode = false;
end

% Validate output
if isnan(E_cond_second) || E_cond_second < 0
    warning('Invalid conditioning energy calculated: %.2f J, using 0', E_cond_second);
    E_cond_second = 0;
end
end