%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 91.427/545 Machine Learning
% Mike Stowell, Anthony Salani, Misael Moscat
%
% mainDriver.m
% This file will load the movies, perform learning, and output the top
% movie recommendations for a given user.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; close all; clear;

% flags for using a test set, prediction truncation, SVD,
% and mean normalization
use_test = 1;
use_pred_trunc = 1;
use_svd = 0;
use_mean_norm = 1;

% initialize the number of features to use, regularization parameter,
% and number of iterations to train with
num_features = 50;
lambda       = 10;
iterations   = 40;

% data matrix and movie title file locations
f_movie_matrix = 'data/movies.mat'; %test.mat
f_movie_titles = 'data/movie_titles.txt';%'data/movies.lookup';

% load in movie rating data
plush('\nLoading movie rating data...\n');

% this will load a matrix Y containing movie ratings where the rows
% are movies and columns are users
load(f_movie_matrix);
plush('...complete.\n\n');

% load in movie titles
plush('Matching movie IDs to titles...\n');
map_id_name = loadMovieIDNameMap(f_movie_titles);
plush('...complete.\n\n');

clear f_movie_matrix;
clear f_movie_titles;

% add a new user's ratings to the system
%new_ratings = zeros(size(Y, 1), 1);
%new_ratings(1)   = 4;
%new_ratings(7)   = 3;
%new_ratings(12)  = 5;
%new_ratings(54)  = 4;
%new_ratings(64)  = 5;
%new_ratings(66)  = 3;
%new_ratings(69)  = 5;
%new_ratings(98)  = 2;
%new_ratings(183) = 4;
%new_ratings(226) = 5;
%new_ratings(355) = 5;
%
%plush('You rated:\n');
%for i = 1 : length(new_ratings)
%    if (new_ratings(i) > 0)
%        fprintf('\t%.1f for %s\n', ...
%                new_ratings(i), map_id_name{i});
%    end
%end

% add the new ratings to the data
%Y = [new_ratings Y];
plush('');

% generate a test set - ratings are removed from 1:num_test_users
% in the Y matrix, and Y_test contains the original ratings for
% num_test_users users
if (use_test > 0)
  plush('Generating test set...\n');
  compar_Y = Y(1,1:20);

  percent_in_test_set    = .2;
  percent_ratings_remove = .5;
  fprintf('\tPercent data in test set:  %d%%\n', ...
          percent_in_test_set * 100);
  fprintf('\tPercent ratings extracted: %d%%\n', ...
          percent_ratings_remove * 100);
  plush('');

  [Y, Y_test] = genTestSet(Y, percent_in_test_set, percent_ratings_remove);
  num_test_users = size(Y_test, 2);
  plush('...complete.\n\n');
end

% Reduce dimensionality using SVD
if (use_svd == 1)
  plush('Dimensionality reduction with SVD...\n');
  [Y_reduced, U_reduce] = svdReduce(Y);
  plush('...complete.\n\n');
else
  Y_reduced = Y;
end

% map R(i,j) to 1 if Y_reduced(i,j) is > 0, and 0 otherwise
R = logical(Y_reduced > 0);

% perform mean normalization
if (use_mean_norm == 1)
  plush('Applying mean normalization...\n');
  [Y_norm, Y_mean] = meanNormData(Y_reduced, R);
  plush('...complete.\n\n');
else
  Y_norm = Y_reduced;
end

plush('Hyperparameters:\n');
printf('\tFeature count: %d\n', num_features);
printf('\tLambda:        %d\n', lambda);
printf('\tIterations:    %d\n', iterations);
plush('\n');

% number of movies are rows, number of users are columns
[num_movies, num_users] = size(Y_norm);
clear Y_reduced;

% randomly initialize X and Theta to small values for collab. filtering
X = randn(num_movies, num_features);
Theta = randn(num_users, num_features);

% fold the parameters into a single row vector
params = [X(:); Theta(:)];
clear X;
clear Theta;

% use collaborative filtering to train the model on the movie rating data
plush('Training the collaborative filtering model...\n');

