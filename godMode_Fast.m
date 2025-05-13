% =========================================================================
% godMode_Fast.m - Digital Twin HVAC Simulation Main Entry Point (Fast)
% =========================================================================
% Description:
%   This is the main script that orchestrates the entire HVAC Digital Twin
%   simulation, using optimized functions for faster performance. It uses
%   the same workflow as godMode.m but with performance optimizations for
%   handling long simulations with hourly data.
%
% Usage:
%   Simply run this script to execute the entire simulation workflow.
%   Modify the configuration parameters at the top to adjust behavior.
%
% Performance Improvements:
%   - Uses multi-rate simulation techniques
%   - Optimizes computational bottlenecks
%   - Reduces logging frequency and progress updates
%   - Maintains accuracy for critical fast dynamics
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

clear; clc;
fprintf('\n==================================================================\n');
fprintf('     HVAC DIGITAL TWIN SIMULATION - FAST MODE\n');
fprintf('==================================================================\n\n');

% -------------------------------------------------------------------------
% Configuration Parameters - Adjust these to change simulation behavior
% -------------------------------------------------------------------------
useGUI = false;            % Set to true to use GUI for parameter adjustment
runCompare = true;         % Set to true to run HEPA filter comparison
autoSaveResults = false;   % Set to true to auto-save results without prompting
pauseBetweenPlots = true;  % Set to true to pause between plot sets
scriptMode = true;         % Always set to true for full script execution

try
    % -------------------------------------------------------------------------
    % Step 1: Initialize simulation parameters
    % -------------------------------------------------------------------------
    fprintf('[MAIN] Initializing parameters...\n');
    guiParams = initGuiParams();
    pidParams = initPidParams();
    darcyParams = initDarcyParams();
    economicParams = initEconomicParams();
    houseParams = initHouseParams();
    particleParams = initParticleParams();
    fprintf('[MAIN] All parameters initialized\n');
    
    % -------------------------------------------------------------------------
    % Step 2: Load environment data (or create synthetic data)
    % -------------------------------------------------------------------------
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
    
    % -------------------------------------------------------------------------
    % Step 3: Launch GUI if enabled
    % -------------------------------------------------------------------------
    try
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
    
    % -------------------------------------------------------------------------
    % Step 4: Set up time grid and arrays
    % -------------------------------------------------------------------------
    try
        fprintf('[MAIN] Setting up time grid and arrays...\n');
        [timeParams, simArrays] = setupTimeGrid(env, particleParams);
        fprintf('[MAIN] Time grid setup complete\n');
    catch ME
        fprintf('[MAIN] Error setting up time grid: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
        rethrow(ME);
    end
    
    % -------------------------------------------------------------------------
    % Step 5: Run baseline simulation with fast algorithm
    % -------------------------------------------------------------------------
    try
        fprintf('[MAIN] Starting baseline simulation (FAST MODE)...\n');
        startTime = tic;
        [simArrays, simState] = runSimulation_Fast(env, guiParams, darcyParams, economicParams, houseParams, particleParams, timeParams, simArrays);
        elapsedTime = toc(startTime);
        fprintf('[MAIN] Baseline simulation completed in %.1f seconds (%.2f ms per simulated hour)\n', ...
                elapsedTime, 1000*elapsedTime/timeParams.num_hours);
    catch ME
        fprintf('[MAIN] Error during simulation: %s\n', ME.message);
        fprintf('[MAIN] Line: %d\n', ME.stack(1).line);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
        rethrow(ME);
    end
    
    % -------------------------------------------------------------------------
    % Step 6: Post-process results
    % -------------------------------------------------------------------------
    try
        fprintf('[MAIN] Post-processing results...\n');
        [results, stats] = postProcessResults(simArrays, simState, guiParams, darcyParams);
        fprintf('[MAIN] Post-processing complete\n');
    catch ME
        fprintf('[MAIN] Error during post-processing: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
        rethrow(ME);
    end
    
    % -------------------------------------------------------------------------
    % Step 7: Visualize baseline results
    % -------------------------------------------------------------------------
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
    
    % -------------------------------------------------------------------------
    % Step 8: Run HEPA filter comparison (if enabled) - also using fast mode
    % -------------------------------------------------------------------------
    try
        if runCompare
            fprintf('\n[MAIN] Running HEPA filter comparison (FAST MODE)...\n');
            
            % Configure scenarios to compare
            scenarioParams = struct();
            
            % Standard filter scenario
            scenarioParams.scenario1 = struct();
            scenarioParams.scenario1.name = 'Standard_Filter';
            scenarioParams.scenario1.hepaEnabled = false;
            scenarioParams.scenario1.targetPressure = guiParams.targetPressure;
            
            % HEPA filter scenario
            scenarioParams.scenario2 = struct();
            scenarioParams.scenario2.name = 'HEPA_Filter';
            scenarioParams.scenario2.hepaEnabled = true;
            scenarioParams.scenario2.targetPressure = guiParams.targetPressure;
            
            % Set auto-save option and fast mode flag
            scenarioParams.saveResults = autoSaveResults;
            scenarioParams.useFastMode = true;  % Enable fast simulation mode
            
            % Run comparison with fast mode
            runScenarioComparison_Fast(scenarioParams);
            fprintf('[MAIN] HEPA comparison completed\n');
            
            if pauseBetweenPlots
                input('[MAIN] Press Enter to continue to export baseline results...');
            end
        end
    catch ME
        fprintf('[MAIN] Error during HEPA comparison: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
    end
    
    % -------------------------------------------------------------------------
    % Step 9: Export baseline results
    % -------------------------------------------------------------------------
    try
        fprintf('[MAIN] Handling results export...\n');
        exportResults(results, autoSaveResults);
        fprintf('[MAIN] Export process complete\n');
    catch ME
        fprintf('[MAIN] Error during export: %s\n', ME.message);
        fprintf('[MAIN] Details: %s\n', getReport(ME));
    end
    
    % -------------------------------------------------------------------------
    % Simulation completed successfully
    % -------------------------------------------------------------------------
    fprintf('\n==================================================================\n');
    fprintf('     HVAC DIGITAL TWIN SIMULATION - COMPLETED SUCCESSFULLY\n');
    fprintf('==================================================================\n\n');
    
catch ME
    % -------------------------------------------------------------------------
    % Handle critical errors
    % -------------------------------------------------------------------------
    fprintf('\n\n');
    fprintf('==================================================================\n');
    fprintf('     ERROR: SIMULATION FAILED\n');
    fprintf('==================================================================\n');
    fprintf('  Error in function: %s\n', ME.stack(1).name);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('  Message: %s\n', ME.message);
    fprintf('  Stack trace:\n');
    
    for i = 1:length(ME.stack)
        fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    
    fprintf('==================================================================\n');
end