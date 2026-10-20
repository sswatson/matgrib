classdef Plot
    %PLOT Grammar-of-graphics plot description; build one with matgrib.gg.
    %
    %   Layers:   point line path step area ribbon col bar histogram density
    %             smooth boxplot errorbar pointrange text tile segment
    %             hline vline abline annotate
    %   Scales:   scaleX scaleY logX logY scaleColour scaleFill
    %   Layout:   labs facet facetGrid coordFlip theme
    %   Output:   show preview build json
    %
    %   Every method returns a new Plot, so calls chain:
    %     matgrib.gg(T, x="x", y="y").point().smooth().labs(title="Fit")
    %
    %   Layer methods take aesthetic overrides (x="col", colour="col", ...),
    %   fixed aesthetics (colour="red", alpha=0.5, size=3, linewidth=1.5,
    %   linetype="dashed", shape="square"), data=T2 to use other data, and
    %   inherit=false to ignore the plot-level aesthetics. Geom-specific
    %   options are documented on each method.

    properties (SetAccess = private)
        Data table = table()
        Aes struct = struct()
        Layers cell = {}
        Scales struct = struct('x', struct(), 'y', struct(), 'colour', struct(), 'fill', struct())
        Labels struct = struct()
        Facet = []
        Flip logical = false
        Options struct = struct('legend', 'right', 'aspect', [], 'maxPoints', 2500, 'maxPath', 1500)
    end

    properties (Constant, Hidden)
        AES = {'x', 'y', 'colour', 'fill', 'group', 'label', 'ymin', 'ymax', 'xmin', 'xmax', 'xend', 'yend'}
        PARAMS = {'alpha', 'size', 'linewidth', 'linetype', 'shape', 'filled', 'fontsize', 'halign'}
    end

    methods
        function p = Plot(data, args)
            if nargin < 1, data = table(); end
            if nargin < 2, args = {}; end
            p.Data = data;
            [p.Aes, extra] = matgrib.Plot.splitArgs(args);
            if ~isempty(fieldnames(extra))
                error('matgrib:gg', 'Unknown argument "%s" to matgrib.gg.', strjoin(fieldnames(extra), '", "'));
            end
        end

        % ----------------------------------------------------------- layers

        function p = point(p, varargin)
            %POINT Scatter points. Options: size (pt), shape, filled, alpha.
            p = p.addLayer('point', varargin);
        end

        function p = line(p, varargin)
            %LINE Lines connecting points in x order, one per group/colour.
            p = p.addLayer('line', varargin);
        end

        function p = path(p, varargin)
            %PATH Lines connecting points in data order.
            p = p.addLayer('path', varargin);
        end

        function p = step(p, varargin)
            %STEP Staircase lines. Options: direction="hv" (default) | "vh".
            p = p.addLayer('step', varargin);
        end

        function p = area(p, varargin)
            %AREA Filled area under y; groups stack. Options: position="stack"|"identity".
            p = p.addLayer('area', varargin);
        end

        function p = ribbon(p, varargin)
            %RIBBON Band between ymin and ymax along x.
            p = p.addLayer('ribbon', varargin);
        end

        function p = col(p, varargin)
            %COL Bars with heights y. Options: position="stack"|"dodge"|"identity", width.
            p = p.addLayer('col', varargin);
        end

        function p = bar(p, varargin)
            %BAR Bars counting rows per x. Options: position, width.
            p = p.addLayer('bar', varargin);
        end

        function p = histogram(p, varargin)
            %HISTOGRAM Binned counts of x. Options: bins=30, binwidth,
            %   normalize="count"|"density", position="stack"|"identity"|"dodge".
            p = p.addLayer('histogram', varargin);
        end

        function p = density(p, varargin)
            %DENSITY Kernel density of x. Options: adjust=1, n=256. Pass a
            %   fill (fixed or mapped) to draw filled areas.
            p = p.addLayer('density', varargin);
        end

        function p = smooth(p, varargin)
            %SMOOTH Fitted trend. Options: method="loess"|"lm", se=true,
            %   level=0.95, span=0.75 (loess), degree=1 (lm), n=80.
            p = p.addLayer('smooth', varargin);
        end

        function p = boxplot(p, varargin)
            %BOXPLOT Box-and-whisker summary of y per x. Options: width,
            %   coef=1.5, outliers=true.
            p = p.addLayer('boxplot', varargin);
        end

        function p = errorbar(p, varargin)
            %ERRORBAR Vertical intervals from ymin to ymax at x.
            p = p.addLayer('errorbar', varargin);
        end

        function p = pointrange(p, varargin)
            %POINTRANGE A point at y with an interval from ymin to ymax.
            p = p.addLayer('pointrange', varargin);
        end

        function p = text(p, varargin)
            %TEXT Text labels at (x, y). Options: fontsize (relative), halign.
            p = p.addLayer('text', varargin);
        end

        function p = tile(p, varargin)
            %TILE Rectangles centred on (x, y), e.g. heatmaps with fill.
            p = p.addLayer('tile', varargin);
        end

        function p = segment(p, varargin)
            %SEGMENT Line segments from (x, y) to (xend, yend).
            p = p.addLayer('segment', varargin);
        end

        function p = hline(p, y, varargin)
            %HLINE Horizontal reference line(s) at y.
            p = p.addLayer('hline', [{'yintercept', y}, varargin]);
        end

        function p = vline(p, x, varargin)
            %VLINE Vertical reference line(s) at x (numbers or datetimes).
            p = p.addLayer('vline', [{'xintercept', x}, varargin]);
        end

        function p = abline(p, intercept, slope, varargin)
            %ABLINE Reference line y = intercept + slope * x across the panel.
            p = p.addLayer('abline', [{'intercept', intercept, 'slope', slope}, varargin]);
        end

        function p = annotate(p, geom, varargin)
            %ANNOTATE A layer whose values are all literal, e.g.
            %   .annotate("text", x=3, y=10, label="peak")
            p = p.addLayer(char(geom), [varargin, {'inherit', false, 'literal', true, 'legend', false}]);
        end

        % ----------------------------------------------------------- scales

        function p = scaleX(p, varargin)
            %SCALEX Options: name, limits, breaks, labels, trans="log10"|"reverse",
            %   format="percent"|"percent:1"|"comma"|"dollar"|"scientific"|"fixed:2",
            %   levels (order of a discrete axis).
            p.Scales.x = matgrib.Plot.mergeOpts(p.Scales.x, varargin);
        end

        function p = scaleY(p, varargin)
            %SCALEY Same options as scaleX.
            p.Scales.y = matgrib.Plot.mergeOpts(p.Scales.y, varargin);
        end

        function p = logX(p, varargin)
            p = p.scaleX('trans', 'log10', varargin{:});
        end

        function p = logY(p, varargin)
            p = p.scaleY('trans', 'log10', varargin{:});
        end

        function p = scaleColour(p, varargin)
            %SCALECOLOUR Options: name, values (colours per level, in level
            %   order, or a dictionary level->colour), levels, palette (continuous:
            %   "viridis", "magma", "blues", "rdbu", any colormap name), limits,
            %   midpoint (centre a diverging palette).
            p.Scales.colour = matgrib.Plot.mergeOpts(p.Scales.colour, varargin);
        end

        function p = scaleColor(p, varargin)
            p = p.scaleColour(varargin{:});
        end

        function p = scaleFill(p, varargin)
            %SCALEFILL Same options as scaleColour.
            p.Scales.fill = matgrib.Plot.mergeOpts(p.Scales.fill, varargin);
        end

        % ----------------------------------------------------------- layout

        function p = labs(p, varargin)
            %LABS Options: title, subtitle, caption, x, y, colour, fill.
            p.Labels = matgrib.Plot.mergeOpts(p.Labels, varargin);
        end

        function p = facet(p, var, varargin)
            %FACET Small multiples by one variable. Options: ncol, scales=
            %   "fixed"|"free"|"free_x"|"free_y".
            o = matgrib.Plot.mergeOpts(struct('ncol', [], 'scales', 'fixed'), varargin);
            p.Facet = struct('type', 'wrap', 'var', char(var), 'ncol', o.ncol, 'scales', o.scales);
        end

        function p = facetGrid(p, varargin)
            %FACETGRID Facets in a grid. Options: rows, cols, scales.
            o = matgrib.Plot.mergeOpts(struct('rows', '', 'cols', '', 'scales', 'fixed'), varargin);
            p.Facet = struct('type', 'grid', 'rows', char(o.rows), 'cols', char(o.cols), 'scales', o.scales);
        end

        function p = coordFlip(p)
            %COORDFLIP Swap the x and y axes (horizontal bars, boxplots, ...).
            p.Flip = ~p.Flip;
        end

        function p = theme(p, varargin)
            %THEME Options: legend="right"|"bottom"|"top"|"left"|"none"|
            %   "top-right"|..., aspect (facet height / width), maxPoints
            %   (point layers are sampled above this), maxPath (per-line budget).
            p.Options = matgrib.Plot.mergeOpts(p.Options, varargin);
        end

        % ----------------------------------------------------------- output

        function display(p, ~)
            %DISPLAY Shown when an expression is left unterminated.
            p.show();
        end

        function show(p)
            %SHOW Emit into the Quarto document being rendered, else preview.
            if matgrib.emit()
                matgrib.emit(p.build());
            else
                p.preview();
            end
        end

        function fig = preview(p)
            %PREVIEW Draw an approximation with MATLAB graphics.
            fig = matgrib.preview(p.build());
        end

        function s = json(p, varargin)
            %JSON The figure spec as JSON text (pass "PrettyPrint", true).
            s = jsonencode(p.build(), varargin{:});
        end

        function disp(p)
            kinds = cellfun(@(l) l.kind, p.Layers, 'UniformOutput', false);
            fprintf('  matgrib.Plot with %d layer(s): %s\n', numel(kinds), strjoin(kinds, ', '));
        end

        function fig = build(p)
            %BUILD Resolve stats, positions and scales into a figure spec struct.
            [panel, notes] = buildPanel(p);
            fig = struct('matgrib', 2, 'title', '', 'subtitle', '', 'caption', '', ...
                'ncol', 1, 'aspect', p.Options.aspect, 'panels', {{panel}}, 'notes', {notes});
        end
    end

    methods (Access = private)
        function p = addLayer(p, kind, args)
            [aes, rest] = matgrib.Plot.splitArgs(args);
            layer = struct('kind', kind, 'aes', aes, 'params', struct(), 'opts', struct());
            f = fieldnames(rest);
            for k = 1:numel(f)
                if any(strcmp(f{k}, matgrib.Plot.PARAMS))
                    layer.params.(f{k}) = rest.(f{k});
                else
                    layer.opts.(f{k}) = rest.(f{k});
                end
            end
            p.Layers{end+1} = layer;
        end
    end

    methods (Static, Hidden)
        function [aes, rest] = splitArgs(args)
            aes = struct(); rest = struct();
            if mod(numel(args), 2) ~= 0
                error('matgrib:args', 'Arguments must be name/value pairs.');
            end
            for k = 1:2:numel(args)
                name = lower(char(args{k}));
                if strcmp(name, 'color'), name = 'colour'; end
                if any(strcmp(name, matgrib.Plot.AES))
                    aes.(name) = args{k + 1};
                else
                    rest.(name) = args{k + 1};
                end
            end
        end

        function s = mergeOpts(s, args)
            if mod(numel(args), 2) ~= 0
                error('matgrib:args', 'Arguments must be name/value pairs.');
            end
            for k = 1:2:numel(args)
                name = char(args{k});
                if strcmpi(name, 'color'), name = 'colour'; end
                s.(name) = args{k + 1};
            end
        end
    end