%%%%% TODO - why does training on Y_norm and adding back Y_mean
%%%%%      - only recommend the best rated movies?
%%%%% - answer: because Y_mean = 5 when only 1 user rated 1
%%%%% -         movie a 5.

%%%%% TODO - maybe we weight each rating by the number of users
%%%%%      - that rated that movie

% set options for fmincg (including iterations) and run the training
%%%%% TODO - report stats on training on Y vs Y_norm
t_start = time();  %%%%% TODO - try fminunc with TolFun
options = optimset('GradObj', 'on', 'MaxIter', iterations);
[params, costJ] = fmincg (@(t)(collabFilter(t, Y_norm, R, num_users, ...
                                  num_movies, num_features, lambda)), ...
                          params, options);
t_end = time();
t_total = t_end - t_start;
fprintf('Training took %d seconds.\n', t_total);

clear Y_norm;
clear R;

% unfold the returned values
X = reshape(params(1:num_movies * num_features), num_movies, num_features);
Theta = reshape(params(num_movies * num_features + 1:end), ...
                num_users, num_features);
plush('...complete.\n\n');
clear params;

% get the recommendation matrix
recom_matrix = X * Theta';
%recom_matrix = recom_matrix .+ 1; <-- do not do this

if (use_mean_norm == 1)
  % recover data from mean normalization
  recom_matrix = bsxfun(@plus, recom_matrix, Y_mean);
  clear Y_mean;
end

% Reconstruct approximation of original matrix after training
if (use_svd == 1)
  recom_matrix = svdReconstruct(recom_matrix, U_reduce);
  clear U_reduce;
end

clear X;
clear Theta;

if (use_pred_trunc == 1)
  % Perform predication truncation by normalizing the ratings to 1-5 per user
  plush('Performing prediction truncation...\n');

  recom_matrix = bsxfun(@minus, recom_matrix, min(recom_matrix));
  recom_matrix = bsxfun(@times, recom_matrix, ...
                        bsxfun(@rdivide, 4, ...
                               (max(recom_matrix) - min(recom_matrix))));
  recom_matrix = recom_matrix + 1;

  plush('...complete.\n\n');
end

% make a prediction for the user
%pred = recom_matrix(:,1);% + Y_mean;
%clear Y_mean;

% sort the vector to get the highest rating movies first
%[tmp, ix] = sort(pred, 'descend');
%clear tmp;

% print top 10 recommendations
%plush('Our top 10 recommendations for you:\n');
%for i = 1 : 10
%    j = ix(i);
%    % skip movies that the user already watched
%    %if (new_ratings(j) > 0)
%    %   i = i - 1;
%    %   continue;
%    %end
%    fprintf('\t%.1f for %s\n', pred(j), map_id_name{j});
%end

clear map_id_name;
%clear new_ratings;

% map R(i,j) to 1 if Y(i,j) is > 0, and 0 otherwise
R = logical(Y > 0);


%%%% TODO - what if we rounded Y and recom_matrix?
% get root-mean-squared-deviation error in comparison
if (use_test > 0)
    plush('\nGenerating RMSD training error: ');
    rmse = rootMeanSqErr(Y, recom_matrix, R);
    printf("%.4f", rmse);
    plush('\nGenerating RMSD test error:     ');
    rmse = rootMeanSqErr(Y_test, recom_matrix(:, 1:num_test_users), ...
                         R(:, 1:num_test_users));
    clear Y_test;
    printf("%.4f\n", rmse);
else
    plush('\nGenerating RMSD error:          ');
    rmse = rootMeanSqErr(Y, recom_matrix, R);
    printf("%.4f\n", rmse);
end
printf("Netflix 2006 RMSD error:        0.9525\n");
plush('\n');

if (use_test == 1)
  plush('Comparison: Y vs. recommendations:\n');
  compar_Y
  compar_rec = round(recom_matrix(1,1:20));
  compar_rec
  plush('\n');
end

clear R;

% plot the cost by iterations using the plotCost function
info.iterations = iterations;
info.costJ = costJ;
info.num_features = num_features;
info.lambda = lambda;
info.rmse = rmse;
info.t_total = t_total;
plotCost(info);
