function p = gg(varargin)
%GG Start a grammar-of-graphics plot.
%   p = matgrib.gg(T, x="date", y="nav", colour="strategy")
%   p = matgrib.gg(x=t, y=sin(t))            % vectors instead of a table
%
%   Aesthetics are x, y, colour (or color), fill, group, label, ymin, ymax,
%   xmin, xmax, xend, yend. A string value names a column of the data; any
%   other value is used as data directly. For colour and fill, a string that
%   is not a column name is a fixed colour instead ("red", "#336699").
%
%   Add layers and settings by chaining methods, then display the plot by
%   leaving the expression unterminated (no semicolon) or calling show:
%
%     matgrib.gg(T, x="date", y="ret", colour="fund") ...
%         .line() ...
%         .smooth(method="loess") ...
%         .labs(title="Returns", y="Daily return") ...
%         .scaleY(format="percent") ...
%         .facet("region", ncol=2)
%
%   Inside a Quarto document rendered with the matlab engine, a displayed
%   plot becomes a native Gribouille (PDF) or Observable Plot (HTML) figure.
%   Elsewhere it opens a MATLAB preview figure.
%
%   See also matgrib.Plot, matgrib.arrange.

data = table();
args = varargin;
if ~isempty(args) && ~(ischar(args{1}) || isstring(args{1}))
    data = args{1};
    args = args(2:end);
    if isstruct(data), data = struct2table(data); end
    if ~istable(data) && ~istimetable(data)
        error('matgrib:gg', 'First argument must be a table, timetable or struct of columns.');
    end
    if istimetable(data), data = timetable2table(data); end
end
p = matgrib.Plot(data, args);
end
