% function god_mode_fixed()
% =====================================================================
%  Digital Twin HVAC Simulation - Enhanced Version
%  This script simulates a year-long HVAC system with PID control,
%  filter dynamics, and indoor air quality tracking.
% =====================================================================
%   last edit monday may 12th 2025 
% =====================================================================
%% MAIN SCRIPT - EXECUTE SIMULATION AND ANALYSIS
% =====================================================================

% Clear workspace and command window for a clean start
clear; clc;

% Set script mode flag to avoid nested execution
script_mode = true;
fprintf('[MAIN] Starting Digital Twin simulation in script mode...\n');

% Enable pause between visualizations for better user experience
pauseBetweenPlots = true;

try
    %% — PART 1: Create default parameters
    fprintf('[MAIN] Initializing parameters...\n');
    guiParams = initGuiParams();
    pidParams = initPidParams();
    darcyParams = initDarcyParams();
    economicParams = initEconomicParams();
    houseParams = initHouseParams();
    particleParams = initParticleParams();
    fprintf('[MAIN] All parameters initialized\n');

    %% — PART 2: Load environment data
    try
        fprintf('[MAIN] Loading environment data...\n');
        dataPath = pwd;
        envFile = fullfile(dataPath, 'ProcessedEnvData', 'alignedEnvData.mat');
        
        if exist(envFile, 'file')
            fprintf('[MAIN] Loading from file: %s\n', envFile);
            S = load(envFile);
            if isfield(S, 'env')
                env = S.env;
                fprintf('[MAIN] Data loaded successfully: %d hours\n', height(env));
            elseif isfield(S, 'OUT')
                % Load from the OUT format (from the comparison script)
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
                
                fprintf('[MAIN] Constructed env data from OUT variable: %d hours\n', height(env));
            else
                error('File does not contain env or OUT variable');
            end
        else
            fprintf('[MAIN] Environment data file not found. Creating synthetic data.\n');
            env = createSyntheticEnvData();
        end
    catch ME
        fprintf('[MAIN] Error loading environment data: %s\n', ME.message);
        fprintf('[MAIN] Creating synthetic data instead.\n');
        env = createSyntheticEnvData();
    end

    %% — PART 3: Set up GUI or use defaults
    try
        useGUI = false;  % Set to true to enable GUI, false to use defaults
        
        if useGUI
            fprintf('[MAIN] Launching parameter GUI...\n');
            guiParams = launchGUI(guiParams);
            fprintf('[MAIN] GUI parameters collected\n');
        else
            fprintf('[MAIN] Using default parameters (GUI disabled)\n');
        end
    catch ME
        fprintf('[MAIN] Error with GUI: %s\n', ME.message);
        fprintf('[MAIN] Continuing with default parameters\n');
    end

    %% — PART 4: Setup time grid and arrays
    try
        fprintf('[MAIN] Setting up time grid and arrays...\n');
        [timeParams, simArrays] = setupTimeGrid(env, particleParams);
        fprintf('[MAIN] Time grid setup complete\n');
    catch ME
        fprintf('[MAIN] Error setting up time grid: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
        rethrow(ME);
    end

    %% — PART 5: Run the baseline simulation
    try
        fprintf('[MAIN] Starting baseline simulation...\n');
        [simArrays, simState] = runSimulation(env, guiParams, darcyParams, economicParams, ...
                                            houseParams, particleParams, timeParams, simArrays);
        fprintf('[MAIN] Baseline simulation completed\n');
    catch ME
        fprintf('[MAIN] Error during simulation: %s\n', ME.message);
        fprintf('[MAIN] Line: %d\n', ME.stack(1).line);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
        rethrow(ME);
    end

    %% — PART 6: Post-process results
    try
        fprintf('[MAIN] Post-processing results...\n');
        [results, stats] = postProcessResults(simArrays, simState, guiParams, darcyParams);
        fprintf('[MAIN] Post-processing complete\n');
    catch ME
        fprintf('[MAIN] Error during post-processing: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
        rethrow(ME);
    end

    %% — PART 7: Visualize baseline results
    try
        fprintf('[MAIN] Visualizing baseline results...\n');
        visualizeResults(results, timeParams.num_hours, particleParams);
        fprintf('[MAIN] Baseline visualization complete\n');
        
        if pauseBetweenPlots
            input('[MAIN] Press Enter to continue to HEPA comparison...');
        end
    catch ME
        fprintf('[MAIN] Error during visualization: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
    end

    %% — PART 8: Run HEPA comparison
    try
        % Ask the user if they want to run the comparison
        runCompare = true;  % Set to false to skip comparison
        
        if runCompare
            fprintf('\n[MAIN] Running HEPA filter comparison...\n');
            
            % Create scenario parameters
            scenarioParams = struct();
            
            % Scenario 1: Standard filter (baseline)
            scenarioParams.scenario1 = struct();
            scenarioParams.scenario1.name = 'Standard_Filter';
            scenarioParams.scenario1.hepaEnabled = false;
            scenarioParams.scenario1.targetPressure = guiParams.targetPressure;
            
            % Scenario 2: HEPA filter
            scenarioParams.scenario2 = struct();
            scenarioParams.scenario2.name = 'HEPA_Filter';
            scenarioParams.scenario2.hepaEnabled = true;
            scenarioParams.scenario2.targetPressure = guiParams.targetPressure;
            
            % Option to save comparison results
            scenarioParams.saveResults = true;
            
            % Run the comparison
            runScenarioComparison(scenarioParams);
            fprintf('[MAIN] HEPA comparison completed\n');
            
            if pauseBetweenPlots
                input('[MAIN] Press Enter to continue to export baseline results...');
            end
        end
    catch ME
        fprintf('[MAIN] Error during HEPA comparison: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
    end

    %% — PART 9: Export baseline results
    try
        fprintf('[MAIN] Handling results export...\n');
        autoSave = false;  % Set to true for automatic saving without prompts
        exportResults(results, autoSave);
        fprintf('[MAIN] Export process complete\n');
    catch ME
        fprintf('[MAIN] Error during export: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
    end

    %% — PART 10: Run original manual comparison (optional)
    try
        runManualMode = false;  % Set to true to also run the original comparison
        
        if runManualMode
            fprintf('\n[MAIN] Running original manual comparison...\n');
            runManualComparison();
            fprintf('[MAIN] Original manual comparison completed\n');
        end
    catch ME
        fprintf('[MAIN] Error in manual comparison: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
    end

    fprintf('[MAIN] Simulation workflow completed successfully!\n');
catch ME
    % Display detailed error information for the main try block
    fprintf('\n\n[ERROR] Simulation failed with error:\n');
    fprintf('  Error in function: %s\n', ME.stack(1).name);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('  Message: %s\n', ME.message);
    fprintf('  Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end
