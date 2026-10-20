function varargout = mgStats(fn, varargin)
%MGSTATS Small statistics library (base MATLAB only, no toolboxes).
%   q = mgStats('quantile', x, p)            type-7 quantiles (R / ggplot default)
%   [xs, ys] = mgStats('kde', x, adjust, n)  Gaussian KDE, bw.nrd0 bandwidth
%   [xs, yh, lo, hi] = mgStats('lm', x, y, level, n, degree)
%   [xs, yh, lo, hi] = mgStats('loess', x, y, span, level, n)
%   t = mgStats('tinv', p, df)
%   b = mgStats('box', y, coef)              boxplot five numbers + outliers

[varargout{1:nargout}] = feval(fn, varargin{:});
end

function q = quantile(x, p)
x = sort(x(isfinite(x)));
x = x(:)'; p = p(:)';   % same orientation, or implicit expansion builds a matrix
n = numel(x);
if n == 0, q = nan(size(p)); return; end
h = (n - 1) * p + 1;
lo = floor(h); hi = min(lo + 1, n);
q = x(lo) + (h - lo) .* (x(hi) - x(lo));
end

function bw = nrd0(x)
s = std(x);
q = quantile(x, [0.25 0.75]);
r = (q(2) - q(1)) / 1.34;
lo = min(s, r);
if lo == 0, lo = s; end
if lo == 0, lo = abs(x(1)); end
if lo == 0, lo = 1; end
bw = 0.9 * lo * numel(x)^(-0.2);
end

function [xs, ys] = kde(x, adjust, n)
x = x(isfinite(x));
bw = nrd0(x) * adjust;
xs = linspace(min(x), max(x), n);
ys = zeros(1, n);
% Chunk the evaluation so very large inputs stay memory-bounded.
for k = 1:ceil(numel(x) / 5000)
    xi = x((k - 1) * 5000 + 1:min(k * 5000, numel(x)));
    ys = ys + sum(exp(-0.5 * ((xs - xi(:)) / bw).^2), 1);
end
ys = ys / (numel(x) * bw * sqrt(2 * pi));
end

function t = tinv(p, df)
% Student t quantile via the inverse regularised incomplete beta function.
if p == 0.5, t = 0; return; end
pp = min(p, 1 - p);
z = betaincinv(2 * pp, df / 2, 0.5);
t = sqrt(df * (1 / z - 1));
if p < 0.5, t = -t; end
end

function [xs, yh, lo, hi] = lm(x, y, level, n, degree)
keep = isfinite(x) & isfinite(y);
x = x(keep); y = y(keep);
mu = mean(x); sd = std(x); if sd == 0, sd = 1; end
z = (x(:) - mu) / sd;
X = z .^ (0:degree);
[Q, R] = qr(X, 0);
beta = R \ (Q' * y(:));
xs = linspace(min(x), max(x), n);
Z = ((xs(:) - mu) / sd) .^ (0:degree);
yh = (Z * beta)';
df = numel(y) - degree - 1;
if df > 0
    s2 = sum((y(:) - X * beta).^2) / df;
    se = sqrt(s2 * sum((Z / R).^2, 2))';
    t = tinv((1 + level) / 2, df);
    lo = yh - t * se; hi = yh + t * se;
else
    lo = yh; hi = yh;
end
end

function [xs, yh, lo, hi] = loess(x, y, span, level, n)
% Local quadratic regression with tricube weights (R's loess defaults).
keep = isfinite(x) & isfinite(y);
x = x(keep); y = y(keep);
m = numel(x);
q = max(3, min(m, ceil(span * m)));
xs = linspace(min(x), max(x), n);
[yh, l2] = localFit(x, y, xs, q);
% Residual scale from fits at the data points (subsampled when large).
if m > 2000
    idx = round(linspace(1, m, 2000));
else
    idx = 1:m;
end
[fit, ~, trace] = localFit(x, y, x(idx), q);
rss = sum((y(idx) - fit).^2) * m / numel(idx);
df = max(1, m - trace * m / numel(idx));
s = sqrt(rss / df);
t = tinv((1 + level) / 2, df);
se = s * sqrt(l2);
lo = yh - t * se; hi = yh + t * se;
end

function [f, l2, trace] = localFit(x, y, x0, q)
x = x(:); y = y(:);
range = max(x) - min(x); if range == 0, range = 1; end
f = zeros(size(x0)); l2 = f; trace = 0;
for i = 1:numel(x0)
    d = abs(x - x0(i));
    ds = sort(d);
    h = max(ds(q), range * 1e-9);
    w = (1 - min(d / h, 1).^3).^3;
    u = (x - x0(i)) / range;
    X = [ones(size(u)) u u.^2];
    sw = sqrt(w);
    A = X .* sw;
    [Q, R] = qr(A, 0);
    if rank(R) < 3
        X = X(:, 1:2); A = X .* sw; [Q, R] = qr(A, 0);
    end
    % Row of the hat operator at x0: e1' * inv(R) * Q' * diag(sw).
    e = zeros(1, size(R, 1)); e(1) = 1;
    l = ((e / R) * Q') .* sw';
    f(i) = l * y;
    l2(i) = sum(l.^2);
    [~, j] = min(d);
    trace = trace + l(j);
end
end

function b = box(y, coef)
y = y(isfinite(y));
q = quantile(y, [0.25 0.5 0.75]);
iqr = q(3) - q(1);
inside = y(y >= q(1) - coef * iqr & y <= q(3) + coef * iqr);
b = struct('lower', q(1), 'middle', q(2), 'upper', q(3), ...
    'ymin', min(inside), 'ymax', max(inside), ...
    'outliers', y(y < q(1) - coef * iqr | y > q(3) + coef * iqr));
end
