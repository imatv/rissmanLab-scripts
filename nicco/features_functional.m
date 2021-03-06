function [subjs_used, feature_set] = features_functional(conn_type, net1, net2)
%
%==========================================================================================
% features_functional.m
%
% Take in network name(s), and a type of relation (specified in "Connectivities Naming.xlsx").
%
% Creates a feature set containing functional connectivity values ranked in descending order
% for each network or network pair. This is done for every subject.
%
% Resulting matrix has functional connectivity values as rows and subjects as columns.
%
% Type of feature set must be specified.
% Allowed types are:
%   wX, amXY_wX_wY, amXY_wX, amXY_wY, amXY
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
%
% Functional data does not change with respect to direction (so one-way is not needed).
% Functional data does not use volumetric values either (so val_type is not needed).
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
% Functional data is located at:
% ~/Nicco/HCP_ALL/Resting_State/Petersen_FC/{SubjectID}_Petersen_FC_Matrices.mat
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

% Retrieve subjects using structural average path
cd(structural_avg_path);
subjs = dir();
regex = regexp({subjs.name},'Subj_*');
subjs = {subjs(~cellfun('isempty',regex)).name}.';

% Keep a used subject array
subjs_used = zeros(1, size(subjs, 1));
for s = 1:length(subjs)
    file_str = char(subjs(s));
    subjectID = file_str(6:end-8);
    subjs_used(1, s) = str2num(subjectID);
end

%%%%%%%%%%%%%%%%%%%%%%% Check subjects for NaNs first %%%%%%%%%%%%%%%%%%%%%%%

% Maintain list of NaN and missing functional subjects
nanlist = [];
missingFunctional = [];

% Loop over subjects
for s = 1:length(subjs)
    
    % Grab info for subject
    file_str = char(subjs(s));
    subjectID = file_str(6:end-8);
    
    % Get subject's data (Skip if missing functional data)
    load([structural_avg_path 'Subj_' subjectID '_avg.mat']);
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

