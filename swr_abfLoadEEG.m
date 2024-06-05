function EEG = swr_abfLoadEEG(filename,eegChannel,targetFS)
%% swr_abfLoadEEG loads and downsamples EEG data from an .abf file
% INPUTS:
%   filename - full path to a file in the directory containing abf file to be used
%   eegChannel - channel number of the EEG, typically 1. Also allowed is a 2-element vector. If given, this will produce a 2-element structure output, one for each of the 2 analog channels in the Intan RHD file(s)
%   targetFS - desired sampling frequency. This is useful for downsampling EEG data and making it easier to work with
% OUTPUTS:
%   EEG - a structure with following fields related to EEG signal:
%       data - actual values of EEG (in volts)
%       time - times corresponding to values in data field (in seconds)
%       tartgetFS - target sampling frequency specified by user (in samples/second)
%       finalFS - the sampling frequency ultimately used (in samples/second)
%
% Written by Scott Kilianski
% 5/2/2023

%% Set defaults as needed if not user-specific by inputs
if ~exist('eegChannel','var')
    eegChannel = 1; %default
end
if ~exist('targetFS','var') 
   targetFS = 200; %default
end

%% Load and properly format data
funClock = tic;     % function clock
[EEGdata, si] = abf2load(filename);
sample_rate = 1/(si*10^-6);
if iscell(EEGdata)
    EEGdata = cell2mat([EEGdata(1); EEGdata(2)]);
end
EEGtime = (0:size(EEGdata,1)-1)./sample_rate;

%% Downsample and format data
dsFactor = floor(sample_rate / targetFS);% downsampling factor to achieve targetFS
finalFS = sample_rate / dsFactor;   % calculate ultimate sampling frequency to be used
EEGdata = EEGdata(1:dsFactor:end,eegChannel); % downsample raw data 
EEGtime = double(EEGtime(1:dsFactor:end)); % create corresponding time vector

%% Create output structure and assign values to fields
EEG = struct('data',EEGdata,...
    'time',EEGtime',...
    'finalFS',finalFS);
fprintf('Loading data took %.2f seconds\n',toc(funClock));

end % function end