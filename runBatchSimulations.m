function runBatchSimulations()
% =========================================================================
% runBatchSimulations.m
%
% Runs multiple digital twin simulations with varying parameters and
% appends metadata from each run into a shared CSV summary table.
%
% Requires: runInterventionSim.m, appendMetadataToTable.m
% =========================================================================

% Define output CSV file
csvFile = 'run_summary.csv';

% Optional: clear old CSV if starting fresh
if isfile(csvFile)
    delete(csvFile);
    fprintf('Old summary file deleted: %s\n', csvFile);
end

% -------------------------------------------------------------------------
% Run 1: Baseline with HEPA OFF
fprintf('\nRunning baseline (HEPA OFF)...\n');
r1 = runInterventionSim(false);
r1.metadata.runLabel = 'Baseline_HEPA_OFF';
appendMetadataToTable(r1, csvFile);

% -------------------------------------------------------------------------
% Run 2: Intervention with HEPA ON
fprintf('\nRunning intervention (HEPA ON)...\n');
r2 = runInterventionSim(true);
r2.metadata.runLabel = 'Intervention_HEPA_ON';
appendMetadataToTable(r2, csvFile);

% -------------------------------------------------------------------------
% [Optional Future Run: Modify parameters]
% To add more runs, duplicate and edit blocks above. For example:
% guiParams.blowerDoor = 800; or guiParams.enableStackEffect = false
% Store each with a unique runLabel before saving.

% Final message
fprintf('\nAll simulations complete.\nSummary CSV: %s\n', csvFile);
end
