function exportResults(results, autoSave)
% =========================================================================
% exportResults.m - Export Simulation Results
% =========================================================================
% Description:
%   This function exports the simulation results to MAT-files and optionally
%   to CSV files. It handles user interaction for saving preferences or
%   uses automatic saving based on the autoSave parameter.
%
% Inputs:
%   results  - Structure with processed simulation results
%   autoSave - (Optional) Boolean flag for automatic saving without prompts
%
% Outputs:
%   None (creates files)
%
% Related files:
%   - godMode.m: Calls this function after visualization
%   - postProcessResults.m: Provides the results to export
%
% Notes:
%   - MAT-file contains the complete results structure
%   - CSV export is optional and contains hourly KPIs
%   - Files are named with date and time stamps
%   - With autoSave=false, prompts the user for save preferences
%   - With autoSave=true, saves automatically to default location
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[exportResults] Handling results export\n');

try
    % Set default for autoSave if not provided
    if nargin < 2
        autoSave = false;
    end
    
    % Generate default filename with timestamp
    defaultFile = fullfile(pwd, sprintf('DTwin_%s.mat', ...
                           datestr(now, 'yyyy-mm-dd_HHMM')));
    
    % Determine whether to save based on autoSave or user choice
    if autoSave
        choice = 'Yes';
    else
        choice = questdlg('Save results to .mat file?', ...
                         'Export Results', ...
                         'Yes', 'No', 'Yes');
    end
    
    % Handle MAT-file export
    if strcmp(choice, 'Yes')
        if autoSave
            % Automatic save to default location
            saveFile = defaultFile;
            save(saveFile, 'results', '-v7.3');
            fprintf('[exportResults] Results saved to %s\n', saveFile);
        else
            % Prompt user for save location
            [file, path] = uiputfile('*.mat', 'Save results as', defaultFile);
            if ischar(file)
                save(fullfile(path, file), 'results', '-v7.3');
                fprintf('[exportResults] Results saved to %s\n', fullfile(path, file));
            else
                fprintf('[exportResults] Save cancelled - results remain in workspace only\n');
            end
        end
    else
        fprintf('[exportResults] User chose not to save results\n');
    end
    
    % Handle optional CSV export for key performance indicators
    if ~autoSave
        choice = questdlg('Also export a CSV with hourly KPIs?', ...
                         'Export CSV', ...
                         'Yes', 'No', 'No');
    else
        choice = 'No';  % Default for autoSave mode
    end
    
    if strcmp(choice, 'Yes')
        % Extract number of hours
        num_hours = length(results.pressure_series);
        
        % Create table with key performance indicators
        kpiTbl = table((0:num_hours-1)', results.pressure_series', results.Qfan_series', ...
               results.cumulative_cost_energy', results.filter_life_series', ...
               'VariableNames', {'Hour', 'Pressure_Pa', 'Flow_CFM', ...
                                 'CumCost', 'FilterLife_Pct'});
        
        % Generate CSV filename with timestamp
        csvFile = fullfile(pwd, sprintf('DTwin_KPI_%s.csv', ...
                          datestr(now, 'yyyy-mm-dd_HHMM')));
        
        % Write table to CSV file
        writetable(kpiTbl, csvFile);
        fprintf('[exportResults] CSV exported to %s\n', csvFile);
    end
    
    fprintf('[exportResults] Export process complete\n');
catch ME
    % Handle errors
    fprintf('[ERROR] in exportResults: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('[exportResults] Export failed but continuing simulation\n');
    rethrow(ME);
end
end