end

% =========================================================================
% Build: resolve layers -> train scales -> stats/positions -> primitives
% =========================================================================

function [panel, notes] = buildPanel(p)
notes = {};
L = cellfun(@(l) resolveLayer(p, l), p.Layers, 'UniformOutput', false);

ax.x = trainPosition(L, {'x', 'xmin', 'xmax', 'xend'}, 'xintercept', p.Scales.x);
ax.y = trainPosition(L, {'y', 'ymin', 'ymax', 'yend'}, 'yintercept', p.Scales.y);
cs.colour = trainColour(L, 'colour', p.Scales.colour);
cs.fill = trainColour(L, 'fill', p.Scales.fill);
facetInfo = trainFacet(L, p.Facet);

prims = {};
for k = 1:numel(L)
    [out, n] = layerPrimitives(L{k}, ax, cs, p.Options);
    prims = [prims out]; %#ok<AGROW>
    notes = [notes n]; %#ok<AGROW>
end
prims = resolveAblines(prims, L);

% Smooth ribbons and filled densities reuse colour levels on fill.
if isempty(cs.fill) && any(cellfun(@(q) any(strcmp(q.aes, 'fill')), prims)) && ~isempty(cs.colour)
    cs.fill = cs.colour;
end

xa = axisSpec(ax.x, p.Scales.x, labelFor(p, L, 'x'));
ya = axisSpec(ax.y, p.Scales.y, labelFor(p, L, 'y'));
if p.Flip
    prims = cellfun(@flipPrimitive, prims, 'UniformOutput', false);
    [xa, ya] = deal(ya, xa);
