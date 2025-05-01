function runManualComparison()
% =========================================================================
% updated:  May 1st 2025
% 
% runManualComparison.m
%   Runs HEPA OFF and HEPA ON simulations using aligned PM10 and Temp data.
%   Includes preprocessing, simulation, summary plots, and AQI analysis.
% =========================================================================

%% SECTION 1 - Preprocess and align environmental data
pm10File = 'hourly_81102_2024.csv';
tempFile = 'fortcollins_2024_hourly.txt';
envData   = preprocessEnvData(pm10File, tempFile);

%% SECTION 2 - Run Simulations for HEPA OFF and ON cases
fprintf('Running simulation: HEPA OFF\n');
results_off = runInterventionSim(false, envData);
results_off.metadata.runLabel = 'HEPA_OFF';

fprintf('Running simulation: HEPA ON\n');
results_on  = runInterventionSim(true,  envData);
results_on.metadata.runLabel  = 'HEPA_ON';

%% SECTION 3 - PM10 Time-Series Line Plot
figure('Name','HEPA Intervention Comparison','Color','w');
plot(results_off.control_time/3600, results_off.total_PM10, 'r--','LineWidth',1.5);
hold on;
plot(results_on.control_time/3600,  results_on.total_PM10, 'b-' ,'LineWidth',1.5);
xlabel('Time (hours)');
ylabel('Total PM_{10} (\mu g/m^3)');
legend('HEPA OFF','HEPA ON','Location','best');
title('Indoor PM_{10} Concentration Comparison', 'Interpreter', 'latex');
grid on;

%% SECTION 4 - Text Summary of Key Metrics
fprintf('\n--- SUMMARY ---\n');
fprintf('HEPA OFF final PM10: %.2f \xB5g/m\xB3\n', results_off.metadata.PM10_final_ugm3);
fprintf('HEPA ON  final PM10: %.2f \xB5g/m\xB3\n', results_on.metadata.PM10_final_ugm3);
fprintf('Reduction: %.2f \xB5g/m\xB3 (%.1f%%)\n', ...
    results_off.metadata.PM10_final_ugm3 - results_on.metadata.PM10_final_ugm3, ...
    100*(results_off.metadata.PM10_final_ugm3 - results_on.metadata.PM10_final_ugm3)/results_off.metadata.PM10_final_ugm3);
fprintf('HEPA OFF total cost: $%.2f\n', results_off.metadata.total_cost_usd);
fprintf('HEPA ON  total cost: $%.2f\n', results_on.metadata.total_cost_usd);

%% SECTION 5 - Bar Plot Comparison
labels      = {'HEPA OFF','HEPA ON'};
pm10_avg    = [results_off.metadata.PM10_avg_ugm3, results_on.metadata.PM10_avg_ugm3];
pm10_max    = [results_off.metadata.PM10_max_ugm3, results_on.metadata.PM10_max_ugm3];
cost_total  = [results_off.metadata.total_cost_usd, results_on.metadata.total_cost_usd];
time_hr     = [results_off.metadata.total_time_s, results_on.metadata.total_time_s]/3600;
cost_per_hr = cost_total ./ time_hr;
runtime     = [results_off.metadata.simulation_runtime_s, results_on.metadata.simulation_runtime_s];

