function penetration_factor = calculatePenetrationFactor(particleSize)
% =========================================================================
% calculatePenetrationFactor.m - Calculate Particle Penetration Factor
% =========================================================================
% Description:
%   This function calculates the penetration factor for particles entering
%   through the building envelope based on particle size. The penetration
%   factor represents the fraction of outdoor particles that successfully
%   pass through the building envelope (cracks, leaks, etc.).
%
% Inputs:
%   particleSize - Particle diameter (μm)
%
% Outputs:
%   penetration_factor - Fraction of particles that penetrate (0-1)
%
% Related files:
%   - updateIndoorPM.m: Could use this for more detailed modeling
%   - calculateDepositionRate.m: Similarly size-dependent calculation
%
% Notes:
%   - Penetration factor typically decreases with particle size
%   - Very small particles (< 0.1 μm) have high penetration (0.95)
%   - Medium particles (0.1-2.5 μm) have moderate penetration
%   - Large particles (> 2.5 μm) have low penetration
%   - Based on empirical studies of particle infiltration
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

% Calculate penetration factor based on particle size
if particleSize < 0.1
    % Ultrafine particles have high penetration
    penetration_factor = 0.95;
elseif particleSize <= 2.5
    % PM2.5 range - linear decrease in penetration with size
    penetration_factor = 0.9 - 0.15 * (particleSize - 0.1) / 2.4;
else
    % Coarse particles - further decrease in penetration
    penetration_factor = 0.75 - 0.35 * min(1, (particleSize - 2.5) / 7.5);
end

% Ensure penetration factor is within physical bounds
penetration_factor = max(0.1, min(0.95, penetration_factor));
end