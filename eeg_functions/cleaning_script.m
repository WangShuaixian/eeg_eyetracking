%%
% tk = str2num(getenv('SGE_TASK_ID')); % to use with the grid engine
 tk = 37;
if ismac    
    cfg             = eeg_etParams_feat('sujid',sprintf('%03d',tk),'expfolder','/Users/jossando/trabajo/features/'); 
else
    cfg             = eeg_etParams_feat('sujid',sprintf('%03d',tk));
end
% %% eeg_etParams_<project_name> set a cfg structure with the necessary paths to the
% different files and the settings for the automatic cleaning procedure (see below)

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% a first sweep to remove here bad segments independently of eye
% movements, here parameter are big enough to include eye-movement
% artifacts (all artifactual setting here are for the brainamp 64ch system semi DC system), this might be different in the
% case of non-filtered DC data (for example ANT system) 
%
% in this example I am cleaning 2 files (a pre-experiment and experiment file)
% so there is a loop here, and then ICA is done with the data of both files 
% together (they were in the same session and the pre-experiment was done in purporse
% to gather data of eye-movements artifacts)

files_prefix = {'pre','NA0'};
for t = 2%1:length(files_prefix)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % clean eye correction from this specific file
    % pause(rand(1)*30)   % to get rid of that random error that seem to be cause
    % by many computers accesing and saving the same file (channel corections) 
    % at the same moment when analysis in parallel multiple sessions of the same subject 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    filename = sprintf('%s%s',files_prefix{t},cfg.sujid);     % without extensions
    
    % every subject/file needs a master file that specifies channels to remove 
    % or swap (for example when channels were mistakingly connected in the amps) 
    % the file goes in the following path: <cfg.expfolder 'subjects_master_files/' upper(cfg.sujid) '_channels_corrections.mat'>
    clean_channel_corrections(cfg,sprintf('%s%s',filename)) % this remove settings of bad channels in file <' upper(cfg.sujid) '_channels_corrections.mat'>, for example when doing this a second time
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    cfg             = eeg_etParams_feat(cfg,...
                                       'filename',filename,...
                                       'event',[filename '.vmrk'],...
                                       'analysisname','cleaning',...
                                       'clean_exclude_eye',0,...           % detection of bad segments taking in account or not channels that are bad (which can have been already pre-specified by knowledge of the experimenter during acquisition)
                                       'clean_foi',30:5:120,...            % frequencies to use for the high-frequency noise artifact detection
                                       'clean_freq_threshold',400,...      % this is the threshold for frequency detection, threshold number are quite arbitrary depend on the size of the moving window, and here for frequency on the frequencies used (previous line)
                                       'clean_range_threshold',[5 600],... % thresholds for rejection based in absolute changes in signal, minimal range is to remove parts were the channel went dead and max for when it went very bad (here is a big number so eye movements are not removed, only period when things go very bad)
                                       'clean_ica_correct',[],...          % to do artefact detection over ICA corrected or not data (here we do not have ICA yet so no)
                                       'clean_trend_threshold',200,...     % thershold for linear trend, again this is very arbitrary, depends on window lengthj, characterisrtic of amplification and pre-filtering
                                       'clean_minclean_interval',100,...   % not sure, I think this is used to join artefactual periods if they are too cose together
                                       'clean_movwin_length',.256,...      % all the artifact detection are done by a omving window of this length
                                       'clean_mov_step',.006,...           % how much the window moves
                                       'clean_name','pre');

    % bad because of high-frequency noise
    [value_g,tot_sample_g]              = freq_artifact(cfg);              % detection of high-frequency artefacs
    [bad_g,badchans_g,channelbad_g]     = badsegments(cfg,value_g,tot_sample_g,cfg.clean_freq_threshold); % what are bad sgments and in which channels
    
    % bad because of high amplitude TODO: add prefiltering option, necessary for DC data
    [value_a,tot_sample_a]              = range_artifact(cfg);
    [bad_a,badchans_a,channelbad_a]     = badsegments(cfg,value_a,tot_sample_a,cfg.clean_range_threshold);

    [bad,badchans]                      = combine_bad({bad_a;bad_g},{badchans_a,badchans_g},cfg.clean_minclean_interval);  % joins bad segments based in different artefact detection procedures
    channelbad                          = combine_bad([channelbad_a;channelbad_g],[],cfg.clean_minclean_interval);

    cfg_clean                           = cfg;

    % save what is bad:
    % save([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename cfg.clean_name],'bad','badchans','channelbad','cfg_clean','value_g','tot_sample_g','value_a','tot_sample_a') % we save all this for now until we now the good seetings
    save([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename cfg.clean_name],'bad','badchans','channelbad','cfg_clean') % TODO: info about the cleaning parameters

    % here we check if there is a channel that is continuously bad even for the
    % lax criteria were using,
    cfg                                 = eeg_etParams_feat(cfg,'clean_bad_channel_criteria',.25); % = if > 25% of the time a channel is marked as artifactual is then set for removal
    check_session(cfg)   % TODO: need to correct this for ICA for more than one file

    % re-check bad segments now without taking in accound bad channels (done in badsegments and check_session)
     cfg                                = eeg_etParams_feat(cfg,'clean_movwin_length',.256,'clean_mov_step',.006);
    [bad_g,badchans_g]                  = badsegments(cfg,value_g,tot_sample_g,cfg.clean_freq_threshold);
    [bad_a,badchans_a]                  = badsegments(cfg,value_a,tot_sample_a,cfg.clean_range_threshold);
    [bad,badchans]                      = combine_bad({bad_a;bad_g},{badchans_a,badchans_g},cfg.clean_minclean_interval);
    save([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename cfg.clean_name],'bad','badchans','bad_a','badchans_a','-append') % TODO: info about the cleaning parameters
    cfgs{t} = cfg;
