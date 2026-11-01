function tf = overLegend(ax, fig)
% True when the pointer is on the legend of ax. A press there belongs to MATLAB's legend drag,
% so the viewer's own mouse handling leaves it alone and the plot behind does not move.

lg = ax.Legend;
tf = false;
if isempty(lg) || ~isvalid(lg) || ~strcmp(lg.Visible, 'on'), return; end
p = getpixelposition(lg, true);
c = fig.CurrentPoint;
tf = c(1) >= p(1) && c(1) <= p(1) + p(3) && c(2) >= p(2) && c(2) <= p(2) + p(4);
end
