
function results = runInterventionSim(enableIntervention)
t_start = tic;  % Start timer
% =========================================================================
% runInterventionSim.m
%
% Simulates indoor air quality in a residential building with or without
% a HEPA 13 filtration intervention (blower fan).
%
% INPUT:
%   enableIntervention (boolean): true = HEPA system ON, false = OFF
%
% OUTPUT:
%   results (struct): contains simulation outputs for comparison
%
% =========================================================================

%% Clear Workspace, Command Window (only inside function)
clc; close all;


%% Pre-Fill Default Global Parameters (instead of GUI)
guiParams.blowerDoor        = 1150;      % [CFM @ 50 Pa]
guiParams.targetPressure    = 1;         % [Pa]
guiParams.filterSlope       = 1.2136;    % [Pa/CFM]
guiParams.ductLength        = 130;       % [ft]
guiParams.useDuctLoss       = true;
guiParams.useHomesLoss      = true;
guiParams.useFilterLoss     = true;
guiParams.useNaturalRemoval = true;
guiParams.enableExhaustFan  = true;
guiParams.enableStackEffect = true;

%% Pre-Simulation Calculations & Physical Constants
n_leak  = 0.65;                         % Leakage flow exponent
effectiveC = guiParams.blowerDoor / (50^n_leak);   % C in Q=C*dP^n
g       = 9.81;                         % Gravity [m/s²]
Patm    = 101325;                       % Atmospheric Pressure [Pa]
R_air   = 287;                          % Gas constant for dry air [J/kg/K]

% Note: GUI is bypassed for automatic wrapper compatibility.

% =========================================================================
%                  << END OF CHUNK 1 >>
% =========================================================================
%% Fan Curve Data (Fixed for This Fan/Filter System)
fixed_flow_rate = [1237, 1156, 1079, 997, 900, 769, 118, 0];   % CFM
fixed_pres      = [0, 49.8, 99.5, 149, 199, 248.8, 374, 399]; % Pa

% Fan Pressure Curve (interpolated function based on blower data)
fan_pressure = @(Q, wiper) (wiper / 128) * interp1(fixed_flow_rate, fixed_pres, Q, 'linear', 'extrap');

%% Loss Models (Duct, Home Envelope, Filter)
duct_loss = @(Q) 0.2717287 * (Q.^1.9) / (10^5.02) * guiParams.ductLength;  % [Pa]
homes_loss = @(Q) (Q / effectiveC).^(1/n_leak);                            % [Pa]
filter_loss = @(Q) guiParams.filterSlope * Q;                              % [Pa]

% Total Loss Function
total_loss = @(Q) duct_loss(Q) + homes_loss(Q) + filter_loss(Q);

%% PID Controller Setup
initial_wiper = 0; 
wiper = initial_wiper;     % starting wiper value (duty cycle command)
Kp = 30; Ki = 0.05; Kd = 1; % PID gains
min_wiper = 0; max_wiper = 128;
integral_error = 0; previous_error = 0;
Q_max = 1237;              % CFM maximum flow limit for this blower

%% Stack Effect Parameters
H_eff = 3;                 % Effective building height [m]
T_indoor_F = 68;           % Indoor setpoint temperature [°F]
T_indoor_K = (T_indoor_F - 32) * 5/9 + 273.15;  % Convert to Kelvin

%% Natural Draft Setup (Envelope Leakage)
Q50_m3s = guiParams.blowerDoor * 0.000471947;  % [m³/s] at 50 Pa
C_disc = 0.65; deltaP_test = 50;               % Discharge coefficient and test pressure
v_test = sqrt((2 * deltaP_test) / 1.2);         % Test velocity [m/s]
A_eff = Q50_m3s / (C_disc * v_test);            % Effective leakage area [m²]

% Duct Parameters (for minor losses, optional)
duct_diameter = sqrt(4 * A_eff / pi);           % Approximate duct diameter [m]
lambda = 0.019; sum_xi = 1; nd_duct_length = 3.5; % friction factor, fittings loss, nondimensional length

% =========================================================================
%                  << END OF CHUNK 2 >>
% =========================================================================
%% Simulation Time Setup
total_time = 21600;    % [seconds] Total simulation time (6 hours)
dt         = 1;        % [seconds] Time step
num_steps  = total_time / dt;   % Number of simulation steps

