function spec = figureSpec(fig, opts)
%FIGURESPEC Describe a MATLAB figure as a renderer-neutral struct.
%   spec = matgrib.figureSpec(fig) walks the axes of FIG and returns a struct
%   that matgrib.typ (Gribouille) and matgrib.js (Observable Plot) can redraw
%   natively. Colors left on 'auto' are emitted as palette slots so the
%   document theme picks them; explicit colors are kept.
%
%   spec.unsupported lists graphics objects that could not be translated.
%   Callers fall back to a vector image export when it is non-empty.
%
%   Options (name/value struct fields):
%     MaxPoints  - per-line point budget before min/max decimation (2000)
%     MaxScatter - scatter points per object before giving up (3000); Typst
%                  draws each marker separately, so huge clouds compile slowly

arguments
    fig (1,1) matlab.ui.Figure
    opts.MaxPoints (1,1) double = 2000
    opts.MaxScatter (1,1) double = 3000
end

drawnow;
spec = struct('version', 1, 'title', '', 'subtitle', '', ...
    'grid', [1 1], 'panels', {{}}, 'unsupported', {{}});

tl = findobj(fig, '-depth', 1, 'Type', 'tiledlayout');
axs = findobj(fig, 'Type', 'axes');
axs = axs(arrayfun(@(a) ~strcmp(a.Tag, 'legend') && ~strcmp(a.Visible, 'off'), axs));
% Anything that is not a 2-D cartesian axes cannot be redrawn; report it so
% the caller exports the whole figure instead of dropping a panel.
others = [findall(fig, 'Type', 'polaraxes'); findall(fig, 'Type', 'geoaxes'); ...
    findall(fig, '-isa', 'matlab.graphics.chart.Chart')];
for k = 1:numel(others)
    spec.unsupported{end+1} = class(others(k));
end
for k = 1:numel(axs)
    if ~isequal(round(axs(k).View), [0 90])
        spec.unsupported{end+1} = '3-D axes view';
    end
end
if isempty(axs) || ~isempty(spec.unsupported)
    if isempty(axs), spec.unsupported{end+1} = 'figure without cartesian axes'; end
    spec = toV2(spec);
    return
end

% Panel order and grid: tiledlayout knows its own grid; subplot / manual axes
% are ordered top-to-bottom, left-to-right from their positions.
if ~isempty(tl)
    tl = tl(1);
    spec.title = textOf(tl.Title);
    spec.subtitle = textOf(tl.Subtitle);
    gs = tl.GridSize;
    tiles = arrayfun(@(a) tileOf(a), axs);
    [~, order] = sort(tiles);
    axs = axs(order);
    spec.grid = [max(1, ceil(numel(axs) / gs(2))) gs(2)];
    if numel(axs) <= gs(2), spec.grid = [1 numel(axs)]; end
else
    pos = cell2mat(arrayfun(@(a) getpixelposition(a), axs, 'UniformOutput', false));
    cx = round(pos(:,1) + pos(:,3)/2, -1);
    cy = round(pos(:,2) + pos(:,4)/2, -1);
    [~, order] = sortrows([-cy cx]);
    axs = axs(order);
    spec.grid = [numel(unique(cy)) numel(unique(cx))];
    sg = findall(fig, 'Type', 'subplottext');
    if ~isempty(sg), spec.title = textOf(sg(1)); end
end

for k = 1:numel(axs)
    [panel, bad] = panelSpec(axs(k), opts);
    panel.layers = cellfun(@compact, panel.layers, 'UniformOutput', false);
    spec.panels{end+1} = panel;
    spec.unsupported = [spec.unsupported bad];
end
spec = toV2(spec);
end

% ---------------------------------------------------------------------------
% The walk above records MATLAB semantics per graphics object; toV2 turns
% that into the shared primitive spec (SPEC.md) that matgrib.gg also emits.

