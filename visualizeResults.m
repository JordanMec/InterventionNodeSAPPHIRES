function visualizeResults(results, num_hours, particleParams)
% Create visualization figures of the simulation results

fprintf('[visualizeResults] Creating visualization figures\n');
try
    % -----------------------------------------------------------------------
    % 8-A.  House pressure, fan flow, and wiper duty
    % -----------------------------------------------------------------------
    figure('Name','HVAC Control Performance','NumberTitle','off','Color','w');
    tl = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
    
    % 1) House pressure -----------------------------------------------------
    nexttile;
    plot(0:num_hours-1, results.pressure_series,'b','LineWidth',1.2); hold on;
    
    % Check if we have target pressure in results
    if isfield(results, 'guiParams') && isfield(results.guiParams, 'targetPressure')
        yline(results.guiParams.targetPressure,'r--','LineWidth',1);
    end
    
    % Plot service events if available
    if isfield(results, 'service_hours') && ~isempty(results.service_hours)
        plot(results.service_hours, 3*ones(size(results.service_hours)), 'rv', ...
             'MarkerFaceColor','r','DisplayName','Filter swap');
    end
    
    xlabel('Hour'); ylabel('Pressure (Pa)');
    title('House pressure vs. set-point');
    grid on; legend('Pressure','Set-point','Replacement');
    
    % 2) Blower flow --------------------------------------------------------
    nexttile;
    plot(0:num_hours-1, results.Qfan_series,'k','LineWidth',1.2);
    xlabel('Hour'); ylabel('Flow (CFM)');
    title('Blower flow (hourly final value)');
    grid on;
    
    % 3) PID wiper signal ---------------------------------------------------
    nexttile;
    plot(0:num_hours-1, results.wiper_series,'m','LineWidth',1.2);
    xlabel('Hour'); ylabel('PWM duty (0-128)');
    title('PID control signal (wiper)');
    grid on;
    
    fprintf('[visualizeResults] Created Figure 1: HVAC Control Performance\n');
    
    % -----------------------------------------------------------------------
    % 8-B.  Cost breakdown & filter lifecycle
    % -----------------------------------------------------------------------
    figure('Name','Cost & Filter Life','NumberTitle','off','Color','w');
    tl2 = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    
    % Cumulative operating cost --------------------------------------------
    nexttile([1 2]);
    plot(0:num_hours-1, results.cumulative_cost_energy,'LineWidth',1.5); hold on;
    
    % Check if we have cost components
    if isfield(results, 'cum_blower_cost') && isfield(results, 'cum_cond_cost') && isfield(results, 'cum_filter_cost')
        plot(0:num_hours-1, results.cum_blower_cost,':','LineWidth',1);
        plot(0:num_hours-1, results.cum_cond_cost ,'-.','LineWidth',1);
        plot(0:num_hours-1, results.cum_filter_cost,'--','LineWidth',1);
        legend('Total','Blower','Heating/Cooling','Filter','Location','northwest');
    else
        legend('Total Cost','Location','northwest');
    end
    
    xlabel('Hour'); ylabel('Cost ($)');
    title('Cumulative operating cost - total and components');
    grid on;
    
    % Filter life % ---------------------------------------------------------
    nexttile;
    plot(0:num_hours-1, results.filter_life_series,'LineWidth',1.2); hold on;
    
    % Plot service events if available
    if isfield(results, 'service_hours') && ~isempty(results.service_hours)
        plot(results.service_hours, 100*ones(size(results.service_hours)), 'kv', ...
             'MarkerFaceColor','k','DisplayName','Replacement');
    end
    
    xlabel('Hour'); ylabel('Life (%)');
    title('Remaining filter life');
    ylim([0 105]); grid on;
    
    % Dust load -------------------------------------------------------------
    nexttile;
    plot(0:num_hours-1, results.dust_total_series,'LineWidth',1.2);
    xlabel('Hour'); ylabel('Dust (g)');
    title('Total dust captured by filter');
    grid on;
    
    fprintf('[visualizeResults] Created Figure 2: Cost & Filter Life\n');
    
    % -----------------------------------------------------------------------
    % 8-C.  Indoor vs. outdoor PM for key bins (optional)
    % -----------------------------------------------------------------------
    if isfield(results, 'C_indoor_PM') && ~isempty(results.C_indoor_PM)
        figure('Name','Indoor PM (snapshots)','NumberTitle','off','Color','w');
        
        % Select bins to display - safely handle different particle size configurations
        if isfield(particleParams, 'particle_sizes') && length(particleParams.particle_sizes) >= 4
            defaultBins = [1, 3, 4, 6];  % indices for 0.3, 1, 2.5, 10 um
            bins2show = defaultBins(defaultBins <= length(particleParams.particle_sizes));
        else
            bins2show = 1:min(4, size(results.C_indoor_PM, 2));
        end
        
        for i = 1:length(bins2show)
            idx = bins2show(i);
            subplot(length(bins2show), 1, i);
            
            % Safely plot indoor PM
            if idx <= size(results.C_indoor_PM, 2)
                plot(0:num_hours-1, results.C_indoor_PM(:, idx), 'b', 'LineWidth', 1.1); 
                
                % Label with particle size if available
                if isfield(particleParams, 'particle_sizes') && idx <= length(particleParams.particle_sizes)
                    ylabel(sprintf('PM %.1f um (ug/m3)', particleParams.particle_sizes(idx)));
                else
                    ylabel(sprintf('PM bin %d (ug/m3)', idx));
                end
                
                if i == 1
                    title('Indoor PM concentrations - hourly');
                end
                grid on;
            end
        end
        xlabel('Hour');
        
        fprintf('[visualizeResults] Created Figure 3: Indoor PM\n');
    else
        fprintf('[visualizeResults] Skipping Indoor PM figure (data not available)\n');
    end
    
    fprintf('[visualizeResults] Visualization complete\n');
catch ME
    fprintf('[ERROR] in visualizeResults: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('[visualizeResults] Visualization failed but continuing simulation\n');
    rethrow(ME);
end
end