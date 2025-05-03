function [simArrays, simState] = runSimulation(env, guiParams, darcyParams, economicParams, houseParams, particleParams, timeParams, simArrays)
% Run the full Digital Twin HVAC simulation

fprintf('[runSimulation] Starting simulation\n');
try
    % Initialize simulation state
    simState = struct();
    simState.actual_pressure   = 0;                  % Pa
    simState.wiper             = 0;                  % PWM duty (0-128)
    simState.Q_blower          = 0;                  % CFM
    simState.dust              = zeros(1,4);         % g in each coarse bin
    simState.dust_total        = 0;                  % g
    simState.filter_life_pct   = 100;                % %
    simState.previous_filter_cost = 0;               % $ already accrued
    simState.cum_cost          = 0;                  % $   cumulative
    simState.clog_state        = false;              % flag inside replacement edge detector
    simState.num_replacements  = 0;                  % counter
    
    % Initialize PID controller state
    simState.integral_error    = 0;                  % for PID control
    simState.previous_error    = 0;                  % for PID control
    
    % Initialize indoor PM concentration safely
    if ~isfield(particleParams, 'numSizes') || isempty(particleParams.numSizes) || particleParams.numSizes <= 0
        fprintf('[runSimulation] WARNING: Invalid particleParams.numSizes, using default of 6\n');
        particleParams.numSizes = 6;
    end
    simState.C_indoor_PM_hour  = zeros(1, particleParams.numSizes); % Initial PM concentration
    
    % Get PID controller gains
    pidParams = initPidParams();  % Get defaults to ensure availability
    Kp = pidParams.Kp;            % proportional [PWM/Pa]
    Ki = pidParams.Ki;            % integral     [PWM/(Pa*s)]
    Kd = pidParams.Kd;            % derivative   [PWM*s/Pa]
    
    min_wiper = 0;    % PWM lower limit
    max_wiper = 128;  % PWM upper limit
    
    % Constants
    n_leak = 0.65;
    
    % Calculate effective leakage coefficient from blower door test
    if ~isfield(guiParams, 'blowerDoor') || isnan(guiParams.blowerDoor) || guiParams.blowerDoor <= 0
        fprintf('[runSimulation] WARNING: Invalid blowerDoor value, using default\n');
        guiParams.blowerDoor = 1150;
    end
    effectiveC = guiParams.blowerDoor / (50^n_leak);  % CFM / Pa^n
    fprintf('[runSimulation] Effective leakage coefficient: %.3f\n', effectiveC);
    
    % Check if we have valid target pressure 
    if ~isfield(guiParams, 'targetPressure') || isnan(guiParams.targetPressure)
        fprintf('[runSimulation] WARNING: Invalid target pressure, using default\n');
        guiParams.targetPressure = 1.0;  % Pa
    end
    
    % Track progress with a waitbar
    progressBar = waitbar(0, 'Simulation starting...', 'Name', 'Digital Twin Progress');
    progressStepSize = max(1, round(timeParams.num_hours / 100));  % Update every ~1%
    updateTimes = [];  % For tracking execution time
    
    % Ensure we have a valid number of hours
    if ~isfield(timeParams, 'num_hours') || timeParams.num_hours <= 0
        error('Invalid number of simulation hours: %d', timeParams.num_hours);
    end
    
    % Run the simulation for each hour
    fprintf('[runSimulation] Starting main loop for %d hours\n', timeParams.num_hours);
    for h = 1:timeParams.num_hours  % ===== OUTER LOOP =====
        loopStartTime = tic;
        
        % Update progress bar occasionally
        if mod(h, progressStepSize) == 0 || h == 1 || h == timeParams.num_hours
            if ishandle(progressBar)
                try
                    waitbar(h/timeParams.num_hours, progressBar, sprintf('Hour %d of %d', h, timeParams.num_hours));
                catch
                    % If waitbar fails, just continue simulation
                end
            end
        end
        
        % -----------------------------------------------------------------
        % 5-A.  Pull one hour of outdoor conditions from the env timetable
        % -----------------------------------------------------------------
        if h <= height(env) && width(env) >= 3
            T_outdoor_F   = env.TempF(h);               % F
            RH_outdoor    = env.RH(h);                  % 0-1
            
            % Input validation for outdoor temperature
            if isnan(T_outdoor_F) || T_outdoor_F < -100 || T_outdoor_F > 150
                fprintf('[runSimulation] WARNING: Invalid outdoor temperature at hour %d: %.1f F\n', h, T_outdoor_F);
                T_outdoor_F = 70;  % Use a reasonable default
            end
            
            % Input validation for RH
            if isnan(RH_outdoor) || RH_outdoor < 0 || RH_outdoor > 1
                fprintf('[runSimulation] WARNING: Invalid RH at hour %d: %.2f\n', h, RH_outdoor);
                RH_outdoor = 0.5;  % Use a reasonable default
            end
            
            % Get outdoor PM concentrations from table safely
            C_out_PM_hr = zeros(1, particleParams.numSizes);
            for i = 1:particleParams.numSizes
                colIdx = 3 + i;  % Adjust index based on table structure
                if colIdx <= width(env)
                    % Get the current value - need to handle it being a cell or array
                    if iscell(env{h, colIdx})
                        val = env{h, colIdx}{1}; % Extract from cell
                    else
                        val = env{h, colIdx};
                    end
                    
                    % Check for valid numeric data (handle scalar values)
                    if isnumeric(val) && isscalar(val) && ~isnan(val) && val >= 0
                        C_out_PM_hr(i) = val;
                    else
                        % Use default value if data is invalid
                        C_out_PM_hr(i) = 10 / (i + 0.1);  % Decreases with size
                    end
                else
                    C_out_PM_hr(i) = 10 / (i + 0.1);  % Default value
                end
            end
            
            % Determine hour of day from datetime or use index
            try
                if isdatetime(env.DateTime(h))
                    hr_of_day = hour(env.DateTime(h));  % 0-23 (military)
                else
                    hr_of_day = mod(h-1, 24);  % Fallback
                end
            catch
                hr_of_day = mod(h-1, 24);  % Fallback if DateTime not available
            end
        else
            % Use defaults if we're beyond the data range
            fprintf('[runSimulation] WARNING: Hour %d is beyond available data. Using defaults.\n', h);
            T_outdoor_F = 70;
            RH_outdoor = 0.5;
            C_out_PM_hr = ones(1, particleParams.numSizes) * 5;
            hr_of_day = mod(h-1, 24);
        end
        
        % -----------------------------------------------------------------
        % 5-B.  Decide exhaust-fan state for this hour (breakfast/lunch/dinner)
        % -----------------------------------------------------------------
        isMealHour = (hr_of_day == 7) || (hr_of_day == 12) || (hr_of_day == 18);   % 07-, 12-, 18-hour blocks
        if isfield(guiParams, 'enableExhaustFan') && guiParams.enableExhaustFan && isMealHour
            exhaust_state_fixed = true;
            Q_exhaust_fixed = houseParams.exhaust_flow;  % CFM
        else
            exhaust_state_fixed = false;
            Q_exhaust_fixed = 0;  % CFM
        end
        
        % -----------------------------------------------------------------
        % 5-C.  Run the INNER 1-second loop
        % -----------------------------------------------------------------
        % Reset per-hour accumulators
        E_blower_hour   = 0;   cost_blower_hour  = 0;
        E_cond_hour     = 0;   cost_cond_hour    = 0;
        cost_filter_hour= 0;
        clog_event_hour = false;
        
        % Calculate air density based on outdoor temperature
        T_out_C = (T_outdoor_F-32)*5/9;
        T_out_K = T_out_C + 273.15;
        rho_out = 101325 ./ (287 * T_out_K);  % kg/m3
        
        % Check for invalid density
        if isnan(rho_out) || rho_out <= 0
            fprintf('[runSimulation] WARNING: Invalid air density at hour %d. Using default.\n', h);
            rho_out = 1.2;  % Default air density at sea level
        end
        
        g = 9.81;  % Gravity
        
        % Get previous PM concentration
        C_prev = simState.C_indoor_PM_hour;
        
        % Ensure we have a valid number of steps per hour
        if ~isfield(timeParams, 'steps_per_hour') || timeParams.steps_per_hour <= 0
            fprintf('[runSimulation] WARNING: Invalid steps_per_hour, using default of 3600\n');
            timeParams.steps_per_hour = 3600;
        end
        
        % Run inner loop for each second in the hour
        for k = 1:timeParams.steps_per_hour  % ==== 3 600 x 1 s ====
            % ==========================================================
            % 6-A.  Stack effect & leak flow at previous pressure
            % ----------------------------------------------------------
            if isfield(guiParams, 'enableStackEffect') && guiParams.enableStackEffect
                T_in_K = houseParams.T_in_K;  % Use consistent temperature
                
                % Check for temperature division by zero
                if T_out_K <= 0
                    T_out_K = 273.15;  % Use freezing point as a safe default
                end
                
                DP_buoy = rho_out * g * 3 * (T_in_K/T_out_K - 1); % Pa
                Q_stack = sign(DP_buoy) * effectiveC * abs(DP_buoy)^n_leak;  % CFM
            else
                Q_stack = 0;
            end
            
            % ==========================================================
            % 6-B.  Solve fan-curve <-> total losses for target flow
            % ----------------------------------------------------------
            Q_guess = 500;  % CFM initial guess
            
            % Define function for fzero based on pressure balance
            fanEq = @(Q) fan_pressure(Q, simState.wiper) - ...
                         totalLoss(Q, simState.dust_total, effectiveC, n_leak, guiParams, darcyParams);
            
            % Solve for flow with error handling
            try
                Q_cmd = fzero(fanEq, Q_guess);  % CFM solution
            catch fzeroError
                fprintf('[runSimulation] Warning at hour %d, step %d: fzero failed: %s\n', ...
                       h, k, fzeroError.message);
                Q_cmd = 0;  % Default to zero flow on error
            end
            Q_cmd = max(Q_cmd, 0);  % Ensure non-negative flow
            
            % First-order blower response to commanded flow
            tau_dyn = 6 * (1 - simState.Q_blower/1237) + 1;
            if tau_dyn <= 0
                tau_dyn = 1;  % Ensure positive time constant
            end
            
            simState.Q_blower = simState.Q_blower + ...
                                (timeParams.dt_ctrl/tau_dyn)*(Q_cmd - simState.Q_blower);
            
            % Prevent extreme values or NaN
            if isnan(simState.Q_blower) || ~isfinite(simState.Q_blower)
                fprintf('[runSimulation] WARNING: Invalid Q_blower at hour %d step %d. Resetting.\n', h, k);
                simState.Q_blower = Q_cmd;  % Reset to commanded flow
            end
            simState.Q_blower = max(0, min(2000, simState.Q_blower));  % Reasonable limits
            
            % ==========================================================
            % 6-C.  Update house pressure via continuity
            % ----------------------------------------------------------
            % Calculate leak flow with protection for extreme pressure
            if abs(simState.actual_pressure) > 1000
                fprintf('[runSimulation] WARNING: Extreme pressure detected (%.1f Pa). Clamping.\n', ...
                       simState.actual_pressure);
                simState.actual_pressure = sign(simState.actual_pressure) * 1000;
            end
            
            Q_leak = effectiveC * abs(simState.actual_pressure)^n_leak;
            leak_effect = sign(simState.actual_pressure) * Q_leak;
            
            Q_net_m3s = (simState.Q_blower + Q_stack - Q_exhaust_fixed - leak_effect) ...
                        * 0.000471947;  % Convert CFM to m3/s
            
            % Update pressure with rate limiting to prevent instability
            pressure_change = timeParams.dt_ctrl * Q_net_m3s;
            max_allowed_change = 0.5;  % Pa per second max
            
            pressure_change = sign(pressure_change) * ...
                             min(abs(pressure_change), max_allowed_change);
            
            simState.actual_pressure = simState.actual_pressure + pressure_change;
            
            % Limit pressure to realistic range to prevent instabilities
            simState.actual_pressure = max(-50, min(50, simState.actual_pressure));
            
            % ==========================================================
            % 6-D.  PID controller adjusts wiper
            % ----------------------------------------------------------
            err = guiParams.targetPressure - simState.actual_pressure;
            simState.integral_error = simState.integral_error + err*timeParams.dt_ctrl;
            
            % Anti-windup on integral term
            simState.integral_error = max(-5, min(5, simState.integral_error));
            
            deriv = (err - simState.previous_error)/timeParams.dt_ctrl;
            
            % Smoothed update of wiper with rate limiting
            wiper_change = 0.05*(Kp*err + Ki*simState.integral_error + Kd*deriv);
            max_wiper_change = 5;  % Max change per second
            
            wiper_change = sign(wiper_change) * min(abs(wiper_change), max_wiper_change);
            simState.wiper = simState.wiper + wiper_change;
            
            % Ensure wiper is within valid range
            simState.wiper = max(min_wiper, min(max_wiper, simState.wiper));
            simState.previous_error = err;
            
            % ==========================================================
            % 6-E.  Accumulate Darcy dust, calculate filter life
            % ----------------------------------------------------------
            Q_m3s = simState.Q_blower * 0.000471947;  % CFM -> m3/s
            
            % Safe handling of flux calculation
            if length(C_out_PM_hr) >= 4
                flux_coeffs = [0.90, 0.85, 0.95, 0.99];  % Filter efficiency by bin
                flux_bin = Q_m3s .* C_out_PM_hr(1:4) .* flux_coeffs;  % g/s
            else
                % Handle case with fewer PM size bins
                numBins = length(C_out_PM_hr);
                flux_coeffs = 0.9 * ones(1, numBins);  % Use uniform efficiency
                flux_bin = zeros(1, 4);
                flux_bin(1:min(4, numBins)) = Q_m3s .* C_out_PM_hr(1:min(4, numBins)) .* flux_coeffs(1:min(4, numBins));
            end
            
            % Accumulate dust
            simState.dust = simState.dust + flux_bin*timeParams.dt_ctrl;
            simState.dust_total = sum(simState.dust);
            
            % Calculate filter life percentage
            filter_capacity = 50 * darcyParams.A_filter;  % g
            simState.filter_life_pct = max(0, 100 * (1 - simState.dust_total / filter_capacity));
            
            % ==========================================================
            % 6-F.  Clog detection & auto-replacement
            % ----------------------------------------------------------
            clogged_now = (simState.actual_pressure < 3) && ...
                         (simState.wiper >= 0.99*max_wiper);
                     
            if clogged_now && ~simState.clog_state
                simState.num_replacements = simState.num_replacements + 1;
                cost_filter_hour = cost_filter_hour + economicParams.filter_replacement_cost;
                simState.dust(:) = 0;
                simState.dust_total = 0;
                simState.filter_life_pct = 100;
                simState.clog_state = true;
                clog_event_hour = true;
                
                fprintf('[runSimulation] Filter replacement #%d at hour %d\n', ...
                       simState.num_replacements, h);
            elseif ~clogged_now
                simState.clog_state = false;
            end
            
            % ==========================================================
            % 6-G.  Energy & cost accumulation for this second
            % ----------------------------------------------------------
            dP_fan = fan_pressure(simState.Q_blower, simState.wiper);  % Pa
            P_blower = dP_fan * Q_m3s;  % W
            E_blower_hour = E_blower_hour + P_blower*timeParams.dt_ctrl;  % J
            
            % heating/cooling cost (simple sign check)
            T_set_C = houseParams.T_in_C;  % C
            Q_th = rho_out*Q_m3s*1005*(T_set_C - T_out_C);  % W
            
            if Q_th >= 0
                % Heating
                if isfield(economicParams, 'gas_efficiency') && economicParams.gas_efficiency > 0
                    E_cond_hour = E_cond_hour + Q_th*timeParams.dt_ctrl/economicParams.gas_efficiency;
                else
                    E_cond_hour = E_cond_hour + Q_th*timeParams.dt_ctrl/0.8;  % Default efficiency
                end
            else
                % Cooling
                if isfield(economicParams, 'COP_cooling') && economicParams.COP_cooling > 0
                    E_cond_hour = E_cond_hour + abs(Q_th)*timeParams.dt_ctrl/economicParams.COP_cooling;
                else
                    E_cond_hour = E_cond_hour + abs(Q_th)*timeParams.dt_ctrl/2.5;  % Default COP
                end
            end
            
            % ==========================================================
            % 6-H.  Indoor PM mass-balance (well-mixed, dt=1 s explicit)
            % ----------------------------------------------------------
            % Safe check for houseParams.V_indoor
            if ~isfield(houseParams, 'V_indoor') || houseParams.V_indoor <= 0
                fprintf('[runSimulation] WARNING: Invalid indoor volume, using default\n');
                houseParams.V_indoor = 500;  % m³
            end
            
            air_exchange = Q_m3s / houseParams.V_indoor;  % s⁻¹
            
            for i = 1:length(C_prev)
                % Ensure we don't go beyond array bounds
                outdoor_conc = 0;
                if i <= length(C_out_PM_hr)
                    outdoor_conc = C_out_PM_hr(i);
                end
                
                dCdt = air_exchange * (outdoor_conc - C_prev(i));
                
                % Add natural deposition if enabled
                if isfield(guiParams, 'useNaturalRemoval') && guiParams.useNaturalRemoval
                    % Simple size-dependent deposition rate (s⁻¹)
                    if i <= length(particleParams.particle_sizes)
                        depo_rate = 1e-4 * particleParams.particle_sizes(i);
                        dCdt = dCdt - depo_rate * C_prev(i);
                    end
                end
                
                C_prev(i) = max(0, C_prev(i) + timeParams.dt_ctrl * dCdt);
            end
        end  % ===== end 3600-second hour =====
        
        % ---------- Convert energy to cost for the hour -------------------------
        kWh_blower = E_blower_hour / 3.6e6;
        
        % Determine electricity rate based on time of day
        if (hr_of_day >= 14 && hr_of_day < 17)
            rate_hr = economicParams.on_peak_rate;
        else
            rate_hr = economicParams.off_peak_rate;
        end
        
        cost_blower_hour = kWh_blower * rate_hr;
        
        % Heating / cooling cost
        if E_cond_hour >= 0  % heating gas
            cost_cond_hour = E_cond_hour * economicParams.gas_cost_per_J;
        else  % cooling electric
            if (hr_of_day >= 14 && hr_of_day < 17)
                cooling_rate = economicParams.on_peak_rate;
            else
                cooling_rate = economicParams.off_peak_rate;
            end
            cost_cond_hour = (abs(E_cond_hour) / 3.6e6) * cooling_rate;
        end
        
        % ----------- Update cumulative cost & indoor PM snapshot ----------------
        simState.cum_cost = simState.cum_cost + cost_blower_hour + cost_cond_hour + cost_filter_hour;
        simState.C_indoor_PM_hour = C_prev;
        
        % -----------------------------------------------------------------
        % 5-D.  Log hourly snapshots to pre-allocated arrays
        % -----------------------------------------------------------------
        if h <= length(simArrays.pressure_series)
            simArrays.pressure_series(h) = simState.actual_pressure;
            simArrays.wiper_series(h) = simState.wiper;
            simArrays.Qfan_series(h) = simState.Q_blower;
            simArrays.dust_total_series(h) = simState.dust_total;
            simArrays.filter_life_series(h) = simState.filter_life_pct;
            simArrays.cumulative_cost_energy(h) = simState.cum_cost;
            
            simArrays.blower_cost_series(h) = cost_blower_hour;
            simArrays.cond_cost_series(h) = cost_cond_hour;
            simArrays.filter_cost_series(h) = cost_filter_hour;
            
            if size(simArrays.C_indoor_PM, 1) >= h && size(simArrays.C_indoor_PM, 2) >= length(simState.C_indoor_PM_hour)
                simArrays.C_indoor_PM(h, 1:length(simState.C_indoor_PM_hour)) = simState.C_indoor_PM_hour;
            else
                fprintf('[runSimulation] WARNING: Array size mismatch when storing indoor PM at hour %d\n', h);
            end
            
            simArrays.clog_event(h) = clog_event_hour;
        else
            fprintf('[runSimulation] WARNING: Hour %d exceeds pre-allocated array size\n', h);
        end
        
        % Store loop execution time for progress estimation
        updateTimes(end+1) = toc(loopStartTime);
        if length(updateTimes) > 10
            updateTimes = updateTimes(end-9:end);  % Keep last 10 measurements
        end
        
        % Provide occasional progress updates to console
        if mod(h, 500) == 0 || h == 1 || h == timeParams.num_hours
            fprintf('[runSimulation] Completed hour %d of %d (%.1f%%)\n', ...
                   h, timeParams.num_hours, 100*h/timeParams.num_hours);
        end
    end  % End of main hourly loop
    
    % Close progress bar
    if exist('progressBar', 'var') && ishandle(progressBar)
        close(progressBar);
    end
    
    fprintf('[runSimulation] Simulation completed successfully: %d hours\n', timeParams.num_hours);
    fprintf('[runSimulation] Filter replacements: %d, Final pressure: %.2f Pa\n', ...
           simState.num_replacements, simState.actual_pressure);
catch ME
    % Close progress bar if it exists
    if exist('progressBar', 'var') && ishandle(progressBar)
        close(progressBar);
    end
    
    fprintf('[ERROR] in runSimulation: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    rethrow(ME);
end
end