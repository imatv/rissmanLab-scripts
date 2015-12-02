function NIQ_full_Ridge(behavioral_var,conn_type,Network_1,Network_2)

toolboxRoot=['/space/raid6/data/rissman/Nicco/MATLAB_PATH/'];
addpath(genpath(toolboxRoot))
toolboxRoot=['/space/raid6/data/rissman/Nicco/NIQ/Scripts'];
addpath(genpath(toolboxRoot))

% Loop over types of analyses
types = {'s', 'smof_upper', 'smof_lower', 'fmos_upper', 'fmos_lower', 'Interact'}; % 'f'?
percent = .5;
for t = 2:size(types, 2)
    
    % Set variables of interest
    switch nargin
        case 3
            fprintf('Trying intranetwork...\n');
            fprintf('%s...\n', types{t});
            if t == 1
                [subjs_used,classification_patterns] = features_structural(conn_type, Network_1);
            elseif t == 2
                [subjs_used,classification_patterns] = features_smof_upper(conn_type, percent, Network_1);
            elseif t == 3
                [subjs_used,classification_patterns] = features_smof_lower(conn_type, percent, Network_1);
            elseif t == 4
                [subjs_used,classification_patterns] = features_fmos_upper(conn_type, percent, Network_1);
            elseif t == 5
                [subjs_used,classification_patterns] = features_fmos_lower(conn_type, percent, Network_1);
            elseif t == 6
                [subjs_used,classification_patterns] = features_sf_Interact(conn_type, Network_1);
            end
            fprintf('Retrieved feature set.\n');
        case 4
            fprintf('Trying internetwork...\n');
            fprintf('%s...\n', types{t});
            if t == 1
                [subjs_used,classification_patterns] = features_structural(conn_type, Network_1, Network_2);
            elseif t == 2
                [subjs_used,classification_patterns] = features_smof_upper(conn_type, percent, Network_1, Network_2);
            elseif t == 3
                [subjs_used,classification_patterns] = features_smof_lower(conn_type, percent, Network_1, Network_2);
            elseif t == 4
                [subjs_used,classification_patterns] = features_fmos_upper(conn_type, percent, Network_1, Network_2);
            elseif t == 5
                [subjs_used,classification_patterns] = features_fmos_lower(conn_type, percent, Network_1, Network_2);
            elseif t == 6
                [subjs_used,classification_patterns] = features_sf_Interact(conn_type, Network_1, Network_2);
            end
            fprintf('Retrieved feature set.\n');
    end

    %% Behavioral Data

    % Initialize paths
    behavioral_dir = '/space/raid6/data/rissman/Nicco/NIQ/Behavioral/';

    % Grab subjects' behavioral data
    fprintf('Grabbing behavioral data...\n');
    cd(behavioral_dir);
    load('all_behave.mat');

    % Initialize a vector for behavioral values for each subject
    temp_behav = zeros(1, length(subjs_used));

    % Loop through subjects
    for s = 1:length(subjs_used)

        % Grab info for subject
        subjectID = subjs_used(s);

        % Grab subject's behavioral value
        temp_behav(s) = all_behave.(['Subject' num2str(subjectID)]).(behavioral_var);
    end

    % Cross Validation
    fprintf('Finding selectors...\n');
    behav_vector = temp_behav;
    condensed_regs_of_interest = 1:length(behav_vector);
    [selectors] = enforce_forced_choice(condensed_regs_of_interest);

    %% Classification
    fprintf('Beginning Classification...\n');
    running_Betas=zeros(size(classification_patterns,1),1);

    for n=1:size(selectors,2)
        current_selector = selectors{n};
        train_idx = find(current_selector == 1);
        test_idx  = find(current_selector == 2);

        train_labels = behav_vector(:,train_idx);
        test_labels = behav_vector(:,test_idx);

        train_pats = classification_patterns(:,train_idx);
        test_pats = classification_patterns(:,test_idx);

        fprintf('Ridge for n = %d \n', n);

        %RIDGE
        class_args.penalty = size(classification_patterns,1);
        [scratch]=train_ridge(train_pats, train_labels, class_args);
        [ridge_acts{n} scratchpad] = test_ridge(test_pats,test_labels,scratch);

    end

    fprintf('Finishing Classification...\n');

    Ridge=corr(cell2mat(ridge_acts)', behav_vector');

    % Output results
    fprintf('Saving results...\n\n');
    switch nargin
        case 3
    save_file=['/space/raid6/data/rissman/Nicco/NIQ/Results/EXPANSION/' Network_1 '_' conn_type '_' behavioral_var '_n' num2str(length(subjs_used)) '_' types{t} '_Ridge.txt'];
        case 4
    save_file=['/space/raid6/data/rissman/Nicco/NIQ/Results/EXPANSION/' Network_1 '_and_' Network_2 '_' conn_type '_' behavioral_var '_n' num2str(length(subjs_used)) '_' types{t} '_Ridge.txt'];
    end

    header={'Ridge'};
    data=[Ridge];

    save_data_with_headers(header,data,save_file);
end