function [subjs_used, feature_set] = features_structural(conn_type, val_type, net1, net2)
%
%==========================================================================================
% features_structural.m
%
% Take in network name(s), and a type of relation (specified in "Connectivities Naming.xlsx").
%
% Creates a feature set containing mean/volume structural connectivity values in descending
% order for each network or network pair. This is done for every subject.
%
% Resulting matrix has mean/volume connectivity values as rows and subjects as columns.
%
% Type of value must be specified.
% Allowed types are: 'M' and 'V' for 'mean' and 'volume' respectively.
%
% Type of feature set must be specified.
% Allowed types are:
%   wX, amXY_wX_wY, amXY_wX, amXY_wY, amXY, aoXY_wX_wY, ao_XY_wX, ao_XY_wY, aoXY.
% Explained below:
% - Intranetwork Connectivities (w/in each individual network X)
%   Possible Sets:                                      Naming Convention:
%   - w/in X                                            wX
% - Internetwork Connectivities (2 networks: X and Y)
%   Possible Sets:                                      Naming Convention:
%   - across mutual XY, w/in X, w/in Y                  amXY_wX_wY
%   - across mutual XY, w/in X                          amXY_wX
%   - across mutual XY, w/in Y                          amXY_wY
%   - across mutual XY                                  amXY
%   - across one-way XY, w/in X, w/in Y                 aoXY_wX_wY
%   - across one-way XY, w/in X                         aoXY_wX
%   - across one-way XY, w/in Y                         aoXY_wY
%   - across one-way XY                                 aoXY
%
% "Across mutual" describes the mutual averaged connections between ROIs in separate networks.
%   Uses mean connectivity values for this.
% "Across one-way" describes the specific one-directional connection from an ROI in one network to another.
%   Uses the values in "Compiled_Values" for this.
%
% Note: All intranetwork connectivities are averaged.
%
% If only one network is specified, type must be wX. Function will return
% an empty struct otherwise.
%
% If a network and its subset are given as arguments, function will return
% an empty struct. (Example: Default_Mode_L & Default_Mode)
%
% Averaged structural data is located at:
% ~/Nicco/NIQ/EXPANSION/Probtrack_Subject_Specific/Compiled_Values/Average_Values/Subj_{SubjectID}_avg.mat
%
% For non-averaged structural data, we use data located at:
% ~/Nicco/NIQ/EXPANSION/Probtrack_Subject_Specific/Compiled_Values/Subj_{SubjectID}.mat
%
% For the network indices, we use:
% ~/Nicco/NIQ/Network_Indices/Petersen_Networks.mat
%
%==========================================================================================

% Set paths
structural_avg_path = '/space/raid6/data/rissman/Nicco/NIQ/EXPANSION/Probtrack_Subject_Specific/Compiled_Values/Average_Values/';
structural_path = '/space/raid6/data/rissman/Nicco/NIQ/EXPANSION/Probtrack_Subject_Specific/Compiled_Values/';
functional_path = '/space/raid6/data/rissman/Nicco/HCP_ALL/Resting_State/Petersen_FC/';
network_indices_path = '/space/raid6/data/rissman/Nicco/NIQ/Network_Indices/';

% Get network info
load([network_indices_path 'Petersen_Networks.mat']);
networks = fieldnames(Petersen_Networks);

% Retrieve subjects using structural path
cd(structural_path);
subjs = dir();
regex = regexp({subjs.name},'Subj_*');
subjs = {subjs(~cellfun('isempty',regex)).name}.';

% Keep a used subject array
subjs_used = zeros(1, size(subjs, 1));
for s = 1:length(subjs)
    file_str = char(subjs(s));
    subjectID = file_str(6:end-4);
    subjs_used(s) = str2num(subjectID);
end

%%%%%%%%%%%%%%%%%%%%%%% Check subjects for NaNs first %%%%%%%%%%%%%%%%%%%%%%%

% Maintain list of NaN and missing functional subjects
nanlist = [];
missingFunctional = [];

% Loop over subjects
for s = 1:length(subjs)
    
    % Grab info for subject
    file_str = char(subjs(s));
    subjectID = file_str(6:end-4);
    
    % Get subject's data (Skip if missing functional data or subject is not averaged yet)
    try 
        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
    catch
        continue;
    end
    try
        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
    catch
        missingFunctional = [missingFunctional str2num(subjectID)];
        %fprintf('Subject %s is missing functional data. Skipping.\n', subjectID);
        continue;
    end
    
    % Check connectivity values for each pair, for NaNs
    for i = 1:264
        for j = 1:264
            % Skip diagonals
            if i == j
                continue;
            end
            val = mean_non_zero_avg(i, j);
            % If NaN is found, add subject to list if not added already
            if (isnan(val))
                if (ismember(str2num(subjectID), nanlist))
                    continue;
                end
                %fprintf('%s has a nan.\n', subjectID);
                nanlist = [nanlist str2num(subjectID)];
                continue;
            end
        end
    end
