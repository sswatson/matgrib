function out = emit(spec)
%EMIT Queue a figure spec for the Quarto document being rendered.
%   tf = matgrib.emit() is true while matgrib.runJob is executing cells.
%   matgrib.emit(spec) appends SPEC to the current cell's figures.

active = isappdata(groot, 'matgrib_queue');
if nargin == 0
    out = active;
    return
end
if ~active
    error('matgrib:emit', 'Not rendering a Quarto document; use preview instead.');
end
q = getappdata(groot, 'matgrib_queue');
q{end+1} = spec;
setappdata(groot, 'matgrib_queue', q);
end
