function runManualComparison()
% =========================================================================
% updated:  May 3rd 2025
%
% runManualComparison.m
%   Runs HEPA OFF and HEPA ON simulations using preprocessed .mat EnvData.
%   Loads aligned PM10 & Temp from MATLAB file, runs sims, and generates plots & summaries.
% =========================================================================

%% — Set LaTeX as default interpreter for all text
set(groot, ...
    'defaultTextInterpreter','latex', ...
    'defaultAxesTickLabelInterpreter','latex', ...
    'defaultLegendInterpreter','latex');

%% — SECTION 1: Load preprocessed environmental data
matFile = fullfile(pwd, 'ProcessedEnvData', 'alignedEnvData.mat');
if ~isfile(matFile)
    error('Preprocessed MAT-file not found: %s', matFile);
end
S = load(matFile,'OUT');
if ~isfield(S,'OUT')
    error('MAT-file does not contain variable OUT.');
end
T = S.OUT;
% construct datetime
dt = datetime(T.Date + " " + T.Time, 'InputFormat','yyyy-MM-dd HH:mm');
envData = table(dt, T.TempC, T.PM10, 'VariableNames',{'datetime','TempC','PM10'});

%% SECTION 1.1 – Inspect imported envData
disp(head(envData,10));
% also show the F conversion
disp(table( ...
    envData.datetime(1:10), ...
    envData.TempC(1:10), ...
    envData.TempC(1:10)*9/5+32, ...
    envData.TempC(1:10)+273.15, ...
    'VariableNames',{'DateTime','TempC','TempF','TempK'}));


%% — SECTION 2: Run simulations for HEPA OFF and ON
fprintf('Running simulation: HEPA OFF\n');
results_off = runInterventionSim(false, envData);
% Add safety check for NaN values
if any(isnan(results_off.total_PM10))
    warning('NaN values detected in HEPA OFF PM10 results. Check simulation parameters.');
    % Replace NaN with zeros for plotting
    results_off.total_PM10(isnan(results_off.total_PM10)) = 0;
end
results_off.metadata.runLabel = 'HEPA\_OFF';

fprintf('Running simulation: HEPA ON\n');
results_on = runInterventionSim(true, envData);
% Add safety check for NaN values
if any(isnan(results_on.total_PM10))
    warning('NaN values detected in HEPA ON PM10 results. Check simulation parameters.');
    % Replace NaN with zeros for plotting
    results_on.total_PM10(isnan(results_on.total_PM10)) = 0;
end
results_on.metadata.runLabel = 'HEPA\_ON';

%% — SECTION 3: PM10 Time-Series Line Plot
figure('Name','HEPA Intervention Comparison','Color','w');
plot(results_off.control_time/3600, results_off.total_PM10,'r--','LineWidth',1.5);
hold on;
plot(results_on.control_time/3600, results_on.total_PM10,'b-','LineWidth',1.5);
xlabel('Time (hours)');
ylabel('Total $PM_{10}$ ($\mu\mathrm{g}/\mathrm{m}^3$)');
title('Indoor $PM_{10}$ Concentration Comparison');
legend({'HEPA OFF','HEPA ON'},'Location','best');
grid on;

%% — SECTION 4: Text Summary of Key Metrics
fprintf('\n--- SUMMARY ---\n');
% Add safety checks for NaN values in metadata
PM10_off_final = results_off.metadata.PM10_final_ugm3;
if isnan(PM10_off_final), PM10_off_final = 0; end
PM10_on_final = results_on.metadata.PM10_final_ugm3;
if isnan(PM10_on_final), PM10_on_final = 0; end

fprintf('HEPA OFF final PM10: %.2f \xB5g/m\xB3\n', PM10_off_final);
fprintf('HEPA ON  final PM10: %.2f \xB5g/m\xB3\n', PM10_on_final);

% Avoid division by zero
if PM10_off_final > 0
    reduction_percent = 100*(PM10_off_final - PM10_on_final)/PM10_off_final;
else
    reduction_percent = 0;
end

fprintf('Reduction: %.2f \xB5g/m\xB3 (%.1f%%)\n', ...
    PM10_off_final - PM10_on_final, ...
    reduction_percent);

% Safety check for cost values
cost_off = results_off.metadata.total_cost_usd;
if isnan(cost_off) || cost_off > 1e6
    warning('Unrealistic cost value detected! Check energy calculations.');
    cost_off = 0;
end

cost_on = results_on.metadata.total_cost_usd;
if isnan(cost_on) || cost_on > 1e6
    warning('Unrealistic cost value detected! Check energy calculations.');
    cost_on = 0;
end

fprintf('HEPA OFF total cost: $%.2f\n', cost_off);
fprintf('HEPA ON  total cost: $%.2f\n', cost_on);

%% — SECTION 5: Bar Plot Comparison
labels = {'HEPA OFF','HEPA ON'};

% Get values with safety checks
PM10_off_avg = results_off.metadata.PM10_avg_ugm3;
if isnan(PM10_off_avg), PM10_off_avg = 0; end
PM10_on_avg = results_on.metadata.PM10_avg_ugm3;
if isnan(PM10_on_avg), PM10_on_avg = 0; end

PM10_off_max = results_off.metadata.PM10_max_ugm3;
if isnan(PM10_off_max), PM10_off_max = 0; end
PM10_on_max = results_on.metadata.PM10_max_ugm3;
if isnan(PM10_on_max), PM10_on_max = 0; end

pm10_avg = [PM10_off_avg, PM10_on_avg];
pm10_max = [PM10_off_max, PM10_on_max];
cost_total = [cost_off, cost_on];
time_hr = [results_off.metadata.total_time_s, results_on.metadata.total_time_s]/3600;