% Simulation Time Array
control_time = (0:num_steps-1) * dt;  % [seconds]

%% Initialize Indoor Air Parameters
floor_area      = 232.2576;  % [m²] (e.g., 2500 ft² house)
ceiling_height  = 2.4384;    % [m] (e.g., 8 ft ceilings)
V_indoor        = floor_area * ceiling_height;  % [m³] Indoor volume

particle_sizes  = [0.3, 0.5, 1, 2.5, 5, 10];    % µm, bin upper edges
numSizes        = length(particle_sizes);       % Number of PM size bins
% HEPA 13 filter efficiency by size bin (from smallest to largest)
HEPA_eff = [0.9995, 0.9997, 0.9999, 0.99999, 0.999995, 0.999999];


%% Placeholder Outdoor PM Data (replace with real data later)
pm10Dist = [0.11, 0.11, 0.11, 0.11, 0.28, 0.28];    % Outdoor PM fraction per bin
pm10_ts  = 30 + 5 * sin(2*pi*(control_time)/(3600*24));  % Outdoor PM time series variation (sinusoidal)
baseline_PM_ts = pm10_ts' .* pm10Dist;   % Each row: [bin1, bin2, ..., bin6]

%% Preallocate Data Series for Results
pressure_series         = zeros(1, num_steps);
wiper_series            = zeros(1, num_steps);
Qfan_series             = zeros(1, num_steps);
Q_infiltration_series   = zeros(1, num_steps);
error_series            = zeros(1, num_steps);
stack_series            = zeros(1, num_steps);
exhaust_series          = zeros(1, num_steps);
power_series            = zeros(1, num_steps);
blower_cost_series      = zeros(1, num_steps);
cond_cost_series        = zeros(1, num_steps);
filter_cost_series      = zeros(1, num_steps);
dust_total_series       = zeros(1, num_steps);
filter_pressure_series  = zeros(1, num_steps);
filter_life_series      = zeros(1, num_steps);
cumulative_cost_energy  = zeros(1, num_steps);
outside_temp_series     = zeros(1, num_steps);
dust_bins               = zeros(4, num_steps);   % 4 size bins for dust tracking
cost_series             = zeros(1, num_steps);   % ($/step)
C_indoor_PM             = zeros(num_steps, numSizes);  % Indoor PM concentrations

%% Initial Conditions
actual_pressure = guiParams.targetPressure;   % [Pa]
dust = zeros(1,4);                             % [g] Dust in each filter bin
exhaust_state = 0;                             % Exhaust fan state (0=off, 1=on)
Q_blower = 0;                                  % Blower flow (CFM)

