function writeAlignedEnvFile(pm10File, tempFile, outFile)
% writeAlignedEnvFile  Extracts matching date/time, TempC & PM10 and writes to .mat AND .xlsx
%
%   writeAlignedEnvFile(pm10File,tempFile,outFile) will:
%     1. Read your PM10 CSV & Temp TXT.
%     2. Find exact datetime matches.
%     3. Build a table [Date, Time, TempC, PM10].
%     4. Save it as a .mat (forcing .mat) in ProcessedEnvData.
%     5. Write the same table to an Excel file alongside the MAT.

    %%— Input validation
    if nargin < 3
        error('Usage: writeAlignedEnvFile(pm10File, tempFile, outFile)');
    end

    %%— Load PM10 data
    opts  = detectImportOptions(pm10File);
    Tpm   = readtable(pm10File, opts);
    vars  = Tpm.Properties.VariableNames;
    dVar  = vars{find(contains(lower(vars),'datelocal'),1)};
    tVar  = vars{find(contains(lower(vars),'timelocal'),1)};
    vVar  = vars{find(contains(lower(vars),'samplemeasurement'),1)};
    Draw  = Tpm.(dVar);
    if ~isdatetime(Draw)
        D = datetime(string(Draw),'InputFormat','yyyy-MM-dd','Locale','en_US');
        bad = isnat(D);
        if any(bad)
            r2 = string(Draw(bad));
            D(bad) = datetime(r2,'InputFormat','M/d/yyyy','Locale','en_US');
        end
    else
        D = dateshift(Draw,'start','day');
    end
    TDraw = Tpm.(tVar);
    if ~isdatetime(TDraw)
        S = string(TDraw);
        C = split(S,':');
        TP = hours(str2double(C(:,1))) + minutes(str2double(C(:,2)));
    else
        TP = timeofday(TDraw);
    end
    pmDT  = D + TP;
    pmVal = Tpm.(vVar);

    %%— Load temperature data
    Tt   = readtable(tempFile, ...
                    'Delimiter',' ','MultipleDelimsAsOne',true, ...
                    'ReadVariableNames',false);
    dnum = Tt{:,4};
    tnum = Tt{:,5};
    tVal = Tt{:,10};
    Dt   = datetime(dnum,'ConvertFrom','yyyyMMdd');
    tDT  = Dt + hours(floor(tnum/100));

    %%— Find exact matches
    [commonDT, iP, iT] = intersect(pmDT, tDT);
    if isempty(commonDT)
        error('No matching date–time stamps found.');
    end
    tempC = tVal(iT);
    pm10  = pmVal(iP);

    %%— Build output table (fixed date formatting)
    dateStr = string(commonDT,'yyyy-MM-dd');   % uppercase MM = month
    timeStr = string(commonDT,'HH:mm');        % lowercase mm = minutes
    OUT = table(dateStr, timeStr, tempC, pm10, ...
                'VariableNames',{'Date','Time','TempC','PM10'});

    %%— Save .mat file
    [p,n,ext] = fileparts(outFile);
    if isempty(p)
        outDir = fullfile(pwd,'ProcessedEnvData');
        if ~exist(outDir,'dir')
            mkdir(outDir);
        end
        savePath = fullfile(outDir,[n ext]);
    else
        if ~exist(p,'dir')
            mkdir(p);
        end
        savePath = fullfile(p,[n ext]);
    end
    if ~strcmpi(ext,'.mat')
        warning('Forcing .mat extension.');
        savePath = fullfile(fileparts(savePath),[n '.mat']);
    end
    save(savePath,'OUT');
    fprintf('Saved %d records to MAT file: %s\n',height(OUT),savePath);

    %%— Write to Excel
    excelPath = fullfile(fileparts(savePath), [n '.xlsx']);
    writetable(OUT, excelPath, 'FileType','spreadsheet');
    fprintf('Wrote %d records to Excel file: %s\n',height(OUT),excelPath);
end