function out = toV2(spec)
out = struct('matgrib', 2, 'title', spec.title, 'subtitle', spec.subtitle, 'caption', '', ...
    'ncol', spec.grid(2), 'aspect', [], 'panels', {cellfun(@panelV2, spec.panels, 'UniformOutput', false)}, ...
    'notes', {{}}, 'unsupported', {spec.unsupported});
end

function q = panelV2(p)
q = struct('title', p.title, 'subtitle', p.subtitle, 'caption', '');
q.x = axisV2(p.x, p.xlabel);
q.y = axisV2(p.y, p.ylabel);
fillGeoms = {'rect', 'ribbon', 'polygon'};
strokeNames = {}; fillNames = {};
for k = 1:numel(p.layers)
    L = p.layers{k};
    if ~L.legend, continue; end
    if any(strcmp(L.geom, fillGeoms)), fillNames{end+1} = L.series; else, strokeNames{end+1} = L.series; end %#ok<AGROW>
end
q.colour = discreteScale(p.series, strokeNames);
q.fill = discreteScale(p.series, fillNames);
cv = find(cellfun(@(L) isfield(L, 'cvalue'), p.layers), 1);
if ~isempty(cv)
    L = p.layers{cv};
    v = L.cvalue;
    q.colour = struct('type', 'continuous', 'limits', [min(v) max(v)], 'colours', {L.colormap}, 'title', '');
end
q.legend = 'none';
if p.legend.visible, q.legend = p.legend.position; end
if ~isempty(cv) && p.colorbar && strcmp(q.legend, 'none'), q.legend = 'right'; end
q.facet = [];
q.layers = {};
for k = 1:numel(p.layers)
    q.layers = [q.layers layerV2(p.layers{k}, ~isempty(cv) && p.colorbar)];
end
end

function s = discreteScale(series, names)
s = [];
names = unique(names, 'stable');
if isempty(names), return; end
cols = cell(1, numel(names));
for k = 1:numel(names)
    hit = find(cellfun(@(e) strcmp(e.name, names{k}), series), 1);
    cols{k} = series{hit}.color;
end
s = struct('type', 'discrete', 'levels', {names}, 'values', {cols}, 'title', '');
end

function a = axisV2(a1, label)
types = struct('numeric', 'continuous', 'datetime', 'date', 'categorical', 'discrete');
a = struct('label', label, 'type', types.(a1.type), 'trans', 'identity', ...
    'limits', a1.limits, 'breaks', a1.ticks, 'labels', {a1.ticklabels}, 'format', '');
if strcmp(a1.scale, 'log'), a.trans = 'log10'; elseif a1.reverse, a.trans = 'reverse'; end
end

function w = lineWidth(L)
w = 1;
if isfield(L, 'linewidth')
    w = L.linewidth;
    if w == 0.5, w = 0.9; end   % MATLAB's default reads as a hairline on paper
end
end

function out = layerV2(L, colorbar)
fills = any(strcmp(L.geom, {'rect', 'ribbon', 'polygon'}));
key = 'colour'; if fills, key = 'fill'; end
q = struct('geom', L.geom, 'data', struct(), 'aes', {{}}, 'legend', L.legend, 'params', struct());
if L.legend
    q.aes = {key};
    q.data.(key) = L.series;
else
    q.params.(key) = L.color;
