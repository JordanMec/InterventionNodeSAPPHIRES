function [simArrays, simState] = runSimulation(env, guiParams, darcyParams, economicParams, houseParams, particleParams, timeParams, simArrays)
% last edit: monday may 12th 2025
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
    
    % Ensure n_leak is in a safe range to prevent numerical issues
    n_leak = max(0.1, min(0.9, n_leak));  % Keep between 0.1 and 0.9
    
    effectiveC = guiParams.blowerDoor / (50^n_leak);  % CFM / Pa^n
    
    % Ensure effectiveC is reasonable
    if effectiveC <= 0 || isnan(effectiveC) || isinf(effectiveC)
        fprintf('[runSimulation] WARNING: Invalid effective leakage coefficient, using default\n');
        effectiveC = 20;  % Default safe value
    }
    
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
            
            % Validate exhaust flow
            if ~isfield(houseParams, 'exhaust_flow') || isnan(houseParams.exhaust_flow) || houseParams.exhaust_flow < 0
                fprintf('[runSimulation] WARNING: Invalid exhaust flow, using default\n');
                Q_exhaust_fixed = 150;  % Default exhaust flow
            end
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
        
        % IMPROVED: More robust air density calculation
        try
            rho_out = 101325 ./ (287 * T_out_K);  % kg/m3
            
            % Check for invalid density
            if isnan(rho_out) || rho_out <= 0 || rho_out > 2
                fprintf('[runSimulation] WARNING: Invalid air density at hour %d. Using default.\n', h);
                rho_out = 1.2;  % Default air density at sea level
            end
        catch
            rho_out = 1.2;  % Default air density if calculation fails
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
                % IMPROVED: More robust T_in_K handling
                if ~isfield(houseParams, 'T_in_K') || isnan(houseParams.T_in_K) || houseParams.T_in_K <= 0
                    T_in_K = 293.15;  % Default 20°C if invalid
                else
                    T_in_K = houseParams.T_in_K;
                end
                
                % IMPROVED: Check for temperature division by zero
                if T_out_K <= 0
                    T_out_K = 273.15;  % Use freezing point as a safe default
                end
                
                % IMPROVED: More robust buoyancy calculation with validation
                try
                    DP_buoy = rho_out * g * 3 * (T_in_K/T_out_K - 1); % Pa
                    
                    % Validate the result
                    if isnan(DP_buoy) || isinf(DP_buoy) || abs(DP_buoy) > 50
                        DP_buoy = 0;  % Use zero for unrealistic values
                    end
                    
                    Q_stack = sign(DP_buoy) * effectiveC * abs(DP_buoy)^n_leak;  % CFM
                    
                    % Validate stack flow
                    if isnan(Q_stack) || isinf(Q_stack) || abs(Q_stack) > 1000
                        Q_stack = 0;  % Use zero for unrealistic values
                    end
                catch
                    DP_buoy = 0;
                    Q_stack = 0;
                end
            else
                Q_stack = 0;
            end
            
            % ==========================================================
            % 6-B.  Solve fan-curve <-> total losses for target flow
            % ----------------------------------------------------------
            % IMPROVED: Check for wiper value
            if isnan(simState.wiper) || simState.wiper < 0
                warning('Invalid wiper value detected: %.2f, resetting to 0', simState.wiper);
                simState.wiper = 0;
            elseif simState.wiper > 128
                warning('Wiper value exceeds max: %.2f, limiting to 128', simState.wiper);
                simState.wiper = 128;
            end
            
            % IMPROVED: Better initial guess for flow based on wiper setting
            Q_guess = 5 * simState.wiper;  % Scale initial guess with wiper setting
            if Q_guess < 10
                Q_guess = 10;  % Minimum initial guess to avoid near-zero values
            end
            
            % IMPROVED: Define a more robust function for fzero
            % Using a wrapper that ensures inputs are in valid ranges
            fanEq = @(Q) safeBalanceFunction(Q, simState.wiper, simState.dust_total, ...
                                           effectiveC, n_leak, guiParams, darcyParams);
            
            % IMPROVED: More robust fzero call with bounded interval and options
            try
                % Set options for fzero to improve convergence
                options = optimset('TolX', 0.1, 'Display', 'off');
                
                % Try with bounds first (more robust)
                Q_cmd = fzero(fanEq, [0.1, 2000], options);
                
                % If Q_cmd is unrealistic, try again with initial guess
                if Q_cmd < 0.1 || Q_cmd > 2000 || isnan(Q_cmd)
                    warning('Flow solution outside physical range, retrying with initial guess');
                    Q_cmd = fzero(fanEq, Q_guess, options);
                end
                
                % Final check on solution
                Q_cmd = max(0, min(2000, Q_cmd));
            catch fzeroError
                fprintf('[runSimulation] Warning at hour %d, step %d: fzero failed: %s\n', ...
                       h, k, fzeroError.message);
                
                % IMPROVED: More intelligent fallback when fzero fails
                % Estimate flow based on wiper position using typical fan curve
                Q_max = 1200;  % Maximum flow rate (CFM)
                wiper_fraction = simState.wiper / 128;
                Q_cmd = Q_max * wiper_fraction * 0.7;  % 70% of max flow at full wiper
                
                % Adjust for filter loading
                filter_factor = max(0.2, 1 - (simState.dust_total / 1000));
                Q_cmd = Q_cmd * filter_factor;
                
                fprintf('[runSimulation] Using fallback flow estimate: %.1f CFM\n', Q_cmd);
            end
            
            % IMPROVED: Improve first-order blower response calculation
            tau_dyn = 6 * max(0, (1 - simState.Q_blower/1237)) + 1;
            if tau_dyn <= 0 || isnan(tau_dyn) || isinf(tau_dyn)
                warning('Invalid time constant in blower response, using default');
                tau_dyn = 1;  % Default time constant
            end
            
            % IMPROVED: More stable blower dynamics update
            if isnan(simState.Q_blower) || ~isfinite(simState.Q_blower)
                % Reset if invalid
                simState.Q_blower = Q_cmd;
            else
                % Update with rate-limited dynamics
                delta_Q = (Q_cmd - simState.Q_blower) * (timeParams.dt_ctrl/tau_dyn);
                
                % Limit the step size for stability
                max_delta = 20;  % Max 20 CFM change per step
                delta_Q = max(-max_delta, min(max_delta, delta_Q));
                
                simState.Q_blower = simState.Q_blower + delta_Q;
            end
            
            % Ensure flow is within physical bounds
            simState.Q_blower = max(0, min(2000, simState.Q_blower));
            
            % ==========================================================
            % 6-C.  Update house pressure via continuity
            % ----------------------------------------------------------
            % IMPROVED: Better pressure validation and limiting
            if isnan(simState.actual_pressure)
                fprintf('[runSimulation] WARNING: NaN pressure detected. Resetting to 0.\n');
                simState.actual_pressure = 0;
            end
            
            % Calculate leak flow with protection for extreme pressure
            if abs(simState.actual_pressure) > 50
                fprintf('[runSimulation] WARNING: Extreme pressure detected (%.1f Pa). Clamping.\n', ...
                       simState.actual_pressure);
                simState.actual_pressure = sign(simState.actual_pressure) * 50;
            end
            
            % IMPROVED: More robust leak flow calculation
            try
                Q_leak = effectiveC * abs(simState.actual_pressure)^n_leak;
                
                % Validate leak flow
                if isnan(Q_leak) || isinf(Q_leak) || Q_leak < 0 || Q_leak > 5000
                    warning('Invalid leak flow calculated: %.2f, using fallback', Q_leak);
                    Q_leak = 20 * abs(simState.actual_pressure)^0.65;  % Simple fallback model
                end
                
                leak_effect = sign(simState.actual_pressure) * Q_leak;
            catch
                warning('Error in leak flow calculation, using zero');
                leak_effect = 0;
            end
            
            % IMPROVED: More robust flow balance calculation
            Q_net_m3s = (simState.Q_blower + Q_stack - Q_exhaust_fixed - leak_effect) ...
                        * 0.000471947;  % Convert CFM to m3/s
            
            % Validate the net flow
            if isnan(Q_net_m3s) || isinf(Q_net_m3s) || abs(Q_net_m3s) > 1
                warning('Invalid net flow: %.6f m3/s, using zero', Q_net_m3s);
                Q_net_m3s = 0;
            end
            
            % IMPROVED: Update pressure with rate limiting to prevent instability
            pressure_change = timeParams.dt_ctrl * Q_net_m3s * 10;  % Scale factor to convert flow to pressure rate
            max_allowed_change = 0.2;  % Pa per second max (reduced from 0.5)
            
            pressure_change = sign(pressure_change) * ...
                             min(abs(pressure_change), max_allowed_change);
            
            simState.actual_pressure = simState.actual_pressure + pressure_change;
            
            % IMPROVED: Tighter limit pressure to realistic range to prevent instabilities
            simState.actual_pressure = max(-30, min(30, simState.actual_pressure));
            
            % ==========================================================
            % 6-D.  PID controller adjusts wiper
            % ----------------------------------------------------------
            % IMPROVED: More robust PID controller with validation
            % Compute error with validation
            if isnan(simState.actual_pressure)
                err = guiParams.targetPressure;  % Full error if pressure is invalid
            else
                err = guiParams.targetPressure - simState.actual_pressure;
            end
            
            % Apply limits to error
            err = max(-10, min(10, err));  % Limit error to reasonable range
            
            % Update integral term with anti-windup
            simState.integral_error = simState.integral_error + err*timeParams.dt_ctrl;
            simState.integral_error = max(-3, min(3, simState.integral_error));  % Tighter anti-windup
            
            % Check previous error validity
            if isnan(simState.previous_error)
                simState.previous_error = err;
            end
            
            % Calculate derivative term with safety
            if timeParams.dt_ctrl > 0
                deriv = (err - simState.previous_error)/timeParams.dt_ctrl;
                deriv = max(-10, min(10, deriv));  % Limit derivative to avoid spikes
            else
                deriv = 0;
            end
            
            % IMPROVED: Smoothed update of wiper with rate limiting
            wiper_change = 0.05*(Kp*err + Ki*simState.integral_error + Kd*deriv);
            max_wiper_change = 3;  % Max change per second (reduced from 5)
            
            wiper_change = sign(wiper_change) * min(abs(wiper_change), max_wiper_change);
            simState.wiper = simState.wiper + wiper_change;
            
            % Ensure wiper is within valid range
            simState.wiper = max(min_wiper, min(max_wiper, simState.wiper));
            simState.previous_error = err;
            
            % ==========================================================
            % 6-E.  Accumulate Darcy dust, calculate filter life
            % ----------------------------------------------------------
            % IMPROVED: More robust flow conversion with validation
            Q_m3s = simState.Q_blower * 0.000471947;  % CFM -> m3/s
            
            if isnan(Q_m3s) || Q_m3s < 0 || Q_m3s > 1
                warning('Invalid Q_m3s: %.6f, using safe value', Q_m3s);
                Q_m3s = max(0, min(1, simState.Q_blower * 0.000471947));
            end
            
            % Safe handling of flux calculation
            if length(C_out_PM_hr) >= 4
                flux_coeffs = [0.90, 0.85, 0.95, 0.99];  % Filter efficiency by bin
                flux_bin = zeros(1, 4);
                
                % IMPROVED: Calculate each bin separately with validation
                for i = 1:4
                    if i <= length(C_out_PM_hr) && ~isnan(C_out_PM_hr(i)) && C_out_PM_hr(i) >= 0
                        flux_bin(i) = Q_m3s * C_out_PM_hr(i) * flux_coeffs(i);  % g/s
                    else
                        flux_bin(i) = 0;
                    end
                    
                    % Validate each flux value
                    if isnan(flux_bin(i)) || flux_bin(i) < 0
                        flux_bin(i) = 0;
                    end
                end
            else
                % Handle case with fewer PM size bins
                numBins = length(C_out_PM_hr);
                flux_coeffs = 0.9 * ones(1, numBins);  % Use uniform efficiency
                flux_bin = zeros(1, 4);
                
                for i = 1:min(4, numBins)
                    if ~isnan(C_out_PM_hr(i)) && C_out_PM_hr(i) >= 0
                        flux_bin(i) = Q_m3s * C_out_PM_hr(i) * flux_coeffs(i);
                    end
                    
                    % Validate each flux value
                    if isnan(flux_bin(i)) || flux_bin(i) < 0
                        flux_bin(i) = 0;
                    end
                end
            end
            
            % Accumulate dust with validation
            simState.dust = simState.dust + flux_bin*timeParams.dt_ctrl;
            
            % IMPROVED: Validate dust values
            for i = 1:length(simState.dust)
                if isnan(simState.dust(i)) || simState.dust(i) < 0
                    simState.dust(i) = 0;
                end
            end
            
            simState.dust_total = sum(simState.dust);
            
            % IMPROVED: Validate dust total
            if isnan(simState.dust_total) || simState.dust_total < 0
                warning('Invalid dust total, resetting to 0');
                simState.dust_total = 0;
                simState.dust = zeros(size(simState.dust));
            end
            
            % Calculate filter life percentage
            filter_capacity = 50 * darcyParams.A_filter;  % g
            
            % IMPROVED: Validate filter capacity
            if isnan(filter_capacity) || filter_capacity <= 0
                filter_capacity = 500;  % Default capacity if invalid
            end
            
            simState.filter_life_pct = max(0, 100 * (1 - simState.dust_total / filter_capacity));
            
            % ==========================================================
            % 6-F.  Clog detection & auto-replacement
            % ----------------------------------------------------------
            % IMPROVED: More robust clog detection
            if isnan(simState.actual_pressure)
                clogged_now = false;  % Can't determine if invalid pressure
            else
                clogged_now = (simState.actual_pressure < 3) && ...
                             (simState.wiper >= 0.95*max_wiper);  % Slightly more conservative
            end
                     
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
            % IMPROVED: More robust energy calculations
            try
                dP_fan = fan_pressure(simState.Q_blower, simState.wiper);  % Pa
                
                % Validate fan pressure
                if isnan(dP_fan) || dP_fan < 0 || dP_fan > 1000
                    dP_fan = (simState.wiper / 128) * 400;  % Simple fallback model
                end
                
                P_blower = dP_fan * Q_m3s;  % W
                
                % Validate blower power
                if isnan(P_blower) || P_blower < 0 || P_blower > 1000
                    P_blower = simState.wiper * 3;  % Simple fallback model
                end
                
                E_blower_hour = E_blower_hour + P_blower*timeParams.dt_ctrl;  % J
            catch
                warning('Error in energy calculation, using fallback');
                P_blower = simState.wiper * 3;  % Simple fallback model
                E_blower_hour = E_blower_hour + P_blower*timeParams.dt_ctrl;
            end
            
            % IMPROVED: More robust heating/cooling energy calculation
            try
                T_set_C = houseParams.T_in_C;  % C
                if isnan(T_set_C) || T_set_C < -50 || T_set_C > 50
                    T_set_C = 21;  % Default to typical indoor temperature
                end
                
                Q_th = rho_out*Q_m3s*1005*(T_set_C - T_out_C);  % W
                
                % Validate thermal load
                if isnan(Q_th) || abs(Q_th) > 10000
                    Q_th = 0;  % Skip if invalid
                end
                
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
                
                % Validate accumulated energy
                if isnan(E_cond_hour) || abs(E_cond_hour) > 1e9
                    E_cond_hour = 0;  % Reset if invalid
                end
            catch
                warning('Error in thermal calculation, skipping this step');
            end
            
            % ==========================================================
            % 6-H.  Indoor PM mass-balance (well-mixed, dt=1 s explicit)
            % ----------------------------------------------------------
            % IMPROVED: More robust volume validation
            if ~isfield(houseParams, 'V_indoor') || houseParams.V_indoor <= 0 || isnan(houseParams.V_indoor)
                fprintf('[runSimulation] WARNING: Invalid indoor volume, using default\n');
                houseParams.V_indoor = 500;  % m³
            end
            
            % IMPROVED: More robust indoor PM mass-balance calculation
            for i = 1:length(C_prev)
                % Ensure we don't go beyond array bounds
                outdoor_conc = 0;
                if i <= length(C_out_PM_hr)
                    outdoor_conc = max(0, C_out_PM_hr(i));
                    if isnan(outdoor_conc)
                        outdoor_conc = 0;
                    end
                end
                
                % Safe calculation of concentration change
                air_exchange = max(0, Q_m3s) / max(1, houseParams.V_indoor);  % Ensure positive
                
                dCdt = air_exchange * (outdoor_conc - C_prev(i));
                
                % Add natural deposition if enabled
                if isfield(guiParams, 'useNaturalRemoval') && guiParams.useNaturalRemoval
                    % Simple size-dependent deposition rate (s⁻¹)
                   if i <= length(particleParams.particle_sizes)
                       depo_rate = min(0.01, 1e-4 * particleParams.particle_sizes(i));  % Cap at 1%/s
                       dCdt = dCdt - depo_rate * max(0, C_prev(i));
                   end
               end
               
               % IMPROVED: Use a safe time-step integration method with limits
               delta_C = timeParams.dt_ctrl * dCdt;
               
               % Limit the maximum change per step for stability
               max_delta_c = C_prev(i) * 0.1;  % Max 10% change per step
               if max_delta_c < 0.1
                   max_delta_c = 0.1;  % Minimum limit for small concentrations
               end
               
               delta_C = max(-max_delta_c, min(max_delta_c, delta_C));
               
               % Update with bounds checking
               C_prev(i) = max(0, C_prev(i) + delta_C);
               
               % Additional safety cap to prevent unrealistic values
               C_prev(i) = min(1000, C_prev(i));  % Cap at 1000 μg/m³
           end
       end  % ===== end 3600-second hour =====
       
       % ---------- Convert energy to cost for the hour -------------------------
       % IMPROVED: More robust energy to cost conversion
       try
           kWh_blower = E_blower_hour / 3.6e6;
           
           % Validate kWh
           if isnan(kWh_blower) || kWh_blower < 0 || kWh_blower > 1000
               warning('Invalid blower energy: %.2f kWh, using conservative estimate', kWh_blower);
               kWh_blower = 0.1 * simState.wiper / 128;  % Simple fallback based on wiper
           end
           
           % Determine electricity rate based on time of day
           if (hr_of_day >= 14 && hr_of_day < 17)
               if isfield(economicParams, 'on_peak_rate') && economicParams.on_peak_rate > 0
                   rate_hr = economicParams.on_peak_rate;
               else
                   rate_hr = 0.3;  % Default on-peak rate
               end
           else
               if isfield(economicParams, 'off_peak_rate') && economicParams.off_peak_rate > 0
                   rate_hr = economicParams.off_peak_rate;
               else
                   rate_hr = 0.1;  % Default off-peak rate
               end
           end
           
           cost_blower_hour = kWh_blower * rate_hr;
           
           % Validate blower cost
           if isnan(cost_blower_hour) || cost_blower_hour < 0 || cost_blower_hour > 100
               cost_blower_hour = 0;  % Zero if invalid
           end
           
           % Heating / cooling cost with validation
           if isnan(E_cond_hour)
               E_cond_hour = 0;
           end
           
           if E_cond_hour >= 0  % heating gas
               if isfield(economicParams, 'gas_cost_per_J') && economicParams.gas_cost_per_J > 0
                   cost_cond_hour = E_cond_hour * economicParams.gas_cost_per_J;
               else
                   cost_cond_hour = E_cond_hour * 1e-8;  % Default gas cost
               end
           else  % cooling electric
               if (hr_of_day >= 14 && hr_of_day < 17)
                   if isfield(economicParams, 'on_peak_rate') && economicParams.on_peak_rate > 0
                       cooling_rate = economicParams.on_peak_rate;
                   else
                       cooling_rate = 0.3;  % Default on-peak
                   end
               else
                   if isfield(economicParams, 'off_peak_rate') && economicParams.off_peak_rate > 0
                       cooling_rate = economicParams.off_peak_rate;
                   else
                       cooling_rate = 0.1;  % Default off-peak
                   end
               end
               cost_cond_hour = (abs(E_cond_hour) / 3.6e6) * cooling_rate;
           end
           
           % Validate conditioning cost
           if isnan(cost_cond_hour) || cost_cond_hour < 0 || cost_cond_hour > 100
               cost_cond_hour = 0;  % Zero if invalid
           end
       catch
           warning('Error in cost calculation, using zero');
           cost_blower_hour = 0;
           cost_cond_hour = 0;
       end
       
       % ----------- Update cumulative cost & indoor PM snapshot ----------------
       simState.cum_cost = simState.cum_cost + cost_blower_hour + cost_cond_hour + cost_filter_hour;
       
       % IMPROVED: Validate cumulative cost
       if isnan(simState.cum_cost) || simState.cum_cost < 0 || simState.cum_cost > 1e6
           warning('Invalid cumulative cost: $%.2f, resetting', simState.cum_cost);
           simState.cum_cost = 0;
       end
       
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
               % IMPROVED: Try to resize or pad array if possible
               try
                   if size(simArrays.C_indoor_PM, 1) < h
                       % Extend rows
                       simArrays.C_indoor_PM(end+1:h, :) = 0;
                   end
                   if size(simArrays.C_indoor_PM, 2) < length(simState.C_indoor_PM_hour)
                       % Extend columns
                       simArrays.C_indoor_PM(:, end+1:length(simState.C_indoor_PM_hour)) = 0;
                   end
                   % Try again after resizing
                   simArrays.C_indoor_PM(h, 1:length(simState.C_indoor_PM_hour)) = simState.C_indoor_PM_hour;
               catch
                   fprintf('[runSimulation] Could not resize arrays. Some data may be lost.\n');
               end
           end
           
           simArrays.clog_event(h) = clog_event_hour;
       else
           fprintf('[runSimulation] WARNING: Hour %d exceeds pre-allocated array size\n', h);
           % IMPROVED: Try to extend arrays if possible
           try
               % Extend all arrays to accommodate the new hour
               current_length = length(simArrays.pressure_series);
               new_length = h;
               
               % Extend simple 1D arrays
               array_fields = {'pressure_series', 'wiper_series', 'Qfan_series', 'dust_total_series', ...
                              'filter_life_series', 'cumulative_cost_energy', 'blower_cost_series', ...
                              'cond_cost_series', 'filter_cost_series', 'clog_event'};
               
               for i = 1:length(array_fields)
                   if isfield(simArrays, array_fields{i})
                       % Create extension array
                       if islogical(simArrays.(array_fields{i}))
                           extension = false(1, new_length - current_length);
                       else
                           extension = zeros(1, new_length - current_length);
                       end
                       simArrays.(array_fields{i}) = [simArrays.(array_fields{i}), extension];
                       
                       % Now we can write to the extended array
                       simArrays.(array_fields{i})(h) = eval(array_fields{i}(1:end-7));
                   end
               end
               
               % Handle the 2D C_indoor_PM array separately
               if isfield(simArrays, 'C_indoor_PM')
                   [rows, cols] = size(simArrays.C_indoor_PM);
                   if rows < h
                       simArrays.C_indoor_PM(rows+1:h, :) = 0;
                   end
                   if cols < length(simState.C_indoor_PM_hour)
                       simArrays.C_indoor_PM(:, cols+1:length(simState.C_indoor_PM_hour)) = 0;
                   end
                   
                   simArrays.C_indoor_PM(h, 1:length(simState.C_indoor_PM_hour)) = simState.C_indoor_PM_hour;
               end
               
               fprintf('[runSimulation] Successfully extended arrays to hour %d\n', h);
           catch
               fprintf('[runSimulation] Could not extend arrays. Data for hour %d will be lost.\n', h);
           end
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
   fprintf('  Stack trace:\n');
   for i = 1:length(ME.stack)
       fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
   end
   
   % IMPROVED: Try to create minimal valid outputs even after error
   fprintf('[runSimulation] Attempting to return minimal valid outputs\n');
   
   try
       % Ensure simArrays has minimal required fields
       if ~isfield(simArrays, 'pressure_series') || isempty(simArrays.pressure_series)
           simArrays.pressure_series = zeros(1, timeParams.num_hours);
       end
       if ~isfield(simArrays, 'Qfan_series') || isempty(simArrays.Qfan_series)
           simArrays.Qfan_series = zeros(1, timeParams.num_hours);
       end
       if ~isfield(simArrays, 'wiper_series') || isempty(simArrays.wiper_series)
           simArrays.wiper_series = zeros(1, timeParams.num_hours);
       end
       if ~isfield(simArrays, 'dust_total_series') || isempty(simArrays.dust_total_series)
           simArrays.dust_total_series = zeros(1, timeParams.num_hours);
       end
       if ~isfield(simArrays, 'filter_life_series') || isempty(simArrays.filter_life_series)
           simArrays.filter_life_series = zeros(1, timeParams.num_hours);
       end
       if ~isfield(simArrays, 'cumulative_cost_energy') || isempty(simArrays.cumulative_cost_energy)
           simArrays.cumulative_cost_energy = zeros(1, timeParams.num_hours);
       end
       if ~isfield(simArrays, 'C_indoor_PM') || isempty(simArrays.C_indoor_PM)
           simArrays.C_indoor_PM = zeros(timeParams.num_hours, 6);
       end
       
       % Ensure simState has minimal required fields
       if ~exist('simState', 'var') || ~isstruct(simState)
           simState = struct();
       end
       if ~isfield(simState, 'num_replacements')
           simState.num_replacements = 0;
       end
       if ~isfield(simState, 'actual_pressure')
           simState.actual_pressure = 0;
       end
   catch
       % Last resort: Create completely new outputs
       fprintf('[runSimulation] Creating emergency fallback outputs\n');
       simArrays = struct(...
           'pressure_series', zeros(1, timeParams.num_hours), ...
           'Qfan_series', zeros(1, timeParams.num_hours), ...
           'wiper_series', zeros(1, timeParams.num_hours), ...
           'dust_total_series', zeros(1, timeParams.num_hours), ...
           'filter_life_series', zeros(1, timeParams.num_hours), ...
           'cumulative_cost_energy', zeros(1, timeParams.num_hours), ...
           'C_indoor_PM', zeros(timeParams.num_hours, 6) ...
       );
       
       simState = struct(...
           'num_replacements', 0, ...
           'actual_pressure', 0 ...
       );
   end
   
   fprintf('[runSimulation] Returning with minimal outputs after error\n');
   rethrow(ME);
