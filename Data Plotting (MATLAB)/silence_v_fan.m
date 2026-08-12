clear; clc; close all;

filename = 'bruxism_data_log.csv';
USE_RAW = true;  % true -> analyze Raw cols instead of Filtered

% spectrum range
maxDisplayFreq = [1000]; % [] to auto-pick (50 Hz - Filtered, full - Raw)
yAxisLimits    = [-20 25]; % dB, y-axis limit on both plots

%% LOAD DATA
if ~isfile(filename)
    error(['Can''t find "%s" in the current folder (%s).\n' ...
           'Either cd to the folder containing the CSV, or set filename ' ...
           'to the full path, e.g. filename = ''C:\\path\\to\\%s'';'], ...
           filename, pwd, filename);
end

% row 2 has the column labels we need
fid = fopen(filename, 'r');
fgetl(fid); % row 1: dates, skip
headerLine2 = fgetl(fid);   % row 2: Silence/Fan - Raw/Filtered labels
fclose(fid);
headerRow2 = strsplit(headerLine2, ',');

% data starts row 3
nCols = numel(headerRow2);
opts = delimitedTextImportOptions('NumVariables', nCols, 'DataLines', [3 Inf], 'Delimiter', ',');
opts.VariableTypes = repmat({'double'}, 1, nCols);
M = readmatrix(filename, opts);

%% find the silence/fan columns
if USE_RAW
    keep = @(h) contains(h, 'Raw', 'IgnoreCase', true);
else
    keep = @(h) contains(h, 'Filtered', 'IgnoreCase', true);
end

silenceCols = find(cellfun(@(h) contains(h, 'Silence', 'IgnoreCase', true) && keep(h), headerRow2));
fanCols     = find(cellfun(@(h) contains(h, 'Fan', 'IgnoreCase', true) && keep(h), headerRow2));

fprintf('Found %d Silence column(s), %d Fan column(s).\n', numel(silenceCols), numel(fanCols));
assert(~isempty(silenceCols) && ~isempty(fanCols), 'No matching columns found — check header text / CSV layout.');

% sample rate from the Time column
timeCol = M(:,2);
dt = median(diff(timeCol), 'omitnan');
Fs = round(1/dt);
fprintf('Detected sample rate: %d Hz\n', Fs);

%% build one long signal per condition
silenceSignal = extractAndConcat(M, silenceCols);
fanSignal     = extractAndConcat(M, fanCols);

fprintf('Total Silence samples: %d (%.1f s)\n', numel(silenceSignal), numel(silenceSignal)/Fs);
fprintf('Total Fan samples: %d (%.1f s)\n', numel(fanSignal), numel(fanSignal)/Fs);

%% frequency domain via Welch's method
winLen   = 4096; % ~0.82 s window at 5 kHz
noverlap = round(winLen/2);
nfft     = winLen;

[Psilence, fAxis] = welchPSD(silenceSignal, winLen, noverlap, nfft, Fs);
[Pfan, ~] = welchPSD(fanSignal, winLen, noverlap, nfft, Fs);

%% plot
if isempty(maxDisplayFreq)
    if USE_RAW
        plotMaxFreq = Fs/2;
    else
        plotMaxFreq = 50;
    end
else
    plotMaxFreq = maxDisplayFreq;
end

fig = figure('Position', [100 100 900 700], 'Color', 'white');

subplot(2,1,1);
plotSpectrum(fAxis, Pfan, 'Teeth Grinding — Silence (Frequency Spectrum)', [0 0.4470 0.7410], plotMaxFreq, yAxisLimits);

subplot(2,1,2);
plotSpectrum(fAxis, Psilence, 'Teeth Grinding — Fan Noise (Frequency Spectrum)', [0.85 0.33 0.10], plotMaxFreq, yAxisLimits);

sgtitle('Bruxism Signal: Silence vs Fan Noise — Dominant Frequency Comparison', 'Color', 'black');

outPng = 'bruxism_silence_vs_fan_spectrum.png';
exportgraphics(fig, outPng, 'Resolution', 200);
fprintf('Saved plot to %s\n', outPng);

%% functions
function [Pxx, f] = welchPSD(x, winLen, noverlap, nfft, Fs)
    % segment -> window -> FFT -> average (no toolbox needed)
    x = x(:);
    n = (0:winLen-1)';
    win = 0.54 - 0.46*cos(2*pi*n/(winLen-1));  % Hamming window
    U = sum(win.^2);   % window power, for normalization

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
        Pk(2:end-1) = 2*Pk(2:end-1);   % fold negative freqs in
        Pxx = Pxx + Pk;
    end
    Pxx = Pxx / numSegs;
    f = (0:halfN-1)' * (Fs/nfft);
end

function sigOut = extractAndConcat(M, cols)
    % each day: drop NaN tail, remove that day's own baseline, append
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

function plotSpectrum(fAxis, Pxx, titleStr, lineColor, plotMaxFreq, yAxisLimits)
    % one spectrum subplot, styled consistently
    plot(fAxis, 10*log10(Pxx), 'LineWidth', 1, 'Color', lineColor);
    title(titleStr, 'Color', 'black');
    xlabel('Frequency (Hz)', 'Color', 'black');
    ylabel('Decibels (dB)', 'Color', 'black');
    grid on;
    xlim([0 plotMaxFreq]);
    ylim(yAxisLimits);
    set(gca, 'Color', 'white', 'XColor', 'black', 'YColor', 'black');
end
