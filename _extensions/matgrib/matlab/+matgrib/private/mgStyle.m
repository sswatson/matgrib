function s = mgStyle(kind, v)
%MGSTYLE Normalise linetype / shape names (MATLAB or ggplot spellings).

v = char(v);
switch kind
    case 'linetype'
        switch v
            case {'-', 'solid'}, s = 'solid';
            case {'--', 'dashed'}, s = 'dashed';
            case {':', 'dotted'}, s = 'dotted';
            case {'-.', 'dashdot', 'dash-dotted', 'dotdash'}, s = 'dash-dotted';
            case {'none', ''}, s = 'none';
            otherwise, error('matgrib:linetype', 'Unknown linetype "%s".', v);
        end
    case 'shape'
        switch v
            case {'o', '.', 'circle', 'point'}, s = 'circle';
            case {'s', 'square'}, s = 'square';
            case {'d', 'diamond'}, s = 'diamond';
            case {'^', 'v', '<', '>', 'triangle', 'p', 'h', 'pentagram', 'hexagram'}, s = 'triangle';
            case {'x', 'times'}, s = 'x';
            case {'+', '*', 'cross', 'plus'}, s = 'cross';
            case {'none'}, s = 'none';
            otherwise, error('matgrib:shape', 'Unknown shape "%s".', v);
        end
end
end