end
if isfield(L, 'alpha'), q.params.alpha = L.alpha; end
switch L.geom
    case {'line', 'step'}
        x = L.x; y = L.y;
        seg = zeros(size(x));
        if isfield(L, 'seg'), seg = L.seg; end
        if strcmp(L.geom, 'step')
            n = numel(x);
            xs = zeros(1, 2 * n - 1); ys = xs;
            xs(1:2:end) = x; ys(1:2:end) = y;
            xs(2:2:end) = x(2:end); ys(2:2:end) = y(1:end-1);
            x = xs; y = ys; seg = zeros(size(x));
        end
        q.geom = 'path';
        q.data.x = x; q.data.y = y;
        q.data.group = arrayfun(@(s) sprintf('s%d', s), seg, 'UniformOutput', false);
        q.aes{end+1} = 'group';
        q.params.linewidth = lineWidth(L);
        if isfield(L, 'linetype'), q.params.linetype = L.linetype; end
    case 'point'
        q.data.x = L.x; q.data.y = L.y;
        q.params.size = L.size * 0.75;
        q.params.shape = L.shape;
        q.params.filled = L.filled;
        if isfield(L, 'cvalue')
            q.data.colour = L.cvalue;
            q.aes = {'colour'};
            q.legend = colorbar;
            q.params = rmfieldIf(q.params, 'colour');
        end
    case 'rect'
        if L.horizontal
            q.data.xmin = L.ymin; q.data.xmax = L.ymax; q.data.ymin = L.xmin; q.data.ymax = L.xmax;
        else
            q.data.xmin = L.xmin; q.data.xmax = L.xmax; q.data.ymin = L.ymin; q.data.ymax = L.ymax;
        end
        if isfield(L, 'outline') && L.outline
            q.params.colour = 'paper'; q.params.linewidth = 0.4;
            q.params.alpha = min(1, getOr(q.params, 'alpha', 1) * 1.4);
        else
            q.params.linewidth = 0;
        end
    case 'ribbon'
        q.data.x = L.x; q.data.ymin = L.ymin; q.data.ymax = L.ymax;
        q.params.alpha = getOr(q.params, 'alpha', 1) * 0.85;
    case 'polygon'
        q.data.x = L.x; q.data.y = L.y;
    case 'errorbar'
        q.data.x = L.x; q.data.ymin = L.ymin; q.data.ymax = L.ymax;
        q.params.linewidth = lineWidth(L); q.params.caps = true;
    case {'hline', 'vline'}
        q.data = struct(); q.aes = {}; q.legend = false;
        q.params = struct('colour', L.color, 'linewidth', lineWidth(L) * 0.8, 'linetype', L.linetype);
        if strcmp(L.geom, 'hline'), q.data.y = L.value; else, q.data.x = L.value; end
    case 'text'
        q.data = struct('x', L.x, 'y', L.y, 'label', L.label);
        q.aes = {'label'}; q.legend = false;
        q.params = struct('colour', L.color, 'halign', L.halign, 'fontsize', L.fontsize / 10);
end
out = {q};
end

function s = rmfieldIf(s, f)
if isfield(s, f), s = rmfield(s, f); end
end

