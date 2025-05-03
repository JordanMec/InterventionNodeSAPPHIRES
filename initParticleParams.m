function particleParams = initParticleParams()
% Initialize particle size bins for PM model

fprintf('[initParticleParams] Initializing particle parameters\n');
try
    particleParams = struct();
    particleParams.particle_sizes = [0.3 0.5 1 2.5 5 10];   % um (upper edge of each bin)
    particleParams.numSizes = numel(particleParams.particle_sizes);
    
    fprintf('[initParticleParams] Particle parameters initialized with %d size bins\n', particleParams.numSizes);
catch ME
    fprintf('[ERROR] in initParticleParams: %s\n', ME.message);
    % Create minimal default parameters
    particleParams = struct('particle_sizes', [0.3 0.5 1 2.5 5 10], 'numSizes', 6);
end
end