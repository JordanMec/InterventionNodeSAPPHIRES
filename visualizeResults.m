function visualizeResults(results, num_hours, particleParams)
% =========================================================================
% visualizeResults.m - Create Visualization Figures
% =========================================================================
% Description:
%   This function creates visualization figures for the simulation results.
%   It generates plots for HVAC control performance, costs, filter life,
%   and indoor air quality.
%
% Inputs:
%   results        - Structure with processed simulation results
%   num_hours      - Total number of simulation hours
%   particleParams - Structure with particle size parameters
%
% Outputs:
%   None (creates figures)
%
% Related files:
%   - godMode.m: Calls this function after post-processing
%   - postProcessResults.m: Provides the processed results to visualize
%   - compareScenarios.m: Creates similar visualizations for comparisons
%
% Notes:
%   - Creates multiple figures:
%     * Figure 1: HVAC Control Performance (pressure, flow, wiper)
%     * Figure 2: Cost & Filter Life (costs, filter life, dust)
%     * Figure 3: Indoor PM Concentrations (by size bin)
%   - All plots include appropriate labels and titles
%   - Filter replacement events are marked on relevant plots
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[visualizeResults] Creating visualization figures\n');

try
    % -------------------------------------------------------------------------
    % Figure 1: HVAC Control Performance
    % -------------------------------------------------------------------------
    figure('Name','HVAC Control Performance','NumberTitle','off','Color','w');
    tl = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
    
    % Plot 1: House pressure vs. setpoint
    nexttile;
    plot(0:num_hours-1, results.pressure_series,'b','LineWidth',1.2); hold on;
    
    % Add target pressure line if available
    if isfield(results, 'guiParams') && isfield(results.guiParams, 'targetPressure')
        yline(results.guiParams.targetPressure,'r--','LineWidth',1);
    end
    
    % Mark filter replacement events if available
    if isfield(results, 'service_hours') && ~isempty(results.service_hours)
        plot(results.service_hours, 3*ones(size(results.service_hours)), 'rv', 'MarkerFaceColor','r','DisplayName','Filter swap');
    end
    
    xlabel('Hour'); ylabel('Pressure (Pa)');
    title('House pressure vs. set-point');
    grid on; legend('Pressure','Set-point','Replacement');
    
    % Plot 2: Blower flow
    nexttile;
    plot(0:num_hours-1, results.Qfan_series,'k','LineWidth',1.2);
    xlabel('Hour'); ylabel('Flow (CFM)');
    title('Blower flow (hourly final value)');
    grid on;
    
    % Plot 3: PID control signal (wiper)
    nexttile;
    plot(0:num_hours-1, results.wiper_series,'m','LineWidth',1.2);
    xlabel('Hour'); ylabel('PWM duty (0-128)');
    title('PID control signal (wiper)');
    grid on;
    
    fprintf('[visualizeResults] Created Figure 1: HVAC Control Performance\n');
    
    % -------------------------------------------------------------------------
    % Figure 2: Cost & Filter Life
    % -------------------------------------------------------------------------
    figure('Name','Cost & Filter Life','NumberTitle','off','Color','w');
    tl2 = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    
    % Plot 1: Cumulative operating costs
    nexttile([1 2]);
    plot(0:num_hours-1, results.cumulative_cost_energy,'LineWidth',1.5); hold on;
    
    % Add component costs if available
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
    
    % Plot 2: Filter life
    nexttile;
    plot(0:num_hours-1, results.filter_life_series,'LineWidth',1.2); hold on;
    
    % Mark filter replacement events if available
    if isfield(results, 'service_hours') && ~isempty(results.service_hours)
        plot(results.service_hours, 100*ones(size(results.service_hours)), 'kv', 'MarkerFaceColor','k','DisplayName','Replacement');
    end
    
    xlabel('Hour'); ylabel('Life (%)');
    title('Remaining filter life');
    ylim([0 105]); grid on;
    
    % Plot 3: Dust accumulation
    nexttile;
    plot(0:num_hours-1, results.dust_total_series,'LineWidth',1.2);
    xlabel('Hour'); ylabel('Dust (g)');
    title('Total dust captured by filter');
    grid on;
    
    fprintf('[visualizeResults] Created Figure 2: Cost & Filter Life\n');
    
    % -------------------------------------------------------------------------
    % Figure 3: Indoor PM Concentrations
    % -------------------------------------------------------------------------
    if isfield(results, 'C_indoor_PM') && ~isempty(results.C_indoor_PM)
        figure('Name','Indoor PM (snapshots)','NumberTitle','off','Color','w');
        
        % Determine which size bins to show
        if isfield(particleParams, 'particle_sizes') && length(particleParams.particle_sizes) >= 4
            defaultBins = [1, 3, 4, 6];  % Selected size bins (PM0.3, PM1, PM2.5, PM10)
            bins2show = defaultBins(defaultBins <= length(particleParams.particle_sizes));
        else
            bins2show = 1:min(4, size(results.C_indoor_PM, 2));
        end
        
        % Create subplot for each selected size bin
        for i = 1:length(bins2show)
            idx = bins2show(i);
            subplot(length(bins2show), 1, i);
            
            if idx <= size(results.C_indoor_PM, 2)
                plot(0:num_hours-1, results.C_indoor_PM(:, idx), 'b', 'LineWidth', 1.1); 
                
                % Label with size if available
                if isfield(particleParams, 'particle_sizes') && idx <= length(particleParams.particle_sizes)
                    ylabel(sprintf('PM %.1f um (ug/m3)', particleParams.particle_sizes(idx)));
                else
                    ylabel(sprintf('PM bin %d (ug/m3)', idx));
                end
                
                % Add title to first subplot only
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
    % Handle errors
    fprintf('[ERROR] in visualizeResults: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('[visualizeResults] Visualization failed but continuing simulation\n');
    rethrow(ME);
end
end