function artifacts = emit(result, opts)
arguments
    result struct
    opts.OutputDir {mustBeTextScalar} = ""
    opts.EmitPlots (1,1) logical = false
    opts.WriteJSON (1,1) logical = true
    opts.WriteMAT (1,1) logical = true
    opts.WriteCSV (1,1) logical = true
end

outputDir = string(opts.OutputDir);
if strlength(outputDir) == 0
    outputDir = fullfile(pwd, 'runs', char(result.analysisType));
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

artifacts = struct('outputDir', outputDir, 'files', {{}}, 'plotFiles', {{}}, 'csvFiles', {{}}, 'jsonFile', "", 'matFile', "");

if opts.WriteMAT
    matFile = fullfile(outputDir, 'result.mat');
    save(matFile, 'result');
    artifacts.matFile = string(matFile);
    artifacts.files{end + 1} = matFile;
end

if opts.WriteJSON
    jsonFile = fullfile(outputDir, 'result.json');
    serializable = spice.output.toSerializable(result);
    fid = fopen(jsonFile, 'w');
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, jsonencode(serializable), 'char');
    clear cleaner
    artifacts.jsonFile = string(jsonFile);
    artifacts.files{end + 1} = jsonFile;
end

if opts.WriteCSV
    for idx = 1:numel(result.signals)
        signal = result.signals(idx);
        csvFile = fullfile(outputDir, [spice.output.sanitizeFileName(signal.name) '.csv']);
        writeSignalCsv(csvFile, result.analysisType, result.axis, signal);
        artifacts.csvFiles{end + 1} = csvFile;
        artifacts.files{end + 1} = csvFile;
    end
end

if opts.EmitPlots
    plotFiles = emitPlots(result, outputDir);
    artifacts.plotFiles = plotFiles;
    artifacts.files = [artifacts.files, plotFiles];
end
end

function plotFiles = emitPlots(result, outputDir)
plotFiles = {};

switch result.analysisType
    case "ac"
        for idx = 1:numel(result.signals)
            signal = result.signals(idx);
            magnitudeFile = fullfile(outputDir, [spice.output.sanitizeFileName(signal.name) '_magnitude.png']);
            phaseFile = fullfile(outputDir, [spice.output.sanitizeFileName(signal.name) '_phase.png']);
            writeAcPlot(result.axis, signal, magnitudeFile, phaseFile);
            plotFiles{end + 1} = magnitudeFile; %#ok<AGROW>
            plotFiles{end + 1} = phaseFile; %#ok<AGROW>
        end
    case {"dc", "dcsweep", "trans", "shoot"}
        for idx = 1:numel(result.signals)
            signal = result.signals(idx);
            plotFile = fullfile(outputDir, [spice.output.sanitizeFileName(signal.name) '.png']);
            writeRealPlot(result.axis, signal, plotFile);
            plotFiles{end + 1} = plotFile; %#ok<AGROW>
        end
    case "pz"
        plotFile = fullfile(outputDir, 'pz_map.png');
        writePzPlot(result.signals, plotFile);
        plotFiles{end + 1} = plotFile;
end
end

function writeRealPlot(axis, signal, outputPath)
figureHandle = figure('Visible', 'off');
cleanup = onCleanup(@() safeCloseFigure(figureHandle));
plot(axis.values, real(signal.values), 'LineWidth', 1.2);
xlabel(axis.name);
ylabel(signal.unit);
title(signal.name);
grid on;
saveas(figureHandle, outputPath);
delete(cleanup);
end

function writeAcPlot(axis, signal, magnitudePath, phasePath)
figureHandle = figure('Visible', 'off');
cleanup = onCleanup(@() safeCloseFigure(figureHandle));
signalMagnitude = magnitudeValues(signal);
if string(axis.scale) == "dec"
    semilogx(axis.values, signalMagnitude, 'LineWidth', 1.2);
else
    plot(axis.values, signalMagnitude, 'LineWidth', 1.2);
end
xlabel(axis.name);
ylabel('|H|');
title(signal.name + " Magnitude");
grid on;
saveas(figureHandle, magnitudePath);
delete(cleanup);

figureHandle = figure('Visible', 'off');
cleanup = onCleanup(@() safeCloseFigure(figureHandle));
signalPhaseDeg = phaseDegValues(signal);
if string(axis.scale) == "dec"
    semilogx(axis.values, signalPhaseDeg, 'LineWidth', 1.2);
else
    plot(axis.values, signalPhaseDeg, 'LineWidth', 1.2);
end
xlabel(axis.name);
ylabel('Phase (deg)');
title(signal.name + " Phase");
grid on;
saveas(figureHandle, phasePath);
delete(cleanup);
end

function writePzPlot(signals, outputPath)
figureHandle = figure('Visible', 'off');
cleanup = onCleanup(@() safeCloseFigure(figureHandle));
hold on;
for idx = 1:numel(signals)
    signal = signals(idx);
    if signal.kind == "zeroRoots"
        scatter(real(signal.values), imag(signal.values), 50, 'o', 'DisplayName', signal.name);
    else
        scatter(real(signal.values), imag(signal.values), 50, 'x', 'DisplayName', signal.name);
    end
end
xlabel('Real');
ylabel('Imag');
title('Pole-Zero Map');
grid on;
legend('Interpreter', 'none', 'Location', 'bestoutside');
saveas(figureHandle, outputPath);
delete(cleanup);
end

function writeSignalCsv(outputPath, analysisType, axis, signal)
fid = fopen(outputPath, 'w');
cleanup = onCleanup(@() fclose(fid));

switch analysisType
    case "ac"
        fprintf(fid, '%s,real,imag,magnitude,phase_deg\n', axis.name);
        signalMagnitude = magnitudeValues(signal);
        signalPhaseDeg = phaseDegValues(signal);
        for idx = 1:numel(signal.values)
            fprintf(fid, '%.15g,%.15g,%.15g,%.15g,%.15g\n', ...
                axis.values(idx), real(signal.values(idx)), imag(signal.values(idx)), ...
                signalMagnitude(idx), signalPhaseDeg(idx));
        end
    case "pz"
        fprintf(fid, 'root_index,real,imag,magnitude,phase_deg\n');
        signalMagnitude = magnitudeValues(signal);
        signalPhaseDeg = phaseDegValues(signal);
        for idx = 1:numel(signal.values)
            fprintf(fid, '%d,%.15g,%.15g,%.15g,%.15g\n', ...
                idx, real(signal.values(idx)), imag(signal.values(idx)), ...
                signalMagnitude(idx), signalPhaseDeg(idx));
        end
    otherwise
        fprintf(fid, '%s,value\n', axis.name);
        if numel(signal.values) == 1
            fprintf(fid, '0,%.15g\n', signal.values);
        else
            for idx = 1:numel(signal.values)
                fprintf(fid, '%.15g,%.15g\n', axis.values(idx), signal.values(idx));
            end
        end
end

clear cleanup
end

function values = magnitudeValues(signal)
if isfield(signal, 'magnitude') && ~isempty(signal.magnitude)
    values = signal.magnitude;
else
    values = abs(signal.values);
end
end

function values = phaseDegValues(signal)
if isfield(signal, 'phaseDeg') && ~isempty(signal.phaseDeg)
    values = signal.phaseDeg;
else
    values = rad2deg(angle(signal.values));
end
end

function safeCloseFigure(figureHandle)
if ishghandle(figureHandle)
    close(figureHandle);
end
end