% =========================================================================
%                  << END OF CHUNK 3 >>
% =========================================================================
%% MAIN SIMULATION LOOP
for cs = 1:num_steps
    current_time = (cs-1) * dt;

    %% 1. Exhaust Fan Update
    if guiParams.enableExhaustFan
        % Exhaust fan operation windows (example: 3 events)
        periods = [1800 4500; 8100 10800; 14400 17100];  % [start, end] in seconds
        desired_exhaust = any(current_time >= periods(:,1) & current_time < periods(:,2));

        if desired_exhaust
            exhaust_state = min(1, exhaust_state + dt/15);  % smooth ramp-up
        else
            exhaust_state = max(0, exhaust_state - dt/8);   % smooth ramp-down
        end
    else
        exhaust_state = 0;  % exhaust fan off
    end

    Q_exhaust = exhaust_state * 150;  % Exhaust fan flow [CFM] (default 150 CFM)
    exhaust_series(cs) = Q_exhaust;

    %% 2. Outdoor Temperature (for stack effect)
    if guiParams.enableStackEffect
        if current_time < 7200  % First 2 hours
            T_outdoor_F = 68;
        else
            T_outdoor_F = 80;
        end
    else
        T_outdoor_F = 68;  % Constant if no stack effect
    end

    outside_temp_series(cs) = T_outdoor_F;
    T_outdoor_K = (T_outdoor_F - 32) * 5/9 + 273.15;  % Convert to Kelvin
    rho_outdoor = Patm / (R_air * T_outdoor_K);       % Outdoor air density [kg/m³]

    %% 3. Stack-Effect Infiltration Flow
    if guiParams.enableStackEffect
        DP_buoy = rho_outdoor * g * H_eff * ((T_indoor_K / T_outdoor_K) - 1);
        Q_stack = sign(DP_buoy) * effectiveC * abs(DP_buoy)^n_leak;  % [CFM]
    else
        Q_stack = 0;  % No stack effect
    end
    stack_series(cs) = Q_stack;

    %% 4. Blower Fan Command (PID-controlled Flow Target)
    % Define system fan curve and system loss balance
    fan_equation = @(Q) fan_pressure(Q, wiper) - total_loss(Q);  % Pressure balance

    % Solve for target flow (use fzero; if fail, fallback to zero flow)
    try
        Q_cmd = fzero(fan_equation, 500);  % Initial guess: 500 CFM
    catch
        Q_cmd = 0;  % fallback
    end
    Q_cmd = max(Q_cmd, 0);  % no negative flows

    if cs == 1
        Q_blower = Q_cmd;  % First step: jump to commanded flow
    else
        % Blower dynamics (first-order lag)
        tau_dyn = 6 * (1 - Q_blower/Q_max) + 1;
        Q_blower = Q_blower + (dt / tau_dyn) * (Q_cmd - Q_blower);
    end
    Qfan_series(cs) = Q_blower;  % Log blower flow [CFM]

    %% 5. Back-calculate Instantaneous House Pressure
    p_old = actual_pressure;  % previous pressure
    p_new = p_old;            % initial guess
    tol = 1e-6; max_iter = 10;

    for iter = 1:max_iter
        % Calculate leakage based on candidate pressure
        Q_leak = effectiveC * abs(p_new)^n_leak;
        leak_effect = sign(p_new) * Q_leak;  % positive if exfiltration

        % Net airflow (blower + stack - exhaust - leaks)
        Q_net = Q_blower + Q_stack - Q_exhaust - leak_effect;  % [CFM]
        Q_net_m3s = Q_net * 0.000471947;                      % [m³/s]

        % Pressure update using backward-Euler
        p_next = p_old + dt * Q_net_m3s;  % Pressure in Pascals

        if abs(p_next - p_new) < tol
            p_new = p_next;
            break
        end
        p_new = p_next;
    end

    actual_pressure = p_new;               % Update actual pressure
    pressure_series(cs) = actual_pressure; % Log pressure

