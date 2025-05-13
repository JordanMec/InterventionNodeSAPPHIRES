function Q_cmd = solveFlowBalance(simState, effectiveC, guiParams, darcyParams)
% =========================================================================
% solveFlowBalance.m - Solve for Flow Balance in HVAC System
% =========================================================================
% Description:
%   This function solves for the flow rate that balances the fan pressure
%   and system losses. It finds the operating point where the fan curve
%   and the system resistance curve intersect.
%
% Inputs:
%   simState      - Current simulation state with wiper position and dust loading
%   effectiveC    - Effective leakage coefficient
%   guiParams     - GUI/user parameters
%   darcyParams   - Filter parameters
%
% Outputs:
%   Q_cmd         - Calculated balanced flow rate (CFM)
%
% Related files:
%   - innerLoop.m: Calls this function to determine flow rate
%   - fanPressure.m: Provides fan curve data
%   - totalLoss.m: Calculates system pressure losses
%   - safeBalanceFunction.m: Used as the objective function for solving
%
% Notes:
%   - Uses fzero to find where (fan pressure - system loss) = 0
%   - Includes fallback methods if fzero fails to converge
%   - The wiper position (0-128) controls fan speed/pressure
%   - Filter dust loading affects system resistance
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Constants
n_leak = 0.65;  % Leakage exponent

% Check for wiper value
if isnan(simState.wiper) || simState.wiper < 0
    warning('Invalid wiper value detected: %.2f, resetting to 0', simState.wiper);
    simState.wiper = 0;
elseif simState.wiper > 128
    warning('Wiper value exceeds max: %.2f, limiting to 128', simState.wiper);
    simState.wiper = 128;
end

% Better initial guess for flow based on wiper setting
Q_guess = 5 * simState.wiper;  % Scale initial guess with wiper setting
if Q_guess < 10
    Q_guess = 10;  % Minimum initial guess to avoid near-zero values
end

% First directly check if wiper is zero - if so, flow is zero
if simState.wiper <= 0.001
    Q_cmd = 0;
    return;
end

% Define a more robust function for fzero
% Using a wrapper that ensures inputs are in valid ranges
fanEq = @(Q) safeBalanceFunction(Q, simState.wiper, simState.dust_total, ...
                               effectiveC, n_leak, guiParams, darcyParams);

% Let's test our function at a few points to make sure it behaves well
try
    low_flow = fanEq(1);    % Test at low flow
    mid_flow = fanEq(500);  % Test at medium flow
    high_flow = fanEq(1500); % Test at high flow
    
    % If all test values have the same sign, or any are NaN, use fallback immediately
    if (sign(low_flow) == sign(high_flow) && ~isnan(low_flow) && ~isnan(high_flow)) || ...
       isnan(low_flow) || isnan(mid_flow) || isnan(high_flow)
        % Skip fzero and use direct fallback
        Q_max = 1200;  % Maximum flow rate (CFM)
        wiper_fraction = simState.wiper / 128;
        Q_cmd = Q_max * wiper_fraction * 0.7;  % 70% of max flow at full wiper
        
        % Adjust for filter loading
        filter_factor = max(0.2, 1 - (simState.dust_total / 1000));
        Q_cmd = Q_cmd * filter_factor;
        
        fprintf('[solveFlowBalance] Function behavior unsuitable for fzero, using direct fallback: %.1f CFM\n', Q_cmd);
        return;
    end
catch testError
    % If even the test calls fail, use fallback immediately
    Q_cmd = 200 * (simState.wiper / 128);
    fprintf('[solveFlowBalance] Function testing failed: %s, using simple fallback: %.1f CFM\n', testError.message, Q_cmd);
    return;
end

% More robust fzero call with bounded interval and options
try
    % Set options for fzero to improve convergence
    options = optimset('TolX', 0.1, 'Display', 'off');
    
    % Wrap the whole fzero call in another try-catch for ultimate safety
    try
        % First, let's try to find a sign change in the function
        % Start with some test points
        test_points = [1, 50, 100, 200, 400, 600, 800, 1000, 1200, 1500, 1800];
        test_values = zeros(size(test_points));
        
        for i = 1:length(test_points)
            test_values(i) = fanEq(test_points(i));
        end
        
        % Find where the function changes sign
        sign_changes = find(diff(sign(test_values)) ~= 0);
        
        if ~isempty(sign_changes)
            % We found a sign change, use the interval around it
            left_pt = test_points(sign_changes(1));
            right_pt = test_points(sign_changes(1) + 1);
            
            % Try with this interval
            Q_cmd = fzero(fanEq, [left_pt, right_pt], options);
        else
            % No sign change found, try with simple single-point guess
            Q_cmd = fzero(fanEq, Q_guess, options);
        end
    catch fzero_err1
        fprintf('[solveFlowBalance] First fzero attempt failed: %s\n', fzero_err1.message);
        try
            % Try with simple single-point guess instead
            Q_cmd = fzero(fanEq, Q_guess, options);
        catch fzero_err2
            fprintf('[solveFlowBalance] Second fzero attempt failed: %s\n', fzero_err2.message);
            % If all fzero attempts fail, use a direct search instead
            Q_test = [10, 50, 100, 200, 400, 600, 800, 1000, 1200];
            f_vals = zeros(size(Q_test));
            
            for i = 1:length(Q_test)
                try
                    f_vals(i) = fanEq(Q_test(i));
                catch
                    f_vals(i) = NaN;
                end
            end
            
            % Find the closest to zero or use a weighted average
            valid_indices = ~isnan(f_vals);
            if any(valid_indices)
                [~, idx] = min(abs(f_vals(valid_indices)));
                valid_Q = Q_test(valid_indices);
                Q_cmd = valid_Q(idx);
                fprintf('[solveFlowBalance] Using direct search result: Q = %.1f\n', Q_cmd);
            else
                % Ultimate fallback
                Q_cmd = 200 * (simState.wiper / 128);
                fprintf('[solveFlowBalance] Using wiper-based fallback: Q = %.1f\n', Q_cmd);
            end
        end
    end
    
    % If Q_cmd is unrealistic, try again with initial guess
    if Q_cmd < 0.1 || Q_cmd > 2000 || isnan(Q_cmd)
        warning('Flow solution outside physical range (%.2f), using fallback', Q_cmd);
        Q_cmd = 200 * (simState.wiper / 128);  % Simple wiper-based fallback
    end
    
    % Final check on solution
    Q_cmd = max(0, min(2000, Q_cmd));
catch fzeroError
    fprintf('[solveFlowBalance] Warning: fzero failed: %s\n', fzeroError.message);
    
    % More intelligent fallback when fzero fails
    % Estimate flow based on wiper position using typical fan curve
    Q_max = 1200;  % Maximum flow rate (CFM)
    wiper_fraction = simState.wiper / 128;
    Q_cmd = Q_max * wiper_fraction * 0.7;  % 70% of max flow at full wiper
    
    % Adjust for filter loading
    filter_factor = max(0.2, 1 - (simState.dust_total / 1000));
    Q_cmd = Q_cmd * filter_factor;
    
    fprintf('[solveFlowBalance] Using fallback flow estimate: %.1f CFM\n', Q_cmd);
end
end