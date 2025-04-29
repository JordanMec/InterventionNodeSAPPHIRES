function plotRunSummary(csvFile)
% =========================================================================
% plotRunSummary
%
% Reads a run_summary CSV file and generates bar plots to compare:
% - Avg and Max PM₁₀
% - Total cost
% - Cost per hour
% - Simulation runtime
% Also prints cost per µg/m³ PM₁₀ reduction if two runs are present.
% =========================================================================

if nargin < 1
    csvFile = 'run_summary.csv';
end

if ~isfile(csvFile)
    error('Could not find file: %s', csvFile);
end

% Load the CSV summary
T = readtable(csvFile);

% Use labels if available
if ismember('runLabel', T.Properties.VariableNames)
    labels = T.runLabel;
else
    labels = strcat("Run ", string(1:height(T)));
end

% Extract primary metrics
pm10_avg    = T.PM10_avg_ugm3;
pm10_max    = T.PM10_max_ugm3;
cost_total  = T.total_cost_usd;
runtime     = T.simulation_runtime_s;
time_hr     = T.total_time_s / 3600;

% Normalized cost per hour
cost_per_hour = cost_total ./ time_hr;

% If exactly two runs: calculate cost per µg/m³ PM10 reduction
if height(T) == 2
    delta_PM   = diff(pm10_avg);
    delta_cost = diff(cost_total);
    cost_per_PM10 = abs(delta_cost / delta_PM);
    fprintf('\nCost per µg/m³ PM₁₀ reduced: $%.4f\n', cost_per_PM10);
else
    cost_per_PM10 = NaN;
    fprintf('\nMore than two runs present — PM₁₀ reduction cost not calculated.\n');
end

% Plot
figure('Name','Run Summary Comparison','Color','w','Position',[100 100 1400 600]);
tiledlayout(2,3,"Padding","compact","TileSpacing","compact");

% Avg PM10
nexttile;
bar(pm10_avg);
title('Avg PM₁₀ (µg/m³)');
ylabel('µg/m³'); xticks(1:length(labels)); xticklabels(labels); xtickangle(45); grid on;

% Max PM10
nexttile;
bar(pm10_max);
title('Max PM₁₀ (µg/m³)');
ylabel('µg/m³'); xticks(1:length(labels)); xticklabels(labels); xtickangle(45); grid on;

% Total Cost
nexttile;
bar(cost_total);
title('Total Cost ($)');
ylabel('USD'); xticks(1:length(labels)); xticklabels(labels); xtickangle(45); grid on;

% Cost per Hour
nexttile;
bar(cost_per_hour);
title('Normalized Cost ($/hr)');
ylabel('USD/hr'); xticks(1:length(labels)); xticklabels(labels); xtickangle(45); grid on;

% Runtime
nexttile;
bar(runtime);
title('Simulation Runtime (s)');
ylabel('Seconds'); xticks(1:length(labels)); xticklabels(labels); xtickangle(45); grid on;

% Optional: Display cost/PM₁₀ reduction in plot if 2 runs
if height(T) == 2
    nexttile;
    bar(cost_per_PM10);
    title('Cost per µg/m³ PM₁₀ Reduced');
    ylabel('$/µg/m³'); xticks(1); xticklabels({'Δ Cost / Δ PM₁₀'}); grid on;
end

sgtitle('Digital Twin Intervention Comparison');

end
