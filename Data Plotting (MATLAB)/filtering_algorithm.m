%% bruxism_warning_simple.m
% Reads daily_log.csv, analyzes one selected Trial+Type column, prints a
% 3-level warning (No Warning / Mild / Severe). Base MATLAB only.

clear; clc; close all;

%% ---- Settings ----
filename    = 'daily_log.csv';
trial       = 1;          % trial block (1, 2, 3)
dataType    = 'No Warning';     % 'Severe', 'Mild', or 'No Warning'

freqBand    = [20 80];      % Hz, grinding band -- from silence-condition FFT peak cluster
shortDur    = 0.25;          % s, below this = noise (ignore)
longDur     = 1.5;           % s, above this = SEVERE (clinical phasic/tonic cutoff, Lavigne et al.)
threshMult  = 2;             % burst = envelope > threshMult x quiet baseline
baselinePct = 8;            % baseline = quietest 10% of envelope (median fails for nonstop grinding)
mergeGap    = 0.1;          % s, gaps shorter than this get bridged into one stretch
minDutyCycle = 0.6;          % bridged stretch must be actively active this fraction of its span
                             % (filters out sparse bridged speech pulses)
minSpectralFlatness = 0.4;   % grinding = broadband noise (flatness~1), speech = tonal (flatness~0)
minCorroboratingBursts = 2;  % need >=N qualifying bursts before a tier actually fires
                             % (one stray burst, e.g. a consonant, shouldn't trip a warning)

%% ---- 1. Load data (numeric matrix, skip 2 header rows) ----
raw = readmatrix(filename, 'NumHeaderLines', 2);

t = raw(:,2);   % Time (s) is always column B

% Column layout: A=Sample#, B=Time, then repeating 4-col blocks per
% trial (Severe, Mild, No Warning, blank spacer), starting at column C.
typeOffset = struct('Severe', 0, 'Mild', 1, 'NoWarning', 2);
typeKey = strrep(dataType, ' ', '');   % 'No Warning' -> 'NoWarning' for struct lookup
col = 3 + (trial - 1) * 4 + typeOffset.(typeKey);
data = raw(:, col);

validRows = ~isnan(t) & ~isnan(data);   % drop blank/incomplete rows
t = t(validRows);
data = data(validRows);

Fs = round(1 / mean(diff(t)));
N  = numel(data);
fprintf('Trial %d, Column: %s\n', trial, dataType);
fprintf('Loaded %d samples at %d Hz (%.1f s of data)\n', N, Fs, t(end)-t(1));

%% ---- 2. Clean up signal ----
data = double(data) - mean(data);   % remove DC offset
data = detrend(data);               % remove slow drift

%% ---- 3. Frequency-domain estimate for DISPLAY ONLY ----
% Detection (steps 4-6 below) still runs on the raw single-FFT band
% mask, untouched. For the plot, a single un-averaged FFT over an entire
% ~80s trial is extremely noisy bin-to-bin (that's what made the old
% plot unreadable). Welch's method -- segment, window, FFT, average --
% is the same technique already used in the silence-vs-fan script, so
% this plot is now directly comparable to those. No toolbox required.
winLen   = min(4096, 2^floor(log2(N/8)));   % adapt to trial length, power of 2
noverlap = round(winLen/2);
nfft     = winLen;
[PxxWelch, fWelch] = welchPSD(data, winLen, noverlap, nfft, Fs);

dbOffset = 15;   % shift the whole curve up by 15 dB
pxx_dB_display = 10*log10(PxxWelch + eps) + dbOffset;

%% ---- 4. Bandpass via FFT bin zeroing (toolbox-free filter) ----
Y = fft(data);
freqAxisFull = (0:N-1) * (Fs / N);
inBand = (freqAxisFull >= freqBand(1) & freqAxisFull <= freqBand(2)) | ...
         (freqAxisFull >= (Fs - freqBand(2)) & freqAxisFull <= (Fs - freqBand(1)));
Yband = Y;
Yband(~inBand) = 0;
bandSignal = real(ifft(Yband));

%% ---- 5. Burst detection on raw broadband envelope ----
% Detection uses raw signal loudness, not the band-passed signal --
% Severe vs Mild/No Warning differ ~8x in raw amplitude but that gap
% disappears once filtered to just 80-160 Hz (broadband, not tonal).
winSize  = round(0.05 * Fs);
envelope = sqrt(movmean(data.^2, winSize));

% Baseline = quietest baselinePct% of envelope, not median (median
% breaks for nonstop grinding, where most of the recording is loud).
sortedEnv = sort(envelope);
pctIdx    = max(1, round((baselinePct/100) * numel(sortedEnv)));
baseline  = sortedEnv(pctIdx);
threshold = baseline * threshMult;
active = envelope > threshold;

% Bridge short gaps so continuous grinding isn't fragmented into many
% sub-threshold dips.
rawActive = active(:);
gapSamples = round(mergeGap * Fs);
active = active(:);
gapEdges = diff([0; ~active; 0]);
gapStarts = find(gapEdges == 1);
gapStops  = find(gapEdges == -1) - 1;
for k = 1:numel(gapStarts)
    if (gapStops(k) - gapStarts(k) + 1) <= gapSamples
        active(gapStarts(k):gapStops(k)) = true;
    end
end

% Find active stretches, then keep only ones that are genuinely active
% most of their own span (real grinding, not bridged speech pulses).
edges  = diff([0; active; 0]);
starts = find(edges == 1);
stops  = find(edges == -1) - 1;
durations = (stops - starts + 1) / Fs;

dutyCycle = zeros(size(durations));
flatness  = zeros(size(durations));
for k = 1:numel(starts)
    dutyCycle(k) = sum(rawActive(starts(k):stops(k))) / (stops(k) - starts(k) + 1);

    % Spectral flatness (geo mean / arith mean of power spectrum):
    % near 1 = broadband/noisy (grinding), near 0 = tonal (voiced speech).
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

% Diagnostic printout of every candidate burst, pass or fail.
fprintf('\n--- Burst candidates (before filters) ---\n');
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

% Count qualifying bursts per tier (mildEligible includes severe-length
% bursts too, since those clear the mild floor as well).
mildEligible   = durations(durations >= shortDur);
severeEligible = durations(durations > longDur);
numMildEligible   = numel(mildEligible);
numSevereEligible = numel(severeEligible);

fprintf('Bursts clearing Mild-length floor (%.2fs+): %d | clearing Severe-length floor (%.2fs+): %d\n', ...
    shortDur, numMildEligible, longDur, numSevereEligible);
fprintf('Baseline (quietest %d%% of envelope): %.2f | Threshold (%gx): %.2f\n', ...
    baselinePct, baseline, threshMult, threshold);
fprintf('Total active time in band: %.1f s (%.0f%% of recording)\n', ...
    sum(active)/Fs, 100*sum(active)/numel(active));

%% ---- 6. Decide warning level ----
% A tier only fires with >=minCorroboratingBursts qualifying bursts --
% a single stray burst that slips past the filters won't trip it alone.
if numSevereEligible >= minCorroboratingBursts
    warningLevel = 'Severe Warning';
elseif numMildEligible >= minCorroboratingBursts
    warningLevel = 'Mild Warning';
else
    warningLevel = 'No Warning';
end

fprintf('\nLongest continuous grinding-band activity: %.2f s\n', longestBurst);
fprintf('==> %s\n\n', upper(warningLevel));

%% ---- 7. Plot: time domain (top), frequency domain (bottom) ----
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

set(gca, 'Color', 'white', ...
    'XColor', 'black', ...
    'YColor', 'black');


subplot(2,1,2);

plot(fWelch, pxx_dB_display, ...
    'Color', [0.30 0.60 1.00], ...
    'LineWidth', 1.2);

hold on;

xline(freqBand(1), '--', 'Color', [1 0.3 0.3]);
xline(freqBand(2), '--', 'Color', [1 0.3 0.3]);

xlim([0 1000]);
ylim([-2 22]);              % Fixed y-axis range

xlabel('Frequency (Hz)', 'Color', 'black');
ylabel('Decibels (dB)', 'Color', 'black');
title('Frequency Domain', 'Color', 'black');

grid on;

set(gca, 'Color', 'white', ...
    'XColor', 'black', ...
    'YColor', 'black');

%% ---- HELPERS ----
function [Pxx, f] = welchPSD(x, winLen, noverlap, nfft, Fs)
    % Minimal Welch's-method PSD estimate using only base MATLAB (fft):
    % segment the signal, apply a Hamming window, FFT each segment, and
    % average the resulting power spectra. Same technique used in the
    % silence-vs-fan script, so this plot is now on equal footing with
    % those -- no significant spectral content is discarded, it's just
    % averaged across overlapping windows instead of shown as one huge
    % single-shot FFT.
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

function styleAxesDark(ax)
    % Same dark-background / light-gridline styling used in the
    % silence-vs-fan script, so figures look consistent side by side.
    ax.Color = 'k';
    ax.XColor = 'w';
    ax.YColor = 'w';
    ax.GridColor = 'w';
    ax.GridAlpha = 0.25;
    ax.Title.Color = 'w';
    ax.FontSize = 10;
    ax.Box = 'on';
end