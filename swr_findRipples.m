%% --- Load in Data --- %%
HippFN = 'Z:\Scott\CopeColab\20240529_Ch14.abf';
CTXfn = 'Z:\Scott\CopeColab\20240529_Ch15.abf';
CTX = swr_abfLoadEEG(CTXfn,1,1000); % load cortical EEG
Hipp = swr_abfLoadEEG(HippFN,1,1000); % load hippocampus EEG
Fs = Hipp.finalFS; % sampling frequency (Hz)

% -- Sample only a specific portion of recording -- %
if 0% SET TO 1 AND CHANGE tRange VALUES TO SAMPLE PORTION OF RECORDING. SET TO 0 TO USE WHOLE RECORDING
    tRange = [2 4]; % in hours
    tInd = [tRange(1)*3600,(tRange(2)*3600)] * Fs;
    indRange = 1+tInd(1):tInd(2);
    CTX.data = CTX.data(indRange);
    CTX.time = CTX.time(indRange);
    Hipp.data = Hipp.data(indRange);
    Hipp.time = Hipp.time(indRange);
end

%% --- Set Parameters --- %%
durThreshTime = 0.015; % minimum ripple duration (in seconds)
sdet = 2; % Ripple envelope EDGE threshold (z-score)
sdP = 4; % Ripple envelope PEAK threshold (z-score)
swLag = 0.04; % largest acceptable gap between sharp wave trough and ripple start (seconds)
SWT = -2; % sharp wave-threshold (z-score)
noiseT = 2; % cortical noise threshold (z-score)
lfc_sw = 4; % Lower cutoff frequency for sharp waves (Hz)
ufc_sw = 40; % Upper cutoff frequency for sharp wave (Hz)
lfc_noise = 60; % Lower cutoff frequency for NOISE (Hz)
ufc_noise = 499; % Upper cutoff frequency for NOISE (Hz)
lfc_rip = 100; % Lower cutoff frequency for RIPPLES (Hz)
ufc_rip = 250; % Upper cutoff frequency for RIPPLES (Hz)

%% --- Filter traces in different frequency bands --- %%
% -- Sharp waves -- %
[b, a] = butter(3, [lfc_sw, ufc_sw]/(Fs/2), 'bandpass'); % Set filter coefficients for a 3rd order Butterworth filter
HippSW = filtfilt(b, a, Hipp.data); % Apply the filter using filtfilt

% -- Ripples -- %
[b, a] = butter(3, [lfc_rip, ufc_rip]/(Fs/2), 'bandpass'); % filter coefficients
HippRip = filtfilt(b, a, Hipp.data); % apply filter

% -- Noise -- %%
[b, a] = butter(3, [lfc_noise, ufc_noise]/(Fs/2), 'bandpass'); %3rd order butterworth filter
CTXnoise = filtfilt(b, a, CTX.data);

%% --- Compute ripple signal --- %%
% envSize = 2*Fs/lfc_rip;
% hippEnv = envelope(HippRip,envSize);
% noiseEnv = envelope(CTXnoise,envSize);
% rippEnv = zscore(hippEnv)-zscore(noiseEnv);
smoothWin = .008; % smoothing window
noiseWin = smoothdata(abs(zscore(CTXnoise)),1,'movmean',round(smoothWin*Fs)); % smoothed noise trace
noiseLog = noiseWin > noiseT; % find times of dense noise and store in logical vector
noiseInds = find(noiseLog); % get those indices of noisey samples
HippRip(noiseLog) = 0; % remove the noisey samples from the hippocampal trace
rectWin = smoothdata(abs(zscore(HippRip)),1,'movmean',round(smoothWin*Fs)); % smooth ripple power trace
rippSig = rectWin;%-noiseWin; 

%% --- Find slow wave troughs --- %%
zHippSW = zscore(HippSW);
tlog = zHippSW<SWT;
plog = false(size(tlog));
[PKS, LOCS] = findpeaks(-zHippSW);
plog(LOCS) = true;
ptLog = tlog & plog;
SWinds = find(ptLog);
SWtimes = Hipp.time(SWinds);
SWtroughs = zHippSW(SWinds);
SWlog = false(size(Hipp.time));
swtInterp = interp1(SWtimes,SWtimes,Hipp.time,'nearest','extrap');
ctSWt = find(abs(Hipp.time-swtInterp) <= swLag);

