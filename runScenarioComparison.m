function runScenarioComparison(scenarioParams)
% =========================================================================
% runScenarioComparison.m - Run and Compare Simulation Scenarios
% =========================================================================
% Description:
%   This function runs multiple simulation scenarios with different
%   parameters and compares the results. It's primarily used to compare
%   standard filters with HEPA filters, but can be used for other
%   parameter comparisons as well.
%
% Inputs:
%   scenarioParams - Structure containing scenario definitions:
%     .scenario1: Structure with parameters for first scenario
%     .scenario2: Structure with parameters for second scenario
%     .saveResults: Boolean flag for saving comparison results
%
% Outputs:
%   None (creates comparison plots and optionally saves results)
%
% Related files:
%   - godMode.m: Can call this function after baseline simulation
%   - compareScenarios.m: Called to visualize scenario comparisons
%   - runDigitalTwinComparison.m: Wrapper script that calls this function
%
% Notes:
%   - Typical usage is to compare standard vs. HEPA filters
%   - Each scenario can have different parameters (e.g., filter type, pressure)
%   - Results are visualized using compareScenarios.m
%   - Optional saving of comparison results to MAT-file
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('Starting HVAC Digital Twin scenario comparison...\n');

% Validate input parameters
if ~isstruct(scenarioParams) || ~isfield(scenarioParams, 'scenario1') || ~isfield(scenarioParams, 'scenario2')
    error('At least two scenarios must be provided in the scenarioParams struct');
end

try
    % Load environment data for simulation
    fprintf('Loading environment data...\n');
    matFile = fullfile(pwd, 'ProcessedEnvData', 'alignedEnvData.mat');
    
    if exist(matFile, 'file')
        fprintf('Loading from MAT file: %s\n', matFile);
        S = load(matFile);
        
        if isfield(S, 'env')
            env = S.env;
            fprintf('Loaded env data: %d hours\n', height(env));
        elseif isfield(S, 'OUT')
            T = S.OUT;
            dt = datetime(T.Date + " " + T.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
            env = table(dt, T.TempC*9/5+32, T.PM10, 'VariableNames', {'DateTime', 'TempF', 'PM10'});
            env.PM0_3 = T.PM10 * 10;
            env.PM0_5 = T.PM10 * 8;
            env.PM1   = T.PM10 * 5;
            env.PM2_5 = T.PM10 * 3;
            env.PM5   = T.PM10 * 1.5;
            
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
        fprintf('Environment data file not found. Creating synthetic data.\n');
        env = createSyntheticEnvData();
    end
    
    % Initialize base parameters for both scenarios
    baseGuiParams = initGuiParams();
    basePidParams = initPidParams();
    baseDarcyParams = initDarcyParams();
    baseEconomicParams = initEconomicParams();
    baseHouseParams = initHouseParams();
    baseParticleParams = initParticleParams();
    
    % -------------------------------------------------------------------------
    % Run Scenario 1
    % -------------------------------------------------------------------------
    fprintf('\n=====================================================================\n');
    fprintf('Running scenario 1: %s\n', scenarioParams.scenario1.name);
    fprintf('=====================================================================\n');
    
    % Copy base parameters for scenario 1
    guiParams1 = baseGuiParams;
    pidParams1 = basePidParams;
    darcyParams1 = baseDarcyParams;
    economicParams1 = baseEconomicParams;
    houseParams1 = baseHouseParams;
    particleParams1 = baseParticleParams;
    
    % Apply scenario-specific parameters
    if isfield(scenarioParams.scenario1, 'targetPressure')
        guiParams1.targetPressure = scenarioParams.scenario1.targetPressure;
        fprintf('Set target pressure to: %.2f Pa\n', guiParams1.targetPressure);
    end
    
    if isfield(scenarioParams.scenario1, 'hepaEnabled')
        if scenarioParams.scenario1.hepaEnabled
            darcyParams1.k_media_clean = 1e-11;  % Higher resistance for HEPA
            darcyParams1.k_cake = 5e-13;         % Higher cake resistance for HEPA
            fprintf('HEPA filter enabled\n');
        else
            fprintf('Standard filter parameters\n');
        end
    end
    
    % Run simulation for scenario 1
    [timeParams1, simArrays1] = setupTimeGrid(env, particleParams1);
    [simArrays1, simState1] = runSimulation(env, guiParams1, darcyParams1, economicParams1, ...
                                         houseParams1, particleParams1, timeParams1, simArrays1);
    [results1, stats1] = postProcessResults(simArrays1, simState1, guiParams1, darcyParams1);
    results1.scenarioName = scenarioParams.scenario1.name;
    
    % -------------------------------------------------------------------------
    % Run Scenario 2
    % -------------------------------------------------------------------------
    fprintf('\n=====================================================================\n');
    fprintf('Running scenario 2: %s\n', scenarioParams.scenario2.name);
    fprintf('=====================================================================\n');
    
    % Copy base parameters for scenario 2
    guiParams2 = baseGuiParams;
    pidParams2 = basePidParams;
    darcyParams2 = baseDarcyParams;
    economicParams2 = baseEconomicParams;
    houseParams2 = baseHouseParams;
    particleParams2 = baseParticleParams;
    
    % Apply scenario-specific parameters
    if isfield(scenarioParams.scenario2, 'targetPressure')
        guiParams2.targetPressure = scenarioParams.scenario2.targetPressure;
        fprintf('Set target pressure to: %.2f Pa\n', guiParams2.targetPressure);
    end
    
    if isfield(scenarioParams.scenario2, 'hepaEnabled')
        if scenarioParams.scenario2.hepaEnabled
            darcyParams2.k_media_clean = 1e-11;  % Higher resistance for HEPA
            darcyParams2.k_cake = 5e-13;         % Higher cake resistance for HEPA
            fprintf('HEPA filter enabled\n');
        else
            fprintf('Standard filter parameters\n');
        end
    end
    
    % Run simulation for scenario 2
    [timeParams2, simArrays2] = setupTimeGrid(env, particleParams2);
    [simArrays2, simState2] = runSimulation(env, guiParams2, darcyParams2, economicParams2, ...
                                         houseParams2, particleParams2, timeParams2, simArrays2);
    [results2, stats2] = postProcessResults(simArrays2, simState2, guiParams2, darcyParams2);
    results2.scenarioName = scenarioParams.scenario2.name;
    
    % -------------------------------------------------------------------------
    % Compare Scenarios
    % -------------------------------------------------------------------------
    fprintf('\n=====================================================================\n');
    fprintf('Comparing scenarios: %s vs %s\n', scenarioParams.scenario1.name, scenarioParams.scenario2.name);
    fprintf('=====================================================================\n');
    
    compareScenarios(results1, results2, scenarioParams.scenario1.name, scenarioParams.scenario2.name);
    
    % -------------------------------------------------------------------------
    % Save Comparison Results (if enabled)
    % -------------------------------------------------------------------------
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
catch ME
    % Handle errors
    fprintf('\n[ERROR] in runScenarioComparison: %s\n', ME.message);
    fprintf('Line: %d\n', ME.stack(1).line);
    rethrow(ME);
end
end