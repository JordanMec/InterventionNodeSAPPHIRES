function deposition_rate = calculateDepositionRate(particleSize)
% =========================================================================
% calculateDepositionRate.m - Calculate Particle Deposition Rate
% =========================================================================
% Description:
%   This function calculates the natural deposition rate for particles
%   based on their size. The deposition rate represents how quickly
%   particles settle out of the air onto surfaces through gravitational
%   settling, diffusion, and other mechanisms.
%
% Inputs:
%   particleSize - Particle diameter (μm)
%
% Outputs:
%   deposition_rate - Particle deposition rate (1/s)
%
% Related files:
%   - updateIndoorPM.m: Could use this for more detailed modeling
%   - calculatePenetrationFactor.m: Similarly size-dependent calculation
%
% Notes:
%   - Deposition rate varies with particle size in a U-shaped curve:
%     * Very small particles (<0.1 μm): High deposition from diffusion
%     * Medium particles (0.1-1 μm): Lowest deposition
%     * Large particles (>1 μm): High deposition from settling
%   - Rates are expressed in 1/s (fraction deposited per second)
%   - Based on experimental studies of indoor particle behavior
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Calculate deposition rate based on particle size
if particleSize < 0.1
    % Ultrafine particles - high deposition from diffusion
    % Linear increase as size decreases
    deposition_rate = 0.15 + 0.3 * (0.1 - particleSize) / 0.1;
elseif particleSize < 1
    % Fine particles - minimum deposition rate
    % Linear decrease from 0.1 to 1 μm
    deposition_rate = 0.15 - 0.1 * (particleSize - 0.1) / 0.9;
else
    % Coarse particles - high deposition from gravitational settling
    % Increases with size
    deposition_rate = 0.05 + 0.55 * min(1, (particleSize - 1) / 9);
end

% Convert from per hour to per second
deposition_rate = deposition_rate / 3600;

% Ensure deposition rate is within reasonable bounds
deposition_rate = max(1e-6, min(0.01, deposition_rate));
end