end
%%

% run first ICA
expica(cfg)

%%
% the second sweep is over data clean from eye-movement compontent and muscle artifact components, we can
% use narrower thresholds here, we check visually that everything is ok and then we run ICA again
clearvars -except files_prefix tk 
if ismac    
    cfg             = eeg_etParams_feat('sujid',sprintf('%03d',tk),'expfolder','/Users/jossando/trabajo/features/'); % this is just to being able to do analysis at work and with my laptop
else
    cfg             = eeg_etParams_feat('sujid',sprintf('%03d',tk));
end
for t = 2%1:length(files_prefix)
     filename = sprintf('%s%s',files_prefix{t},cfg.sujid);     % without extensions
   
    cfg             = eeg_etParams_feat(cfg,...
                                        'filename',filename,...
                                       'event',[filename '.vmrk'],...
                                       'analysisname','cleaning',...
                                       'clean_exclude_eye',0,...
                                       'clean_foi',30:5:120,...
                                       'clean_freq_threshold',125,...      % now threshold for rejection are tighter
                                       'clean_range_threshold',[125],...
                                       'clean_trend_threshold',70,...
                                       'clean_minclean_interval',500,...
                                       'clean_ica_correct','yes',...
                                       'clean_movwin_length',.256,...
                                       'clean_mov_step',.006,...
                                       'clean_name','general');

    % bad because of gamma
    [value_g,tot_sample_g]              = freq_artifact(cfg);
    [bad_g,badchans_g,channelbad_g]     = badsegments(cfg,value_g,tot_sample_g,cfg.clean_freq_threshold);
    % 
    % % bad because of amplitude
    [value_a,tot_sample_a]              = range_artifact(cfg);
    [bad_a,badchans_a,channelbad_a]     = badsegments(cfg,value_a,tot_sample_a,cfg.clean_range_threshold);
    % 
    % % bad because of trend, longer
     cfg                                = eeg_etParams_feat(cfg,'clean_movwin_length',1,...
                                              'clean_mov_step',.06);
    [value,tot_sample]                  = trend_artifact(cfg);
    [bad_t,badchans_t,channelbad_t]     = badsegments(cfg,value,tot_sample,cfg.clean_trend_threshold); %TODO: borders need to be readjusted to hthe length of gthe moving window
    %                    
    % % combine info and save,[channelbad_a;channelbad_g;channelbad_t]
    [bad,badchans]                      = combine_bad({bad_a;bad_g;bad_t},{badchans_a,badchans_g,badchans_t},cfg.clean_minclean_interval);
    channelbad                          = combine_bad([channelbad_a;channelbad_g;channelbad_t],[],cfg.clean_minclean_interval);

    cfg_clean                           = cfg;

    % save([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename cfg.clean_name],'bad','badchans','channelbad','cfg_clean','value_g','tot_sample_g','value_a','tot_sample_a') % we save all this for now until we now the good seetings
    save([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename cfg.clean_name],'bad','badchans','channelbad','cfg_clean') % TODO: info about the cleaning parameters

    % remove bad channel
    cfg                                 = eeg_etParams_feat(cfg,'clean_bad_channel_criteria',.20);
    check_session(cfg)

    % re-check bad segments now whitout taking in accound bad channels (done in badsegments)
    cfg                                = eeg_etParams_feat(cfg,'clean_movwin_length',.256,'clean_mov_step',.006);
    [bad_g,badchans_g]                 = badsegments(cfg,value_g,tot_sample_g,cfg.clean_freq_threshold);
    [bad_a2,badchans_a2]                 = badsegments(cfg,value_a,tot_sample_a,cfg.clean_range_threshold);
    cfg                                = eeg_etParams_feat(cfg,'clean_movwin_length',1,'clean_mov_step',.06);
    [bad_t,badchans_t]                 = badsegments(cfg,value,tot_sample,cfg.clean_trend_threshold); %TODO: borders need to be readjusted to hthe length of gthe moving window

    % we reuse the very bad segments becuase of range of the first iteration to get rid of
    % problems with some dataset where there is a very bad segment that gets
    % celan by ICA
    load([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename 'pre'],'bad_a','badchans_a') % TODO: info about the cleaning parameters

    [bad,badchans]                     = combine_bad({bad_a;bad_a2;bad_g;bad_t},{badchans_a,badchans_a2,badchans_g,badchans_t},cfg.clean_minclean_interval);
    save([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename cfg.clean_name],'bad','badchans','-append') % TODO: info about the cleaning parameters
