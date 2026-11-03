function [t, y] = envelope(t, y, n)
% Reduces a series to the lowest and highest sample in each of n equal time buckets, in time
% order, for an overview that is only a few hundred pixels wide. Buckets are cut by time, not by
% sample count, so gaps in the log stay where they are; each kept sample keeps its own time.

ok = isfinite(t) & isfinite(y);
t = t(ok);
y = y(ok);
if numel(t) <= 2*n, return; end
t0 = min(t);
w = max((max(t) - t0)/n, eps);
b = min(floor((t - t0)/w) + 1, n);
[~, o] = sortrows([b(:) y(:)]);
first = [true; diff(b(o)) ~= 0];
last = [diff(b(o)) ~= 0; true];
keep = sort([o(first); o(last)]);
keep = keep([true; diff(keep) ~= 0]);
t = t(keep);
y = y(keep);
end