%% --- Find putative ripples --- %%
riseI = find(diff(rippSig>sdet)>0)+1;
fallI = find(diff(rippSig>sdet)<0)+1;

% Remove incomplete events, potentially at start and end of recording
% Checks that riseI(1) starts BEFORE fallI(1)
% and that riseI(end) has a correspondonig fallI(end)
if fallI(1) < riseI(1)
    fallI(1) = [];
end
if riseI(end) > fallI(end)
    riseI(end) = [];
end
putRips = [riseI,fallI]; % putative ripple start and end indices

% Remove potential ripples that are too short
durThreshSamps = Fs*durThreshTime;
rmLog = diff(putRips,1,2)<durThreshSamps;
putRips(rmLog,:) = [];

% PTtcI = find(rippEnv>sdP); % peak threshold indices
PTtcI = find(rippSig>sdP); % peak threshold indices
nopeLog = false(size(putRips,1),3); % logical vector storing ripples to remove b/c no peak threshold crossing

% Check for peak threshold crossing
fprintf('Found %d putative ripples!\n',size(putRips,1));
fprintf('Checking for peak threshold crossing, coincidence with sharp waves, and performing noise rejection...\n');
ripClock = tic;
for pri = 1:size(putRips,1)
    if ~mod(pri,1000)
        fprintf('%d ripples took %.2f seconds...\n',pri,toc(ripClock));
    end
    nopeLog(pri,1) = ~any(ismember(putRips(pri,1):putRips(pri,2),PTtcI));     % check for crossing peak threshold
    nopeLog(pri,2) = any(ismember(putRips(pri,1):putRips(pri,2),noiseInds));  % check for noise violation
    nopeLog(pri,3) = ~any(ismember(putRips(pri,1):putRips(pri,2),ctSWt));     % check for proximity to sharp wave trough
end

nopeLog = nopeLog(:,1) | nopeLog(:,2) | nopeLog(:,3);
putRips(nopeLog,:) = []; % remove ripples with no peak threshold crossings


%% --- Putative Ripple Merging --- %%
fprintf('Merging ripples if/when appropriate...\n')
minRipInt = round(durThreshTime*Fs); % minimum interval between ripples (converted to # samples)
pzInts = putRips(2:end,1)-putRips(1:end-1,2); % intervals between putative ripples
tmInd = find(pzInts<minRipInt,1,'first'); % index of 1st putative ripple pair to be merged

while tmInd % if putative seizures to merge, do it, then check for more
    putRips(tmInd,2) = putRips(tmInd+1,2); % replace the end time
    putRips(tmInd+1,:) = []; % remove 2nd putative seizure in the pair
    pzInts = putRips(2:end,1)-putRips(1:end-1,2); % intervals between putative seizures
    tmInd = find(pzInts<minRipInt,1,'first'); % index of 1st putative ripple pair to be merged
end

ripTimes = Hipp.time(putRips);

%% --- Store output in structure --- %%
rip.SWT = SWT;
rip.CTX = CTX.data;
rip.time = Hipp.time;
rip.Hipp = Hipp.data;
rip.FS = Fs;
rip.noiseT = noiseT;
rip.HFnoise = noiseWin;
rip.ripInds = putRips;
rip.rippSig = rippSig;
rip.hippRip = HippRip;
rip.ripET =sdet;
rip.ripPT = sdP;
rip.hippSW = HippSW;
fprintf('Found %d ripples!\n',size(rip.ripInds,1))
RPM = size(rip.ripInds,1)/((Hipp.time(end)-Hipp.time(1))/60);
fprintf('%.2f ripples per minute\n',RPM)
% [~, fd] = fileparts(ffp{ii});
% dn = 'Z:\Scott\CopeColab\';
% fnn = sprintf('%s%s_Ch%dRips.mat',dn,fd,ch{ii,jj}(1));
% save(fnn,'rip','-v7.3')