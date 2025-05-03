function runScenarioComparison(scenarioParams)
% RUNSCENARIOCOMPARISON Runs multiple HVAC simulation scenarios and compares them
%
% Example usage:
%   scenarioParams = struct();
%   scenarioParams.scenario1.name = 'Baseline';
%   scenarioParams.scenario1.hepaEnabled = false;
%   scenarioParams.scenario1.targetPressure = 1;
%   
%   scenarioParams.scenario2.name = 'HEPA_ON';
%   scenarioParams.scenario2.hepaEnabled = true;
%   scenarioParams.scenario2.targetPressure = 1;
%   
%   runScenarioComparison(scenarioParams);

fprintf('Starting HVAC Digital Twin scenario comparison...\n');

% Check if we have at least two scenarios
if ~isstruct(scenarioParams) || ~isfield(scenarioParams, 'scenario1') || ~isfield(scenarioParams, 'scenario2')
    error('At least two scenarios must be provided in the scenarioParams struct');
end

% Load environment data or create synthetic data
try
    fprintf('Loading environment data...\n');
    
    % First, try to load from MAT file
    matFile = fullfile(pwd, 'ProcessedEnvData', 'alignedEnvData.mat');
    if exist(matFile, 'file')
        fprintf('Loading from MAT file: %s\n', matFile);
        S = load(matFile);
        
        % Check for 'env' variable first
        if isfield(S, 'env')
            env = S.env;
            fprintf('Loaded env data: %d hours\n', height(env));
        % Check for 'OUT' variable (from the comparison script)
        elseif isfield(S, 'OUT')
            T = S.OUT;
            % Construct datetime
            dt = datetime(T.Date + " " + T.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
            env = table(dt, T.TempC*9/5+32, T.PM10, 'VariableNames', {'DateTime', 'TempF', 'PM10'});
            
            % Add additional PM columns by scaling PM10
            env.PM0_3 = T.PM10 * 10;  % Smaller particles usually higher concentration
            env.PM0_5 = T.PM10 * 8;
            env.PM1   = T.PM10 * 5;
            env.PM2_5 = T.PM10 * 3;
            env.PM5   = T.PM10 * 1.5;
            
            % Add RH column if missing (default 50%)
            if ~isfield(T, 'RH')
                env.RH = ones(height(env), 1) * 0.5;
            else
                env.RH = T.RH;
            end
            
            fprintf('Constructed env data from OUT variable: %d hours\n', height(env));
        else
            error('MAT file does not contain env or OUT variable');
        end
    else
        % If file doesn't exist, create synthetic data
        fprintf('Environment data file not found. Creating synthetic data.\n');
        env = createSyntheticEnvData();
    end
catch ME
    fprintf('Error loading environment data: %s\n', ME.message);
    fprintf('Creating synthetic data instead.\n');
    env = createSyntheticEnvData();
end

% Initialize default parameters for each scenario
baseGuiParams = initGuiParams();
basePidParams = initPidParams();
baseDarcyParams = initDarcyParams();
baseEconomicParams = initEconomicParams();
baseHouseParams = initHouseParams();
baseParticleParams = initParticleParams();

% Run first scenario
fprintf('\n=====================================================================\n');
fprintf('Running scenario 1: %s\n', scenarioParams.scenario1.name);
fprintf('=====================================================================\n');

% Create a copy of base parameters
guiParams1 = baseGuiParams;
pidParams1 = basePidParams;
darcyParams1 = baseDarcyParams;
economicParams1 = baseEconomicParams;
houseParams1 = baseHouseParams;
particleParams1 = baseParticleParams;

% Apply scenario-specific overrides
if isfield(scenarioParams.scenario1, 'targetPressure')
    guiParams1.targetPressure = scenarioParams.scenario1.targetPressure;
    fprintf('Set target pressure to: %.2f Pa\n', guiParams1.targetPressure);
end

if isfield(scenarioParams.scenario1, 'hepaEnabled')
    if scenarioParams.scenario1.hepaEnabled
        % Enhanced filter parameters for HEPA
        darcyParams1.k_media_clean = 1e-11;  % Tighter media (less permeable)
        darcyParams1.k_cake = 5e-13;        % Better dust cake capture
        fprintf('HEPA filter enabled\n');
    else
        fprintf('Standard filter parameters\n');
    end
end

% Setup time grid and arrays
[timeParams1, simArrays1] = setupTimeGrid(env, particleParams1);

% Run the simulation
[simArrays1, simState1] = runSimulation(env, guiParams1, darcyParams1, economicParams1, ...
                                     houseParams1, particleParams1, timeParams1, simArrays1);

% Post-process results
[results1, stats1] = postProcessResults(simArrays1, simState1, guiParams1, darcyParams1);

% Add scenario name to results
results1.scenarioName = scenarioParams.scenario1.name;

% Run second scenario
fprintf('\n=====================================================================\n');
fprintf('Running scenario 2: %s\n', scenarioParams.scenario2.name);
fprintf('=====================================================================\n');

% Create a copy of base parameters
guiParams2 = baseGuiParams;
pidParams2 = basePidParams;
darcyParams2 = baseDarcyParams;
economicParams2 = baseEconomicParams;
houseParams2 = baseHouseParams;
particleParams2 = baseParticleParams;

% Apply scenario-specific overrides
if isfield(scenarioParams.scenario2, 'targetPressure')
    guiParams2.targetPressure = scenarioParams.scenario2.targetPressure;
    fprintf('Set target pressure to: %.2f Pa\n', guiParams2.targetPressure);
end

if isfield(scenarioParams.scenario2, 'hepaEnabled')
    if scenarioParams.scenario2.hepaEnabled
        % Enhanced filter parameters for HEPA
        darcyParams2.k_media_clean = 1e-11;  % Tighter media (less permeable)
        darcyParams2.k_cake = 5e-13;        % Better dust cake capture
        fprintf('HEPA filter enabled\n');
    else
        fprintf('Standard filter parameters\n');
    end
end

% Setup time grid and arrays
[timeParams2, simArrays2] = setupTimeGrid(env, particleParams2);

% Run the simulation
[simArrays2, simState2] = runSimulation(env, guiParams2, darcyParams2, economicParams2, ...
                                     houseParams2, particleParams2, timeParams2, simArrays2);

% Post-process results
[results2, stats2] = postProcessResults(simArrays2, simState2, guiParams2, darcyParams2);

% Add scenario name to results
results2.scenarioName = scenarioParams.scenario2.name;

% Compare the scenarios
fprintf('\n=====================================================================\n');
fprintf('Comparing scenarios: %s vs %s\n', scenarioParams.scenario1.name, scenarioParams.scenario2.name);
fprintf('=====================================================================\n');

compareScenarios(results1, results2, scenarioParams.scenario1.name, scenarioParams.scenario2.name);

% Save results if requested
if isfield(scenarioParams, 'saveResults') && scenarioParams.saveResults
    saveFile = fullfile(pwd, sprintf('ScenarioComparison_%s_vs_%s_%s.mat', ...
                       scenarioParams.scenario1.name, ...
                       scenarioParams.scenario2.name, ...
                       datestr(now, 'yyyy-mm-dd_HHMM')));
    
    comparison = struct();
    comparison.scenario1 = scenarioParams.scenario1;
    comparison.scenario2 = scenarioParams.scenario2;
    comparison.results1 = results1;
    comparison.results2 = results2;
    comparison.stats1 = stats1;
    comparison.stats2 = stats2;
    
    save(saveFile, 'comparison', '-v7.3');
    fprintf('Results saved to %s\n', saveFile);
end

fprintf('Scenario comparison completed.\n');
end