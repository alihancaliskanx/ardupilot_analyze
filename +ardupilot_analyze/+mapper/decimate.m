function p = decimate(p, step)
% Keeps one sample per step seconds; a 25 Hz source over an hour is too much to redraw on every drag.

keep = false(size(p.t));
last = -Inf;
for i = 1:numel(p.t)
    if p.t(i) - last >= step
        keep(i) = true;
        last = p.t(i);
    end
end
p = structfun(@(v) v(keep), p, 'UniformOutput', false);
end
