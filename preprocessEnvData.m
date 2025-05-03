function envData = preprocessEnvData(envMatFile, varargin)
% preprocessEnvData Load pre-aligned EnvData from .mat and return as table
%   envData = preprocessEnvData(envMatFile) loads a .mat file containing the
%   table OUT with variables Date, Time, TempC, PM10 and returns envData as a
%   table with datetime, TempC, and PM10.
%
%   Name-Value Arguments:
%     'PreviewPlot' (true/false) Display a quick plot of TempC & PM10 (default: true)
%
% Example:
%   envData = preprocessEnvData('ProcessedEnvData/alignedEnvData.mat','PreviewPlot',false);

    %% Parse optional inputs
    p = inputParser;
    addParameter(p,'PreviewPlot',true,@(x) islogical(x) || isnumeric(x));
    parse(p, varargin{:});
    doPreview = logical(p.Results.PreviewPlot);

    %% Validate input file
    [~,~,ext] = fileparts(envMatFile);
    if ~strcmpi(ext, '.mat')
        error('Input file must be a .mat file containing OUT.');
    end
    if ~isfile(envMatFile)
        error('MAT-file not found: %s', envMatFile);
    end

    %% Load the pre-aligned data
    S = load(envMatFile, 'OUT');
    if ~isfield(S, 'OUT')
        error('MAT-file does not contain variable OUT.');
    end
    T = S.OUT;

    %% Reconstruct datetime vector
    dt = datetime(T.Date + " " + T.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');
    envData = table(dt, T.TempC, T.PM10, 'VariableNames', {'datetime', 'TempC', 'PM10'});

    %% Optional preview plot
    if doPreview
        figure('Name', 'Env Data Preview', 'Color', 'w');
        yyaxis left;
        plot(envData.datetime, envData.TempC, '-b');
        ylabel('Temp (°C)');
        yyaxis right;
        plot(envData.datetime, envData.PM10, '-r');
        ylabel('PM10');
        title('Preprocessed Environmental Data');
        grid on;
        legend('Temp', 'PM10');
    end
end
