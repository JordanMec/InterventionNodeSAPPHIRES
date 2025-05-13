function guiParams = launchGUI(guiParams)
% =========================================================================
% launchGUI.m - Launch GUI for Parameter Adjustment
% =========================================================================
% Description:
%   This function creates and manages a graphical user interface that
%   allows the user to adjust simulation parameters. It displays input
%   fields for key parameters and returns the updated values when the
%   user clicks the "RUN" button.
%
% Inputs:
%   guiParams - Initial parameter structure from initGuiParams()
%
% Outputs:
%   guiParams - Updated parameter structure with user-defined values
%
% Related files:
%   - godMode.m: Calls this function when GUI mode is enabled
%   - initGuiParams.m: Provides initial parameter values
%
% Notes:
%   - GUI allows adjustment of key simulation parameters
%   - Changes are applied when the "RUN" button is clicked
%   - User can cancel simulation with the close button
%   - Parameters include house characteristics and features to enable/disable
%
% =========================================================================
% Last updated: May 12, 2025
% =========================================================================

fprintf('[launchGUI] Creating GUI window\n');

try
    % Create main figure window
    guiFig = figure('Name','Digital Twin - Simulation Options', ...
                    'NumberTitle','off', ...
                    'Position',[100 100 520 420], ...
                    'Resize','off');
    
    % Store original parameters in case of cancellation
    originalParams = guiParams;
    
    % Create global variable to store parameters during GUI interaction
    global GUI_PARAMS;
    GUI_PARAMS = guiParams;
    
    % Title label
    uicontrol(guiFig,'Style','text','String','Set Home / HVAC Parameters', ...
              'Units','normalized','Position',[0.05 0.90 0.90 0.07], ...
              'FontSize',12,'FontWeight','bold');
    
    % Blower door test input
    uicontrol(guiFig,'Style','text','String','Blower Door (CFM @ 50 Pa):', ...
              'Units','normalized','Position',[0.05 0.78 0.40 0.05], ...
              'HorizontalAlignment','left');
    uicontrol(guiFig,'Style','edit','String',num2str(guiParams.blowerDoor), ...
              'Units','normalized','Position',[0.50 0.78 0.40 0.06],'Tag','blowerDoor', ...
              'Callback',@updateParam);
    
    % Target pressure input
    uicontrol(guiFig,'Style','text','String','Target Pressure (Pa, <= 8):', ...
              'Units','normalized','Position',[0.05 0.70 0.40 0.05], ...
              'HorizontalAlignment','left');
    uicontrol(guiFig,'Style','edit','String',num2str(guiParams.targetPressure), ...
              'Units','normalized','Position',[0.50 0.70 0.40 0.06],'Tag','targetPressure', ...
              'Callback',@updateParam);
    
    % Duct length input
    uicontrol(guiFig,'Style','text','String','Duct Length (ft):', ...
              'Units','normalized','Position',[0.05 0.62 0.40 0.05], ...
              'HorizontalAlignment','left');
    uicontrol(guiFig,'Style','edit','String',num2str(guiParams.ductLength), ...
              'Units','normalized','Position',[0.50 0.62 0.40 0.06],'Tag','ductLength', ...
              'Callback',@updateParam);
    
    % Feature checkboxes - left column
    uicontrol(guiFig,'Style','checkbox','String','Include duct loss', ...
              'Value',guiParams.useDuctLoss, ...
              'Units','normalized','Position',[0.05 0.50 0.40 0.06],'Tag','useDuctLoss', ...
              'Callback',@updateParam);
    
    uicontrol(guiFig,'Style','checkbox','String','Include envelope loss', ...
              'Value',guiParams.useHomesLoss, ...
              'Units','normalized','Position',[0.50 0.50 0.40 0.06],'Tag','useHomesLoss', ...
              'Callback',@updateParam);
    
    uicontrol(guiFig,'Style','checkbox','String','Enable stack effect', ...
              'Value',guiParams.enableStackEffect, ...
              'Units','normalized','Position',[0.05 0.42 0.40 0.06],'Tag','enableStackEffect', ...
              'Callback',@updateParam);
    
    uicontrol(guiFig,'Style','checkbox','String','Enable meal-time exhaust', ...
              'Value',guiParams.enableExhaustFan, ...
              'Units','normalized','Position',[0.50 0.42 0.40 0.06],'Tag','enableExhaustFan', ...
              'Callback',@updateParam);
    
    uicontrol(guiFig,'Style','checkbox','String','Use natural PM removal', ...
              'Value',guiParams.useNaturalRemoval, ...
              'Units','normalized','Position',[0.05 0.34 0.40 0.06],'Tag','useNaturalRemoval', ...
              'Callback',@updateParam);
    
    % Run button
    uicontrol(guiFig,'Style','pushbutton','String','RUN', ...
              'Units','normalized','Position',[0.30 0.15 0.40 0.10], ...
              'FontSize',12,'Callback',@runButtonCallback);
    
    % Set close callback
    set(guiFig, 'CloseRequestFcn', @closeGUI);
    
    % Wait for user to interact with GUI
    fprintf('[launchGUI] Waiting for user input...\n');
    uiwait(guiFig);
    
    % Get updated parameters from global variable
    guiParams = GUI_PARAMS;
    clear global GUI_PARAMS;
    
    fprintf('[launchGUI] GUI closed, parameters collected\n');
catch ME
    % Handle any errors
    fprintf('[ERROR] in launchGUI: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('[launchGUI] Using original parameters\n');
    
    % Clean up global variable if exists
    if ~isempty(who('global', 'GUI_PARAMS'))
        clear global GUI_PARAMS;
    end
    
    % Close GUI if still open
    if exist('guiFig', 'var') && ishandle(guiFig)
        close(guiFig);
    end
end
end

% Callback function for parameter updates
function updateParam(src, ~)
    global GUI_PARAMS;
    
    % Get control tag (parameter name)
    tag = get(src, 'Tag');
    
    % Handle different control types
    if strcmp(get(src, 'Style'), 'edit')
        % Convert string to number for edit controls
        val = str2double(get(src, 'String'));
        
        % Validate numeric input
        if isnan(val)
            warning('Invalid numeric input for %s', tag);
            val = GUI_PARAMS.(tag);
            set(src, 'String', num2str(val));
        end
    else
        % Get value directly for checkbox controls
        val = get(src, 'Value');
    end
    
    % Update parameter in global structure
    GUI_PARAMS.(tag) = val;
    fprintf('[GUI] Updated %s to %.6g\n', tag, val);
end

% Callback function for RUN button
function runButtonCallback(~, ~)
    fprintf('[GUI] Run button clicked\n');
    uiresume(gcbf);
    delete(gcbf); 
end

% Callback function for window close
function closeGUI(src, ~)
    % Confirm before closing
    selection = questdlg('Abort simulation?', 'Confirm Exit', 'Yes', 'No', 'No');
    if strcmp(selection, 'Yes')
        fprintf('[GUI] User aborted simulation\n');
        uiresume(src);
        delete(src);
        error('Simulation aborted by user.');
    end
end