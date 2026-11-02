function p = fromNed(t, north, east)
% Path from positions already in metres north and east of a local origin (EKF PN/PE).
% A path is a struct of column vectors t (s), north and east (m).

p = struct('t', t(:), 'north', north(:), 'east', east(:));
end
