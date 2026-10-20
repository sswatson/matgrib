function fig = preview(spec, fig)
%PREVIEW Draw a matgrib figure spec with MATLAB graphics.
%   fig = matgrib.preview(spec) approximates what the Typst and HTML
%   renderers will draw, for interactive work outside Quarto. Fonts, sizes
%   and spacing differ; geometry, scales and colours match.

if nargin < 2 || isempty(fig), fig = figure('Color', 'w'); else, clf(fig); end
cfg.palette = hex2rgb({'#0072B2', '#D55E00', '#009E73', '#E69F00', '#56B4E9', '#CC79A7', '#7F7F7F', '#F0E442'});
cfg.ink = [0.153 0.188 0.212];
cfg.paper = [1 1 1];

panels = asCell(spec.panels);
ncol = max(1, min(spec.ncol, numel(panels)));
outer = tiledlayout(fig, ceil(numel(panels) / ncol), ncol, 'TileSpacing', 'compact', 'Padding', 'compact');
if ~isempty(spec.title), title(outer, spec.title, 'FontWeight', 'bold'); end
if isfield(spec, 'subtitle') && ~isempty(spec.subtitle), subtitle(outer, spec.subtitle); end
for k = 1:numel(panels)
    drawPanel(outer, k, panels{k}, cfg);
end
end

function c = asCell(v)
if iscell(v), c = v; elseif isstruct(v), c = num2cell(v); else, c = {}; end
end

