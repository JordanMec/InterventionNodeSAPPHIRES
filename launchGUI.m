function guiParams = launchGUI(guiParams)
% Create a simple GUI to modify parameters

fprintf('[launchGUI] Creating GUI window\n');

try
    % Create the figure
    guiFig = figure('Name','Digital Twin - Simulation Options', ...
                    'NumberTitle','off', ...
                    'Position',[100 100 520 420], ...
                    'Resize','off');
    
    % Store the original guiParams for cancel operation
    originalParams = guiParams;
    
    % Save parameters globally so the callbacks can modify them
    global GUI_PARAMS;
    GUI_PARAMS = guiParams;
    
    % Create the GUI elements
    uicontrol(guiFig,'Style','text','String','Set Home / HVAC Parameters', ...
              'Units','normalized','Position',[0.05 0.90 0.90 0.07], ...
              'FontSize',12,'FontWeight','bold');
    
    % Blower door
    uicontrol(guiFig,'Style','text','String','Blower Door (CFM @ 50 Pa):', ...
              'Units','normalized','Position',[0.05 0.78 0.40 0.05], ...
              'HorizontalAlignment','left');
    uicontrol(guiFig,'Style','edit','String',num2str(guiParams.blowerDoor), ...
              'Units','normalized','Position',[0.50 0.78 0.40 0.06],'Tag','blowerDoor', ...
              'Callback',@updateParam);
    
    % Target pressure
    uicontrol(guiFig,'Style','text','String','Target Pressure (Pa, <= 8):', ...
              'Units','normalized','Position',[0.05 0.70 0.40 0.05], ...
              'HorizontalAlignment','left');
    uicontrol(guiFig,'Style','edit','String',num2str(guiParams.targetPressure), ...
              'Units','normalized','Position',[0.50 0.70 0.40 0.06],'Tag','targetPressure', ...
              'Callback',@updateParam);
    
    % Duct length
    uicontrol(guiFig,'Style','text','String','Duct Length (ft):', ...
              'Units','normalized','Position',[0.05 0.62 0.40 0.05], ...
              'HorizontalAlignment','left');
    uicontrol(guiFig,'Style','edit','String',num2str(guiParams.ductLength), ...
              'Units','normalized','Position',[0.50 0.62 0.40 0.06],'Tag','ductLength', ...
              'Callback',@updateParam);
    
    % Checkboxes
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
    
    % RUN button
    uicontrol(guiFig,'Style','pushbutton','String','RUN', ...
              'Units','normalized','Position',[0.30 0.15 0.40 0.10], ...
              'FontSize',12,'Callback',@runButtonCallback);
    
    % Set close request function
    set(guiFig, 'CloseRequestFcn', @closeGUI);
    
    % Wait for user interaction
    fprintf('[launchGUI] Waiting for user input...\n');
    uiwait(guiFig);
    
    % Return the updated parameters
    guiParams = GUI_PARAMS;
    clear global GUI_PARAMS;
    
    fprintf('[launchGUI] GUI closed, parameters collected\n');
catch ME
    fprintf('[ERROR] in launchGUI: %s\n', ME.message);
    fprintf('  Line: %d\n', ME.stack(1).line);
    fprintf('[launchGUI] Using original parameters\n');
    
    % Clean up global variable and return original parameters
    if ~isempty(who('global', 'GUI_PARAMS'))
        clear global GUI_PARAMS;
    end
    
    % Close figure if still open
    if exist('guiFig', 'var') && ishandle(guiFig)
        close(guiFig);
    end
end
end

% GUI callback functions - must be in same file
function updateParam(src, ~)
    global GUI_PARAMS;
    tag = get(src, 'Tag');
    
    if strcmp(get(src, 'Style'), 'edit')
        val = str2double(get(src, 'String'));
        if isnan(val)
            warning('Invalid numeric input for %s', tag);
            val = GUI_PARAMS.(tag);  % Restore previous value
            set(src, 'String', num2str(val));
        end
    else
        val = get(src, 'Value');
    end
    
    GUI_PARAMS.(tag) = val;
    fprintf('[GUI] Updated %s to %.6g\n', tag, val);
end

function runButtonCallback(~, ~)
    fprintf('[GUI] Run button clicked\n');
    uiresume(gcbf);  % Resume from uiwait
    delete(gcbf);    % Close the figure
end

function closeGUI(src, ~)
    % Ask for confirmation before closing
    selection = questdlg('Abort simulation?', 'Confirm Exit', 'Yes', 'No', 'No');
    if strcmp(selection, 'Yes')
        fprintf('[GUI] User aborted simulation\n');
        uiresume(src);  % Resume from uiwait
        delete(src);    % Close the figure
        error('Simulation aborted by user.');
    end
end