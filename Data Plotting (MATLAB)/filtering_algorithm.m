clear; clc; close all;

%% thresholds
filename = 'daily_log.csv';
trial = 1; % trial block (1, 2, 3)
dataType = 'No Warning'; % 'Severe', 'Mild', or 'No Warning'

freqBand = [20 80];  %grinding band (HZ)
shortDur = 0.25;
longDur = 1.5;
threshMult = 2;
baselinePct = 8;
mergeGap = 0.1;
minDutyCycle = 0.6;
minSpectralFlatness = 0.4;
minCorroboratingBursts = 2;

%% load data
raw = readmatrix(filename, 'NumHeaderLines', 2);

t = raw(:,2);   % Time (s) is always column B

% data layout: A = Sample#, B = Time, then repeating 4-col blocks per trial (Severe, Mild, No Warning, blank column), starting at column C
typeOffset = struct('Severe', 0, 'Mild', 1, 'NoWarning', 2);
typeKey = strrep(dataType, ' ', '');
col = 3 + (trial - 1) * 4 + typeOffset.(typeKey);
data = raw(:, col);

validRows = ~isnan(t) & ~isnan(data); % drop blank/incomplete rows
t = t(validRows);
data = data(validRows);

Fs = round(1 / mean(diff(t)));
N  = numel(data);
fprintf('Trial %d, Column: %s\n', trial, dataType);
fprintf('Loaded %d samples at %d Hz (%.1f s of data)\n', N, Fs, t(end)-t(1));

%% clean up signal
data = double(data) - mean(data); % remove DC offset
data = detrend(data); % remove slow drift

%% frequency domain estimate for display
winLen = min(4096, 2^floor(log2(N/8))); % adapt to trial length
noverlap = round(winLen/2);
nfft = winLen;
[PxxWelch, fWelch] = welchPSD(data, winLen, noverlap, nfft, Fs);

dbOffset = 15; % shift the whole curve up by 15 dB
pxx_dB_display = 10*log10(PxxWelch + eps) + dbOffset;

%% bandpass via FFT bin zeroing
Y = fft(data);
freqAxisFull = (0:N-1) * (Fs / N);
inBand = (freqAxisFull >= freqBand(1) & freqAxisFull <= freqBand(2)) | (freqAxisFull >= (Fs - freqBand(2)) & freqAxisFull <= (Fs - freqBand(1)));
Yband = Y;
Yband(~inBand) = 0;
bandSignal = real(ifft(Yband));

%% burst detection on raw broadband envelope
winSize  = round(0.05 * Fs);
envelope = sqrt(movmean(data.^2, winSize));

% baseline --> quietest baselinePct percent
sortedEnv = sort(envelope);
pctIdx = max(1, round((baselinePct/100) * numel(sortedEnv)));
baseline  = sortedEnv(pctIdx);
threshold = baseline * threshMult;
active = envelope > threshold;
rawActive = active(:);   % keep pre-merge version for duty cycle later

% bridge short gaps between active stretches
gapSamples = round(mergeGap * Fs);
[gapStarts, gapStops] = findRuns(~active); % runs of "not active"
for k = 1:numel(gapStarts)
    if (gapStops(k) - gapStarts(k) + 1) <= gapSamples
        active(gapStarts(k):gapStops(k)) = true; % fill small gap
    end
end

% locate active stretches; keep only genuinely active
[starts, stops] = findRuns(active);
durations = (stops - starts + 1) / Fs;

dutyCycle = zeros(size(durations));
flatness = zeros(size(durations));
for k = 1:numel(starts)
    dutyCycle(k) = sum(rawActive(starts(k):stops(k))) / (stops(k) - starts(k) + 1);

    % spectral flatness (geo mean / arith mean of power spectrum)
    % near 1 = broadband (grinding), near 0 = tonal (voiced speech)
    seg = data(starts(k):stops(k));
    if numel(seg) >= 8
        Pseg = abs(fft(seg)).^2;
        Pseg = Pseg(2:floor(numel(Pseg)/2)) + eps;
        flatness(k) = exp(mean(log(Pseg))) / mean(Pseg);
    else
        flatness(k) = 0;   % too short to trust
    end
end

validBurst = (dutyCycle >= minDutyCycle) & (flatness >= minSpectralFlatness);