function rgb = hex2rgb(h)
if ischar(h), h = {h}; end
rgb = cell2mat(cellfun(@(s) sscanf(s(2:end), '%2x%2x%2x')' / 255, h(:), 'UniformOutput', false));
end

function c = resolveColour(c, cfg)
if isstruct(c), c = cfg.palette(mod(c.auto - 1, size(cfg.palette, 1)) + 1, :);
elseif strcmp(c, 'ink'), c = cfg.ink;
elseif strcmp(c, 'paper'), c = cfg.paper;
elseif strcmp(c, 'none'), c = 'none';
else, c = hex2rgb(c);
end
end

function f = colourFn(s, cfg)
% Returns a function mapping a level (string) or value (number) to RGB.
if isempty(s), f = []; return; end
if strcmp(s.type, 'discrete')
    levels = string(s.levels);
    vals = asCell(s.values);
    rgb = cell2mat(cellfun(@(v) resolveColour(v, cfg), vals(:), 'UniformOutput', false));
    f = @(v) rgb(max(1, find(levels == string(v), 1)), :);
else
    stops = hex2rgb(s.colours);
    lim = s.limits;
    f = @(v) interp1(linspace(lim(1), lim(2) + eps(lim(2)), size(stops, 1)), stops, ...
        min(max(v, lim(1)), lim(2)));
end
end

function drawPanel(outer, k, p, cfg)
f = p.facet;
cells = {struct('key', '', 'row', '', 'col', '')};
fr = 1; fc = 1;
if ~isempty(f)
    if strcmp(f.type, 'wrap')
        lv = string(f.levels);
        fc = min(f.ncol, numel(lv)); fr = ceil(numel(lv) / fc);
        cells = arrayfun(@(l) struct('key', l, 'row', '', 'col', ''), lv, 'UniformOutput', false);
    else
        rs = string(f.rows); cs = string(f.cols);
        if isempty(rs), rs = ""; end
        if isempty(cs), cs = ""; end
        fr = numel(rs); fc = numel(cs);
        cells = {};
        for r = rs(:)', for c = cs(:)', cells{end+1} = struct('key', '', 'row', r, 'col', c); end, end %#ok<AGROW>
    end
end
if numel(cells) > 1
    inner = tiledlayout(outer, fr, fc, 'TileSpacing', 'compact');
    inner.Layout.Tile = k;
    if ~isempty(p.title), title(inner, p.title, 'FontWeight', 'bold'); end
else
    inner = outer;
end
colourF = colourFn(p.colour, cfg);
fillF = colourFn(p.fill, cfg);
for j = 1:numel(cells)
    if numel(cells) > 1, ax = nexttile(inner, j); else, ax = nexttile(outer, k); end
    hold(ax, 'on'); box(ax, 'off'); grid(ax, 'on');
    ax.GridColor = cfg.ink; ax.GridAlpha = 0.12;
    layers = asCell(p.layers);
    for i = 1:numel(layers)
        drawLayer(ax, layers{i}, cells{j}, colourF, fillF, cfg);
    end
    styleAxis(ax, p.x, 'X'); styleAxis(ax, p.y, 'Y');
    if numel(cells) > 1
        parts = [cells{j}.key cells{j}.row cells{j}.col];
        label = strjoin(cellstr(parts(parts ~= "")), ' · ');
        title(ax, label, 'FontWeight', 'bold', 'FontSize', 9);
    else
        if ~isempty(p.title), title(ax, p.title); end
        if ~isempty(p.subtitle), subtitle(ax, p.subtitle); end
    end
    xlabel(ax, p.x.label); ylabel(ax, p.y.label);
end
addLegend(ax, p, colourF, fillF, cfg);
end

function styleAxis(ax, a, d)
if strcmp(a.trans, 'log10'), ax.([d 'Scale']) = 'log'; end
if strcmp(a.trans, 'reverse'), ax.([d 'Dir']) = 'reverse'; end
if numel(a.limits) == 2, ax.([d 'Lim']) = a.limits; end
if ~isempty(a.breaks), ax.([d 'Tick']) = a.breaks; end
lbl = a.labels;
if ~isempty(lbl) && numel(lbl) == numel(a.breaks), ax.([d 'TickLabel']) = lbl; end
if strcmp(a.type, 'date')
    t = ax.([d 'Tick']);
    ax.([d 'Tick']) = t;   % freeze, or later layout changes desync the labels
    ax.([d 'TickLabel']) = cellstr(string(datetime(t / 1000, 'ConvertFrom', 'posixtime'), 'MMM yyyy'));
end
end

function v = col(d, name, n)
v = d.(name);
if iscell(v), v = string(v); end
if isscalar(v) && n > 1, v = repmat(v, 1, n); end
v = v(:)';
end

function keep = inCell(d, cellInfo, n)
keep = true(1, n);
if isfield(d, 'facet') && cellInfo.key ~= "", keep = keep & col(d, 'facet', n) == cellInfo.key; end
if isfield(d, 'facet_row') && cellInfo.row ~= "", keep = keep & col(d, 'facet_row', n) == cellInfo.row; end
if isfield(d, 'facet_col') && cellInfo.col ~= "", keep = keep & col(d, 'facet_col', n) == cellInfo.col; end
end

function drawLayer(ax, L, cellInfo, colourF, fillF, cfg)
d = L.data;
P = L.params;
aes = string(L.aes);
f = fieldnames(d);
n = 0;
for k = 1:numel(f), n = max(n, numel(d.(f{k}))); end
keep = inCell(d, cellInfo, n);
idx = find(keep);
if isempty(idx), return; end
colv = @(name) subsref(col(d, name, n), struct('type', '()', 'subs', {{idx}}));
fixed = @(name, def) resolveOr(P, name, def, cfg);
lw = getfieldOr(P, 'linewidth', 1);
ls = lineSpec(getfieldOr(P, 'linetype', 'solid'));
alpha = getfieldOr(P, 'alpha', 1);
colourOf = @(i) pick(aes, 'colour', d, n, idx, i, colourF, fixed('colour', cfg.palette(1, :)));
fillOf = @(i) pick(aes, 'fill', d, n, idx, i, fillF, fixed('fill', cfg.palette(1, :)));
groups = ones(1, numel(idx));
if any(aes == "group") || any(aes == "colour") || any(aes == "fill")
    key = strings(1, numel(idx));
    for a = ["group" "colour" "fill"]
        if any(aes == a), key = key + "|" + string(colv(char(a))); end
    end
    [~, ~, groups] = unique(key, 'stable');
    groups = groups(:)';
end
switch L.geom
    case 'point'
        x = colv('x'); y = colv('y');
        C = cell2mat(arrayfun(colourOf, (1:numel(idx))', 'UniformOutput', false));
        sz = (getfieldOr(P, 'size', 4.5) * 1.3)^2;
        mk = markerOf(getfieldOr(P, 'shape', 'circle'));
        if getfieldOr(P, 'filled', true)
            scatter(ax, x, y, sz, C, mk, 'filled', 'MarkerFaceAlpha', alpha);
        else
            scatter(ax, x, y, sz, C, mk);
        end
    case 'path'
        x = colv('x'); y = colv('y');
        for g = unique(groups)
            r = groups == g; i = find(r, 1);
            plot(ax, x(r), y(r), ls, 'Color', colourOf(i), 'LineWidth', lw);
        end
    case {'ribbon', 'polygon'}
        for g = unique(groups)
            r = groups == g; i = find(r, 1);
            if strcmp(L.geom, 'ribbon')
                x = colv('x'); X = [x(r) fliplr(x(r))]; lo = colv('ymin'); hi = colv('ymax'); Y = [lo(r) fliplr(hi(r))];
            else
                x = colv('x'); y = colv('y'); X = x(r); Y = y(r);
            end
            fill(ax, X, Y, fillOf(i), 'FaceAlpha', alpha, 'EdgeColor', 'none');
        end
    case 'rect'
        x0 = colv('xmin'); x1 = colv('xmax'); y0 = colv('ymin'); y1 = colv('ymax');
        C = cell2mat(arrayfun(fillOf, (1:numel(idx))', 'UniformOutput', false));
        E = C;
        if lw > 0 && ~any(aes == "colour"), E = repmat(fixed('colour', cfg.ink), numel(idx), 1); end
        if lw > 0 && any(aes == "colour"), E = cell2mat(arrayfun(colourOf, (1:numel(idx))', 'UniformOutput', false)); end
        V = [x0' y0'; x1' y0'; x1' y1'; x0' y1'];
        m = numel(idx);
        F = [1:m; m+1:2*m; 2*m+1:3*m; 3*m+1:4*m]';
        patch(ax, 'Faces', F, 'Vertices', V, 'FaceVertexCData', C, 'FaceColor', 'flat', ...
            'FaceAlpha', alpha, 'EdgeColor', 'none');
        if lw > 0
            patch(ax, 'Faces', F, 'Vertices', V, 'FaceColor', 'none', 'EdgeColor', 'flat', ...
                'FaceVertexCData', repmat(E, 4, 1), 'LineWidth', lw);
        end
    case 'segment'
        x = colv('x'); y = colv('y'); xe = colv('xend'); ye = colv('yend');
        for i = 1:numel(idx)
            plot(ax, [x(i) xe(i)], [y(i) ye(i)], ls, 'Color', colourOf(i), 'LineWidth', lw);
        end
    case 'errorbar'
        horizontal = getfieldOr(P, 'horizontal', false);
        for i = 1:numel(idx)
            if horizontal
                y = colv('y'); a = colv('xmin'); b = colv('xmax');
                plot(ax, [a(i) b(i)], [y(i) y(i)], 'Color', colourOf(i), 'LineWidth', lw);
            else
                x = colv('x'); a = colv('ymin'); b = colv('ymax');
                plot(ax, [x(i) x(i)], [a(i) b(i)], 'Color', colourOf(i), 'LineWidth', lw);
            end
        end
    case 'text'
        x = colv('x'); y = colv('y'); lbl = colv('label');
        for i = 1:numel(idx)
            text(ax, x(i), y(i), lbl(i), 'Color', colourOf(i), ...
                'HorizontalAlignment', getfieldOr(P, 'halign', 'center'));
        end
    case 'hline'
        yline(ax, colv('y'), ls, 'Color', fixed('colour', cfg.ink), 'LineWidth', lw);
    case 'vline'
        xline(ax, colv('x'), ls, 'Color', fixed('colour', cfg.ink), 'LineWidth', lw);
end
end

function c = pick(aes, key, d, n, idx, i, fn, fallback)
if any(aes == key) && ~isempty(fn)
    v = col(d, key, n);
    c = fn(v(idx(i)));
else
    c = fallback;
end
end

function v = resolveOr(P, name, def, cfg)
if isfield(P, name), v = resolveColour(P.(name), cfg); else, v = def; end
if ischar(v) && strcmp(v, 'none'), v = def; end
end

function v = getfieldOr(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end

function s = lineSpec(t)
switch t
    case 'dashed', s = '--';
    case 'dotted', s = ':';
    case 'dash-dotted', s = '-.';
    otherwise, s = '-';
end
end

function m = markerOf(s)
switch s
    case 'square', m = 's';
    case 'diamond', m = 'd';
    case 'triangle', m = '^';
    case 'x', m = 'x';
    case 'cross', m = '+';
    otherwise, m = 'o';
end
end

function addLegend(ax, p, colourF, fillF, cfg)
if strcmp(p.legend, 'none'), return; end
layers = asCell(p.layers);
handles = gobjects(0);
for key = ["colour" "fill"]
    s = p.(char(key));
    if isempty(s), continue; end
    used = any(cellfun(@(L) L.legend && any(string(L.aes) == key), layers));
    if ~used, continue; end
    if strcmp(s.type, 'continuous')
        colormap(ax, interp1(linspace(0, 1, numel(s.colours)), hex2rgb(s.colours), linspace(0, 1, 256)));
        clim(ax, s.limits);
        cb = colorbar(ax);
        if ~isempty(s.title), cb.Label.String = s.title; end
        continue
    end
    fn = colourF; if key == "fill", fn = fillF; end
    for l = reshape(string(s.levels), 1, [])
        if key == "fill"
            handles(end+1) = patch(ax, NaN, NaN, fn(l), 'EdgeColor', 'none', 'DisplayName', l); %#ok<AGROW>
        else
            handles(end+1) = plot(ax, NaN, NaN, '-', 'Color', fn(l), 'LineWidth', 1.5, 'DisplayName', l); %#ok<AGROW>
        end
    end
end
if isempty(handles), return; end
[~, keep] = unique(string({handles.DisplayName}), 'stable');
handles = handles(keep);
loc = struct('right', 'eastoutside', 'left', 'westoutside', 'top', 'northoutside', 'bottom', 'southoutside');
pos = strrep(p.legend, '-', '');
if isfield(loc, pos), L = legend(ax, handles, 'Location', loc.(pos)); else, L = legend(ax, handles, 'Location', 'best'); end
L.Box = 'off';
end
