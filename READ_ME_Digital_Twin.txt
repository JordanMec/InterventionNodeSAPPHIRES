# Digital Twin HVAC Simulation
## Complete Script Documentation

This document provides a comprehensive catalog of all scripts that comprise the Digital Twin HVAC simulation framework. Each script's purpose, functionality, and dependencies are documented to facilitate understanding, maintenance, and potential recreation of the system.

Last updated: May 3, 2025

## 1. Core Script Files

### 1.1 Main Script

- **god_mode_fixed.m** - The master script that orchestrates the entire simulation workflow. Initializes parameters, loads data, runs simulations, creates visualizations, and coordinates all comparison operations. This is the entry point for running the Digital Twin.

### 1.2 Initialization Functions

- **initGuiParams.m** - Creates default HVAC and home parameters including blower door leakage, target pressure, duct length, and operating mode flags.
- **initPidParams.m** - Initializes PID controller parameters (Kp, Ki, Kd) for pressure control.
- **initDarcyParams.m** - Sets up filter model constants including media permeability, filter area, and cake parameters.
- **initEconomicParams.m** - Defines economic and utility rate assumptions for cost calculations.
- **initHouseParams.m** - Establishes house geometry parameters including volume, floor area, and temperature setpoints.
- **initParticleParams.m** - Defines particle size bins for the PM concentration model.

### 1.3 Data Management Functions

- **createSyntheticEnvData.m** - Generates synthetic environmental data when real measurements are unavailable, creating a full year of hourly temperature, humidity, and PM concentrations with realistic daily and seasonal patterns.
- **setupTimeGrid.m** - Configures the dual-clock simulation time grid (1s control loop, 1h environment) and pre-allocates result arrays.

## 2. Physics/Calculation Functions

- **fan_pressure.m** - Calculates blower static pressure capability based on flow rate and PWM duty cycle using an 8-point fan curve with linear interpolation.
- **duct_loss.m** - Computes pressure loss in ductwork using Darcy-Weisbach formulation with CFD-derived exponents.
- **homes_loss.m** - Determines envelope infiltration/exfiltration pressure losses as a function of flow rate.
- **darcy_filter_loss.m** - Implements a time-varying composite filter model with clean media and dust cake components.
- **totalLoss.m** - Combines all pressure losses (duct, home, filter) to calculate system total resistance.

## 3. Simulation Functions

- **runSimulation.m** - Executes the main simulation with nested hourly/second loops, implementing pressure dynamics, airflow, filter loading, and PM mass balance physics.
- **postProcessResults.m** - Calculates summary statistics, prepares visualization data, and bundles results for export.
- **visualizeResults.m** - Creates standard visualization figures showing simulation results (pressure, flow, filter life, costs).
- **exportResults.m** - Handles the saving of simulation results to MAT and/or CSV files.

## 4. GUI Functions

- **launchGUI.m** - Creates and manages the parameter configuration GUI with input validation and callbacks.

## 5. Comparison and Analysis Functions

- **compareScenarios.m** - Creates comparison visualization between two simulation scenarios including time series plots, bar charts, AQI analysis, and cost metrics.
- **runScenarioComparison.m** - High-level function to run and compare multiple HVAC scenarios with different parameters.
- **runInterventionSim.m** - Simplified simulation focused specifically on HEPA filtration impact, compatible with the original comparison framework.
- **runManualComparison.m** - The original comparison script comparing HEPA ON/OFF scenarios with comprehensive PM10 analysis.
- **runDigitalTwinComparison.m** - Example script demonstrating scenario comparison workflow.

## 6. Technical Details

### 6.1 Simulation Physics

The simulation incorporates multiple physical models:
- Fan curve and system curve intersection for flow calculation
- Darcy filter loading model with permeability evolution
- Mass-balance approach for indoor PM concentration
- Stack-effect calculations based on temperature differential
- Energy consumption model for HVAC components

### 6.2 Parameter Structures

The simulation uses several parameter structures:
- **guiParams** - User-configurable operational parameters
- **pidParams** - Control algorithm parameters
- **darcyParams** - Filter model parameters
- **economicParams** - Cost calculation parameters
- **houseParams** - Building characteristics
- **particleParams** - Particulate matter size distribution
- **timeParams** - Simulation time grid settings

### 6.3 Input Data Requirements

The simulation expects a data file with hourly outdoor conditions:
- **alignedEnvData.mat** - Contains either 'env' or 'OUT' variable with DateTime, temperature, humidity, and PM concentrations

### 6.4 Outputs

The simulation produces several types of outputs:
- Time series plots of key variables (pressure, flow, filter life)
- Cost breakdown analysis
- Indoor air quality metrics
- HEPA vs. standard filter comparisons
- AQI band distribution analysis

## 7. Recreation Instructions

If you need to recreate this system from scratch:
1. Create each file listed above with its described functionality
2. Maintain the parameter structure interfaces between components
3. Pay special attention to the flow solver (fan curve/system curve intersection)
4. Ensure the dual-clock time stepping is preserved (1s control, 1h environment)
5. Implement robust error handling in all components

The most critical components are the nested simulation loops in runSimulation.m and the pressure balance calculation that determines airflow in each time step.