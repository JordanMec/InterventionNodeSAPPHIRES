function dP = ductLoss(Q, L_ft)
% =========================================================================
% ductLoss.m - Calculate Duct Pressure Loss
% =========================================================================
% Description:
%   This function calculates the pressure loss in ducts based on flow rate
%   and duct length. It uses a simplified form of the Darcy-Weisbach
%   equation, assuming standard duct dimensions and roughness.
%
% Inputs:
%   Q       - Flow rate (CFM)
%   L_ft    - Duct length (ft)
%
% Outputs:
%   dP      - Pressure loss in duct (Pa)
%
% Related files:
%   - totalLoss.m: Includes duct loss in total system losses
%   - solveFlowBalance.m: Uses system losses to determine operating point
%   - initGuiParams.m: Defines duct length parameter
%
% Notes:
%   - Pressure loss increases approximately with the square of flow rate
%   - Longer ducts with many bends and turns have higher pressure losses
%   - The equation uses a coefficient derived from standard duct sizing
%   - Assumes 8" round ducts with typical roughness
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

try
    % Input type validation
    if ~isnumeric(Q) || ~isnumeric(L_ft)
        error('Invalid input types: Q and L_ft must be numeric');
    end
    
    % Flow rate validation
    Q = max(0, Q);
    if isnan(Q)
        warning('NaN detected in duct_loss Q input, using 0');
        Q = 0;
    end
    
    % Duct length validation
    L_ft = max(0, L_ft);
    if isnan(L_ft)
        warning('NaN detected in duct_loss L_ft input, using 0');
        L_ft = 0;
    end
    
    % Calculate pressure loss using simplified Darcy-Weisbach with fitted coefficient
    % The coefficient 0.2717287 accounts for friction factor, density, diameter, etc.
    % The exponent 1.9 is close to 2.0 but adjusted for typical residential systems
    dP = 0.2717287 .* (Q.^1.9) ./ (10^5.02) .* L_ft;
    
    % Final validation
    if isnan(dP)
        warning('NaN detected in duct_loss output, using 0');
        dP = 0;
    end
    
catch ME
    % Handle all errors
    fprintf('[ERROR] in duct_loss: %s\n', ME.message);
    dP = 0;
end
end