%% bruxism_fft_silence_vs_fan
clear; clc; close all;

filename        = 'bruxism_data_log.csv';
USE_RAW_INSTEAD = true;   % true -> analyze Raw cols instead of Filtered

% spectrum range
% 0-2500 Hz range just buries the real bumps in flat noise floor
% empty [] to auto-pick (50 Hz - Filtered, full - Raw), or set manually
maxDisplayFreq = [1000];
yAxisLimits    = [-20 25];   % dB, y-axis limit on both plots

%% LOAD DATA
if ~isfile(filename)
    error(['Can''t find "%s" in the current folder (%s).\n' ...
           'Either cd to the folder containing the CSV, or set filename ' ...
           'to the full path, e.g. filename = ''C:\\path\\to\\%s'';'], ...
           filename, pwd, filename);
end

% grab just the header row that labels each column (row 2 of the file)
fid = fopen(filename, 'r');
fgetl(fid);                 % row 1: dates, not needed
headerLine2 = fgetl(fid);   % row 2: Silence/Fan - Raw/Filtered labels
fclose(fid);
headerRow2 = strsplit(headerLine2, ',');

% numeric data starts at row 3 (row 1 = dates, row 2 = column labels,
% row 3 onward = actual samples). NumVariables is forced to match the
% header length so trailing columns aren't silently dropped by
% auto-detection.
nCols = numel(headerRow2);
opts = delimitedTextImportOptions('NumVariables', nCols, ...
    'DataLines', [3 Inf], 'Delimiter', ',');
opts.VariableTypes = repmat({'double'}, 1, nCols);
M = readmatrix(filename, opts);

%% ---------------- LOCATE THE SILENCE/FAN FILTERED COLUMNS ----------------
if USE_RAW_INSTEAD
    keep = @(h) contains(h, 'Raw', 'IgnoreCase', true);
else
    keep = @(h) contains(h, 'Filtered', 'IgnoreCase', true);
end

silenceCols = find(cellfun(@(h) contains(h, 'Silence', 'IgnoreCase', true) && keep(h), headerRow2));
fanCols     = find(cellfun(@(h) contains(h, 'Fan', 'IgnoreCase', true) && keep(h), headerRow2));

fprintf('Found %d Silence column(s), %d Fan column(s).\n', numel(silenceCols), numel(fanCols));
assert(~isempty(silenceCols) && ~isempty(fanCols), ...
    'No matching columns found — check header text / CSV layout.');

% Sample rate computed from the Time column itself (don't hardcode it)
timeCol = M(:,2);
dt = median(diff(timeCol), 'omitnan');
Fs = round(1/dt);
fprintf('Detected sample rate: %d Hz\n', Fs);

%% ---------------- BUILD ONE LONG SIGNAL PER CONDITION ----------------
% Each day's column has a different amount of *real* data (the rest is
% pre-populated blank template rows -> NaN), so each day is trimmed to its
% own valid samples and has its own DC/baseline offset removed BEFORE
% concatenating, avoiding cross-day offset jumps in the combined signal.
silenceSignal = extractAndConcat(M, silenceCols);
fanSignal     = extractAndConcat(M, fanCols);

fprintf('Total Silence samples: %d (%.1f s)\n', numel(silenceSignal), numel(silenceSignal)/Fs);
fprintf('Total Fan samples: %d (%.1f s)\n', numel(fanSignal), numel(fanSignal)/Fs);

%% ---------------- FREQUENCY DOMAIN VIA WELCH'S METHOD ----------------
% Welch's method (segment -> window -> FFT -> average) gives a stable
% spectrum without building one giant FFT over the whole concatenated
% signal, and stays fast even with this much data. Implemented here with
% plain fft() so it doesn't require the Signal Processing Toolbox.
winLen   = 4096;                 % ~0.82 s window at 5 kHz
noverlap = round(winLen/2);
nfft     = winLen;

[Psilence, fAxis] = welchPSD(silenceSignal, winLen, noverlap, nfft, Fs);
[Pfan, ~]         = welchPSD(fanSignal,     winLen, noverlap, nfft, Fs);

%% ---------------- PLOT ----------------
% Plotted in dB: the "Filtered" signal is a non-negative envelope, so even
% after removing each day's mean there's a large low-frequency component
% that would swamp everything else on a linear scale. dB compresses that
% dynamic range so smaller peaks elsewhere in the spectrum are visible too.
if isempty(maxDisplayFreq)
    if USE_RAW_INSTEAD
        plotMaxFreq = Fs/2;
    else
        plotMaxFreq = 50;
    end
else
    plotMaxFreq = maxDisplayFreq;
end

fig = figure('Position', [100 100 900 700], 'Color', 'white');

subplot(2,1,1);

plot(fAxis, 10*log10(Pfan), 'LineWidth', 1);

title('Teeth Grinding — Silence (Frequency Spectrum)', 'Color', 'black');
xlabel('Frequency (Hz)', 'Color', 'black');
ylabel('Decibels (dB)', 'Color', 'black');
grid on;
xlim([0 plotMaxFreq]);
ylim(yAxisLimits);

set(gca, 'Color', 'white', 'XColor', 'black', 'YColor', 'black');

subplot(2,1,2);

plot(fAxis, 10*log10(Psilence), 'LineWidth', 1, ...
    'Color', [0.85 0.33 0.10]);

title('Teeth Grinding — Fan Noise (Frequency Spectrum)', 'Color', 'black');
xlabel('Frequency (Hz)', 'Color', 'black');
ylabel('Decibels (dB)', 'Color', 'black');
grid on;
xlim([0 plotMaxFreq]);
ylim(yAxisLimits);

set(gca, 'Color', 'white', 'XColor', 'black', 'YColor', 'black');

sgtitle('Bruxism Signal: Silence vs Fan Noise — Dominant Frequency Comparison', ...
    'Color', 'black');

outPng = 'bruxism_silence_vs_fan_spectrum.png';

exportgraphics(fig, outPng, 'Resolution', 200);

fprintf('Saved plot to %s\n', outPng);

%% ---------------- HELPERS ----------------
function [Pxx, f] = welchPSD(x, winLen, noverlap, nfft, Fs)
    % Minimal Welch's-method PSD estimate using only base MATLAB (fft):
    % segment the signal, apply a Hamming window, FFT each segment, and
    % average the resulting power spectra. Equivalent in spirit to
    % Signal Processing Toolbox's pwelch, without requiring the toolbox.
    x = x(:);
    n = (0:winLen-1)';
    win = 0.54 - 0.46*cos(2*pi*n/(winLen-1));  % Hamming window
    U = sum(win.^2);                            % window power, for normalization

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
        Pk(2:end-1) = 2*Pk(2:end-1);             % fold negative-frequency energy in
        Pxx = Pxx + Pk;
    end
    Pxx = Pxx / numSegs;
    f = (0:halfN-1)' * (Fs/nfft);
end

function sigOut = extractAndConcat(M, cols)
    % Pulls each day's column, drops the pre-populated NaN tail, removes
    % that day's own baseline, and appends it to the running signal.
    sigOut = [];
    for c = cols
        col = M(:,c);
        col = col(~isnan(col));
        if isempty(col)
            continue
        end
        col = col - mean(col);
        sigOut = [sigOut; col]; %#ok<AGROW>
    end
end