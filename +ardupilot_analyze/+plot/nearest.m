function i = nearest(t, q)
% Index of the sample of t nearest to time q, or [] when t is empty. t must be sorted; a binary
% search, because it runs on every mouse move over series of a million samples.

n = numel(t);
if n == 0, i = []; return; end
lo = 1;
hi = n;
while hi - lo > 1
    mid = floor((lo + hi)/2);
    if t(mid) < q, lo = mid; else, hi = mid; end
end
if abs(t(hi) - q) < abs(t(lo) - q), i = hi; else, i = lo; end
end