% =========================================================================
%                  << END OF CHUNK 4 >>
% =========================================================================
    %% 6. PID Controller – Refine Blower Wiper Signal
    %% 6. PID Controller – Refine Blower Wiper Signal
    err = guiParams.targetPressure - actual_pressure;
    error_series(cs) = err;

    % Intervention OFF: Force wiper to zero
    if ~enableIntervention
    wiper = 0;
    end

    if cs == 1
        previous_error = err;
    else
        % Anti-wind-up: reset integral if error sign flips
        if sign(err) ~= sign(previous_error)
            integral_error = 0;
        end

        % PID terms
        integral_error = integral_error + err * dt;
        integral_error = max(-5, min(5, integral_error));  % Clamp integral

        deriv = (err - previous_error) / dt;  % Derivative term

        % PID controller output
        wiper_adjust = Kp * err + Ki * integral_error + Kd * deriv;
        wiper = wiper + 0.05 * wiper_adjust;  % Small step update
        wiper = max(min_wiper, min(max_wiper, wiper));  % Clamp to [0,128]

        previous_error = err;  % Save for next step
    end
    wiper_series(cs) = wiper;

    %% 7. Blower Power and Electric Cost
    Q_m3s = Q_blower * 0.000471947;  % Convert CFM to m³/s
    current_power = fan_pressure(Q_blower, wiper) * Q_m3s;  % Power [W]

    power_series(cs) = current_power;  % Log power use

    % Energy usage this step (kWh)
    energy_kWh = (current_power / 1000) * (dt / 3600);

    % Determine cost rate (on-peak vs off-peak)
    if mod(current_time/3600, 6) >= 2 && mod(current_time/3600, 6) < 3.5
        cost_rate = 0.3047;  % On-peak $/kWh
    else
        cost_rate = 0.0846;  % Off-peak $/kWh
    end

    cost_blower = energy_kWh * cost_rate;  % Cost [$]
    blower_cost_series(cs) = cost_blower;  % Log blower cost

    %% 8. Conditioning (Heating/Cooling) Cost
    cost_cond = 0;   % Default

    if Q_blower > 0
        % Mass-flow rate of outdoor air
        rho_out = Patm / (R_air * T_outdoor_K);  % [kg/m³]
        m_dot = rho_out * Q_m3s;  % [kg/s]

        % Indoor and outdoor dry-bulb [°C]
        T_out_C = (T_outdoor_F - 32) * 5/9;
        T_set_C = (T_indoor_F  - 32) * 5/9;

        % Saturation vapor pressures [Pa]
        P_sat_out = 610.78 * exp(17.27 * T_out_C / (T_out_C + 237.3));
        P_sat_set = 610.78 * exp(17.27 * T_set_C / (T_set_C + 237.3));

        % Humidity ratios
        RH_outdoor = 0.5;  % Assume outdoor 50% RH
        RH_indoor = 0.4;   % Assume indoor 40% RH

        P_v_out = RH_outdoor * P_sat_out;
        P_v_set = RH_indoor * P_sat_set;

        w_out = 0.622 * P_v_out / (Patm - P_v_out);
        w_set = 0.622 * P_v_set / (Patm - P_v_set);

        % Specific enthalpies
        cp_dry = 1005; cp_vap = 1860; h_fg = 2.5e6;
        h_out = cp_dry * (T_out_C + 273.15) + w_out * (h_fg + cp_vap * (T_out_C + 273.15));
        h_set = cp_dry * (T_set_C + 273.15) + w_set * (h_fg + cp_vap * (T_set_C + 273.15));

        % Thermal energy needed
        Q_th = m_dot * (h_set - h_out);  % W (positive = heating)

        E_th = Q_th * dt;  % Joules in this step

        % Calculate cost based on heating vs cooling
        gas_efficiency = 0.90;  % Furnace efficiency
        gas_cost_per_J = 1e-8;  % $/J for heating
        COP_cooling = 3.0;      % Coefficient of Performance for cooling

        if Q_th >= 0  % Heating
            E_gas = E_th / gas_efficiency;
            cost_cond = E_gas * gas_cost_per_J;
        else  % Cooling
            E_elec = abs(E_th) / COP_cooling;
            cost_cond = (E_elec / 3.6e6) * cost_rate;  % $ for electricity
        end
    end
    cond_cost_series(cs) = cost_cond;

% =========================================================================
%                  << END OF CHUNK 5 >>
% =========================================================================
    %% 9. Indoor PM Mass Balance (Size-Resolved)
    
    % Define airflow paths
    if enableIntervention
        Q_HEPA = Q_blower * 0.000471947;    % [m³/s] clean HEPA air
    else
        Q_HEPA = 0;                         % No clean air if intervention off
    end
    % Infiltration based on pressure balance
    if actual_pressure < 0
        Q_infiltration = effectiveC * abs(actual_pressure)^n_leak;  % [CFM]
    else
        Q_infiltration = 0;  % No infiltration when pressurized
    end
    Q_infiltration_series(cs) = Q_infiltration;  % Log infiltration
    Q_infil = Q_infiltration * 0.000471947;       % [m³/s]

    % Penetration efficiency per size bin (walls filter coarse PM)
    P_i = [0.95, 0.9, 0.85, 0.7, 0.5, 0.3];  % Example empirical values
    
    % Air exchange rate (sum of HEPA supply + infiltration)
    air_exchange_rate = (Q_HEPA + Q_infil) / V_indoor;  % [s⁻¹]

    % Pull in this timestep's outdoor PM profile
    C_out_PM = baseline_PM_ts(cs,:);  % [1×6] PM for bins at this time

    % Temp & RH Factors (simple sinusoidal profile)
    temp_current = 298 + 5 * sin(2*pi*((current_time/3600)-6)/24);   % [K]
    RH_current   = 0.70 + 0.10 * sin(2*pi*((current_time/3600)-12)/24);

    % Hygroscopic Growth Factor
    growth_factor = (1 + 0.3*(RH_current/(1 - RH_current)))^(1/3);

    % --- Deposition and Removal Rates ---
    diam_m = particle_sizes * 1e-6;  % particle diameter [m]

    % Settling velocity [m/s]
    v_settling = ((1500 - 1.2) .* g .* diam_m.^2) / (18 * 1.81e-5);

    % Gravitational removal rate [s⁻¹]
    k_gravity = (v_settling / ceiling_height) .* growth_factor.^2;

    % Surface deposition rate [s⁻¹] (scaled with GF)
    k_surface = [2e-6, 3e-6, 4e-6, 6e-6, 8e-6, 1e-5] .* growth_factor.^2;

    % Coagulation rate [s⁻¹] (scaled by temp)
    k_coag = [1e-6, 1e-6, 2e-6, 2e-6, 2e-6, 3e-6] .* sqrt(temp_current/298);

    % Total removal rate per bin
    if guiParams.useNaturalRemoval
        k_total = k_gravity + k_surface + k_coag;
    else
        k_total = zeros(1, numSizes);
    end