switch nargin
    case 3
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
            
            % Find size values
            sizeROI1 = length(roiList1);
            sizeROI2 = length(roiList2);
            num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2) + (sizeROI2*(sizeROI2-1)/2);
            
            % Initialize a matrix to hold pairwise connectivity values
            feature_set = zeros(num_connections, length(subjs));
            
            % For each subject
            for s = 1:length(subjs)
                
                % Grab info for subject
                file_str = char(subjs(s));
                subjectID = file_str(6:end-8);
                
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
                connectivities = zeros(num_connections, 3);
                for i = 1:length(roiList1)
                    for j = 1:length(roiList2)
                        connectivities(n, 1) = roiList1(i);
                        connectivities(n, 2) = roiList2(j);
                        connectivities(n, 3) = FC_Matrix(roiList1(i), roiList2(j));
                        n = n + 1;
                    end
                end
                
                % ...Within net1
                for i = 1:(length(roiList1)-1)
                    for j = (i+1):length(roiList1)
                        connectivities(n, 1) = roiList1(i);
                        connectivities(n, 2) = roiList1(j);
                        connectivities(n, 3) = FC_Matrix(roiList1(i), roiList1(j));
                        n = n + 1;
                    end
                end
                
                % ...Within net2
                for i = 1:(length(roiList2)-1)
                    for j = (i+1):length(roiList2)
                        connectivities(n, 1) = roiList2(i);
                        connectivities(n, 2) = roiList2(j);
                        connectivities(n, 3) = FC_Matrix(roiList2(i), roiList2(j));
                        n = n + 1;
                    end
                end
                
                % Sort by descending order and set return value
                functional_sorted = sortrows(connectivities, -3);
                
                % Move results to feature set
                feature_set(:, s) = functional_sorted(:, 3);
                
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
            
            % Find size values
            sizeROI1 = length(roiList1);
            sizeROI2 = length(roiList2);
            num_connections = (sizeROI1 * sizeROI2) + (sizeROI1*(sizeROI1-1)/2);
            
            % Initialize a matrix to hold pairwise connectivity values
            feature_set = zeros(num_connections, length(subjs));
            
            % For each subject
            for s = 1:length(subjs)
                
                % Grab info for subject
                file_str = char(subjs(s));
                subjectID = file_str(6:end-8);
                
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
                connectivities = zeros(num_connections, 3);
                for i = 1:length(roiList1)
                    for j = 1:length(roiList2)
                        connectivities(n, 1) = roiList1(i);
                        connectivities(n, 2) = roiList2(j);
                        connectivities(n, 3) = FC_Matrix(roiList1(i), roiList2(j));
                        n = n + 1;
                    end
                end
                
                % ...Within net1
                for i = 1:(length(roiList1)-1)
                    for j = (i+1):length(roiList1)
                        connectivities(n, 1) = roiList1(i);
                        connectivities(n, 2) = roiList1(j);
                        connectivities(n, 3) = FC_Matrix(roiList1(i), roiList1(j));
                        n = n + 1;
                    end
                end
                
                % Sort by descending order and set return value
                functional_sorted = sortrows(connectivities, -3);

                % Move results to feature set
                feature_set(:, s) = functional_sorted(:, 3);
                
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
            
            % Find size values
            sizeROI1 = length(roiList1);
            sizeROI2 = length(roiList2);
            num_connections = (sizeROI1 * sizeROI2) + (sizeROI2*(sizeROI2-1)/2);
            
            % Initialize a matrix to hold pairwise connectivity values
            feature_set = zeros(num_connections, length(subjs));
            
            % For each subject
            for s = 1:length(subjs)
                
                % Grab info for subject
                file_str = char(subjs(s));
                subjectID = file_str(6:end-8);
                
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
                connectivities = zeros(num_connections, 3);
                for i = 1:length(roiList1)
                    for j = 1:length(roiList2)
                        connectivities(n, 1) = roiList1(i);
                        connectivities(n, 2) = roiList2(j);
                        connectivities(n, 3) = FC_Matrix(roiList1(i), roiList2(j));
                        n = n + 1;
                    end
                end
                
                % ...Within net2
                for i = 1:(length(roiList2)-1)
                    for j = (i+1):length(roiList2)
                        connectivities(n, 1) = roiList2(i);
                        connectivities(n, 2) = roiList2(j);
                        connectivities(n, 3) = FC_Matrix(roiList2(i), roiList2(j));
                        n = n + 1;
                    end
                end
                
                % Sort by descending order and set return value
                functional_sorted = sortrows(connectivities, -3);

                % Move results to feature set
                feature_set(:, s) = functional_sorted(:, 3);
                
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
            
            % Find size values
            sizeROI1 = length(roiList1);
            sizeROI2 = length(roiList2);
            num_connections = (sizeROI1 * sizeROI2);
            
            % Initialize a matrix to hold pairwise connectivity values
            feature_set = zeros(num_connections, length(subjs));
            
            % For each subject
            for s = 1:length(subjs)
                
                % Grab info for subject
                file_str = char(subjs(s));
                subjectID = file_str(6:end-8);
                
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
                connectivities = zeros(num_connections, 3);
                for i = 1:length(roiList1)
                    for j = 1:length(roiList2)
                        connectivities(n, 1) = roiList1(i);
                        connectivities(n, 2) = roiList2(j);
                        connectivities(n, 3) = FC_Matrix(roiList1(i), roiList2(j));
                        n = n + 1;
                    end
                end
                
                % Sort by descending order and set return value
                functional_sorted = sortrows(connectivities, -3);

                % Move results to feature set
                feature_set(:, s) = functional_sorted(:, 3);
                
            end
            
            % Remove subjects with incomplete data
            subjs_used(:, all(~feature_set,1)) = [];
            feature_set(:, all(~feature_set,1)) = [];
            
        elseif (strcmp(conn_type, 'aoXY_wX_wY'))
            % Type: Across One-Way XY, w/in X, w/in Y
            fprintf('Functional does not support: %s\n', conn_type);
            feature_set = struct;
        elseif (strcmp(conn_type, 'aoXY_wX'))
            % Type: Across One-Way XY, w/in X
            fprintf('Functional does not support: %s\n', conn_type);
            feature_set = struct;
        elseif (strcmp(conn_type, 'aoXY_wY'))
            % Type: Across One-Way XY, w/in Y
            fprintf('Functional does not support: %s\n', conn_type);
            feature_set = struct;
        elseif (strcmp(conn_type, 'aoXY'))
            % Type: Across One-Way
            fprintf('Functional does not support: %s\n', conn_type);
            feature_set = struct;
        else
            % Type is invalid
            fprintf('Functional does not support: %s\n', conn_type);
            feature_set = struct;
        end
        
    case 2
        % Intranetwork Connectivities (only one network specified)
        if (strcmp(conn_type, 'wX'))
            % Type: w/in X
            
            % Find networks specified
            found1 = 0;
            for net = 1:numel(networks)
                if (strcmp(networks{net}, net1))
                    % Found network
                    found1 = 1;
                end
            end
            if (found1 == 0)
                % Invalid network name
                fprintf('Invalid network name.\n');
                feature_set = struct;
                return
            end
            
            % Retrieve networks' ROIs
            roiList1 = Petersen_Networks.(net1);
            
            % Find size values
            sizeROI1 = length(roiList1);
            num_connections = (sizeROI1*(sizeROI1-1)/2);
            
            % Initialize a matrix to hold pairwise connectivity values
            feature_set = zeros(num_connections, length(subjs));
            
            % For each subject
            for s = 1:length(subjs)
                
                % Grab info for subject
                file_str = char(subjs(s));
                subjectID = file_str(6:end-8);
                
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
                connectivities = zeros(num_connections, 3);
                
                % ...Within net1
                for i = 1:(length(roiList1)-1)
                    for j = (i+1):length(roiList1)
                        connectivities(n, 1) = roiList1(i);
                        connectivities(n, 2) = roiList1(j);
                        connectivities(n, 3) = FC_Matrix(roiList1(i), roiList1(j));
                        n = n + 1;
                    end
                end
                
                % Sort by descending order and set return value
                functional_sorted = sortrows(connectivities, -3);

                % Move results to feature set
                feature_set(:, s) = functional_sorted(:, 3);
                
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

end

