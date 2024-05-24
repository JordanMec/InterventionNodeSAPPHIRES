% Define the time and degree of openness data
time = [10, 20, 30, 40, 54]; % time in seconds
degree_of_openness = [15, 35, 49, 69, 90]; % degree of openness in degrees

% Create the plot
figure;
plot(time, degree_of_openness, 'o', 'MarkerFaceColor', 'b'); % plot the data points
hold on;

% Fit a linear model to the data
coefficients = polyfit(time, degree_of_openness, 1);
fitted_y = polyval(coefficients, time);

% Plot the line of best fit
plot(time, fitted_y, '-r');

% Calculate the R-squared value
y_mean = mean(degree_of_openness);
SS_tot = sum((degree_of_openness - y_mean).^2);
SS_res = sum((degree_of_openness - fitted_y).^2);
R_squared = 1 - (SS_res / SS_tot);

% Add labels and title
ylabel('Degree of Openness (degrees)');
xlabel('Time (seconds)');
title('Degree of Openness Based on Run Time');

% Add the R-squared value as text on the plot
text(10, 60, ['R^2 = ' num2str(R_squared, 2)], 'FontSize', 12, 'Color', 'r');

% Set y-axis limits and increments
yticks(0:10:90);

% Set x-axis limits and increments
xticks(0:10:60);

% Display the grid
grid on;

% Hold off to stop adding to the current plot
hold off;