%% PM Update Equations (Backward Euler / Well-Mixed)
if cs == 1
    C_indoor_PM(cs,:) = zeros(1, numSizes);  % Initial condition
else
    for i = 1:numSizes
        % Outdoor contribution through infiltration
        outdoor_PM_input = (Q_infil / V_indoor) * P_i(i) * C_out_PM(i);

        % HEPA-filtered air contribution (accounting for partial inefficiency)
        if enableIntervention
            HEPA_input = (Q_HEPA / V_indoor) * (1 - HEPA_eff(i)) * C_out_PM(i);
        else
            HEPA_input = 0;
        end

        % Total change in concentration
        dCdt = outdoor_PM_input + HEPA_input ...
             - air_exchange_rate * C_indoor_PM(cs-1,i) ...
             - k_total(i) * C_indoor_PM(cs-1,i);

        % Update indoor PM concentration
        C_indoor_PM(cs,i) = C_indoor_PM(cs-1,i) + dt * dCdt;
    end
end


    %% 10. Filter Dust Loading (Dust Accumulation Model)
    % Air volume filtered this step [m³/s]
    Qfan_m3s = Q_blower * 0.000471947;

    % Dust mass-flux captured by HEPA (4 size bins for dust bins, different from PM bins)
    conc_bin = [4000, 8000, 5000, 1000] * 1e-6;  % example µg/m³ per dust bin
    eff_bin  = [0.90, 0.85, 0.95, 0.99];         % HEPA capture efficiency

    flux_bin = Qfan_m3s * conc_bin .* eff_bin;  % [g/s] collected dust flux

    dust = dust + flux_bin * dt;  % Accumulate dust over time

    % Log cumulative dust per bin
    dust_bins(:,cs) = dust;

    % Total dust
    dust_total = sum(dust);
    dust_total_series(cs) = dust_total;

    % Filter pressure drop
    filter_area = 10.92;  % m² HEPA filter area
    P0 = 250;             % Initial pressure drop [Pa]
    dust_capacity_total = 50 * filter_area;  % Total dust capacity [g]
    K_dust = P0 / dust_capacity_total;       % Dust loading slope

    deltaP_dust = K_dust * dust_total;        % Added pressure [Pa]
    filter_pressure = P0 + deltaP_dust;       % Total filter pressure drop
    filter_pressure_series(cs) = filter_pressure;

    % Filter life remaining (%)
    filter_life_pct = max(0, 100 * (1 - dust_total / dust_capacity_total));
    filter_life_series(cs) = filter_life_pct;

    %% 11. Step Cost Accumulation
    cost_step = cost_blower + cost_cond;  % $ cost this timestep

    if cs == 1
        cumulative_cost_energy(cs) = cost_step;
    else
        cumulative_cost_energy(cs) = cumulative_cost_energy(cs-1) + cost_step;
    end
    cost_series(cs) = cost_step;
end  % end of main simulation loop

