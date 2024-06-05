%% --- Set up figure --- %%
ripFig = figure;
% zHF = zscore(rip.);
zSW = zscore(rip.hippSW);
zRip = rip.rippSig;

% Subplot #1: Raw Hippocampal LFP
sax(1) = subplot(5,1,1);
hippLFP = plot(0); % raw hippocampal LFP trace
figttl = title('');

% Subplot #2: Ripple-filtered Hippocampal LFP
sax(2) = subplot(5,1,2);
ripTrace = plot(0); % Ripple filtered LFP trace
hold on
ripPK = plot([rip.time(1), rip.time(end)],[rip.ripPT, rip.ripPT],'r'); % ripple peak threshold
ripBott = plot([rip.time(1), rip.time(end)],[rip.ripET, rip.ripET],'r'); % ripple power lower threshold
hold off
title('Ripple Signal');

% Subplot #3: Sharp wave-filtered Hippocampal LFP
sax(3) = subplot(5,1,3);
SWtrace = plot(0); % sharp wave filtered LFP tace
hold on
SWT = plot([rip.time(1), rip.time(end)],[rip.SWT, rip.SWT],'r'); % Sharp wave threshold
hold off
title('Hippocampal Sharp Waves')

% Subplot #4: High Frequency Power (Noise) in Cortex
sax(4) = subplot(5,1,4);
HFpower = plot(0); % HF power trace
% hold on
% NT = plot([rip.time(1), rip.time(end)],[rip.NT, rip.NT],'r'); % noise threshold
% hold off
title('Cortical noise signal')

% Subplot #5: Somatosensory ECoG
sax(5) = subplot(5,1,5);
ssecog = plot(0);
title('Raw Cortical LFP')

linkaxes(sax,'x');
rii = 1; % set the ripple index for viewing in section below
numRipsToInspect = 100;
if size(rip.ripInds,1) < numRipsToInspect
    numRipsToInspect = size(rip.ripInds,1);
end
ripList = randperm(length(rip.ripInds),numRipsToInspect);
ripLabels = nan(length(rip.ripInds),1);

hwsSec = 5;  % window size in seconds
halfWinSize = round(hwsSec/2*rip.FS); % in samples/indices (i.e. real positive integer value)

%% --- Label randomly selected ripples --- %%
for rii = 1:numRipsToInspect
    ripn = ripList(rii);
    tInds = (rip.ripInds(ripn,1)-halfWinSize):(rip.ripInds(ripn,1)+halfWinSize);
    xd = rip.time(tInds);

    % -- Update plots -- %
    set(hippLFP,'XData',xd,'YData',rip.Hipp(tInds));
    set(ripTrace,'XData',xd,'YData',zRip(tInds));
    set(SWtrace,'XData',xd,'YData',zSW(tInds));
    set(HFpower,'XData',xd,'YData',rip.HFnoise(tInds));
    set(ssecog,'XData',xd,'YData',rip.CTX(tInds));
    set(sax,'XLim', [xd(1), xd(end)])
    set(figttl,'String',sprintf('Ripple %d of %d (#%d)', ...
        rii,numRipsToInspect,ripn))

    % -- Get and store user label -- %
    loopstate = 0;
while ~loopstate 
    bb = waitforbuttonpress; % wait for click or keyboard button
    if bb % if a keyboard button is pressed
        key= get(gcf,'CurrentKey');
        switch key
            case '1'
                ripLabels(rii) = 1; loopstate = 1;
            case 'numpad1'
                    ripLabels(rii) = 1; loopstate = 1;
            case '0' 
                ripLabels(rii) = 0; loopstate = 1;
            case 'numpad0'
                ripLabels(rii) = 0; loopstate = 1;
        end
    end
end

end
percGood = 100*nansum(ripLabels)/numRipsToInspect;
fprintf('%.0f%% ripples labeled good \n',percGood)
close(ripFig)