end

panel = struct();
panel.title = getOr(p.Labels, 'title', '');
panel.subtitle = getOr(p.Labels, 'subtitle', '');
panel.caption = getOr(p.Labels, 'caption', '');
panel.x = xa;
panel.y = ya;
panel.colour = colourSpec(cs.colour, getOr(p.Labels, 'colour', nameFor(L, 'colour')));
panel.fill = colourSpec(cs.fill, getOr(p.Labels, 'fill', nameFor(L, 'fill')));
panel.legend = char(p.Options.legend);
panel.facet = facetInfo.spec;
panel.layers = cellfun(@finalise, prims, 'UniformOutput', false);
end

function v = getOr(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
if isstring(v), v = char(v); end
end

% ------------------------------------------------------------- resolution

function R = resolveLayer(p, layer)
o = layer.opts;
R = struct('kind', layer.kind, 'opts', o, 'params', layer.params, ...
    'vals', struct(), 'names', struct(), 'n', 0, 'facet', struct());
literal = isfield(o, 'literal') && o.literal;
if isfield(o, 'data')
    D = o.data;
    if isstruct(D), D = struct2table(D); end
    if istimetable(D), D = timetable2table(D); end
elseif literal
    D = table();
else
    D = p.Data;
end
aes = layer.aes;
if ~isfield(o, 'inherit') || o.inherit
    f = fieldnames(p.Aes);
    for k = 1:numel(f)
        if ~isfield(aes, f{k}), aes.(f{k}) = p.Aes.(f{k}); end
    end
end
cols = D.Properties.VariableNames;
n = height(D);
keys = fieldnames(aes);
raw = struct();
for k = 1:numel(keys)
    key = keys{k};
    v = aes.(key);
    if isempty(v) && ~ischar(v), continue; end   % x=[] removes an inherited mapping
    isName = (ischar(v) || (isstring(v) && isscalar(v))) && ~literal;
    if isName && any(strcmp(char(v), cols))
        raw.(key) = D.(char(v));
        R.names.(key) = char(v);
    elseif isName && any(strcmp(key, {'colour', 'fill'}))
        R.params.(key) = v;          % a colour, not a column
    elseif isName && ~strcmp(key, 'label')
        error('matgrib:column', 'No column named "%s" for aesthetic %s.', char(v), key);
    else
        raw.(key) = v;
    end
end
% Literal vectors set the row count when there is no table.
keys = fieldnames(raw);
if n == 0
    for k = 1:numel(keys), n = max(n, numel(raw.(keys{k}))); end
end
for k = 1:numel(keys)
    v = raw.(keys{k});
    if ischar(v), v = string(v); end
    if isscalar(v) && n > 1, v = repmat(v, n, 1); end
    if numel(v) ~= n
        error('matgrib:length', 'Aesthetic %s has %d values but the data has %d rows.', keys{k}, numel(v), n);
    end
    R.vals.(keys{k}) = v(:);
end
R.n = n;
if ~isempty(p.Facet)
    if strcmp(p.Facet.type, 'wrap')
        vars = {'facet', p.Facet.var};
    else
        vars = {'facet_row', p.Facet.rows; 'facet_col', p.Facet.cols};
        vars = reshape(vars', 1, []);
    end
    for k = 1:2:numel(vars)
        if ~isempty(vars{k + 1}) && any(strcmp(vars{k + 1}, cols)) && ~literal
            R.facet.(vars{k}) = levelStrings(D.(vars{k + 1}));
        end
    end
end
end

function s = levelStrings(v)
if iscategorical(v) || islogical(v) || isnumeric(v) || isdatetime(v)
    s = string(v);
else
    s = string(v);
end
s = s(:);
s(ismissing(s)) = "NA";
end

function t = valueType(v)
if isdatetime(v), t = 'date';
elseif isnumeric(v), t = 'continuous';
else, t = 'discrete';
end
end

function A = trainPosition(L, keys, interceptKey, opts)
A = struct('type', '', 'levels', {{}});
vals = {};
for k = 1:numel(L)
    for j = 1:numel(keys)
        if isfield(L{k}.vals, keys{j}), vals{end+1} = L{k}.vals.(keys{j}); end %#ok<AGROW>
    end
    if isfield(L{k}.opts, interceptKey), vals{end+1} = L{k}.opts.(interceptKey)(:); end %#ok<AGROW>
end
types = cellfun(@valueType, vals, 'UniformOutput', false);
if any(strcmp(types, 'discrete')), A.type = 'discrete';
elseif any(strcmp(types, 'date')), A.type = 'date';
else, A.type = 'continuous';
end
if strcmp(A.type, 'discrete')
    if isfield(opts, 'levels')
        A.levels = cellstr(string(opts.levels));
    else
        lv = strings(0, 1);
        for k = 1:numel(vals)
            v = vals{k};
            if iscategorical(v)
                c = string(categories(v));
                lv = [lv; c(ismember(c, string(v)))]; %#ok<AGROW>
            elseif ~isnumeric(v)
                lv = [lv; levelStrings(v)]; %#ok<AGROW>
            end
        end
        A.levels = cellstr(unique(lv, 'stable'))';
    end
end
end

function x = encode(A, v)
switch A.type
    case 'date'
        if ~isdatetime(v), x = double(v); return; end
        v.TimeZone = '';
        x = milliseconds(v - datetime(1970, 1, 1));
    case 'discrete'
        if isnumeric(v), x = double(v); return; end
        [~, x] = ismember(levelStrings(v), string(A.levels));
        x = double(x); x(x == 0) = NaN;
    otherwise
        x = double(v);
end
x = x(:);
end

function C = trainColour(L, key, opts)
C = [];
vals = {};
for k = 1:numel(L)
    if isfield(L{k}.vals, key), vals{end+1} = L{k}.vals.(key); end %#ok<AGROW>
end
if isempty(vals), return; end
if all(cellfun(@(v) isnumeric(v) && ~isfield(opts, 'levels'), vals))
    allv = cell2mat(cellfun(@(v) double(v(:)), vals(:), 'UniformOutput', false));
    lim = [min(allv) max(allv)];
    if isfield(opts, 'limits'), lim = double(opts.limits); end
    if isfield(opts, 'midpoint')
        r = max(abs(lim - opts.midpoint));
        lim = opts.midpoint + [-r r];
    end
    pal = 'viridis';
    if isfield(opts, 'midpoint'), pal = 'rdbu'; end
    if isfield(opts, 'palette'), pal = opts.palette; end
    C = struct('type', 'continuous', 'limits', lim, 'colours', {mgPalette(pal)});
else
    if isfield(opts, 'levels')
        lv = string(opts.levels(:));
    else
        lv = strings(0, 1);
        for k = 1:numel(vals)
            v = vals{k};
            if iscategorical(v)
                c = string(categories(v));
                lv = [lv; c(ismember(c, string(v)))]; %#ok<AGROW>
            else
                lv = [lv; levelStrings(v)]; %#ok<AGROW>
            end
        end
        lv = unique(lv, 'stable');
    end
    values = cell(1, numel(lv));
    for i = 1:numel(lv), values{i} = struct('auto', i); end
    if isfield(opts, 'values')
        v = opts.values;
        if isa(v, 'dictionary')
            for i = 1:numel(lv)
                if isKey(v, lv(i)), values{i} = mgColour(v(lv(i))); end
            end
        else
            if isnumeric(v) && size(v, 2) == 3, v = num2cell(v, 2); end
            v = cellstr(string(v));
            for i = 1:min(numel(v), numel(lv)), values{i} = mgColour(v{i}); end
        end
    end
    C = struct('type', 'discrete', 'levels', {cellstr(lv)'}, 'values', {values});
end
end

function F = trainFacet(L, facet)
F = struct('spec', []);
if isempty(facet), return; end
pick = @(key) pickFacet(L, key);
if strcmp(facet.type, 'wrap')
    lv = cellstr(pick('facet'))';
    ncol = facet.ncol;
    if isempty(ncol), ncol = ceil(sqrt(numel(lv))); end
    F.spec = struct('type', 'wrap', 'ncol', ncol, 'levels', {lv}, 'scales', char(facet.scales));
else
    F.spec = struct('type', 'grid', 'rows', {cellstr(pick('facet_row'))'}, ...
        'cols', {cellstr(pick('facet_col'))'}, 'scales', char(facet.scales));
end
end

function v = pickFacet(L, key)
v = strings(0, 1);
for k = 1:numel(L), v = [v; getFacet(L{k}, key)]; end %#ok<AGROW>
v = unique(v, 'stable');
end

function v = getFacet(l, key)
if isfield(l.facet, key), v = unique(l.facet.(key), 'stable'); else, v = strings(0, 1); end
end

% ------------------------------------------------------------- stats

function [prims, notes] = layerPrimitives(R, ax, cs, options)
notes = {};
o = R.opts;
kind = R.kind;
% Encoded numeric positions.
E = struct();
pos = {'x', 'xmin', 'xmax', 'xend'; 'y', 'ymin', 'ymax', 'yend'};
for a = 1:2
    for j = 1:4
        k = pos{a, j};
        if isfield(R.vals, k)
            E.(k) = encode(ax.(pos{a, 1}), R.vals.(k));
        end
    end
end
% Meta columns carried through stats.
M = struct();
mapped = {};
for key = {'colour', 'fill'}
    k = key{1};
    if isfield(R.vals, k)
        v = R.vals.(k);
        if isnumeric(v) && strcmp(cs.(k).type, 'continuous'), M.(k) = double(v);
        else, M.(k) = levelStrings(v);
        end
        mapped{end+1} = k; %#ok<AGROW>
    end
end
if isfield(R.vals, 'group'), M.group = levelStrings(R.vals.group); end
if isfield(R.vals, 'label'), M.label = string(R.vals.label); end
fk = fieldnames(R.facet);
for k = 1:numel(fk), M.(fk{k}) = R.facet.(fk{k}); end

% Group = discrete meta interaction (the unit stats run over).
g = repmat("", R.n, 1);
for key = {'colour', 'fill', 'group', 'facet', 'facet_row', 'facet_col'}
    k = key{1};
    if isfield(M, k) && ~isnumeric(M.(k)), g = g + "|" + M.(k); end
end
% First-appearance order, so facets and dodged bars follow the data rather
% than an alphabetical sort.
[~, ~, G] = unique(g, 'stable');
G = G(:);
ng = max([G; 0]);

legendOn = ~isfield(o, 'legend') || o.legend;
par = normaliseParams(R.params);
res = resolution(E, ax);
prims = {};

switch kind
    case 'point'
        need(E, {'x', 'y'}, kind);
        keep = isfinite(E.x) & isfinite(E.y);
        rows = find(keep);
        idx = mgThin('sample', rows, rows, options.maxPoints);
        if numel(idx) < numel(rows)
            notes{end+1} = sprintf('point layer sampled to %d of %d rows', numel(idx), numel(rows));
        end
        rows = rows(idx);
        prims{1} = prim('point', cols(E, M, rows, {'x', 'y'}), mapped, legendOn, ...
            defaults(par, struct('colour', struct('auto', 1), 'size', 4.5, 'shape', 'circle', 'filled', true)));

    case {'line', 'path', 'step'}
        need(E, {'x', 'y'}, kind);
        X = []; Y = []; idx = []; grp = strings(0, 1);
        thinned = false;
        for i = 1:ng
            r = find(G == i);
            if ~strcmp(kind, 'path'), [~, s] = sort(E.x(r)); r = r(s); end
            x = E.x(r); y = E.y(r);
            seg = cumsum([0; ~isfinite(y(1:end-1)) & isfinite(y(2:end))]);
            ok = isfinite(x) & isfinite(y);
            r = r(ok); x = x(ok); y = y(ok); seg = seg(ok);
            for s = unique(seg)'
                q = seg == s;
                xs = x(q); ys = y(q); rs = r(q);
                if strcmp(kind, 'step')
                    [xs, ys, rs] = staircase(xs, ys, rs, getOr(o, 'direction', 'hv'));
                end
                t = mgThin('minmax', xs, ys, options.maxPath);
                thinned = thinned || numel(t) < numel(xs);
                X = [X; xs(t)]; Y = [Y; ys(t)]; idx = [idx; rs(t)]; %#ok<AGROW>
                grp = [grp; repmat(string(i) + "." + s, numel(t), 1)]; %#ok<AGROW>
            end
        end
        if thinned, notes{end+1} = sprintf('%s layer decimated to %d points per series', kind, options.maxPath); end
        d = cols(struct('x', X, 'y', Y), M, idx, {'x', 'y'}, true);
        d.group = cellstr(grp)';
        prims{1} = prim('path', d, [mapped {'group'}], legendOn, ...
            defaults(par, struct('colour', struct('auto', 1), 'linewidth', 1)));

    case {'area', 'ribbon'}
        if strcmp(kind, 'area')
            need(E, {'x', 'y'}, kind);
            position = getOr(o, 'position', 'stack');
            [E.ymin, E.ymax] = stackY(E.x, E.y, G, position);
        else
            need(E, {'x', 'ymin', 'ymax'}, kind);
        end
        X = []; lo = []; hi = []; idx = []; grp = strings(0, 1);
        for i = 1:ng
            r = find(G == i);
            [~, s] = sort(E.x(r)); r = r(s);
            r = r(isfinite(E.x(r)) & isfinite(E.ymin(r)) & isfinite(E.ymax(r)));
            X = [X; E.x(r)]; lo = [lo; E.ymin(r)]; hi = [hi; E.ymax(r)]; idx = [idx; r]; %#ok<AGROW>
            grp = [grp; repmat(string(i), numel(r), 1)]; %#ok<AGROW>
        end
        d = cols(struct('x', X, 'ymin', lo, 'ymax', hi), M, idx, {'x', 'ymin', 'ymax'}, true);
        d.group = cellstr(grp)';
        fillMapped = mapped(strcmp(mapped, 'fill'));
        if isempty(fillMapped) && any(strcmp(mapped, 'colour')) && ~isfield(par, 'fill')
            d.fill = d.colour; fillMapped = {'fill'};
        end
        prims{1} = prim('ribbon', d, [fillMapped {'group'}], legendOn, ...
            defaults(par, struct('fill', struct('auto', 1), 'alpha', ifelse(strcmp(kind, 'area'), 0.85, 0.35))));

    case {'col', 'bar', 'histogram'}
        if strcmp(kind, 'histogram')
            need(E, {'x'}, kind);
            [xmin, xmax, y, idx] = binned(E.x, G, ng, o);
            if strcmp(getOr(o, 'normalize', 'count'), 'density')
                for i = 1:ng
                    q = G(idx) == i;
                    y(q) = y(q) / (sum(y(q)) * (xmax(1) - xmin(1)));
                end
            end
            position = getOr(o, 'position', 'stack');
            [ymin, ymax] = stackY((xmin + xmax) / 2, y, G(idx), position);
            if strcmp(position, 'dodge')
                [xmin, xmax] = dodge((xmin + xmax) / 2, G(idx), xmax - xmin);
            end
            d = cols(struct('xmin', xmin, 'xmax', xmax, 'ymin', ymin, 'ymax', ymax), M, idx, {'xmin', 'xmax', 'ymin', 'ymax'}, true);
        else
            need(E, {'x'}, kind);
            if strcmp(kind, 'bar')
                [x, y, idx] = counted(E.x, G, ng);
            else
                need(E, {'y'}, kind);
                idx = find(isfinite(E.x) & isfinite(E.y));
                x = E.x(idx); y = E.y(idx);
            end
            w = getOr(o, 'width', 0.9) * res;
            position = getOr(o, 'position', 'stack');
            [ymin, ymax] = stackY(x, y, G(idx), position);
            if strcmp(position, 'dodge')
                [xmin, xmax] = dodge(x, G(idx), w);
            else
                xmin = x - w / 2; xmax = x + w / 2;
            end
            d = cols(struct('xmin', xmin, 'xmax', xmax, 'ymin', ymin, 'ymax', ymax), M, idx, {'xmin', 'xmax', 'ymin', 'ymax'}, true);
        end
        [d, fm] = fillFromColour(d, mapped, par);
        prims{1} = prim('rect', d, fm, legendOn, ...
            defaults(par, struct('fill', struct('auto', 1), 'linewidth', ifelse(strcmp(kind, 'histogram'), 0.4, 0))));
        if strcmp(kind, 'histogram') && ~isfield(par, 'colour'), prims{1}.params.colour = 'paper'; end

    case 'density'
        need(E, {'x'}, kind);
        X = []; Y = []; idx = []; grp = strings(0, 1);
        for i = 1:ng
            r = find(G == i & isfinite(E.x));
            if numel(r) < 2, continue; end
            [xs, ys] = mgStats('kde', E.x(r), getOr(o, 'adjust', 1), getOr(o, 'n', 256));
            X = [X; xs(:)]; Y = [Y; ys(:)]; idx = [idx; repmat(r(1), numel(xs), 1)]; %#ok<AGROW>
            grp = [grp; repmat(string(i), numel(xs), 1)]; %#ok<AGROW>
        end
        hasFill = any(strcmp(mapped, 'fill')) || isfield(par, 'fill');
        if hasFill
            d = cols(struct('x', X, 'ymin', 0 * X, 'ymax', Y), M, idx, {'x', 'ymin', 'ymax'}, true);
            d.group = cellstr(grp)';
            prims{end+1} = prim('ribbon', d, [mapped(strcmp(mapped, 'fill')) {'group'}], legendOn, ...
                defaults(par, struct('alpha', 0.4)));
        end
        d = cols(struct('x', X, 'y', Y), M, idx, {'x', 'y'}, true);
        d.group = cellstr(grp)';
        lp = rmfieldIf(par, 'fill');
        prims{end+1} = prim('path', d, [mapped(strcmp(mapped, 'colour')) {'group'}], legendOn && ~hasFill, ...
            defaults(lp, struct('colour', ifelse(any(strcmp(mapped, 'colour')), 'ink', struct('auto', 1)), 'linewidth', 0.9)));

    case 'smooth'
        need(E, {'x', 'y'}, kind);
        method = char(getOr(o, 'method', 'loess'));
        level = getOr(o, 'level', 0.95);
        n = getOr(o, 'n', 80);
        X = []; Y = []; lo = []; hi = []; idx = []; grp = strings(0, 1);
        for i = 1:ng
            r = find(G == i & isfinite(E.x) & isfinite(E.y));
            if numel(r) < 3, continue; end
            switch method
                case 'lm', [xs, yh, l, h] = mgStats('lm', E.x(r), E.y(r), level, n, getOr(o, 'degree', 1));
                case 'loess', [xs, yh, l, h] = mgStats('loess', E.x(r), E.y(r), getOr(o, 'span', 0.75), level, n);
                otherwise, error('matgrib:smooth', 'Unknown smooth method "%s" (use "loess" or "lm").', method);
            end
            X = [X; xs(:)]; Y = [Y; yh(:)]; lo = [lo; l(:)]; hi = [hi; h(:)]; %#ok<AGROW>
            idx = [idx; repmat(r(1), numel(xs), 1)]; grp = [grp; repmat(string(i), numel(xs), 1)]; %#ok<AGROW>
        end
        if getOr(o, 'se', true)
            d = cols(struct('x', X, 'ymin', lo, 'ymax', hi), M, idx, {'x', 'ymin', 'ymax'}, true);
            d.group = cellstr(grp)';
            fm = {};
            if any(strcmp(mapped, 'colour')) && ~isnumeric(M.colour), d.fill = d.colour; fm = {'fill'}; end
            prims{end+1} = prim('ribbon', d, [fm {'group'}], false, ...
                struct('fill', ifelse(isempty(fm), 'ink', struct('auto', 1)), 'alpha', ifelse(isempty(fm), 0.15, 0.2)));
        end
        d = cols(struct('x', X, 'y', Y), M, idx, {'x', 'y'}, true);
        d.group = cellstr(grp)';
        prims{end+1} = prim('path', d, [mapped(strcmp(mapped, 'colour')) {'group'}], legendOn, ...
            defaults(par, struct('colour', struct('auto', 1), 'linewidth', 1.2)));

    case 'boxplot'
        need(E, {'y'}, kind);
        if ~isfield(E, 'x'), E.x = ones(R.n, 1); end
        coef = getOr(o, 'coef', 1.5);
        keyx = findgroups(G, E.x);
        B = struct('x', [], 'lower', [], 'middle', [], 'upper', [], 'ymin', [], 'ymax', [], 'row', []);
        outx = []; outy = []; outrow = [];
        for i = 1:max([keyx; 0])
            r = find(keyx == i);
            b = mgStats('box', E.y(r), coef);
            B.x(end+1, 1) = E.x(r(1)); B.lower(end+1, 1) = b.lower; B.middle(end+1, 1) = b.middle;
            B.upper(end+1, 1) = b.upper; B.ymin(end+1, 1) = b.ymin; B.ymax(end+1, 1) = b.ymax; B.row(end+1, 1) = r(1);
            outy = [outy; b.outliers(:)]; outx = [outx; repmat(i, numel(b.outliers), 1)]; %#ok<AGROW>
            outrow = [outrow; repmat(r(1), numel(b.outliers), 1)]; %#ok<AGROW>
        end
        w = getOr(o, 'width', 0.75) * res;
        [xmin, xmax] = dodge(B.x, G(B.row), w);
        xc = (xmin + xmax) / 2;
        boxMapped = mapped;
        lp = defaults(par, struct('colour', 'ink', 'fill', 'paper', 'linewidth', 0.6));
        d = cols(struct('xmin', xmin, 'xmax', xmax, 'ymin', B.lower, 'ymax', B.upper), M, B.row, {'xmin', 'xmax', 'ymin', 'ymax'}, true);
        prims{end+1} = prim('rect', d, boxMapped, legendOn, lp);
        segs = struct('x', [xc; xc; xmin], 'y', [B.upper; B.lower; B.middle], ...
            'xend', [xc; xc; xmax], 'yend', [B.ymax; B.ymin; B.middle]);
        d = cols(segs, M, [B.row; B.row; B.row], {'x', 'y', 'xend', 'yend'}, true);
        prims{end+1} = prim('segment', d, mapped(strcmp(mapped, 'colour')), false, rmfieldIf(lp, 'fill'));
        if getOr(o, 'outliers', true) && ~isempty(outy)
            d = cols(struct('x', xc(outx), 'y', outy), M, outrow, {'x', 'y'}, true);
            prims{end+1} = prim('point', d, mapped(strcmp(mapped, 'colour')), false, ...
                struct('colour', lp.colour, 'size', 3, 'shape', 'circle', 'filled', true));
        end

    case {'errorbar', 'pointrange'}
        need(E, {'x', 'ymin', 'ymax'}, kind);
        r = find(isfinite(E.x) & isfinite(E.ymin) & isfinite(E.ymax));
        lp = defaults(par, struct('colour', ifelse(isempty(mapped), 'ink', struct('auto', 1)), 'linewidth', 0.8));
        lp.caps = strcmp(kind, 'errorbar');
        d = cols(E, M, r, {'x', 'ymin', 'ymax'});
        prims{end+1} = prim('errorbar', d, mapped(strcmp(mapped, 'colour')), legendOn, rmfieldIf(lp, 'fill'));
        if strcmp(kind, 'pointrange')
            need(E, {'y'}, kind);
            d = cols(E, M, r, {'x', 'y'});
            prims{end+1} = prim('point', d, mapped(strcmp(mapped, 'colour')), false, ...
                defaults(rmfieldIf(par, 'linewidth'), struct('colour', lp.colour, 'size', 5, 'filled', true, 'shape', 'circle')));
        end

    case 'text'
        need(E, {'x', 'y'}, kind);
        if ~isfield(M, 'label'), error('matgrib:text', 'text needs a label aesthetic.'); end
        r = find(isfinite(E.x) & isfinite(E.y));
        d = cols(E, M, r, {'x', 'y'});
        d.label = cellstr(M.label(r))';
        prims{1} = prim('text', d, [mapped(strcmp(mapped, 'colour')) {'label'}], false, ...
            defaults(par, struct('colour', 'ink', 'fontsize', 0.9, 'halign', 'center')));

    case 'tile'
        need(E, {'x', 'y'}, kind);
        rx = res;
        ry = resolution(struct('x', E.y), struct('x', ax.y));
        r = find(isfinite(E.x) & isfinite(E.y));
        w = getOr(o, 'width', 1) * rx; h = getOr(o, 'height', 1) * ry;
        d = cols(struct('xmin', E.x - w/2, 'xmax', E.x + w/2, 'ymin', E.y - h/2, 'ymax', E.y + h/2), ...
            M, r, {'xmin', 'xmax', 'ymin', 'ymax'});
        [d, fm] = fillFromColour(d, mapped, par);
        prims{1} = prim('rect', d, fm, legendOn, defaults(par, struct('fill', struct('auto', 1), 'linewidth', 0)));

    case 'segment'
        need(E, {'x', 'y', 'xend', 'yend'}, kind);
        r = find(isfinite(E.x) & isfinite(E.y) & isfinite(E.xend) & isfinite(E.yend));
        prims{1} = prim('segment', cols(E, M, r, {'x', 'y', 'xend', 'yend'}), mapped(strcmp(mapped, 'colour')), legendOn, ...
            defaults(par, struct('colour', 'ink', 'linewidth', 0.8)));

    case {'hline', 'vline'}
        if strcmp(kind, 'hline')
            v = encode(ax.y, o.yintercept(:)); key = 'y';
        else
            v = encode(ax.x, o.xintercept(:)); key = 'x';
        end
        prims{1} = prim(kind, struct(key, v'), {}, false, ...
            defaults(par, struct('colour', 'ink', 'linewidth', 0.7, 'linetype', 'dashed')));

    case 'abline'
        prims{1} = prim('abline', struct('intercept', o.intercept, 'slope', o.slope), {}, false, ...
            defaults(par, struct('colour', 'ink', 'linewidth', 0.7, 'linetype', 'dashed')));

    otherwise
        error('matgrib:geom', 'Unknown layer type "%s".', kind);
end
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end

function s = rmfieldIf(s, f)
if isfield(s, f), s = rmfield(s, f); end
end

function need(E, keys, kind)
for k = 1:numel(keys)
    if ~isfield(E, keys{k})
        error('matgrib:aes', '%s needs the %s aesthetic.', kind, keys{k});
    end
end
end

function par = normaliseParams(par)
if isfield(par, 'colour'), par.colour = mgColour(par.colour); end
if isfield(par, 'fill'), par.fill = mgColour(par.fill); end
if isfield(par, 'linetype'), par.linetype = mgStyle('linetype', par.linetype); end
if isfield(par, 'shape'), par.shape = mgStyle('shape', par.shape); end
if isfield(par, 'halign'), par.halign = char(par.halign); end
end

function s = defaults(s, d)
f = fieldnames(d);
for k = 1:numel(f)
    if ~isfield(s, f{k}), s.(f{k}) = d.(f{k}); end
end
end

function [d, fm] = fillFromColour(d, mapped, par)
% Bars/tiles are filled shapes: a mapped colour means fill.
fm = mapped(strcmp(mapped, 'fill'));
if isempty(fm) && any(strcmp(mapped, 'colour')) && ~isfield(par, 'fill')
    d.fill = d.colour;
    d = rmfield(d, 'colour');
    fm = {'fill'};
elseif any(strcmp(mapped, 'colour'))
    fm = [fm {'colour'}];
end
end

function r = resolution(E, ax)
if ~isfield(E, 'x') || strcmp(ax.x.type, 'discrete'), r = 1; return; end
u = unique(E.x(isfinite(E.x)));
if numel(u) < 2, r = 1; else, r = min(diff(u)); end
end

function d = cols(E, M, rows, keys, aligned)
% Assemble output columns. With aligned=true, E's columns are already the
% output rows and `rows` indexes meta rows; otherwise both are indexed.
if nargin < 5, aligned = false; end
d = struct();
for k = 1:numel(keys)
    v = E.(keys{k});
    if ~aligned, v = v(rows); end
    d.(keys{k}) = v(:)';
end
f = fieldnames(M);
for k = 1:numel(f)
    v = M.(f{k});
    v = v(rows);
    if isnumeric(v), d.(f{k}) = v(:)'; else, d.(f{k}) = cellstr(v(:))'; end
end
end

function q = prim(geom, data, aes, legend, params)
q = struct('geom', geom, 'data', data, 'aes', {aes}, 'legend', legend, 'params', params);
end

function [xs, ys, rs] = staircase(x, y, r, direction)
n = numel(x);
if n < 2, xs = x; ys = y; rs = r; return; end
k = 2 * n - 1;
xs = zeros(k, 1); ys = xs; rs = xs;
xs(1:2:end) = x; ys(1:2:end) = y; rs(1:2:end) = r;
if strcmp(direction, 'vh')
    xs(2:2:end) = x(1:end-1); ys(2:2:end) = y(2:end);
else
    xs(2:2:end) = x(2:end); ys(2:2:end) = y(1:end-1);
end
rs(2:2:end) = r(1:end-1);
end

function [ymin, ymax] = stackY(x, y, G, position)
x = x(:); y = y(:); G = G(:);
ymin = zeros(size(y)); ymax = y;
if ~strcmp(position, 'stack'), return; end
[ux, ~, xi] = unique(x);
pos = zeros(numel(ux), 1); neg = pos;
[~, order] = sortrows([G (1:numel(G))']);
for j = order'
    if ~isfinite(y(j)), continue; end
    if y(j) >= 0
        ymin(j) = pos(xi(j)); pos(xi(j)) = pos(xi(j)) + y(j);
    else
        ymin(j) = neg(xi(j)); neg(xi(j)) = neg(xi(j)) + y(j);
    end
    ymax(j) = ymin(j) + y(j);
end
end

function [xmin, xmax] = dodge(x, G, w)
x = x(:); G = G(:);
if isscalar(w), w = repmat(w, size(x)); end
xmin = x - w / 2; xmax = x + w / 2;
[ux, ~, xi] = unique(x);
for i = 1:numel(ux)
    r = find(xi == i);
    [~, o] = sort(G(r));
    r = r(o);
    m = numel(r);
    for j = 1:m
        lo = x(r(j)) - w(r(j)) / 2 + (j - 1) * w(r(j)) / m;
        xmin(r(j)) = lo; xmax(r(j)) = lo + w(r(j)) / m;
    end
end
end

function [x, y, idx] = counted(xv, G, ng)
x = []; y = []; idx = [];
for i = 1:ng
    r = find(G == i & isfinite(xv));
    [u, ~, j] = unique(xv(r));
    c = accumarray(j, 1);
    first = arrayfun(@(k) r(find(j == k, 1)), 1:numel(u))';
    x = [x; u]; y = [y; c]; idx = [idx; first]; %#ok<AGROW>
end
end

function [xmin, xmax, y, idx] = binned(xv, G, ng, o)
v = xv(isfinite(xv));
lo = min(v); hi = max(v);
if isfield(o, 'binwidth')
    bw = o.binwidth;
    edges = (floor(lo / bw) * bw):bw:(ceil(hi / bw) * bw + bw / 2);
else
    nb = getOr(o, 'bins', 30);
    if hi == lo, hi = lo + 1; end
    edges = linspace(lo, hi, nb + 1);
end
if numel(edges) < 2, edges = [lo lo + 1]; end
xmin = []; xmax = []; y = []; idx = [];
for i = 1:ng
    r = find(G == i & isfinite(xv));
    if isempty(r), continue; end
    c = histcounts(xv(r), edges);
    xmin = [xmin; edges(1:end-1)']; xmax = [xmax; edges(2:end)']; %#ok<AGROW>
    y = [y; c(:)]; idx = [idx; repmat(r(1), numel(c), 1)]; %#ok<AGROW>
end
end

function prims = resolveAblines(prims, ~)
xs = [];
for k = 1:numel(prims)
    d = prims{k}.data;
    for f = {'x', 'xmin', 'xmax', 'xend'}
        if isfield(d, f{1}) && isnumeric(d.(f{1})), xs = [xs d.(f{1})]; end %#ok<AGROW>
    end
end
if isempty(xs), xs = [0 1]; end
for k = 1:numel(prims)
    if ~strcmp(prims{k}.geom, 'abline'), continue; end
    a = prims{k}.data.intercept; b = prims{k}.data.slope;
    x0 = min(xs); x1 = max(xs);
    prims{k}.geom = 'segment';
    prims{k}.data = struct('x', x0, 'y', a + b * x0, 'xend', x1, 'yend', a + b * x1);
end
end

% ------------------------------------------------------------- flip / spec

function q = flipPrimitive(q)
d = q.data;
switch q.geom
    case 'ribbon'
        % A horizontal band is a polygon once the axes swap.
        g = string(getOr(d, 'group', {''}));
        if isscalar(g), g = repmat(g, size(d.x)); end
        X = []; Y = []; grp = {}; keepIdx = [];
        for u = unique(g, 'stable')
            r = find(g == u);
            X = [X d.x(r) fliplr(d.x(r))]; Y = [Y d.ymin(r) fliplr(d.ymax(r))]; %#ok<AGROW>
            grp = [grp repmat({char(u)}, 1, 2 * numel(r))]; %#ok<AGROW>
            keepIdx = [keepIdx r fliplr(r)]; %#ok<AGROW>
        end
        nd = struct('x', Y, 'y', X, 'group', {grp});
        for f = {'fill', 'colour', 'facet', 'facet_row', 'facet_col'}
            if isfield(d, f{1}), nd.(f{1}) = d.(f{1})(keepIdx); end
        end
        q.geom = 'polygon';
        q.data = nd;
        return
    case 'hline', q.geom = 'vline';
    case 'vline', q.geom = 'hline';
    case 'errorbar', q.params.horizontal = ~getOr(q.params, 'horizontal', false);
end
swap = struct('x', 'y', 'y', 'x', 'xmin', 'ymin', 'ymin', 'xmin', 'xmax', 'ymax', ...
    'ymax', 'xmax', 'xend', 'yend', 'yend', 'xend');
nd = struct();
f = fieldnames(d);
for k = 1:numel(f)
    name = f{k};
    if isfield(swap, name), name = swap.(name); end
    nd.(name) = d.(f{k});
end
q.data = nd;
end

function s = labelFor(p, L, key)
s = getOr(p.Labels, key, '');
if ~isempty(s) || isfield(p.Labels, key), return; end
s = nameFor(L, key);
end

function s = nameFor(L, key)
s = '';
for k = 1:numel(L)
    if isfield(L{k}.names, key), s = L{k}.names.(key); return; end
end
end

function a = axisSpec(A, opts, label)
a = struct('label', getOr(opts, 'name', label), 'type', A.type, 'trans', 'identity', ...
    'limits', [], 'breaks', [], 'labels', {{}}, 'format', char(getOr(opts, 'format', '')));
if isfield(opts, 'trans'), a.trans = char(opts.trans); end
if isfield(opts, 'limits'), a.limits = encode(A, opts.limits(:))'; end
if isfield(opts, 'breaks'), a.breaks = encode(A, opts.breaks(:))'; end
if isfield(opts, 'labels'), a.labels = cellstr(string(opts.labels))'; end
if strcmp(A.type, 'discrete')
    k = numel(A.levels);
    if isempty(a.breaks), a.breaks = 1:k; a.labels = A.levels; end
    if isempty(a.limits), a.limits = [0.4 k + 0.6]; end
end
end

function c = colourSpec(C, title)
c = [];
if isempty(C), return; end
c = C;
c.title = char(title);
end

function q = finalise(q)
% Drop empty optional columns and keep the JSON shape predictable.
if ~isfield(q.params, 'colour') && ~isfield(q.params, 'fill') && isempty(q.aes)
    q.params.colour = 'ink';
end
end