% Avoid division by zero
cost_per_hr = zeros(1,2);
for i = 1:2
    if time_hr(i) > 0
        cost_per_hr(i) = cost_total(i) / time_hr(i);
    end
end

runtime = [results_off.metadata.simulation_runtime_s, results_on.metadata.simulation_runtime_s];

figure('Name','Run Summary Comparison','Color','w','Position',[100 100 1400 600]);
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');

nexttile;
bar(pm10_avg);
title('Avg $PM_{10}$ ($\mu\mathrm{g}/\mathrm{m}^3$)');
ylabel('$\mu\mathrm{g}/\mathrm{m}^3$');
xticks(1:2); xticklabels(labels); xtickangle(45); grid on;

nexttile;
bar(pm10_max);
title('Max $PM_{10}$ ($\mu\mathrm{g}/\mathrm{m}^3$)');
ylabel('$\mu\mathrm{g}/\mathrm{m}^3$');
xticks(1:2); xticklabels(labels); xtickangle(45); grid on;

nexttile;
bar(cost_total);
title('Total Cost (\$)');
ylabel('USD');
xticks(1:2); xticklabels(labels); xtickangle(45); grid on;

nexttile;
bar(cost_per_hr);
title('Normalized Cost (\$/hr)');
ylabel('USD/hr');
xticks(1:2); xticklabels(labels); xtickangle(45); grid on;

if numel(labels)==2
    nexttile;
    % Avoid division by zero
    if abs(diff(pm10_avg)) > 0
        cost_per_PM10 = abs(diff(cost_total)./diff(pm10_avg));
    else
        cost_per_PM10 = 0;
    end
    
    % Safety check for unrealistic values
    if isnan(cost_per_PM10) || cost_per_PM10 > 1e6
        cost_per_PM10 = 0;
    end
    
    bar(cost_per_PM10);
    title('Cost per $\Delta PM_{10}$ Reduced');
    ylabel('$\$/\mu\mathrm{g}\,\mathrm{m}^{-3}$');
    xticks(1); xticklabels({'$\Delta$ Cost/$\Delta PM_{10}$'});
    grid on;
end

%% — SECTION 6: Time in AQI Bands
aqi_bins = [0 54; 55 154; 155 254; 255 354; 355 424; 425 604];
aqi_labels = {'Good','Moderate','Unhealthy SG','Unhealthy','Very Unhealthy','Hazardous'};

% Safety function for NaN values
safe_PM10_off = results_off.total_PM10;
safe_PM10_off(isnan(safe_PM10_off)) = 0;
safe_PM10_on = results_on.total_PM10;
safe_PM10_on(isnan(safe_PM10_on)) = 0;

computeTimeInAQI = @(series) arrayfun(@(i) sum(series>=aqi_bins(i,1)&series<=aqi_bins(i,2)),1:size(aqi_bins,1));

time_bins_off = computeTimeInAQI(safe_PM10_off);
time_bins_on = computeTimeInAQI(safe_PM10_on);

time_min_off = time_bins_off * results_off.dt/60;
time_min_on = time_bins_on * results_on.dt/60;

figure('Name','Time in AQI Categories','Color','w');
bar([time_min_off; time_min_on]','grouped');
ylabel('Time (minutes)');
title('Time Spent in Indoor AQI Bands');
legend(labels,'Location','northwest');
xticks(1:length(aqi_labels)); xticklabels(aqi_labels); xtickangle(45); grid on;

%% — SECTION 7: Cumulative PM Exposure
% Safety check for NaN values
exposure_total = [trapz(results_off.control_time,safe_PM10_off), ...
                  trapz(results_on.control_time,safe_PM10_on)];

figure('Name','Cumulative PM Exposure','Color','w');
bar(exposure_total);
title('Cumulative $PM_{10}$ Exposure');
ylabel('$\int PM_{10}\,dt\ (\mu\mathrm{g}\cdot s/m^3)$');
xticks(1:2); xticklabels(labels); grid on;

%% — SECTION 8: AQI Time Series Plot
figure('Name','AQI Time Series Comparison','Color','w','Position',[100 100 1200 400]);
hold on;

% Precompute horizontal span
xmax = max(results_on.control_time)/3600;
xcoords = [0, xmax, xmax, 0];

% Draw each AQI band as a gray patch
for k = 1:size(aqi_bins,1)
    ycoords = [ ...
        aqi_bins(k,1), ...
        aqi_bins(k,1), ...
        aqi_bins(k,2), ...
        aqi_bins(k,2)  ...
    ];
    fill(xcoords, ycoords, [0.9 0.9 0.9], ...
         'EdgeColor','none', 'FaceAlpha',0.3);
end

% Overlay the two PM10 time series
h1 = plot(results_off.control_time/3600, safe_PM10_off, 'r--','LineWidth',1.5);
h2 = plot(results_on.control_time/3600, safe_PM10_on, 'b-','LineWidth',1.5);

% Add AQI labels
for k = 1:size(aqi_bins,1)
    ymid = mean(aqi_bins(k,:));
    text(0.5, ymid, aqi_labels{k}, ...
         'FontWeight','bold');
end

% Final touches
xlabel('Time (hours)');
ylabel('Indoor $PM_{10}$ ($\mu\mathrm{g}/\mathrm{m}^3$)');
title('Indoor AQI Bands \& $PM_{10}$ Levels');
legend([h1 h2], {'HEPA OFF','HEPA ON'}, 'Location','northwest');
grid on;

fprintf('Script complete.\n');
end