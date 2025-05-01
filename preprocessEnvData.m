function envData = preprocessEnvData(pm10File, tempFile, varargin)
% =========================================================================
% updated:  May 1st 2025
% 
% preprocessEnvData
%   Reads AQS PM10 CSV (quoted, comma-delimited) and NCEI hourly TXT,
%   aligns them on an hourly grid (unique times), fills gaps, and returns a clean table.
% =========================================================================

%% Parse inputs
p = inputParser;
addParameter(p,'InterpMethod','linear');
addParameter(p,'GapFill',     {});
addParameter(p,'PreviewPlot', true);
parse(p, varargin{:});
interpMethod = p.Results.InterpMethod;
gapFillSpec  = p.Results.GapFill;
doPreview    = p.Results.PreviewPlot;

%% Ensure files exist
if ~isfile(pm10File)
    error('PM10 file not found: %s', pm10File);
end
if ~isfile(tempFile)
    error('Temperature file not found: %s', tempFile);
end

%% Load PM10 CSV
opts  = detectImportOptions(pm10File);
pmRaw = readtable(pm10File, opts);
vars  = pmRaw.Properties.VariableNames;
% Find PM10 date, time, and measurement columns
dateVar = vars{find(contains(lower(vars),'datelocal'),1)};
timeVar = vars{find(contains(lower(vars),'timelocal'),1)};
pmVar   = vars{find(contains(lower(vars),'samplemeasurement'),1)};
% Extract columns
dateCol  = pmRaw.(dateVar);
timeCol  = pmRaw.(timeVar);
pm10Vals = pmRaw.(pmVar);
% Parse date part
if isdatetime(dateCol)
    datePart = dateshift(dateCol,'start','day');
else
    dateStr  = string(dateCol);
    datePart = datetime(dateStr,'InputFormat','yyyy-MM-dd','Locale','en_US');
    badDate  = isnat(datePart);
    if any(badDate)
        datePart(badDate) = datetime(dateStr(badDate),'InputFormat','M/d/yyyy','Locale','en_US');
    end
end
% Parse time part
if isdatetime(timeCol)
    timePart = timeofday(timeCol);
else
    timeStr = string(timeCol);
    tp      = split(timeStr,':'); % ["HH" "MM"]
    hr      = str2double(tp(:,1));
    mn      = str2double(tp(:,2));
    timePart= hours(hr) + minutes(mn);
end
% Combine into datetime
pmDateTime = datePart + timePart;
badDateTime = isnat(pmDateTime);
if any(badDateTime)
    idx = find(badDateTime,1);
    error('Failed to parse PM10 timestamp at row %d: %s %s', idx, ...
          string(dateStr(idx)), string(timeStr(idx)));
end
pmData = table(pmDateTime, pm10Vals, 'VariableNames',{'datetime','PM10'});

%% Load Temperature TXT by column index
% Columns: 4=LST_DATE (yyyymmdd), 5=LST_TIME (HHMM), 10=T_HR_AVG
tempRaw = readtable(tempFile, ...
    'Delimiter',' ', 'MultipleDelimsAsOne',true, 'ReadVariableNames',false);
lstDateNums = tempRaw{:,4};
lstTimeNums = tempRaw{:,5};
tempVals     = tempRaw{:,10};
% Build datetime for temp
datePartT    = datetime(lstDateNums,'ConvertFrom','yyyyMMdd');
timePartT    = hours(floor(lstTimeNums/100));
tempDateTime = datePartT + timePartT;
tempData = table(tempDateTime, tempVals, 'VariableNames',{'datetime','TempC'});

%% Merge and enforce unique hourly grid
envData = innerjoin(pmData, tempData, 'Keys','datetime');
% Remove duplicate datetime entries
[uniqueTimes, ia] = unique(envData.datetime, 'first');
envData = envData(ia,:);
% Create full-hour vector
t0        = dateshift(min(envData.datetime),'start','hour');
t1        = dateshift(max(envData.datetime),'start','hour');
hoursFull = (t0:hours(1):t1)';
% Convert to timetable
envTT    = table2timetable(envData,'RowTimes','datetime');
% Retime with interpolation
envTT    = retime(envTT, hoursFull, interpMethod);
% Optional gap fill
if ~isempty(gapFillSpec)
    m = gapFillSpec{1};
    if numel(gapFillSpec)==2
        envTT = fillmissing(envTT, m, gapFillSpec{2});
    else
        envTT = fillmissing(envTT, m);
    end
end
% Drop remaining missing hours
nmiss = sum(any(ismissing(envTT),2));
if nmiss>0
    warning('%d missing hours dropped.', nmiss);
    envTT = rmmissing(envTT);
end
% Back to table
envData = timetable2table(envTT,'ConvertRowTimes',true);
envData.Properties.VariableNames{1} = 'datetime';

%% Sanity & preview
if isempty(envData)
    error('No data left after preprocessing.');
end
fprintf('Aligned dataset: %d hourly records (%s to %s)\n', ...
    height(envData), string(envData.datetime(1)), string(envData.datetime(end)));
if doPreview
    figure('Name','Env Data Preview','Color','w');
    yyaxis left;  plot(envData.datetime,envData.TempC,'-b'); ylabel('Temp (°C)');
    yyaxis right; plot(envData.datetime,envData.PM10,'-r'); ylabel('PM10');
    title('Aligned PM10 & Temperature'); grid on; legend('Temp','PM10');
end
end