end
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%% Now process subjects excluding NaNs and incompletes %%%%%%%%%%%%

% Use volume connectivity values
if (strcmp(val_type, 'V'))
    switch nargin
        case 4
            % Internetwork Connectivities (two networks specified)
            if (strcmp(conn_type, 'amXY_wX_wY'))
                % Type: Across Mutual XY, w/in X, w/in Y

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2) + (sizeROI2*(sizeROI2-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = volume_non_zero_avg(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net1
                    for i = 1:(length(roiList1)-1)
                        for j = (i+1):length(roiList1)
                            connectivities(n) = volume_non_zero_avg(roiList1(i), roiList1(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net2
                    for i = 1:(length(roiList2)-1)
                        for j = (i+1):length(roiList2)
                            connectivities(n) = volume_non_zero_avg(roiList2(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'amXY_wX'))
                % Type: Across Mutual XY, w/in X

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = volume_non_zero_avg(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net1
                    for i = 1:(length(roiList1)-1)
                        for j = (i+1):length(roiList1)
                            connectivities(n) = volume_non_zero_avg(roiList1(i), roiList1(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'amXY_wY'))
                % Type: Across Mutual XY, w/in Y

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI2*(sizeROI2-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = volume_non_zero_avg(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net2
                    for i = 1:(length(roiList2)-1)
                        for j = (i+1):length(roiList2)
                            connectivities(n) = volume_non_zero_avg(roiList2(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'amXY'))
                % Type: Across Mutual XY

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = volume_non_zero_avg(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'aoXY_wX_wY'))
                % Type: Across One-Way XY, w/in X, w/in Y

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2) + (sizeROI2*(sizeROI2-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = volume_non_zero(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net1
                    for i = 1:(length(roiList1)-1)
                        for j = (i+1):length(roiList1)
                            connectivities(n) = volume_non_zero_avg(roiList1(i), roiList1(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net2
                    for i = 1:(length(roiList2)-1)
                        for j = (i+1):length(roiList2)
                            connectivities(n) = volume_non_zero_avg(roiList2(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'aoXY_wX'))
                % Type: Across One-Way XY, w/in X

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = volume_non_zero(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net1
                    for i = 1:(length(roiList1)-1)
                        for j = (i+1):length(roiList1)
                            connectivities(n) = volume_non_zero_avg(roiList1(i), roiList1(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'aoXY_wY'))
                % Type: Across One-Way XY, w/in Y

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI2*(sizeROI2-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = volume_non_zero(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net2
                    for i = 1:(length(roiList2)-1)
                        for j = (i+1):length(roiList2)
                            connectivities(n) = volume_non_zero_avg(roiList2(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'aoXY'))
                % Type: Across One-Way

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = volume_non_zero(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            else
                % Type is invalid
                fprintf('Invalid type: %s\n', conn_type);
                feature_set = struct;
            end

        case 3
            % Intranetwork Connectivities (only one network specified)
            if (strcmp(conn_type, 'wX'))
                % Type: w/in X

                % Find network specified
                found = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found = 1;
                        break;
                    end
                end
                if (found == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve network ROIs
                roiList = Petersen_Networks.(net1);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI = length(roiList);
                num_connections = (sizeROI*(sizeROI-1)/2); % Number of pairs of ROIs
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Within network
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:(length(roiList)-1)
                        for j = (i+1):length(roiList)
                            connectivities(n) = volume_non_zero_avg(roiList(i), roiList(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            else
                % Type is invalid
                fprintf('Invalid type: %s\n', conn_type);
                feature_set = struct;
            end

        otherwise
            % Invalid # of arguments
            fprintf('Invalid # of arguments.\n');
            feature_set = struct;
    end

% Use mean connectivity values
elseif (strcmp(val_type, 'M'))
    switch nargin
        case 4
            % Internetwork Connectivities (two networks specified)
            if (strcmp(conn_type, 'amXY_wX_wY'))
                % Type: Across Mutual XY, w/in X, w/in Y

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2) + (sizeROI2*(sizeROI2-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = mean_non_zero_avg(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net1
                    for i = 1:(length(roiList1)-1)
                        for j = (i+1):length(roiList1)
                            connectivities(n) = mean_non_zero_avg(roiList1(i), roiList1(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net2
                    for i = 1:(length(roiList2)-1)
                        for j = (i+1):length(roiList2)
                            connectivities(n) = mean_non_zero_avg(roiList2(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'amXY_wX'))
                % Type: Across Mutual XY, w/in X

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = mean_non_zero_avg(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net1
                    for i = 1:(length(roiList1)-1)
                        for j = (i+1):length(roiList1)
                            connectivities(n) = mean_non_zero_avg(roiList1(i), roiList1(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'amXY_wY'))
                % Type: Across Mutual XY, w/in Y

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI2*(sizeROI2-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = mean_non_zero_avg(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net2
                    for i = 1:(length(roiList2)-1)
                        for j = (i+1):length(roiList2)
                            connectivities(n) = mean_non_zero_avg(roiList2(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'amXY'))
                % Type: Across Mutual XY

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = mean_non_zero_avg(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'aoXY_wX_wY'))
                % Type: Across One-Way XY, w/in X, w/in Y

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2) + (sizeROI2*(sizeROI2-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = mean_non_zero(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net1
                    for i = 1:(length(roiList1)-1)
                        for j = (i+1):length(roiList1)
                            connectivities(n) = mean_non_zero_avg(roiList1(i), roiList1(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net2
                    for i = 1:(length(roiList2)-1)
                        for j = (i+1):length(roiList2)
                            connectivities(n) = mean_non_zero_avg(roiList2(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'aoXY_wX'))
                % Type: Across One-Way XY, w/in X

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = mean_non_zero(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net1
                    for i = 1:(length(roiList1)-1)
                        for j = (i+1):length(roiList1)
                            connectivities(n) = mean_non_zero_avg(roiList1(i), roiList1(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'aoXY_wY'))
                % Type: Across One-Way XY, w/in Y

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2) + (sizeROI2*(sizeROI2-1)/2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = mean_non_zero(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % ...Within net2
                    for i = 1:(length(roiList2)-1)
                        for j = (i+1):length(roiList2)
                            connectivities(n) = mean_non_zero_avg(roiList2(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            elseif (strcmp(conn_type, 'aoXY'))
                % Type: Across One-Way

                % Find networks specified
                found1 = 0;
                found2 = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found1 = 1;
                    elseif (strcmp(networks{net}, net2))
                        % Found network
                        found2 = 1;
                    end
                end
                if (found1 == 0 || found2 == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Network is a subset of the other
                if (strcmp(net1(1:end-2), net2) || strcmp(net2(1:end-2), net1))
                    fprintf('No network subsets allowed.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve networks' ROIs
                roiList1 = Petersen_Networks.(net1);
                roiList2 = Petersen_Networks.(net2);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI1 = length(roiList1);
                sizeROI2 = length(roiList2);
                num_connections = (sizeROI1 * sizeROI2);
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Across networks
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:length(roiList1)
                        for j = 1:length(roiList2)
                            connectivities(n) = mean_non_zero(roiList1(i), roiList2(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            else
                % Type is invalid
                fprintf('Invalid type: %s\n', conn_type);
                feature_set = struct;
            end

        case 3
            % Intranetwork Connectivities (only one network specified)
            if (strcmp(conn_type, 'wX'))
                % Type: w/in X

                % Find network specified
                found = 0;
                for net = 1:numel(networks)
                    if (strcmp(networks{net}, net1))
                        % Found network
                        found = 1;
                        break;
                    end
                end
                if (found == 0)
                    % Invalid network name
                    fprintf('Invalid network name.\n');
                    feature_set = struct;
                    return
                end

                % Retrieve network ROIs
                roiList = Petersen_Networks.(net1);

                % Initialize a matrix to hold pairwise connectivity values
                sizeROI = length(roiList);
                num_connections = (sizeROI*(sizeROI-1)/2); % Number of pairs of ROIs
                feature_set = zeros(num_connections, length(subjs));

                % For each subject
                for s = 1:length(subjs)

                    % Grab info for subject
                    file_str = char(subjs(s));
                    subjectID = file_str(6:end-4);

                    % Check if subject is part of NaN list. If so, skip.
                    if any(str2num(subjectID)==nanlist)
                        continue;
                    end
                    
                    % Check if subject is part of missing functional list. If so, skip.
                    if any(str2num(subjectID)==missingFunctional)
                        continue;
                    end

                    % Get subject's data
                    try
                        load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
                        load([structural_path 'Subj_' subjectID '.mat']);
                        load([functional_path subjectID '_Petersen_FC_Matrices.mat']);
                    catch
                        % Subject's data is partially missing. Skip.
                        continue;
                    end

                    % Find connectivity values for each pair...
                    % ...Within network
                    n = 1;
                    connectivities = zeros(num_connections, 1);
                    for i = 1:(length(roiList)-1)
                        for j = (i+1):length(roiList)
                            connectivities(n) = mean_non_zero_avg(roiList(i), roiList(j));
                            n = n + 1;
                        end
                    end

                    % Sort by descending order and set return value
                    feature_set(:, s) = sortrows(connectivities, -1);
                end

                % Remove subjects with incomplete data
                subjs_used(:, all(~feature_set,1)) = [];
                feature_set(:, all(~feature_set,1)) = [];

            else
                % Type is invalid
                fprintf('Invalid type: %s\n', conn_type);
                feature_set = struct;
            end

        otherwise
            % Invalid # of arguments
            fprintf('Invalid # of arguments.\n');
            feature_set = struct;
    end

else
    fprintf('Invalid val_type.\n');
    feature_set = struct;
end

end

