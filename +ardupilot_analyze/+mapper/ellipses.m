function [V, F, A] = ellipses(east, north, C, p, n)
% Vertices and faces of confidence ellipses for one patch, one ellipse per centre. C has a row
% [varE varN covEN] per centre (m^2): a full 2-D covariance, so an ellipse can be tilted. Each
% ellipse holds probability p of a 2-D Gaussian with that covariance. n is the number of vertices
% per ellipse (default 48). A has a row [majorE majorN minorE minorN] per ellipse: its semi-axes
% as east/north vectors (m).

if nargin < 5, n = 48; end
k = sqrt(-2*log(1 - p));            % 2.45 for 95 %: radius of the p contour in sigma units
a = linspace(0, 2*pi, n + 1);
unit = [cos(a(1:end - 1)); sin(a(1:end - 1))];
m = numel(east);
V = zeros(m*n, 2);
F = zeros(m, n);
A = zeros(m, 4);
for i = 1:m
    S = [C(i, 1) C(i, 3); C(i, 3) C(i, 2)];
    [U, D] = eig((S + S')/2);
    ax = k*U*sqrt(max(D, 0));       % columns are the semi-axes, eig sorts the minor one first
    A(i, :) = [ax(:, 2)' ax(:, 1)'];
    xy = ax*unit;                   % unit circle scaled along the principal axes
    rows = (i - 1)*n + (1:n);
    V(rows, :) = [east(i) + xy(1, :)', north(i) + xy(2, :)'];
    F(i, :) = rows;
end
end
