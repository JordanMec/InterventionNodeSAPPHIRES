function [E_blower_second, P_blower] = calculateBlowerEnergy(simState, Q_m3s, timeParams)
% =========================================================================
% calculateBlowerEnergy.m - Calculate Blower Energy Usage
% =========================================================================
% Description:
%   This function calculates the energy used by the blower for a single
%   time step based on the current flow rate and wiper position. It uses
%   a simplified model of blower power consumption.
%
% Inputs:
%   simState    - Current simulation state (wiper position, etc.)
%   Q_m3s       - Volumetric flow rate (m³/s)
%   timeParams  - Timing parameters (time step, etc.)
%
% Outputs:
%   E_blower_second - Energy used by blower in this time step (J)
%   P_blower        - Blower power (W)
%
% Related files:
%   - innerLoop.m: Calls this function for energy calculations
%   - calculateHourlyCosts.m: Uses the accumulated energy for cost calculation
%
% Notes:
%   - Power scales with flow rate and wiper position
%   - Maximum blower power at full speed is 250W
%   - Energy = Power × Time
%   - Includes safeguards against NaN or negative values
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Base power when blower is at minimum setting but on
base_power = 20;  % Watts

% Maximum additional power at full speed and flow
max_additional_power = 250;  % Watts

% Calculate normalized wiper position (0-1)
wiper_normalized = simState.wiper / 128;

% Calculate power based on wiper position and flow
% Uses a quadratic model: Power increases with square of wiper position
% This reflects that power consumption increases more rapidly at higher speeds
P_blower = base_power + max_additional_power * (wiper_normalized^2);

% Adjust power based on flow rate
% At very low flow rates (e.g., against high pressure), motor works harder
flow_factor = max(0.5, min(1.0, Q_m3s * 10));  % Scale factor based on flow
P_blower = P_blower * flow_factor;

% Calculate energy for this time step
E_blower_second = P_blower * timeParams.dt_ctrl;  % Energy = Power × Time

% Validate outputs
if isnan(P_blower) || P_blower < 0
    warning('Invalid blower power calculated: %.2f W, using default', P_blower);
    P_blower = base_power;
end

if isnan(E_blower_second) || E_blower_second < 0
    warning('Invalid blower energy calculated: %.2f J, using default', E_blower_second);
    E_blower_second = base_power * timeParams.dt_ctrl;
end
end