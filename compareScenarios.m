function compareScenarios(results1, results2, scenario1_name, scenario2_name)
% =========================================================================
% compareScenarios.m - Visualize Scenario Comparisons
% =========================================================================
% Description:
%   This function creates visualization figures that compare the results
%   of two simulation scenarios. It generates side-by-side comparisons
%   of key metrics including PM concentrations, costs, and filter life.
%
% Inputs:
%   results1        - Results structure from first scenario
%   results2        - Results structure from second scenario
%   scenario1_name  - Name of first scenario for labeling
%   scenario2_name  - Name of second scenario for labeling
%
% Outputs:
%   None (creates comparison figures)
%
% Related files:
%   - runScenarioComparison.m: Calls this function after running scenarios
%   - visualizeResults.m: Similar visualization but for single scenario
%
% Notes:
%   - Creates multiple comparison figures:
%     * PM10 concentration time series comparison
%     * Summary metrics comparison (bar charts)
%     * AQI time distribution comparison
%     * Cumulative PM exposure comparison
%   - Scenarios are typically Standard vs. HEPA filtration
%   - Uses LaTeX formatting for axis labels and titles
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Set LaTeX as default interpreter for all text
set(groot, 'defaultTextInterpreter', 'latex', 'defaultAxesTickLabelInterpreter', 'latex', 'defaultLegendInterpreter', 'latex');

fprintf('Generating comparison visualizations: %s vs. %s\n', scenario1_name, scenario2_name);

% Format scenario names for LaTeX (replace underscores with escaped underscores)
scenario1_label = strrep(scenario1_name, '_', '\_');
scenario2_label = strrep(scenario2_name, '_', '\_');
labels = {scenario1_label, scenario2_label};

