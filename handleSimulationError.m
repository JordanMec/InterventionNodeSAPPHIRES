function [simArrays, simState] = handleSimulationError(ME, simArrays, simState, timeParams, progressBar)
% =========================================================================
% handleSimulationError.m - Handle Simulation Errors
% =========================================================================
% Description:
%   This function handles errors that occur during the simulation process.
%   It ensures that even in case of failure, the simulation returns valid
%   (though possibly incomplete) results and cleans up resources.
%
% Inputs:
%   ME           - MATLAB exception object from try-catch
%   simArrays    - Current simulation arrays (may be incomplete)
%   simState     - Current simulation state (may be incomplete)
%   timeParams   - Timing parameters
%   progressBar  - Handle to progress bar (if exists)
%
% Outputs:
%   simArrays    - Validated simulation arrays
%   simState     - Validated simulation state
%
% Related files:
%   - runSimulation.m: Calls this function in catch block
%   - godMode.m: Receives the handled outputs
%
% Notes:
%   - Ensures that simArrays and simState have valid minimal structure
%   - Closes progress bar if it exists
%   - Logs detailed error information to console
%   - Returns incomplete but usable results
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Close progress bar if it exists
if exist('progressBar', 'var') && ishandle(progressBar)
    close(progressBar);
end

% Log detailed error information
fprintf('[ERROR] in runSimulation: %s\n', ME.message);
fprintf('  Line: %d\n', ME.stack(1).line);
fprintf('  Stack trace:\n');
for i = 1:length(ME.stack)
    fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
end

fprintf('[runSimulation] Attempting to return minimal valid outputs\n');

try
    % Ensure simArrays has all required fields with valid dimensions
    if ~isfield(simArrays, 'pressure_series') || isempty(simArrays.pressure_series)
        simArrays.pressure_series = zeros(1, timeParams.num_hours);
    end
    
    if ~isfield(simArrays, 'Qfan_series') || isempty(simArrays.Qfan_series)
        simArrays.Qfan_series = zeros(1, timeParams.num_hours);
    end
    
    if ~isfield(simArrays, 'wiper_series') || isempty(simArrays.wiper_series)
        simArrays.wiper_series = zeros(1, timeParams.num_hours);
    end
    
    if ~isfield(simArrays, 'dust_total_series') || isempty(simArrays.dust_total_series)
        simArrays.dust_total_series = zeros(1, timeParams.num_hours);
    end
    
    if ~isfield(simArrays, 'filter_life_series') || isempty(simArrays.filter_life_series)
        simArrays.filter_life_series = zeros(1, timeParams.num_hours);
    end
    
    if ~isfield(simArrays, 'cumulative_cost_energy') || isempty(simArrays.cumulative_cost_energy)
        simArrays.cumulative_cost_energy = zeros(1, timeParams.num_hours);
    end
    
    if ~isfield(simArrays, 'C_indoor_PM') || isempty(simArrays.C_indoor_PM)
        simArrays.C_indoor_PM = zeros(timeParams.num_hours, 6);
    end
    
    % Ensure simState has minimal required fields
    if ~exist('simState', 'var') || ~isstruct(simState)
        simState = struct();
    end
    
    if ~isfield(simState, 'num_replacements')
        simState.num_replacements = 0;
    end
    
    if ~isfield(simState, 'actual_pressure')
        simState.actual_pressure = 0;
    end
    
    fprintf('[runSimulation] Created minimal valid outputs after error\n');
catch
    % Emergency fallback if the above fails
    fprintf('[runSimulation] Creating emergency fallback outputs\n');
    
    % Create minimal simArrays
    simArrays = struct('pressure_series', zeros(1, timeParams.num_hours), ...
                       'Qfan_series', zeros(1, timeParams.num_hours), ...
                       'wiper_series', zeros(1, timeParams.num_hours), ...
                       'dust_total_series', zeros(1, timeParams.num_hours), ...
                       'filter_life_series', zeros(1, timeParams.num_hours), ...
                       'cumulative_cost_energy', zeros(1, timeParams.num_hours), ...
                       'C_indoor_PM', zeros(timeParams.num_hours, 6));
    
    % Create minimal simState
    simState = struct('num_replacements', 0, ...
                      'actual_pressure', 0);
end

fprintf('[runSimulation] Returning with minimal outputs after error\n');
end