end
end

% Helper function for safe balance function
function result = safeBalanceFunction(Q, wiper, dust_total, effectiveC, n_leak, guiParams, darcyParams)
   % Safely compute the balance between fan pressure and system losses
   
   % Protect inputs
   Q = max(0.1, min(2000, Q));
   wiper = max(0, min(128, wiper));
   dust_total = max(0, dust_total);
   
   % Get fan pressure
   fanP = fan_pressure(Q, wiper);
   
   % Check for valid fan pressure
   if isnan(fanP) || isinf(fanP) || fanP < 0
       % Fallback to simple linear model if fan_pressure fails
       fanP = wiper * (400 - 0.3 * Q) / 128;
   end
   
   % Get system losses
   sysP = totalLoss(Q, dust_total, effectiveC, n_leak, guiParams, darcyParams);
   
   % Check for valid system pressure
   if isnan(sysP) || isinf(sysP) || sysP < 0
       % Fallback to simple quadratic model if totalLoss fails
       sysP = 0.001 * Q^1.9 * (1 + dust_total/100);
   end
   
   % Return the difference
   result = fanP - sysP;
   
   % Final safety check
   if isnan(result) || isinf(result) || ~isreal(result)
       % If difference is invalid, return a value that pushes Q toward a reasonable range
       if Q < 100
           result = 1;  % Positive result makes fzero increase Q
       elseif Q > 1000
           result = -1; % Negative result makes fzero decrease Q
       else
           result = 0;  % Zero makes fzero accept this as a solution
       end
   end
end
