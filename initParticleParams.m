function particleParams = initParticleParams()
% =========================================================================
% initParticleParams.m - Initialize Particle Parameters
% =========================================================================
% Description:
%   This function initializes the parameters related to particulate matter
%   (PM) size distribution for the simulation. These parameters define the
%   particle size bins used for tracking indoor air quality.
%
% Inputs:
%   None
%
% Outputs:
%   particleParams - Structure containing particle parameters:
%     - particle_sizes: Array of particle diameters (μm)
%     - numSizes: Number of particle size bins
%
% Related files:
%   - updateIndoorPM.m: Uses particle size information for deposition rates
%   - accumulateDust.m: Uses size bins for tracking dust accumulation
%   - setupTimeGrid.m: Uses numSizes for array allocation
%
% Notes:
%   - Common PM size categories include:
%     * PM0.3: Particles with diameter ≤ 0.3 μm
%     * PM0.5: Particles with diameter ≤ 0.5 μm
%     * PM1: Particles with diameter ≤ 1 μm
%     * PM2.5: Particles with diameter ≤ 2.5 μm (respirable)
%     * PM5: Particles with diameter ≤ 5 μm
%     * PM10: Particles with diameter ≤ 10 μm (inhalable)
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[initParticleParams] Initializing particle parameters\n');

try
    % Create the parameters structure
    particleParams = struct();
    
    % Define particle size bins (diameters in μm)
    particleParams.particle_sizes = [0.3, 0.5, 1, 2.5, 5, 10];
    
    % Count the number of size bins
    particleParams.numSizes = numel(particleParams.particle_sizes);
    
    fprintf('[initParticleParams] Particle parameters initialized with %d size bins\n', particleParams.numSizes);
catch ME
    % Handle errors
    fprintf('[ERROR] in initParticleParams: %s\n', ME.message);
    
    % Return minimal default values to allow simulation to continue
    particleParams = struct('particle_sizes', [0.3, 0.5, 1, 2.5, 5, 10], 'numSizes', 6);
    
    fprintf('[initParticleParams] Created minimal defaults due to error\n');
end
end