try
    % -------------------------------------------------------------------------
    % Extract and validate PM10 data
    % -------------------------------------------------------------------------
    PM10_scen1 = results1.C_indoor_PM(:, end);
    PM10_scen2 = results2.C_indoor_PM(:, end);
    
    % Replace NaN values with zeros
    PM10_scen1(isnan(PM10_scen1)) = 0;
    PM10_scen2(isnan(PM10_scen2)) = 0;
    
    % Get time vectors
    num_hours1 = size(results1.C_indoor_PM, 1);
    num_hours2 = size(results2.C_indoor_PM, 1);
    time_hr1 = 0:(num_hours1-1);
    time_hr2 = 0:(num_hours2-1);
    
    % Calculate summary metrics
    PM10_avg1 = mean(PM10_scen1);
    PM10_avg2 = mean(PM10_scen2);
    PM10_max1 = max(PM10_scen1);
    PM10_max2 = max(PM10_scen2);
    
    % Get cost data with validation
    if isfield(results1, 'cumulative_cost_energy') && isfield(results2, 'cumulative_cost_energy')
        cost_total1 = results1.cumulative_cost_energy(end);
        cost_total2 = results2.cumulative_cost_energy(end);
    else
        cost_total1 = sum(results1.cum_blower_cost(end) + results1.cum_cond_cost(end) + results1.cum_filter_cost(end));
        cost_total2 = sum(results2.cum_blower_cost(end) + results2.cum_cond_cost(end) + results2.cum_filter_cost(end));
    end
    
    % Validate cost values
    if isnan(cost_total1) || cost_total1 > 1e6
        warning('Unrealistic cost value detected for scenario 1! Using 0.');
        cost_total1 = 0;
    end
    if isnan(cost_total2) || cost_total2 > 1e6
        warning('Unrealistic cost value detected for scenario 2! Using 0.');
        cost_total2 = 0;
    end
    
    % Calculate hourly costs
    cost_per_hr1 = cost_total1 / num_hours1;
    cost_per_hr2 = cost_total2 / num_hours2;
    
    % -------------------------------------------------------------------------
    % Figure 1: PM10 Time Series Comparison
    % -------------------------------------------------------------------------
    figure('Name', 'Scenario Comparison', 'Color', 'w');
    plot(time_hr1, PM10_scen1, 'r--', 'LineWidth', 1.5);
    hold on;
    plot(time_hr2, PM10_scen2, 'b-', 'LineWidth', 1.5);
    xlabel('Time (hours)');
    ylabel('Total $PM_{10}$ ($\mu\mathrm{g}/\mathrm{m}^3$)');
    title('Indoor $PM_{10}$ Concentration Comparison');
    legend(labels, 'Location', 'best');
    grid on;
    
    % -------------------------------------------------------------------------
    % Print summary to console
    % -------------------------------------------------------------------------
    fprintf('\n--- SUMMARY ---\n');
    fprintf('%s final PM10: %.2f \xB5g/m\xB3\n', scenario1_name, PM10_scen1(end));
    fprintf('%s final PM10: %.2f \xB5g/m\xB3\n', scenario2_name, PM10_scen2(end));
    
    PM10_diff = PM10_scen1(end) - PM10_scen2(end);
    if PM10_scen1(end) > 0
        reduction_percent = 100 * PM10_diff / PM10_scen1(end);
    else
        reduction_percent = 0;
    end
    
    fprintf('Reduction: %.2f \xB5g/m\xB3 (%.1f%%)\n', PM10_diff, reduction_percent);
    fprintf('%s total cost: $%.2f\n', scenario1_name, cost_total1);
    fprintf('%s total cost: $%.2f\n', scenario2_name, cost_total2);
    
    % -------------------------------------------------------------------------
    % Figure 2: Summary Metrics Comparison (Bar Charts)
    % -------------------------------------------------------------------------
    % Prepare data for bar charts
    pm10_avg = [PM10_avg1, PM10_avg2];
    pm10_max = [PM10_max1, PM10_max2];
    cost_total = [cost_total1, cost_total2];
    cost_per_hr = [cost_per_hr1, cost_per_hr2];
    
    figure('Name', 'Run Summary Comparison', 'Color', 'w', 'Position', [100 100 1400 600]);
    tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    
    % Plot 1: Average PM10
    nexttile;
    bar(pm10_avg);
    title('Avg $PM_{10}$ ($\mu\mathrm{g}/\mathrm{m}^3$)');
    ylabel('$\mu\mathrm{g}/\mathrm{m}^3$');
    xticks(1:2); xticklabels(labels); xtickangle(45); grid on;
    
    % Plot 2: Maximum PM10
    nexttile;
    bar(pm10_max);
    title('Max $PM_{10}$ ($\mu\mathrm{g}/\mathrm{m}^3$)');
    ylabel('$\mu\mathrm{g}/\mathrm{m}^3$');
    xticks(1:2); xticklabels(labels); xtickangle(45); grid on;
    
    % Plot 3: Total Cost
    nexttile;
    bar(cost_total);
    title('Total Cost (\$)');
    ylabel('USD');
    xticks(1:2); xticklabels(labels); xtickangle(45); grid on;
    
    % Plot 4: Normalized Cost
    nexttile;
    bar(cost_per_hr);
    title('Normalized Cost (\$/hr)');
    ylabel('USD/hr');
    xticks(1:2); xticklabels(labels); xtickangle(45); grid on;
    
    % Plot 5: Cost per PM10 Reduced
    nexttile;
    if abs(diff(pm10_avg)) > 0
        cost_per_PM10 = abs(diff(cost_total) ./ diff(pm10_avg));
    else
        cost_per_PM10 = 0;
    end
    
    if isnan(cost_per_PM10) || cost_per_PM10 > 1e6
        cost_per_PM10 = 0;
    end
    
    bar(cost_per_PM10);
    title('Cost per $\Delta PM_{10}$ Reduced');
    ylabel('$\$/\mu\mathrm{g}\,\mathrm{m}^{-3}$');
    xticks(1); xticklabels({'$\Delta$ Cost/$\Delta PM_{10}$'});
    grid on;
    
    % -------------------------------------------------------------------------
    % Figure 3: Time in AQI Categories
    % -------------------------------------------------------------------------
    % Define AQI bins and labels
    aqi_bins = [0 54; 55 154; 155 254; 255 354; 355 424; 425 604];
    aqi_labels = {'Good', 'Moderate', 'Unhealthy SG', 'Unhealthy', 'Very Unhealthy', 'Hazardous'};
    
    % Function to compute time spent in each AQI bin
    computeTimeInAQI = @(series) arrayfun(@(i) sum(series >= aqi_bins(i, 1) & series <= aqi_bins(i, 2)), 1:size(aqi_bins, 1));
    
    % Calculate time in each AQI bin
    time_bins1 = computeTimeInAQI(PM10_scen1);
    time_bins2 = computeTimeInAQI(PM10_scen2);
    time_hrs1 = time_bins1;
    time_hrs2 = time_bins2;
    
    % Create bar chart
    figure('Name', 'Time in AQI Categories', 'Color', 'w');
    bar([time_hrs1; time_hrs2]', 'grouped');
    ylabel('Time (hours)');
    title('Time Spent in Indoor AQI Bands');
    legend(labels, 'Location', 'northwest');
    xticks(1:length(aqi_labels)); xticklabels(aqi_labels); xtickangle(45); grid on;
    
    % -------------------------------------------------------------------------
    % Figure 4: Cumulative PM Exposure
    % -------------------------------------------------------------------------
    dt = 1;  % Time step for integration (hours)
    exposure_total = [trapz(time_hr1, PM10_scen1)*dt, trapz(time_hr2, PM10_scen2)*dt];
    
    figure('Name', 'Cumulative PM Exposure', 'Color', 'w');
    bar(exposure_total);
    title('Cumulative $PM_{10}$ Exposure');
    ylabel('$\int PM_{10}\,dt\ (\mu\mathrm{g}\cdot hr/m^3)$');
    xticks(1:2); xticklabels(labels); grid on;
    
    % -------------------------------------------------------------------------
    % Figure 5: AQI Time Series Comparison
    % -------------------------------------------------------------------------
    figure('Name', 'AQI Time Series Comparison', 'Color', 'w', 'Position', [100 100 1200 400]);
    hold on;
    
    % Determine x-axis span
    xmax = max(max(time_hr1), max(time_hr2));
    xcoords = [0, xmax, xmax, 0];
    
    % Draw AQI bands as shaded regions
    for k = 1:size(aqi_bins, 1)
        ycoords = [aqi_bins(k, 1), aqi_bins(k, 1), aqi_bins(k, 2), aqi_bins(k, 2)];
        fill(xcoords, ycoords, [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
    end
    
    % Plot PM10 time series
    h1 = plot(time_hr1, PM10_scen1, 'r--', 'LineWidth', 1.5);
    h2 = plot(time_hr2, PM10_scen2, 'b-', 'LineWidth', 1.5);
    
    % Add AQI labels
    for k = 1:size(aqi_bins, 1)
        ymid = mean(aqi_bins(k, :));
        text(0.5, ymid, aqi_labels{k}, 'FontWeight', 'bold');
    end
    
    % Finalize plot
    xlabel('Time (hours)');
    ylabel('Indoor $PM_{10}$ ($\mu\mathrm{g}/\mathrm{m}^3$)');
    title('Indoor AQI Bands \& $PM_{10}$ Levels');
    legend([h1 h2], labels, 'Location', 'northwest');
    grid on;
    
    fprintf('Comparison visualizations completed.\n');
catch ME
    % Handle errors
    fprintf('Error in comparison visualization: %s\n', ME.message);
    fprintf('Line: %d\n', ME.stack(1).line);
end
end