% printout of every candidate burst, pass or fail.
fprintf('\n Burst candidates (before filters)\n');
for k = 1:numel(starts)
    passFail = 'FAIL';
    if validBurst(k)
        passFail = 'PASS';
    end
    fprintf('  Burst %2d: duration = %.3f s, duty cycle = %.0f%%, flatness = %.2f [%s]\n', ...
        k, durations(k), dutyCycle(k)*100, flatness(k), passFail);
end
if isempty(starts)
    fprintf('  (none found)\n');
end

durations = durations(validBurst);
if isempty(durations)
    longestBurst = 0;
else
    longestBurst = max(durations);
end

% count qualifying bursts per tier
mildEligible = durations(durations >= shortDur); %include severe-length
severeEligible = durations(durations > longDur);
numMildEligible = numel(mildEligible);
numSevereEligible = numel(severeEligible);

fprintf('Bursts clearing Mild-length floor (%.2fs+): %d | clearing Severe-length floor (%.2fs+): %d\n', shortDur, numMildEligible, longDur, numSevereEligible);
fprintf('Baseline (quietest %d%% of envelope): %.2f | Threshold (%gx): %.2f\n', ...
    baselinePct, baseline, threshMult, threshold);
fprintf('Total active time in band: %.1f s (%.0f%% of recording)\n', sum(active)/Fs, 100*sum(active)/numel(active));

%% decide warning level
if numSevereEligible >= minCorroboratingBursts
    warningLevel = 'Severe Warning';
elseif numMildEligible >= minCorroboratingBursts
    warningLevel = 'Mild Warning';
else
    warningLevel = 'No Warning';
end

fprintf('\nLongest continuous grinding-band activity: %.2f s\n', longestBurst);
fprintf('==> %s\n\n', upper(warningLevel));

%% plot (time domain top, frequency domain bottom)
fig = figure('Color', 'white');

subplot(2,1,1);
plot(t, data, 'Color', [0.6 0.6 0.6]);
hold on;
plot(t, bandSignal, 'Color', [0.30 0.60 1.00], 'LineWidth', 1.2);
xlabel('Time (s)', 'Color', 'black');
ylabel('Amplitude', 'Color', 'black');
title('Time Domain', 'Color', 'black');
legend('Raw signal', sprintf('%d-%d Hz band', freqBand(1), freqBand(2)), ...
    'TextColor', 'black', 'Color', 'white');
grid on;
styleAxesLight(gca);

subplot(2,1,2);
plot(fWelch, pxx_dB_display, 'Color', [0.30 0.60 1.00], 'LineWidth', 1.2);
hold on;
xline(freqBand(1), '--', 'Color', [1 0.3 0.3]);
xline(freqBand(2), '--', 'Color', [1 0.3 0.3]);
xlim([0 1000]);
ylim([-2 22]);              % Fixed y-axis range
xlabel('Frequency (Hz)', 'Color', 'black');
ylabel('Decibels (dB)', 'Color', 'black');
title('Frequency Domain', 'Color', 'black');
grid on;
styleAxesLight(gca);

%% Welch's method
function [Pxx, f] = welchPSD(x, winLen, noverlap, nfft, Fs)
    x = x(:);
    n = (0:winLen-1)';
    win = 0.54 - 0.46*cos(2*pi*n/(winLen-1));  % Hamming window
    U = sum(win.^2);

    step = winLen - noverlap;
    numSegs = floor((length(x) - winLen)/step) + 1;
    assert(numSegs >= 1, 'Signal is shorter than the analysis window (%d samples).', winLen);

    halfN = nfft/2 + 1;
    Pxx = zeros(halfN, 1);
    for k = 1:numSegs
        idx = (k-1)*step + (1:winLen);
        seg = x(idx) .* win;
        X = fft(seg, nfft);
        Xh = X(1:halfN);
        Pk = (abs(Xh).^2) / (Fs*U);
        Pk(2:end-1) = 2*Pk(2:end-1);
        Pxx = Pxx + Pk;
    end
    Pxx = Pxx / numSegs;
    f = (0:halfN-1)' * (Fs/nfft);
end

% find start/stop indices of each run of "true" in a logical vector
function [starts, stops] = findRuns(vec)
    vec = vec(:);
    edges = diff([0; vec; 0]);
    starts = find(edges == 1);
    stops  = find(edges == -1) - 1;
end

% white background, black text/axes (used for both subplots)
function styleAxesLight(ax)
    set(ax, 'Color', 'white', 'XColor', 'black', 'YColor', 'black');
end
