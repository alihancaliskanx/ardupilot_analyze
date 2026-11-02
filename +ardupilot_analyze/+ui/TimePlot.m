classdef TimePlot < ardupilot_analyze.ui.Panel
    % Plotted series against time, each with its own y-axis as on plot.ardupilot.org: a ruler in
    % the series colour left of the plot. A ruler is dragged by its tick labels (see AxisDrag):
    % the middle pans that series, the ends scale it, the wheel scales it about the pointer, a
    % double-click gives it automatic limits. Right button + wheel zooms about 0: over a ruler
    % that series, over the plot all of them. A box drawn with the middle button sets the limits:
    % its width becomes the time window and its height the range of every series. A double-click
    % in the plot undoes the last box, one box per double-click; pans and scalings are kept.
    % Each series is drawn scaled from its ruler limits to 0..1 on the plot axes, so moving one
    % ruler moves only its own line.
    % The x-axis is the time window: wheel zooms, left-drag pans.
    % The legend gives the value under the pointer and min, max and mean over the window, read
    % from the data, not from the scaled lines.

    properties (SetAccess = private)
        Axes
        Nav
        Rulers = gobjects(0)        % one axes per drawn series, carrying only its y-axis
        Drags = {}                  % AxisDrag per ruler
    end

    properties (Access = private)
        App
        Box                         % uipanel laid out by hand so the rulers line up with the plot
        Data = {}                   % struct(t, y) per drawn series
        Lines = gobjects(0)
        Index = []                  % series number of each line
        Stats = zeros(0, 3)
        Cursor
        CursorT = []
        Updating = false
        RightHeld = false
        BoxStart = []               % [t f] where a middle-button box started, f as 0..1 height
        BoxShape                    % the dashed rectangle while it is drawn
        Undo = {}                   % state before each box: struct(range, limits)
    end

    properties (Constant, Access = private)
        RULER = 40                  % px per ruler
        MARGIN = [12 45 15 12]      % px left of the rulers, below, right of and above the plot
        STEP = 1.2                  % zoom factor per wheel notch
    end

    methods
        function obj = TimePlot(parent)
            obj.Box = uipanel(parent, 'BorderType', 'none', 'AutoResizeChildren', 'off', ...
                'SizeChangedFcn', @(~, ~) obj.layout());
            ax = uiaxes(obj.Box);
            grid(ax, 'on'); box(ax, 'on');
            xlabel(ax, 'Time since boot (s)');
            ax.YLim = [0 1];
            ax.YTick = 0:0.25:1;
            ax.YTickLabel = {};
            obj.Nav = ardupilot_analyze.ui.MouseNav(ax, 'x');
            addlistener(ax, 'XLim', 'PostSet', @(~, ~) obj.limitsChanged());
            obj.Axes = ax;
            obj.layout();
        end

        function onLoad(obj, app)
            obj.App = app;
            obj.Nav.Home = @() obj.undoBox(app);
            obj.Undo = {};
        end

        function onSelection(obj, app)
            ax = obj.Axes;
            obj.Updating = true;
            delete(ax.Children);
            legend(ax, 'off');
            delete(obj.Rulers);
            obj.Rulers = gobjects(0);
            obj.Drags = {};
            obj.Data = {};
            obj.Lines = gobjects(0);
            obj.Index = [];
            obj.Cursor = [];
            obj.Undo = {};          % the saved limits belong to the old series
            hold(ax, 'on');
            for k = 1:numel(app.Selection)
                [t, y] = app.seriesData(k);
                if isempty(t), continue; end
                n = numel(obj.Lines) + 1;
                c = app.Selection(k).color;
                obj.Data{n} = struct('t', t, 'y', y);
                obj.Lines(n) = plot(ax, t, nan(size(t)), '-', 'Color', c);
                obj.Index(n) = k;
                obj.Rulers(n) = obj.makeRuler(c);
                obj.Drags{n} = ardupilot_analyze.ui.AxisDrag(obj.Rulers(n), obj.RULER - 4);
                obj.Drags{n}.Auto = @() obj.autoLimits(n);
                obj.Drags{n}.Changed = @() obj.rescale(n);
                obj.autoLimits(n);
            end
            ax.XLim = app.Range;
            obj.Updating = false;
            obj.layout();
            obj.updateStats(app);
        end

        function onRange(obj, app)
            obj.Updating = true;
            obj.Axes.XLim = app.Range;
            obj.Updating = false;
            obj.updateStats(app);
        end

        function onCursor(obj, app, t)
            if isempty(obj.Cursor) || ~isvalid(obj.Cursor)
                obj.Cursor = xline(obj.Axes, t, 'Color', app.Theme.cursor, 'HandleVisibility', 'off');
            else
                obj.Cursor.Value = t;
            end
            obj.CursorT = t;
            obj.updateLegend(app);
        end

        % Mouse, called by the App: rulers first, then the plot area

        function tf = down(obj, fig)
            tf = ardupilot_analyze.ui.overLegend(obj.Axes, fig);
            if tf, return; end
            obj.RightHeld = strcmp(fig.SelectionType, 'alt');
            if strcmp(fig.SelectionType, 'extend') && obj.Nav.isOver()
                obj.boxStart(obj.point());
                tf = true;
                return
            end
            for k = 1:numel(obj.Drags)
                if obj.Drags{k}.down(fig), tf = true; return; end
            end
            tf = obj.Nav.down(fig);
        end

        function tf = move(obj)
            if ~isempty(obj.BoxStart)
                obj.boxMove(obj.point());
                tf = true;
                return
            end
            for k = 1:numel(obj.Drags)
                if obj.Drags{k}.move(), tf = true; return; end
            end
            tf = obj.Nav.move();
        end

        function up(obj)
            if ~isempty(obj.BoxStart), obj.boxEnd(obj.point()); end
            cellfun(@(d) d.up(), obj.Drags);
            obj.Nav.up();
            obj.RightHeld = false;
        end

        function tf = scroll(obj, evt)
            f = obj.STEP^evt.VerticalScrollCount;
            k = obj.rulerUnderPointer();
            if ~obj.RightHeld
                % over a ruler the wheel scales that series, over the plot it zooms time
                if isempty(k), tf = obj.Nav.scroll(evt); else, tf = obj.Drags{k}.zoom(f); end
                return
            end
            % right button held: zoom about 0, one ruler or, over the plot, all of them
            if isempty(k)
                if ~obj.Nav.isOver(), tf = false; return; end
                k = 1:numel(obj.Rulers);
            end
            for i = k
                obj.Rulers(i).YLim = obj.Rulers(i).YLim*f;
                obj.rescale(i);
            end
            tf = true;
        end

        function shape = pointerShape(obj)
            shape = '';
            for k = 1:numel(obj.Drags)
                shape = obj.Drags{k}.pointerShape();
                if ~isempty(shape), return; end
            end
        end

        % The middle-button box, split from the mouse so scripts and tests can drive it.
        % p is [time, height as 0..1 of the plot box].

        function boxStart(obj, p)
            obj.BoxStart = p;
            c = [0.5 0.5 0.5];
            if ~isempty(obj.App), c = obj.App.Theme.accent; end
            obj.BoxShape = rectangle(obj.Axes, 'Position', [p 0 0], 'EdgeColor', c, ...
                'LineStyle', '--', 'LineWidth', 1, 'HitTest', 'off', 'PickableParts', 'none');
        end

        function boxMove(obj, p)
            a = min(obj.BoxStart, p);
            b = max(obj.BoxStart, p);
            obj.BoxShape.Position = [a, max(b - a, eps)];
        end

        function boxEnd(obj, p)
            % A box much flatter than the plot sets only the time window, a much narrower one only
            % the series ranges, and a click without a drag nothing
            a = min(obj.BoxStart, p);
            b = max(obj.BoxStart, p);
            obj.BoxStart = [];
            delete(obj.BoxShape);
            before = obj.state();
            a(2) = max(a(2), 0); b(2) = min(b(2), 1);
            setTime = (b(1) - a(1)) > 0.01*diff(obj.Axes.XLim);
            setY = (b(2) - a(2)) > 0.02;
            if setY
                for k = 1:numel(obj.Rulers)
                    L = obj.Rulers(k).YLim;
                    obj.Rulers(k).YLim = L(1) + [a(2) b(2)]*diff(L);
                    obj.rescale(k);
                end
            end
            if setTime && ~isempty(obj.App), obj.App.setRange([a(1) b(1)]); end
            if setTime || setY, obj.Undo{end + 1} = before; end
        end

        function t = timeAtPointer(obj)
            % Time under the pointer, or [] when the pointer is not over the plot area
            t = [];
            if obj.Nav.isOver()
                t = obj.Axes.CurrentPoint(1, 1);
            end
        end
    end

    methods (Access = private)
        function p = point(obj)
            cp = obj.Axes.CurrentPoint;
            p = cp(1, 1:2);
        end

        function r = makeRuler(obj, c)
            r = uiaxes(obj.Box, 'Color', 'none', 'Tag', 'keepcolor', 'Box', 'off', 'XLim', [0 1]);
            r.XAxis.Visible = 'off';
            r.YColor = c;
            r.FontSize = 9;
            disableDefaultInteractivity(r);
            r.Interactions = [];
            r.Toolbar.Visible = 'off';
        end

        function layout(obj)
            % Plot box right of the rulers; each ruler is a 1 px wide box at the same height whose
            % tick labels fill the column to its left
            p = getpixelposition(obj.Box);
            m = obj.MARGIN;
            n = numel(obj.Rulers);
            left = m(1) + n*obj.RULER;
            h = max(p(4) - m(2) - m(4), 10);
            obj.Axes.InnerPosition = [left, m(2), max(p(3) - left - m(3), 10), h];
            for k = 1:n
                obj.Rulers(k).InnerPosition = [left - (k - 1)*obj.RULER - 2, m(2), 1, h];
            end
        end

        function autoLimits(obj, k)
            % Data range over the whole log with 5 % room, like Plotly's autorange
            y = obj.Data{k}.y(isfinite(obj.Data{k}.y));
            if isempty(y), L = [0 1]; else, L = [min(y) max(y)]; end
            if diff(L) == 0, L = L + [-1 1]*max(abs(L(1))*0.1, 1); end
            obj.Rulers(k).YLim = L + [-1 1]*0.05*diff(L);
            obj.rescale(k);
        end

        function rescale(obj, k)
            L = obj.Rulers(k).YLim;
            obj.Lines(k).YData = (obj.Data{k}.y - L(1))/diff(L);
        end

        function k = rulerUnderPointer(obj)
            k = [];
            for i = 1:numel(obj.Drags)
                if ~isempty(obj.Drags{i}.over()), k = i; return; end
            end
        end

        function s = state(obj)
            s = struct('range', obj.Axes.XLim, 'limits', {arrayfun(@(r) r.YLim, obj.Rulers, ...
                'UniformOutput', false)});
        end

        function undoBox(obj, app)
            if isempty(obj.Undo), return; end
            s = obj.Undo{end};
            obj.Undo(end) = [];
            for k = 1:min(numel(s.limits), numel(obj.Rulers))
                obj.Rulers(k).YLim = s.limits{k};
                obj.rescale(k);
            end
            app.setRange(s.range);
        end

        function updateStats(obj, app)
            obj.Stats = nan(numel(obj.Lines), 3);
            for k = 1:numel(obj.Lines)
                d = obj.Data{k};
                y = d.y(d.t >= app.Range(1) & d.t <= app.Range(2) & isfinite(d.y));
                if ~isempty(y), obj.Stats(k, :) = [min(y) max(y) mean(y)]; end
            end
            obj.updateLegend(app);
        end

        function updateLegend(obj, app)
            if isempty(obj.Lines)
                legend(obj.Axes, 'off');
                return
            end
            for k = 1:numel(obj.Lines)
                s = obj.Stats(k, :);
                name = app.Selection(obj.Index(k)).expr;
                if ~isempty(obj.CursorT)
                    name = sprintf('%s = %s', name, num(valueAt(obj.Data{k}, obj.CursorT)));
                end
                obj.Lines(k).DisplayName = sprintf('%s   [min %s  max %s  mean %s]', ...
                    name, num(s(1)), num(s(2)), num(s(3)));
            end
            if isempty(obj.Axes.Legend) || ~isvalid(obj.Axes.Legend)
                lg = legend(obj.Axes, obj.Lines, 'Interpreter', 'none', 'Location', 'northwest');
                lg.TextColor = app.Theme.foreground;
                lg.Color = app.Theme.background;
                lg.EdgeColor = app.Theme.grid;
            end
        end

        function limitsChanged(obj)
            if obj.Updating || isempty(obj.App), return; end
            obj.App.setRange(obj.Axes.XLim);
        end
    end
end

function v = valueAt(d, t)
% Value of the sample nearest to t
if isempty(d.t), v = NaN; return; end
[~, i] = min(abs(d.t - t));
v = d.y(i);
end

function s = num(v)
s = sprintf('%.4g', v);
end
