function exportResults(results, autoSave)
% Export simulation results to file(s)

fprintf('[exportResults] Handling results export\n');
try
    % ---------------------------------------------------------------------
    % 9-A.  Prompt to save results
    % ---------------------------------------------------------------------
    if nargin < 2
        autoSave = false;
    end
    
    defaultFile = fullfile(pwd, sprintf('DTwin_%s.mat', ...
                           datestr(now, 'yyyy-mm-dd_HHMM')));
    
    if autoSave
        choice = 'Yes';
    else
        choice = questdlg('Save results to .mat file?', ...
                         'Export Results', ...
                         'Yes', 'No', 'Yes');
    end
    
    if strcmp(choice, 'Yes')
        if autoSave
            saveFile = defaultFile;
            save(saveFile, 'results', '-v7.3');
            fprintf('[exportResults] Results saved to %s\n', saveFile);
        else
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
    
    % ---------------------------------------------------------------------
    % 9-B.  Optional CSV export for key hourly series
    % ---------------------------------------------------------------------
    if ~autoSave
        choice = questdlg('Also export a CSV with hourly KPIs?', ...
                         'Export CSV', ...
                         'Yes', 'No', 'No');
    else
        choice = 'No';  % Skip CSV in auto mode
    end
    
    if strcmp(choice, 'Yes')
        % Create table with key performance indicators
        num_hours = length(results.pressure_series);
        kpiTbl = table((0:num_hours-1)', results.pressure_series', results.Qfan_series', ...
               results.cumulative_cost_energy', results.filter_life_series', ...
               'VariableNames', {'Hour', 'Pressure_Pa', 'Flow_CFM', ...
                                 'CumCost', 'FilterLife_Pct'});
        
        csvFile = fullfile(pwd, sprintf('DTwin_KPI_%s.csv', ...
                          datestr(now, 'yyyy-mm-dd_HHMM')));
        writetable(kpiTbl, csvFile);
        fprintf('[exportResults] CSV exported to %s\n', csvFile);
    end
    
    fprintf('[exportResults] Export process complete\n');
catch ME
    fprintf('[ERROR] in exportResults: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('[exportResults] Export failed but continuing simulation\n');
    rethrow(ME);
end
end