function c = mgColour(v)
%MGCOLOUR Normalise a MATLAB colour specification for the spec.
%   Returns "#rrggbb", a palette slot struct('auto', i), or one of the
%   tokens "ink" / "paper" / "none". Accepts RGB triplets (0-1), hex strings,
%   MATLAB short/long names ('r', "red"), and integers as palette slots.

if isstruct(v) && isfield(v, 'auto')
    c = v;
elseif isnumeric(v) && isscalar(v)
    c = struct('auto', double(v));
elseif isnumeric(v) && numel(v) == 3
    c = sprintf('#%02x%02x%02x', round(255 * double(v(:)')));
elseif ischar(v) || isstring(v)
    s = char(v);
    switch lower(s)
        case {'ink', 'paper', 'none'}
            c = lower(s);
        otherwise
            if startsWith(s, '#') && numel(s) == 4
                s = ['#' s([2 2 3 3 4 4])];
            end
            if startsWith(s, '#') && numel(s) == 7
                c = lower(s);
            else
                c = sprintf('#%02x%02x%02x', round(255 * validatecolor(s)));
            end
    end
else
    error('matgrib:colour', 'Unrecognised colour specification.');
end
end
