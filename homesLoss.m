function dP = homesLoss(Q, C_eff, n_leak)
% =========================================================================
% homesLoss.m - Calculate House Envelope Pressure Loss
% =========================================================================
% Description:
%   This function calculates the pressure loss through the building envelope
%   based on the flow rate and building leakage characteristics. It uses
%   the power law relationship commonly used in building science.
%
% Inputs:
%   Q       - Flow rate (CFM)
%   C_eff   - Effective leakage coefficient (CFM/Pa^n)
%   n_leak  - Leakage exponent (typically 0.5-0.7)
%
% Outputs:
%   dP      - Pressure drop across building envelope (Pa)
%
% Related files:
%   - totalLoss.m: Includes envelope loss in total system losses
%   - calculateEffectiveLeakage.m: Calculates C_eff from blower door test
%   - initGuiParams.m: Contains blower door test result
%
% Notes:
%   - Based on the power law equation: Q = C × ΔP^n
%   - Tighter buildings (lower C_eff) have higher pressure losses
%   - The leakage exponent n_leak is typically around 0.65
%   - Common reference: ASHRAE Fundamentals
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

try
    % Input type validation
    if ~isnumeric(Q) || ~isnumeric(C_eff) || ~isnumeric(n_leak)
        error('Invalid input types: Q, C_eff, and n_leak must be numeric');
    end
    
    % Flow rate validation
    Q = max(0, Q);
    if isnan(Q)
        warning('NaN detected in homes_loss Q input, using 0');
        Q = 0;
    end
    
    % Leakage coefficient validation
    C_eff = max(0.1, C_eff);  % Prevent division by zero
    if isnan(C_eff)
        warning('NaN detected in homes_loss C_eff input, using 1');
        C_eff = 1;
    end
    
    % Leakage exponent validation
    n_leak = max(0.1, min(1, n_leak));  % Bound to physical range
    if isnan(n_leak)
        warning('NaN detected in homes_loss n_leak input, using 0.65');
        n_leak = 0.65;  % Standard value
    end
    
    % Calculate pressure loss
    if Q < 0.001
        dP = 0;  % Near-zero flow means near-zero pressure 
    else
        % Invert power law: ΔP = (Q/C)^(1/n)
        dP = (Q ./ C_eff).^(1./n_leak);
        
        % Validate result
        if isnan(dP) || isinf(dP) || ~isreal(dP) || dP < 0
            warning('Invalid result after homes_loss calculation, applying fallback');
            dP = Q * 0.1;  % Simple linear relationship as fallback
        end
        
        % Cap at a realistic maximum
        dP = min(1000, dP);
    end
    
catch ME
    % Handle all errors
    fprintf('[ERROR] in homes_loss: %s\n', ME.message);
    dP = 0;  % Return zero pressure loss in case of errors
end
end