function v = getOr(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end

% ---------------------------------------------------------------------------

function L = compact(L)
% Seven significant digits is far below print resolution and keeps the JSON
% (and the typst compile) small. Epoch-millisecond x values keep full precision.
keys = {'x', 'y', 'ymin', 'ymax', 'xmin', 'xmax', 'value', 'cvalue', 'sizes'};
for k = 1:numel(keys)
    f = keys{k};
    if ~isfield(L, f) || ~isnumeric(L.(f)), continue; end
    if any(strcmp(f, {'x', 'xmin', 'xmax', 'value'})) && isfield(L, 'xkind') && strcmp(L.xkind, 'datetime')
        continue
    end
    L.(f) = round(L.(f), 7, 'significant');
end
end

function t = tileOf(ax)
t = 1;
try
    t = ax.Layout.Tile;
catch
end
if ~isnumeric(t), t = 1; end
end

function [p, bad] = panelSpec(ax, opts)
bad = {};
if numel(ax.YAxis) > 1
    bad{end+1} = 'yyaxis (only the left axis is translated)';
end
p = struct();
p.title = textOf(ax.Title);
p.subtitle = textOf(ax.Subtitle);
p.x = axisSpec(ax, 'X');
p.y = axisSpec(ax, 'Y');
p.xlabel = textOf(ax.XLabel);
p.ylabel = textOf(ax.YLabel);
p.box = strcmp(ax.Box, 'on');
p.colorbar = ~isempty(ax.Colorbar) && isvalid(ax.Colorbar);

lg = ax.Legend;
inLegend = gobjects(0);
p.legend = struct('visible', false, 'position', 'right', 'title', '');
if ~isempty(lg) && isvalid(lg) && strcmp(lg.Visible, 'on')
    inLegend = lg.PlotChildren;
    p.legend = struct('visible', true, 'position', legendPosition(lg.Location), ...
        'title', textOf(lg.Title));
end

% allchild also returns HandleVisibility='off' objects (xline/yline helpers,
% annotations). Children are newest-first.
kids = allchild(ax);
kids = kids(~ismember(kids, [ax.Title ax.Subtitle ax.XLabel ax.YLabel ax.ZLabel]));
kids = flipud(kids);
p.layers = {};
p.series = {};                 % legend entries in legend order
for k = 1:numel(kids)
    h = kids(k);
    if strcmp(h.Visible, 'off'), continue; end
    showInLegend = any(inLegend == h);
    [layers, ok] = objectLayers(h, ax, opts);
    if ~ok
        if isa(h, 'matlab.graphics.chart.primitive.Scatter')
            bad{end+1} = sprintf('scatter with %d points (> MaxScatter)', numel(h.XData)); %#ok<AGROW>
        else
            bad{end+1} = class(h); %#ok<AGROW>
        end
        continue
    end
    for j = 1:numel(layers)
        L = layers{j};
        L.legend = showInLegend;
        p.layers{end+1} = L; %#ok<AGROW>
    end
end

% Legend entries follow the legend's own order, not plotting order.
for k = 1:numel(inLegend)
    h = inLegend(k);
    for j = 1:numel(p.layers)
        L = p.layers{j};
        if L.legend && strcmp(L.series, seriesName(h)) && ~isfield(L, 'aux')
            p.series{end+1} = struct('name', L.series, 'color', L.color); %#ok<AGROW>
            break
        end
    end
end
p.series = uniqueSeries(p.series);
end

function s = uniqueSeries(s)
names = cellfun(@(e) e.name, s, 'UniformOutput', false);
[~, keep] = unique(names, 'stable');
s = s(sort(keep));
end

function pos = legendPosition(loc)
switch lower(loc)
    case 'northoutside', pos = 'top';
    case 'southoutside', pos = 'bottom';
    case 'westoutside', pos = 'left';
    case {'eastoutside', 'bestoutside', 'layout', 'none'}, pos = 'right';
    case {'northeast', 'best'}, pos = 'top-right';
    case 'northwest', pos = 'top-left';
    case 'southeast', pos = 'bottom-right';
    case 'southwest', pos = 'bottom-left';
    case 'north', pos = 'top-center';
    case 'south', pos = 'bottom-center';
    case 'east', pos = 'right-center';
    case 'west', pos = 'left-center';
    otherwise, pos = 'right';
end
end

function a = axisSpec(ax, d)
ruler = ax.([d 'Axis']);
if numel(ruler) > 1, ruler = ruler(1); end
a = struct('scale', lower(ax.([d 'Scale'])), 'type', 'numeric', ...
    'limits', [], 'ticks', [], 'ticklabels', {{}}, 'reverse', strcmp(ax.([d 'Dir']), 'reverse'), ...
    'categories', {{}}, 'tickformat', '');
lim = ax.([d 'Lim']);
manualLim = strcmp(ax.([d 'LimMode']), 'manual');
manualTick = strcmp(ax.([d 'TickMode']), 'manual');
manualLabels = strcmp(ax.([d 'TickLabelMode']), 'manual');

if isa(ruler, 'matlab.graphics.axis.decorator.DatetimeRuler')
    a.type = 'datetime';
    if manualLim, a.limits = toEpochMs(lim); end
    if manualTick, a.ticks = toEpochMs(ax.([d 'Tick'])); end
    a.tickformat = ruler.TickLabelFormat;
elseif isa(ruler, 'matlab.graphics.axis.decorator.CategoricalRuler')
    a.type = 'categorical';
    a.categories = cellstr(ruler.Categories(:)');
    a.ticks = 1:numel(a.categories);
    a.ticklabels = a.categories;
    a.limits = [0.5 numel(a.categories) + 0.5];
elseif isa(ruler, 'matlab.graphics.axis.decorator.DurationRuler')
    a.type = 'numeric';
    if manualLim, a.limits = double(lim); end
else
    if manualLim, a.limits = double(lim); end
    if manualTick, a.ticks = double(ax.([d 'Tick'])); end
    if manualTick && manualLabels
        a.ticklabels = cellstr(string(ax.([d 'TickLabel'])))';
    end
end
end

function v = toEpochMs(t)
t.TimeZone = '';
v = milliseconds(t - datetime(1970, 1, 1));
v = double(v(:)');
end

function [v, kind] = numericData(d)
% Convert axis data to doubles, remembering datetime / categorical encodings.
kind = 'numeric';
if isdatetime(d)
    v = toEpochMs(d);
    kind = 'datetime';
elseif iscategorical(d)
    v = double(d(:)');
    kind = 'categorical';
elseif isduration(d)
    v = days(d(:)');
else
    v = double(d(:)');
end
end

function name = seriesName(h)
name = '';
if isprop(h, 'DisplayName'), name = char(h.DisplayName); end
if isempty(name), name = sprintf('series %d', seriesIndexOf(h)); end
end

function i = seriesIndexOf(h)
i = 1;
if isprop(h, 'SeriesIndex')
    i = h.SeriesIndex;
    if ~isnumeric(i) || isempty(i) || i == 0, i = 1; end
end
end

function c = colorOf(h, prop, modeProp)
% Explicit colors are hex strings; 'auto' colors become a palette slot so the
% document theme decides.
c = struct('auto', seriesIndexOf(h));
if nargin >= 3 && isprop(h, modeProp) && strcmp(h.(modeProp), 'auto')
    return
end
v = h.(prop);
if isnumeric(v) && numel(v) == 3
    c = sprintf('#%02x%02x%02x', round(255 * v));
elseif ischar(v) || isstring(v)
    switch char(v)
        case {'none'}, c = 'none';
        case {'flat', 'auto'}  % keep palette slot
        otherwise
            try
                c = sprintf('#%02x%02x%02x', round(255 * validatecolor(v)));
            catch
            end
    end
end
end

function ls = lineStyle(s)
switch char(s)
    case '--', ls = 'dashed';
    case ':', ls = 'dotted';
    case '-.', ls = 'dash-dotted';
    case 'none', ls = 'none';
    otherwise, ls = 'solid';
end
end

function m = markerShape(s)
switch char(s)
    case {'o', 'circle', '.', 'point'}, m = 'circle';
    case {'s', 'square'}, m = 'square';
    case {'d', 'diamond'}, m = 'diamond';
    case {'^', 'v', '<', '>', 'pentagram', 'p', 'hexagram', 'h'}, m = 'triangle';
    case {'x'}, m = 'x';
    case {'+', '*'}, m = 'cross';
    otherwise, m = 'none';
end
end

function L = baseLayer(geom, h)
L = struct('geom', geom, 'series', seriesName(h), 'color', struct('auto', seriesIndexOf(h)), ...
    'legend', false);
end

function [x, y, seg] = decimate(x, y, maxPoints)
% Split at NaN gaps into segments, then min/max-decimate long runs so typst
% compiles stay fast without visibly changing the line.
seg = cumsum([0, ~isfinite(y(1:end-1)) & isfinite(y(2:end))]) ;
keep = isfinite(x) & isfinite(y);
x = x(keep); y = y(keep); seg = seg(keep);
n = numel(x);
if n <= maxPoints, return; end
nb = floor(maxPoints / 2);
edges = round(linspace(0, n, nb + 1));
idx = zeros(1, 2 * nb);
for b = 1:nb
    r = edges(b) + 1:edges(b + 1);
    if isempty(r), continue; end
    [~, i1] = min(y(r)); [~, i2] = max(y(r));
    pair = sort(r([i1 i2]));
    idx(2*b-1:2*b) = pair;
end
idx = unique(idx(idx > 0));
x = x(idx); y = y(idx); seg = seg(idx);
end

function [layers, ok] = objectLayers(h, ax, opts)
layers = {};
ok = true;
switch class(h)
    case 'matlab.graphics.chart.primitive.Line'
        if ~isempty(h.ZData), ok = false; return; end
        [x, xk] = numericData(h.XData); [y, ~] = numericData(h.YData);
        if isempty(h.XData) || all(isnan(x)), x = 1:numel(y); end
        [x, y, seg] = decimate(x, y, opts.MaxPoints);
        col = colorOf(h, 'Color', 'ColorMode');
        ls = lineStyle(h.LineStyle);
        if ~strcmp(ls, 'none')
            L = baseLayer('line', h);
            L.x = x; L.y = y; L.seg = seg; L.color = col;
            L.linetype = ls; L.linewidth = h.LineWidth; L.xkind = xk;
            layers{end+1} = L;
        end
        shape = markerShape(h.Marker);
        if ~strcmp(shape, 'none')
            L = baseLayer('point', h);
            L.x = x; L.y = y; L.color = col; L.shape = shape;
            L.size = h.MarkerSize; L.filled = ~strcmp(h.MarkerFaceColor, 'none');
            if strcmp(h.Marker, '.'), L.size = h.MarkerSize / 3; L.filled = true; end
            L.xkind = xk;
            if ~isempty(layers), L.aux = true; end
            layers{end+1} = L;
        end

    case 'matlab.graphics.chart.primitive.Scatter'
        if numel(h.XData) > opts.MaxScatter
            ok = false;   % reported as unsupported -> image fallback
            return
        end
        [x, xk] = numericData(h.XData); [y, ~] = numericData(h.YData);
        L = baseLayer('point', h);
        L.x = x; L.y = y; L.xkind = xk;
        L.color = colorOf(h, 'MarkerEdgeColor');
        if strcmp(h.CDataMode, 'auto') || size(h.CData, 1) == 1
            if strcmp(h.CDataMode, 'manual') && size(h.CData, 2) == 3
                L.color = sprintf('#%02x%02x%02x', round(255 * h.CData(1, :)));
            else
                L.color = struct('auto', seriesIndexOf(h));
            end
        elseif size(h.CData, 2) == 1 || size(h.CData, 1) == 1
            L.cvalue = double(h.CData(:)');   % continuous color variable
            L.colormap = colormapHex(ax);
        end
        s = h.SizeData;
        L.size = sqrt(double(s(1)));
        if numel(s) > 1, L.sizes = sqrt(double(s(:)')); end
        L.shape = markerShape(h.Marker);
        L.filled = ~strcmp(h.MarkerFaceColor, 'none');
        L.alpha = double(h.MarkerFaceAlpha);
        if ~isnumeric(h.MarkerFaceAlpha), L.alpha = 1; end
        layers{end+1} = L;

    case 'matlab.graphics.chart.primitive.Bar'
        L = baseLayer('rect', h);
        n = numel(h.YData);
        [xe, xk] = numericData(h.XEndPoints);
        ye = double(h.YEndPoints);
        yv = double(h.YData);
        peers = findobj(ax, 'Type', 'bar');
        x = double(h.XData);
        if iscategorical(h.XData), x = double(h.XData); end
        spacing = 1;
        if numel(x) > 1, spacing = min(diff(sort(x))); end
        if numel(peers) > 1 && strcmp(h.BarLayout, 'grouped')
            m = numel(peers);
            groupWidth = min(0.8, m / (m + 1.5));
            w = h.BarWidth * spacing * groupWidth / m;
        else
            w = h.BarWidth * spacing;
        end
        base = ye - yv;
        if strcmp(h.BarLayout, 'grouped'), base = repmat(h.BaseValue, 1, n); end
        L.xmin = xe - w / 2; L.xmax = xe + w / 2;
        L.ymin = base; L.ymax = ye;
        L.horizontal = strcmp(h.Horizontal, 'on');
        L.color = colorOf(h, 'FaceColor', 'FaceColorMode');
        L.alpha = double(h.FaceAlpha);
        L.xkind = xk;
        layers{end+1} = L;

    case 'matlab.graphics.chart.primitive.Histogram'
        L = baseLayer('rect', h);
        e = double(h.BinEdges); v = double(h.Values);
        L.xmin = e(1:end-1); L.xmax = e(2:end);
        L.ymin = zeros(size(v)); L.ymax = v;
        L.horizontal = strcmp(h.Orientation, 'horizontal');
        L.color = colorOf(h, 'FaceColor');
        L.alpha = double(h.FaceAlpha);
        L.outline = true;
        L.xkind = 'numeric';
        layers{end+1} = L;

    case 'matlab.graphics.chart.primitive.Area'
        [x, xk] = numericData(h.XData);
        y = double(h.YData);
        peers = flipud(findobj(ax, 'Type', 'area'));
        below = zeros(size(y));
        for k = 1:numel(peers)
            if peers(k) == h, break; end
            if numel(peers(k).YData) == numel(y), below = below + double(peers(k).YData); end
        end
        if ~any(below), below = repmat(h.BaseValue, size(y)); end
        L = baseLayer('ribbon', h);
        L.x = x; L.ymin = below; L.ymax = below + y; L.xkind = xk;
        L.color = colorOf(h, 'FaceColor', 'FaceColorMode');
        L.alpha = double(h.FaceAlpha);
        layers{end+1} = L;

    case 'matlab.graphics.chart.primitive.Stair'
        [x, xk] = numericData(h.XData);
        L = baseLayer('step', h);
        L.x = x; L.y = double(h.YData); L.xkind = xk;
        L.color = colorOf(h, 'Color', 'ColorMode');
        L.linetype = lineStyle(h.LineStyle); L.linewidth = h.LineWidth;
        layers{end+1} = L;

    case 'matlab.graphics.chart.primitive.ErrorBar'
        [x, xk] = numericData(h.XData); y = double(h.YData);
        col = colorOf(h, 'Color', 'ColorMode');
        ls = lineStyle(h.LineStyle);
        lo = double(h.YNegativeDelta); hi = double(h.YPositiveDelta);
        if isempty(lo), lo = zeros(size(y)); end
        if isempty(hi), hi = zeros(size(y)); end
        if ~strcmp(ls, 'none')
            L = baseLayer('line', h);
            L.x = x; L.y = y; L.seg = zeros(size(x)); L.color = col;
            L.linetype = ls; L.linewidth = h.LineWidth; L.xkind = xk;
            layers{end+1} = L;
        end
        L = baseLayer('errorbar', h);
        L.x = x; L.ymin = y - lo; L.ymax = y + hi; L.color = col;
        L.linewidth = h.LineWidth; L.xkind = xk;
        if ~isempty(layers), L.aux = true; end
        layers{end+1} = L;
        shape = markerShape(h.Marker);
        if ~strcmp(shape, 'none')
            L = baseLayer('point', h);
            L.x = x; L.y = y; L.color = col; L.shape = shape;
            L.size = h.MarkerSize; L.filled = ~strcmp(h.MarkerFaceColor, 'none');
            L.xkind = xk; L.aux = true;
            layers{end+1} = L;
        end

    case 'matlab.graphics.chart.decoration.ConstantLine'
        if strcmp(h.InterceptAxis, 'x'), g = 'vline'; else, g = 'hline'; end
        L = baseLayer(g, h);
        [v, k] = numericData(h.Value);
        L.value = v; L.xkind = k;
        L.color = colorOf(h, 'Color');
        if isequal(h.Color, [0.15 0.15 0.15]), L.color = 'ink'; end  % MATLAB default
        L.linetype = lineStyle(h.LineStyle); L.linewidth = h.LineWidth;
        L.label = char(join(string(h.Label), ' '));
        layers{end+1} = L;

    case 'matlab.graphics.primitive.Text'
        L = baseLayer('text', h);
        p = h.Position;
        L.x = p(1); L.y = p(2);
        L.label = textOf(h);
        L.halign = lower(h.HorizontalAlignment);
        L.color = colorOf(h, 'Color');
        if isequal(h.Color, [0 0 0]), L.color = 'ink'; end
        L.fontsize = h.FontSize;
        layers{end+1} = L;

    case 'matlab.graphics.primitive.Patch'
        v = h.Vertices; f = h.Faces;
        if isempty(v) || size(f, 1) ~= 1, ok = false; return; end
        L = baseLayer('polygon', h);
        idx = f(isfinite(f));
        L.x = double(v(idx, 1))'; L.y = double(v(idx, 2))';
        L.color = colorOf(h, 'FaceColor');
        if isnumeric(h.FaceAlpha), L.alpha = double(h.FaceAlpha); else, L.alpha = 1; end
        layers{end+1} = L;

    case 'matlab.graphics.chart.primitive.Group'   % hggroup-ish containers
        ok = false;

    otherwise
        ok = false;
end
end

function hex = colormapHex(ax)
cm = colormap(ax);
idx = round(linspace(1, size(cm, 1), 9));
hex = arrayfun(@(i) sprintf('#%02x%02x%02x', round(255 * cm(i, :))), idx, 'UniformOutput', false);
end

function s = textOf(t)
% Title/label strings with MATLAB TeX markup reduced to plain Unicode.
s = '';
if isempty(t) || ~isprop(t, 'String'), return; end
v = t.String;
if iscell(v) || (isstring(v) && numel(v) > 1)
    v = strjoin(cellstr(v), newline);
end
s = char(v);
if isempty(s), return; end
interp = 'tex';
if isprop(t, 'Interpreter'), interp = t.Interpreter; end
if strcmp(interp, 'latex')
    s = regexprep(s, '^\$(.*)\$$', '$1');
end
if ~strcmp(interp, 'none'), s = texToUnicode(s); end
end

function s = texToUnicode(s)
greek = {'alpha','α';'beta','β';'gamma','γ';'delta','δ';'epsilon','ε';'zeta','ζ'; ...
    'eta','η';'theta','θ';'kappa','κ';'lambda','λ';'mu','μ';'nu','ν';'xi','ξ'; ...
    'pi','π';'rho','ρ';'sigma','σ';'tau','τ';'phi','φ';'chi','χ';'psi','ψ'; ...
    'omega','ω';'Gamma','Γ';'Delta','Δ';'Theta','Θ';'Lambda','Λ';'Pi','Π'; ...
    'Sigma','Σ';'Phi','Φ';'Psi','Ψ';'Omega','Ω';'infty','∞';'pm','±'; ...
    'times','×';'cdot','·';'leq','≤';'geq','≥';'neq','≠';'approx','≈'; ...
    'rightarrow','→';'leftarrow','←';'circ','°';'partial','∂';'nabla','∇'};
for k = 1:size(greek, 1)
    s = regexprep(s, ['\\' greek{k,1} '(?![a-zA-Z])'], greek{k,2});
end
sup = containers.Map(num2cell('0123456789+-n'), num2cell('⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻ⁿ'));
sub = containers.Map(num2cell('0123456789+-'), num2cell('₀₁₂₃₄₅₆₇₈₉₊₋'));
s = regexprep(s, '\^\{([^}]*)\}', '^$1');
s = mapScripts(s, '^', sup);
s = regexprep(s, '_\{([^}]*)\}', '_$1');
s = mapScripts(s, '_', sub);
s = strrep(s, '\{', '{'); s = strrep(s, '\}', '}');
end

function s = mapScripts(s, mark, table)
out = '';
i = 1;
while i <= numel(s)
    if s(i) == mark && i < numel(s)
        j = i + 1;
        buf = '';
        while j <= numel(s) && isKey(table, s(j))
            buf = [buf table(s(j))]; %#ok<AGROW>
            j = j + 1;
        end
        if ~isempty(buf)
            out = [out buf]; %#ok<AGROW>
            i = j;
            continue
        end
    end
    out = [out s(i)]; %#ok<AGROW>
    i = i + 1;
end
s = out;
end
