%{
Read the *.phu files and save them as 'info_record.mat' and 'TPSF_collect.mat'

Ting-Yi Kuo
Last update: 2024/03/11
%}

clc;clear;close all;

%% param
folderPath='20240612/IRF_530';
process_folder={'IRF1','IRF2'}; % {'SDS1','SDS2'}
repeat_times=5;

% fileNames={'SDS-2-4min-1.phu','SDS-2-4min-2.phu','SDS-2-4min-3.phu','SDS-2-4min-4.phu','SDS-2-4min-5.phu','bg.phu'};
% fileNames={'IRF_380_1.phu','IRF_380_2.phu','IRF_380_4.phu','IRF_380_5.phu'};
% fileNames={'IRF_380_far_1.phu','IRF_380_far_2.phu','IRF_380_far_3.phu','IRF_380_far_4.phu','IRF_380_far_5.phu'};

for pf=1:length(process_folder)

    fileNames={};
    for num=1:repeat_times
        fileNames{num}=[process_folder{pf} '_' num2str(num) '.phu'];
    end


    num_SDS=1;
    repeat_times=5; % how many times of measurements each phantom and SDS
    num_phantom=2;  % if no phantom data, set this to zero
    target_prefix={};

    info_record=[];
    TPSF_collect=[];

    %% init
    % fileList=dir(fullfile(folderPath,'*.phu'));
    % fileNames=cell(1, numel(fileList));
    % for i = 1:numel(fileList)
    %     fileNames{i} = fileList(i).name;
    % end

    tyEmpty8      = hex2dec('FFFF0008');
    tyBool8       = hex2dec('00000008');
    tyInt8        = hex2dec('10000008');
    tyBitSet64    = hex2dec('11000008');
    tyColor8      = hex2dec('12000008');
    tyFloat8      = hex2dec('20000008');
    tyTDateTime   = hex2dec('21000008');
    tyFloat8Array = hex2dec('2001FFFF');
    tyAnsiString  = hex2dec('4001FFFF');
    tyWideString  = hex2dec('4002FFFF');
    tyBinaryBlob  = hex2dec('FFFFFFFF');


    %% main
    for f=1:length(fileNames)
        % [filename, pathname]=uigetfile('*.phu', 'PQ histogram data:');
        filename=fileNames{f};
        fid=fopen(fullfile(folderPath,process_folder{pf},filename));

        Magic = fread(fid, 8, '*char');
        if not(strcmp(Magic(Magic~=0)','PQHISTO'))
            error('Magic invalid, this is not a PHU file.');
        end
        Version = fread(fid, 8, '*char');

        while true
            % read Tag Head
            TagIdent = fread(fid, 32, '*char'); % TagHead.Ident
            TagIdent = (TagIdent(TagIdent ~= 0))'; % remove #0 and make more readable
            TagIdx = fread(fid, 1, 'int32');    % TagHead.Idx
            TagTyp = fread(fid, 1, 'uint32');   % TagHead.Typ
                                                % TagHead.Value will be read in the
                                                % right type function  
            if TagIdx > -1
              EvalName = [TagIdent '(' int2str(TagIdx + 1) ')'];
            else
              EvalName = TagIdent;
            end
            % check Type of Header
            switch TagTyp
                case tyEmpty8
                    fread(fid, 1, 'int64');   
                case tyBool8
                    TagInt = fread(fid, 1, 'int64');
                    if TagInt==0
                        eval([EvalName '=false;']);
                    else
                        eval([EvalName '=true;']);
                    end            
                case tyInt8
                    TagInt = fread(fid, 1, 'int64');
                    eval([EvalName '=TagInt;']);
                case tyBitSet64
                    TagInt = fread(fid, 1, 'int64');
                    eval([EvalName '=TagInt;']);
                case tyColor8    
                    TagInt = fread(fid, 1, 'int64');
                    eval([EvalName '=TagInt;']);
                case tyFloat8
                    TagFloat = fread(fid, 1, 'double');
                    eval([EvalName '=TagFloat;']);
                case tyFloat8Array
                    TagInt = fread(fid, 1, 'int64');
                    fseek(fid, TagInt, 'cof');
                case tyTDateTime
                    TagFloat = fread(fid, 1, 'double');                
                    eval([EvalName '=datenum(1899,12,30)+TagFloat;']); % but keep in memory as Matlab Date Number
                case tyAnsiString
                    TagInt = fread(fid, 1, 'int64');
                    TagString = fread(fid, TagInt, '*char');
                    TagString = (TagString(TagString ~= 0))';
                    if TagIdx > -1
                       EvalName = [TagIdent '{' int2str(TagIdx + 1) '}'];
                    end
                    eval([EvalName '=[TagString];']);
                case tyWideString 
                    % Matlab does not support Widestrings at all, just read and
                    % remove the 0's (up to current (2012))
                    TagInt = fread(fid, 1, 'int64');
                    TagString = fread(fid, TagInt, '*char');
                    TagString = (TagString(TagString ~= 0))';
                    if TagIdx > -1
                       EvalName = [TagIdent '{' int2str(TagIdx + 1) '}'];
                    end
                    eval([EvalName '=[TagString];']);
                case tyBinaryBlob
                    TagInt = fread(fid, 1, 'int64');
                    fseek(fid, TagInt, 'cof');    
                otherwise
                    error('Illegal Type identifier found! Broken file?');
            end
            if strcmp(TagIdent, 'Header_End')
                break
            end
        end

        % read all histograms
        for i = 1:HistoResult_NumberOfCurves
            fseek(fid,HistResDscr_DataOffset(i),'bof');
            Counts(:,i) = fread(fid, HistResDscr_HistogramBins(i), 'uint32');
        end
        Peak=max(Counts);

        % store the histograms info
        info_record(f,1)=HistResDscr_MDescResolution(i);    % Time bin resolution
        info_record(f,2)=HistResDscr_HistogramBins(i);      % Number of time bins
        info_record(f,3)=Peak;                              % Peak count
        info_record(f,4)=HistResDscr_IntegralCount(i);      % Integral count
        TPSF_collect(:,f)=Counts;


        fclose(fid);
    end

    %% save the data and information
    rowLabels={'Time bin resolution','Number of time bins','Peak count','Integral count'};
    info_record=array2table(info_record, 'RowNames', fileNames, 'VariableNames', rowLabels);

    save(fullfile(folderPath,process_folder{pf},[process_folder{pf} '_TPSF_collect.mat']),'TPSF_collect');
    save(fullfile(folderPath,process_folder{pf},[process_folder{pf} '_info_record.mat']),'info_record');
end
fprintf('Done!\n');
