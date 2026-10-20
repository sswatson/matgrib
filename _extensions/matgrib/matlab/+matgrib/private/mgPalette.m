function hex = mgPalette(name)
%MGPALETTE Continuous colour palettes as 9 hex stops.
%   Built-in: viridis, magma, cividis, blues, reds, greens, greys, rdbu,
%   brbg, rdylbu. Any MATLAB colormap function name (parula, turbo, hot,
%   ...) and n-by-3 RGB matrices also work.

if isnumeric(name)
    cm = name;
else
    switch lower(char(name))
        case 'viridis', hex = {'#440154','#472d7b','#3b528b','#2c728e','#21918c','#28ae80','#5ec962','#addc30','#fde725'};
        case 'magma', hex = {'#000004','#1c1044','#4f127b','#812581','#b5367a','#e55964','#fb8761','#fec287','#fcfdbf'};
        case 'cividis', hex = {'#00224e','#123570','#3b496c','#575d6d','#707173','#8a8779','#a69d75','#c4b56c','#fee838'};
        case 'blues', hex = {'#f7fbff','#deebf7','#c6dbef','#9ecae1','#6baed6','#4292c6','#2171b5','#08519c','#08306b'};
        case 'reds', hex = {'#fff5f0','#fee0d2','#fcbba1','#fc9272','#fb6a4a','#ef3b2c','#cb181d','#a50f15','#67000d'};
        case 'greens', hex = {'#f7fcf5','#e5f5e0','#c7e9c0','#a1d99b','#74c476','#41ab5d','#238b45','#006d2c','#00441b'};
        case 'greys', hex = {'#ffffff','#f0f0f0','#d9d9d9','#bdbdbd','#969696','#737373','#525252','#252525','#000000'};
        case 'rdbu', hex = {'#b2182b','#d6604d','#f4a582','#fddbc7','#f7f7f7','#d1e5f0','#92c5de','#4393c3','#2166ac'};
        case 'brbg', hex = {'#8c510a','#bf812d','#dfc27d','#f6e8c3','#f5f5f5','#c7eae5','#80cdc1','#35978f','#01665e'};
        case 'rdylbu', hex = {'#d73027','#f46d43','#fdae61','#fee090','#ffffbf','#e0f3f8','#abd9e9','#74add1','#4575b4'};
        otherwise
            cm = feval(char(name), 9);
    end
    if exist('hex', 'var'), return; end
end
idx = round(linspace(1, size(cm, 1), 9));
hex = arrayfun(@(i) sprintf('#%02x%02x%02x', round(255 * cm(i, :))), idx, 'UniformOutput', false);
end
