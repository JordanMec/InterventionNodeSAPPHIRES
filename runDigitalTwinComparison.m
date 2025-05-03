%  function runDigitalTwinComparison()
%% =====================================================================
%%  Digital Twin HVAC Simulation - Scenario Comparison Example
%%  This script runs two different HVAC scenarios and generates comparison plots
%% =====================================================================

% Clear workspace and command window
clear; clc;

% Set script mode flag to avoid nested execution
script_mode = true;
fprintf('[MAIN] Starting Digital Twin scenario comparison...\n');

%% Define scenarios to compare
% Create scenario parameters structure
scenarioParams = struct();

% Scenario 1: Standard filtration (no HEPA)
scenarioParams.scenario1 = struct();
scenarioParams.scenario1.name = 'Standard_Filter';
scenarioParams.scenario1.hepaEnabled = false;
scenarioParams.scenario1.targetPressure = 1.0;  % Pa

% Scenario 2: HEPA filtration
scenarioParams.scenario2 = struct();
scenarioParams.scenario2.name = 'HEPA_Filter';
scenarioParams.scenario2.hepaEnabled = true;
scenarioParams.scenario2.targetPressure = 1.0;  % Pa

% Option to save results
scenarioParams.saveResults = true;

%% Run the comparison
try
    % Run both scenarios and generate comparison visualizations
    runScenarioComparison(scenarioParams);
    
    fprintf('[MAIN] Scenario comparison completed successfully!\n');
catch ME
    % Display detailed error information
    fprintf('\n\n[ERROR] Comparison failed with error:\n');
    fprintf('  Error in function: %s\n', ME.stack(1).name);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('  Message: %s\n', ME.message);
    fprintf('  Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

%% Alternative: Directly use runManualComparison function
% Uncomment the following line to use the original comparison function
% runManualComparison();

%% Note on usage:
% This script demonstrates two approaches to compare HVAC scenarios:
% 1. Using runScenarioComparison() - Integrates with the full Digital Twin
%    model and allows customization of multiple parameters
% 2. Using runManualComparison() - Uses the original simplified model focused
%    specifically on HEPA filtration impact on indoor air quality
%
% Both approaches produce similar visualizations showing the comparison
% between scenarios with/without HEPA filtration.