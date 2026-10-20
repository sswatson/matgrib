% Render every gallery spec through matgrib.preview and save PNGs.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '_extensions', 'matgrib', 'matlab'));
items = jsondecode(fileread(fullfile(here, 'out', 'gallery.json')));
if ~iscell(items), items = num2cell(items); end
for k = 1:numel(items)
    f = figure('Visible', 'off', 'Position', [0 0 700 380]);
    matgrib.preview(items{k}.spec, f);
    exportgraphics(f, fullfile(here, 'out', ['preview-' items{k}.name '.png']), 'Resolution', 60);
    close(f);
end
disp('previews done')