% =========================================================================
%                  << END OF CHUNK 6 >>
% =========================================================================
%% ===================  P L O T   R E S U L T S  ==========================

if enableIntervention
    runTag = 'HEPA_ON';
else
    runTag = 'HEPA_OFF';
end

combinedFig = figure('Name',['Digital Twin - ' runTag], 'NumberTitle','off','Color','w');
movegui(combinedFig, 'northwest');

tl = tiledlayout(combinedFig,9,2,'TileSpacing','Compact','Padding','Compact');

% 1 House Pressure --------------------------------------------------------
nexttile;
plot(control_time/3600, pressure_series,'b','LineWidth',1.4); hold on;
yline(guiParams.targetPressure,'r--','LineWidth',1.2);
xlabel('Time (h)'); ylabel('Pressure (Pa)');
title(sprintf('House Pressure (Target: %.1f Pa)', guiParams.targetPressure));
grid on;

% 2 Wiper Position --------------------------------------------------------
nexttile;
plot(control_time/3600, wiper_series,'m','LineWidth',1.4);
xlabel('Time (h)'); ylabel('Wiper value');
title('Blower Control Signal');
grid on;

% 3 Blower Flow -----------------------------------------------------------
nexttile;
plot(control_time/3600, Qfan_series,'r','LineWidth',1.4);
xlabel('Time (h)'); ylabel('Flow (CFM)');
title('Blower Flow Rate');
grid on;

% 4 PID Error -------------------------------------------------------------
nexttile;
plot(control_time/3600, error_series,'k','LineWidth',1.2);
xlabel('Time (h)'); ylabel('Error (Pa)');
title('PID Error Signal');
grid on;

% 5 Outside Temperature ---------------------------------------------------
nexttile;
plot(control_time/3600, outside_temp_series,'b','LineWidth',1.4);
xlabel('Time (h)'); ylabel('Temperature (°F)');
title('Outdoor Temperature');
grid on;

% 6 Stack Flow ------------------------------------------------------------
nexttile;
plot(control_time/3600, stack_series,'g','LineWidth',1.4);
xlabel('Time (h)'); ylabel('Flow (CFM)');
title('Stack Effect Flow');
grid on;

% 7 Exhaust Fan Flow ------------------------------------------------------
nexttile;
plot(control_time/3600, exhaust_series,'c','LineWidth',1.4);
xlabel('Time (h)'); ylabel('Flow (CFM)');
title('Exhaust Fan Flow');
grid on;

% 8 Infiltration Flow -----------------------------------------------------
nexttile;
plot(control_time/3600, Q_infiltration_series, 'r', 'LineWidth', 1.4);
xlabel('Time (h)');
ylabel('Flow (CFM)');
title('Infiltration Airflow (Q_{infiltration})');
grid on;

% 9 Blower Power ----------------------------------------------------------
nexttile;
plot(control_time/3600, power_series,'b','LineWidth',1.4);
xlabel('Time (h)'); ylabel('Power (W)');
title('Blower Electrical Power');
grid on;

% 10 Cumulative Operating Cost --------------------------------------------
nexttile;
plot(control_time/3600, cumulative_cost_energy,'r','LineWidth',1.6);
xlabel('Time (h)'); ylabel('Cost ($)');
title('Cumulative Operating Cost');
grid on;

% 11 Filter Life ----------------------------------------------------------
nexttile;
plot(control_time/3600, filter_life_series,'k','LineWidth',1.4);
xlabel('Time (h)'); ylabel('Life Remaining (%)');
title('HEPA Filter Remaining Life');
grid on;

% 12 Filter Pressure Drop -------------------------------------------------
nexttile;
plot(control_time/3600, filter_pressure_series,'r','LineWidth',1.6);
xlabel('Time (h)'); ylabel('ΔP (Pa)');
title('Filter Pressure Drop');
grid on;

% 13 Dust Load Total ------------------------------------------------------
nexttile;
plot(control_time/3600, dust_total_series,'b','LineWidth',1.6);
xlabel('Time (h)'); ylabel('Dust Load (g)');
title('Cumulative Dust Load on Filter');
grid on;

