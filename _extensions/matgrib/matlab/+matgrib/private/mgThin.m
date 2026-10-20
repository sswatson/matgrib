function idx = mgThin(kind, x, y, budget)
%MGTHIN Row indices that keep a layer within its drawing budget.
%   'minmax': for ordered series, split into budget/2 buckets and keep each
%             bucket's lowest and highest point (visible extremes survive).
%   'sample': for unordered points, a reproducible random subset.

n = numel(x);
if n <= budget
    idx = 1:n;
    return
end
switch kind
    case 'minmax'
        nb = max(1, floor(budget / 2));
        edges = round(linspace(0, n, nb + 1));
        idx = zeros(1, 2 * nb);
        for b = 1:nb
            r = edges(b) + 1:edges(b + 1);
            if isempty(r), continue; end
            [~, i1] = min(y(r)); [~, i2] = max(y(r));
            idx(2*b-1:2*b) = sort(r([i1 i2]));
        end
        idx = unique([1, idx(idx > 0), n]);
    case 'sample'
        s = RandStream('mt19937ar', 'Seed', 0);
        idx = sort(randperm(s, n, budget));
end
end