figure('Name','Run Summary Comparison','Color','w','Position',[100 100 1400 600]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');

nexttile; 
bar(pm10_avg); 
title('Avg PM_{10} ($\mu g/m^3$)', 'Interpreter', 'latex'); 
ylabel('$\mu g/m^3$', 'Interpreter', 'latex'); 
xticks(1:2); 
xticklabels(labels); 
xtickangle(45); 
grid on;

nexttile; bar(pm10_max); title('Max PM_{10} (\mu g/m^3)', 'Interpreter', 'latex'); ylabel('\xB5g/m\xB3'); xticks(1:2); xticklabels(labels); xtickangle(45); grid on;
nexttile; bar(cost_total); title('Total Cost ($)'); ylabel('USD'); xticks(1:2); xticklabels(labels); xtickangle(45); grid on;
nexttile; bar(cost_per_hr); title('Normalized Cost ($/hr)'); ylabel('USD/hr'); xticks(1:2); xticklabels(labels); xtickangle(45); grid on;
nexttile; bar(runtime); title('Simulation Runtime (s)'); ylabel('Seconds'); xticks(1:2); xticklabels(labels); xtickangle(45); grid on;

if numel(labels)==2
    delta_PM   = diff(pm10_avg);
    delta_cost = diff(cost_total);
    cost_per_PM10 = abs(delta_cost./delta_PM);
    nexttile; bar(cost_per_PM10); title('Cost per \mu g/m^3 PM_{10} Reduced', 'Interpreter', 'latex'); ylabel('$/\xB5g/m\xB3'); xticks(1); xticklabels({'\x0394 Cost/\x0394 PM_{10}'}); grid on;
end

%% SECTION 6 - Time in AQI Bands
aqi_bins   = [0 54; 55 154; 155 254; 255 354; 355 424; 425 604];
aqi_labels = {'Good','Moderate','Unhealthy SG','Unhealthy','Very Unhealthy','Hazardous'};
computeTimeInAQI = @(series) arrayfun(@(i) sum(series>=aqi_bins(i,1)&series<=aqi_bins(i,2)),1:size(aqi_bins,1));

time_bins_off = computeTimeInAQI(results_off.total_PM10);
time_bins_on  = computeTimeInAQI(results_on.total_PM10);

time_min_off = time_bins_off * results_off.dt/60;
time_min_on  = time_bins_on  * results_on.dt/60;

figure('Name','Time in AQI Categories','Color','w');
bar([time_min_off; time_min_on]','grouped');
ylabel('Time (minutes)');
title('Time Spent in Indoor AQI Bands');
legend('HEPA OFF','HEPA ON','Location','northwest');
xticks(1:length(aqi_labels)); xticklabels(aqi_labels); xtickangle(45); grid on;

%% SECTION 7 - Cumulative PM Exposure
exposure_total = [trapz(results_off.control_time, results_off.total_PM10), trapz(results_on.control_time, results_on.total_PM10)];
figure('Name','Cumulative PM_{10} Exposure','Color','w');
bar(exposure_total);
title('Cumulative PM_{10} Exposure'); ylabel('\int PM_{10} dt (\mu g \cdot s/m^3)', 'Interpreter', 'latex');
xticks(1:2); xticklabels(labels); grid on;

%% SECTION 8 - AQI Time Series Plot
figure('Name','AQI Time Series Comparison','Color','w','Position',[100 100 1200 400]);
hold on;
% Background bands
aqi_ranges = [0 54;55 154;155 254;255 354;355 424;425 604];
colors = [0.6 1 0.6;1 1 0.4;1 0.6 0.2;1 0.4 0.4;0.6 0.4 0.8;0.6 0.2 0.2];
for i=1:size(aqi_ranges,1)
    y1 = aqi_ranges(i,1);
    y2 = aqi_ranges(i,2);
    fill([-1, max(results_on.control_time)/3600, max(results_on.control_time)/3600, -1], [y1 y1 y2 y2], colors(i,:), 'EdgeColor','none','FaceAlpha',0.25);
end
plot(results_off.control_time/3600, results_off.total_PM10,'r--','LineWidth',1.5);
plot(results_on.control_time/3600,  results_on.total_PM10,'b-' ,'LineWidth',1.5);
xlabel('Time (hours)'); ylabel('Indoor PM_{10} (\mu g/m^3)', 'Interpreter', 'latex');
title('Indoor AQI Bands & PM_{10} Levels');
legend('HEPA OFF','HEPA ON','Location','northwest');
grid on;
for i=1:length(aqi_labels)
    ymid = mean(aqi_ranges(i,:));
    text(0.5, ymid, aqi_labels{i}, 'FontWeight','bold','BackgroundColor','w','Margin',2);
end

fprintf('Script complete.\n');
end
