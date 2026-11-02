function len = pathLength(p, idx)
% Length in metres of the path through the samples idx (a logical or index vector).

len = sum(hypot(diff(p.north(idx)), diff(p.east(idx))));
end