% 14 Dust by Bin ----------------------------------------------------------
nexttile;
plot(control_time/3600, dust_bins','LineWidth',1.1);
xlabel('Time (h)'); ylabel('Dust (g)');
title('Dust Load by Size Bin');
legend('Bin 1','Bin 2','Bin 3','Bin 4','Location','best');
grid on;

% 15 Indoor PM Panel (Separate Figure) ------------------------------------
pmFig = figure('Name',['Indoor PM - ' runTag],'NumberTitle','off','Color','w');
movegui(pmFig, 'northeast');


for i = 1:numSizes
    subplot(numSizes,1,i);
    plot(control_time/3600, C_indoor_PM(:,i),'b','LineWidth',1.3); hold on;
    yline(baseline_PM_ts(1,i),'r--','LineWidth',1.0);
    xlabel('Time (h)');
    ylabel(sprintf('PM %.1f µm (µg/m³)', particle_sizes(i)));
    if i == 1
        title('Indoor (blue) vs. Outdoor (red) PM Concentration');
    end
    grid on;
end

fprintf('Simulation and plotting complete.\n');

% =========================================================================
%                  << END OF CHUNK 7 >>
% =========================================================================
%% =================== RETURN RESULTS TO WRAPPER =========================

results.C_indoor_PM         = C_indoor_PM;            % [µg/m³] indoor PM per bin
results.control_time        = control_time;           % [s]
results.dt                  = dt;                     % [s]
results.Q_HEPA_series       = Qfan_series;            % [CFM] clean air supply
results.Q_infiltration      = Q_infiltration_series;  % [CFM] leakage air
results.total_PM10          = sum(C_indoor_PM, 2);    % [µg/m³] summed over all bins
results.cumulative_cost     = cumulative_cost_energy; % [$]
results.dust_total_series   = dust_total_series;      % [g]
results.pressure_series     = pressure_series;        % [Pa]


% Optional: Automatically append this run’s metadata to a cumulative table
% (Uncomment this line to use — or call manually from another script)
% appendMetadataToTable(results, 'run_summary.csv');

%% ---------------- METADATA ENHANCEMENT ---------------- %%
results.metadata.enableIntervention    = enableIntervention;
results.metadata.total_time_s          = total_time;
results.metadata.time_step_s           = dt;
results.metadata.num_steps             = num_steps;

% Building parameters
results.metadata.floor_area_m2         = floor_area;
results.metadata.ceiling_height_m      = ceiling_height;
results.metadata.volume_m3             = V_indoor;

% Blower system
results.metadata.Qfan_CFM_avg          = mean(Qfan_series);
results.metadata.Qfan_CFM_final        = Qfan_series(end);
results.metadata.wiper_final           = wiper_series(end);
results.metadata.pressure_final_Pa     = pressure_series(end);

% Energy & cost
results.metadata.total_cost_usd        = cumulative_cost_energy(end);
results.metadata.total_heating_cost    = sum(cond_cost_series(cond_cost_series > 0));
results.metadata.total_cooling_cost    = sum(cond_cost_series(cond_cost_series < 0));
results.metadata.total_blower_cost     = sum(blower_cost_series);
results.metadata.total_filter_dust_g   = dust_total_series(end);
results.metadata.filter_life_remaining = filter_life_series(end);  % [%]

% Airflow
results.metadata.Q_infiltration_total_m3 = sum(Q_infiltration_series) * dt * 0.000471947;
results.metadata.stack_flow_total_m3     = sum(stack_series) * dt * 0.000471947;
results.metadata.exhaust_flow_total_m3   = sum(exhaust_series) * dt * 0.000471947;

% Indoor air quality
results.metadata.PM10_final_ugm3        = sum(C_indoor_PM(end,:));
results.metadata.PM10_avg_ugm3          = mean(sum(C_indoor_PM, 2));
results.metadata.PM10_max_ugm3          = max(sum(C_indoor_PM, 2));

% Copy of all input flags for reproducibility
results.metadata.guiParams              = guiParams;

results.metadata.simulation_runtime_s = toc(t_start);  % Elapsed time in seconds
end  % <=== CLOSE FUNCTION runInterventionSim.m


% =========================================================================
%                  << END OF CHUNK 8 — Script Complete >>
% =========================================================================


