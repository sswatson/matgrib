% Build a spec for every layer type; errors surface immediately.
addpath(fullfile(fileparts(mfilename('fullpath')), '..', '_extensions', 'matgrib', 'matlab'));
rng(1);
n = 200;
T = table((1:n)', cumsum(randn(n,1)), repmat(["a";"b"], n/2, 1), randn(n,1), ...
    'VariableNames', {'t', 'v', 'g', 'z'});
T.d = datetime(2024,1,1) + caldays(T.t - 1);
specs = struct();
specs.point = matgrib.gg(T, x="z", y="v", colour="g").point().build();
specs.line = matgrib.gg(T, x="d", y="v", colour="g").line().hline(0).build();
specs.step = matgrib.gg(T(1:20,:), x="t", y="v").step().build();
specs.area = matgrib.gg(T, x="t", y=abs(T.z), fill="g").area().build();
specs.col = matgrib.gg(table(["x";"y";"x";"y"], ["p";"p";"q";"q"], [1;2;3;4], 'VariableNames', {'k','s','n'}), x="k", y="n", fill="s").col(position="dodge").build();
specs.bar = matgrib.gg(T, x="g").bar().build();
specs.hist = matgrib.gg(T, x="z", fill="g").histogram(bins=20).build();
specs.density = matgrib.gg(T, x="z", colour="g").density().build();
specs.smooth = matgrib.gg(T, x="t", y="v").point().smooth(method="lm").build();
specs.loess = matgrib.gg(T, x="t", y="v", colour="g").smooth().build();
specs.box = matgrib.gg(T, x="g", y="z").boxplot().coordFlip().build();
specs.err = matgrib.gg(table((1:5)', (1:5)', 'VariableNames', {'x','y'}), x="x", y="y", ymin=(1:5)'-0.5, ymax=(1:5)'+0.5).pointrange().build();
specs.text = matgrib.gg(T(1:3,:), x="t", y="v", label="g").text().build();
specs.tile = matgrib.gg(table(repmat((1:3)',3,1), repelem((1:3)',3), (1:9)', 'VariableNames', {'a','b','c'}), x="a", y="b", fill="c").tile().build();
specs.seg = matgrib.gg().segment(x=0, y=0, xend=1, yend=1).abline(0, 2).build();
specs.facet = matgrib.gg(T, x="t", y="v").line().facet("g").build();
specs.ann = matgrib.gg(T, x="t", y="v").line().annotate("text", x=50, y=0, label="note").vline(20).build();
f = fieldnames(specs);
for k = 1:numel(f)
    s = specs.(f{k});
    geoms = cellfun(@(l) l.geom, s.panels{1}.layers, 'UniformOutput', false);
    fprintf('%-8s %s\n', f{k}, strjoin(geoms, ','));
end

% Write the specs for tests/gallery.typ and tests/gallery.html.
out = fullfile(fileparts(mfilename('fullpath')), 'out');
if ~exist(out, 'dir'), mkdir(out); end
items = cellfun(@(k) struct('name', k, 'spec', specs.(k)), f, 'UniformOutput', false);
fid = fopen(fullfile(out, 'gallery.json'), 'w', 'n', 'UTF-8');
fwrite(fid, jsonencode(items), 'char');
fclose(fid);
