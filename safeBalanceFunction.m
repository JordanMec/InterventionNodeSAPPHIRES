function result = safeBalanceFunction(Q, wiper, dust_total, effectiveC, n_leak, guiParams, darcyParams)
% =========================================================================
% safeBalanceFunction.m - Safe Wrapper for Flow Balance Calculations
% =========================================================================
% Description:
%   This function provides a safe wrapper for calculating the difference
%   between fan pressure and system losses. It's designed to handle various
%   error conditions gracefully, making it suitable for use with numerical
%   solvers like fzero.
%
% Inputs:
%   Q           - Flow rate (CFM)
%   wiper       - Wiper position (0-128)
%   dust_total  - Total accumulated dust (g)
%   effectiveC  - Effective leakage coefficient
%   n_leak      - Leakage exponent
%   guiParams   - GUI/user parameters
%   darcyParams - Filter parameters
%
% Outputs:
%   result      - Difference between fan pressure and system losses (Pa)
%
% Related files:
%   - solveFlowBalance.m: Uses this function with fzero
%   - fanPressure.m: Calculates fan pressure
%   - totalLoss.m: Calculates system losses
%
% Notes:
%   - Acts as an objective function for fzero to find the balance point
%   - Handles NaN, Inf, and other error conditions
%   - Returns fallback values when calculations fail
%   - Sign of result determines which way flow needs to adjust
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

try
    % -------------------------------------------------------------------------
    % Input validation with very strict limits
    % -------------------------------------------------------------------------
    % Bound flow to physically reasonable range - be very strict for stability
    Q = max(1.0, min(1800, Q));
    
    % Bound wiper position
    wiper = max(0, min(128, wiper));
    
    % Ensure non-negative dust
    dust_total = max(0, dust_total);
    
    % Set initial result to zero
    result = 0;
    
    % -------------------------------------------------------------------------
    % Simple fallback model if wiper is near zero
    % -------------------------------------------------------------------------
    if wiper < 0.1
        % If wiper is basically off, flow should be negative for all positive Q
        result = -Q/10;
        return;
    end
    
    % -------------------------------------------------------------------------
    % Calculate fan pressure
    % -------------------------------------------------------------------------
    try
        % Try to use the fanPressure function
        fanP = fanPressure(Q, wiper);
        
        % Validate fan pressure
        if isnan(fanP) || isinf(fanP) || fanP < 0
            % Fallback to simple linear model
            fanP = wiper * (400 - 0.3 * Q) / 128;
        end
    catch
        % Fallback if function call fails
        fanP = wiper * (400 - 0.3 * Q) / 128;
    end
    
    % -------------------------------------------------------------------------
    % Calculate system losses
    % -------------------------------------------------------------------------
    try
        % Try to use the proper totalLoss function
        sysP = totalLoss(Q, dust_total, effectiveC, n_leak, guiParams, darcyParams);
        
        % Validate system pressure
        if isnan(sysP) || isinf(sysP) || sysP < 0
            % Fallback to simple power law model
            sysP = 0.001 * Q^1.9 * (1 + dust_total/100);
        end
    catch
        % Fallback if function call fails
        sysP = 0.001 * Q^1.9 * (1 + dust_total/100);
    end
    
    % -------------------------------------------------------------------------
    % Calculate difference (objective function)
    % -------------------------------------------------------------------------
    result = fanP - sysP;
    
    % Final validation of result
    if isnan(result) || isinf(result) || ~isreal(result)
        % Return value based on flow to guide solver
        if Q < 100
            result = 1;      % For low flow, suggest increasing
        elseif Q > 1000
            result = -1;     % For high flow, suggest decreasing
        else
            result = 0;      % For mid-range flow, suggest it might be close
        end
    end
    
catch ME
    % Handle any errors
    fprintf('Error in safeBalanceFunction: %s\n', ME.message);
    
    % Return value based on flow to guide solver in case of error
    if Q < 100
        result = 1;
    elseif Q > 1000
        result = -1; 
    else
        result = 0;
    end
end
end