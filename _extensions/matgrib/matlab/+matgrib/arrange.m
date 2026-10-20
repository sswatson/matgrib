function a = arrange(varargin)
%ARRANGE Place several matgrib plots side by side in one figure.
%   matgrib.arrange(p1, p2, p3, ncol=3, title="Overview")
%   Options: ncol (default: all in one row), title, subtitle, caption,
%   aspect (panel height / width).

plots = {};
k = 1;
while k <= numel(varargin) && isa(varargin{k}, 'matgrib.Plot')
    plots{end+1} = varargin{k}; %#ok<AGROW>
    k = k + 1;
end
opts = struct('ncol', numel(plots), 'title', '', 'subtitle', '', 'caption', '', 'aspect', []);
rest = varargin(k:end);
for j = 1:2:numel(rest)
    opts.(lower(char(rest{j}))) = rest{j + 1};
end
a = matgrib.Arrangement(plots, opts);
end
