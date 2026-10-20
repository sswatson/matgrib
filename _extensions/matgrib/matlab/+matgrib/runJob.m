function runJob(jobFile)
%RUNJOB Execute the MATLAB cells of a Quarto document.
%   matgrib.runJob(jobFile) reads a job written by matlab-engine.js, runs
%   each cell in the base workspace (so state carries between cells, as in a
%   Jupyter kernel), captures console output, and collects each cell's
%   figures: matgrib.gg plots the cell displays, then every MATLAB figure it
%   leaves open (translated to a spec). Figures the translator cannot
%   express, or cells that ask for it, are exported as images instead.
%
%   The result is written next to the job as <job>.result.json.

job = jsondecode(fileread(jobFile));
cells = job.cells;
if ~iscell(cells), cells = num2cell(cells); end

oldDir = pwd;
restoreDir = onCleanup(@() cd(oldDir));
if isfield(job, 'cwd') && ~isempty(job.cwd), cd(job.cwd); end

% Figures exist only to be translated; never pop windows in a shared session.
oldVis = get(groot, 'DefaultFigureVisible');
set(groot, 'DefaultFigureVisible', 'off');
restoreVis = onCleanup(@() set(groot, 'DefaultFigureVisible', oldVis));

% matgrib.gg plots displayed during a cell land in this queue (matgrib.emit).
setappdata(groot, 'matgrib_queue', {});
clearQueue = onCleanup(@() rmappdata(groot, 'matgrib_queue'));

results = cell(1, numel(cells));
for i = 1:numel(cells)
    c = cells{i};
    r = struct('id', c.id, 'stdout', '', 'error', '', 'figures', {{}});
    before = findall(groot, 'Type', 'figure');
    setappdata(groot, 'matgrib_queue', {});
    code = c.code;
    try
        r.stdout = evalc('evalin(''base'', code)');
    catch err
        r.error = err.message;
    end

    queued = getappdata(groot, 'matgrib_queue');
    for k = 1:numel(queued)
        r.figures{end+1} = struct('spec', queued{k}, 'image', '', 'unsupported', {{}}, 'aspect', []);
    end

    figs = setdiff(findall(groot, 'Type', 'figure'), before);
    if ~isempty(figs)
        [~, order] = sort([figs.Number]);
        figs = figs(order);
    end
    for k = 1:numel(figs)
        base = fullfile(job.figdir, sprintf('%s-%d', c.id, k));
        r.figures{end+1} = figureResult(figs(k), base, c, job);
        close(figs(k));
    end
    results{i} = r;
end

fid = fopen([jobFile '.result.json'], 'w', 'n', 'UTF-8');
fwrite(fid, jsonencode(struct('cells', {results})), 'char');
fclose(fid);
end

function f = figureResult(fig, base, c, job)
f = struct('spec', [], 'image', '', 'unsupported', {{}}, 'aspect', []);
pos = getpixelposition(fig);
f.aspect = pos(4) / pos(3);
mode = 'native';
if isfield(c, 'render') && ~isempty(c.render), mode = c.render; end
if strcmp(mode, 'native')
    try
        spec = matgrib.figureSpec(fig, 'MaxPoints', job.maxPoints, 'MaxScatter', job.maxScatter);
        f.unsupported = spec.unsupported;
        if isempty(spec.unsupported) || ~job.strict
            f.spec = spec;
        end
    catch err
        f.unsupported = {['translator error: ' err.message]};
    end
end
if isempty(f.spec)
    f.spec = [];
    f.image = exportImage(fig, base, job.imageFormat);
end
end

function file = exportImage(fig, base, fmt)
file = [base '.' fmt];
switch fmt
    case 'svg'
        print(fig, file, '-dsvg', '-vector');
    case 'pdf'
        exportgraphics(fig, file, 'ContentType', 'vector');
    otherwise
        exportgraphics(fig, file, 'Resolution', 200);
end
end