end
% TODO:make GUI_visual to work for any experiment and not only CEM
%  cfg.remove_eye = 1;
%  cfg.remove_m = 1;
% cfg.raw=1
% visual_clean(cfg)
%% 
% run second definitive ICA
expica(cfg)

%%
% and we do the cleaning one more time with the final ICA weights
clear cfg
if ismac    
    cfg             = eeg_etParams_feat('sujid',sprintf('%03d',tk),'expfolder','/Users/jossando/trabajo/features/'); % this is just to being able to do analysis at work and with my laptop
else
    cfg             = eeg_etParams_feat('sujid',sprintf('%03d',tk));
end

for t = 2%1:length(files_prefix)
    cfg             = eeg_etParams_feat(cfg,...
                                       'filename',filename,...
                                       'event',[filename '.vmrk'],...
                                       'analysisname','cleaning',...
                                       'clean_exclude_eye',0,...
                                       'clean_foi',30:5:120,...
                                       'clean_freq_threshold',40,...
                                       'clean_range_threshold',125,...
                                       'clean_trend_threshold',70,...
                                       'clean_minclean_interval',500,...
                                       'clean_ica_correct','yes',...
                                       'clean_movwin_length',.256,...
                                       'clean_mov_step',.006,...
                                       'clean_name','final');

    % bad because of gamma
    [value_g,tot_sample_g]              = freq_artifact(cfg);
    [bad_g,badchans_g,channelbad_g]     = badsegments(cfg,value_g,tot_sample_g,cfg.clean_freq_threshold);
    % 
    % % bad because of amplitude
    [value_a,tot_sample_a]              = range_artifact(cfg);
    [bad_a,badchans_a,channelbad_a]     = badsegments(cfg,value_a,tot_sample_a,cfg.clean_range_threshold);
    % 
    % % bad because of trend, longer
     cfg                                = eeg_etParams_feat(cfg,'clean_movwin_length',1,...
                                              'clean_mov_step',.06);
    [value,tot_sample]                  = trend_artifact(cfg);
    [bad_t,badchans_t,channelbad_t]     = badsegments(cfg,value,tot_sample,cfg.clean_trend_threshold); %TODO: borders need to be readjusted to hthe length of gthe moving window
    %                    
    % % combine info and save,[channelbad_a;channelbad_g;channelbad_t]
    [bad,badchans]                      = combine_bad({bad_a;bad_g;bad_t},{badchans_a,badchans_g,badchans_t},cfg.clean_minclean_interval);
    channelbad                          = combine_bad([channelbad_a;channelbad_g;channelbad_t],[],cfg.clean_minclean_interval);

    cfg_clean                           = cfg;
    save([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename cfg.clean_name],'bad','badchans','channelbad','cfg_clean')  % TODO: info about the cleaning parameters
end
% save([cfg.analysisfolder cfg.analysisname '/' cfg.sujid '/' cfg.filename cfg.clean_name],'bad','badchans','channelbad','cfg_clean','value_g','tot_sample_g','value_a','tot_sample_a','value','tot_sample')  % TODO: info about the cleaning parameters
toc
% 

% so there is the problem of very bad periods during eye-movement 
% (possible solutions: embracing periods or ahigher non eye movement
% threshold)
% Can eegplot show whithin periods different causes?

% tag bad channels (bad>25% time within experimental period)

% save preinfo

% 1st ICA with corrected channels (dead_crazy) 
% removal of eye movements components
% bad segment with eye movements
% visual inspection
% 2nd ICA
% removal of eye movements components nad other artifactual components
% bad segmetns with criteria for ERP and TFR
% need to decide other components to remove or mark like heart beats
