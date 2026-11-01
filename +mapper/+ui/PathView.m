classdef PathView < mapper.ui.Panel
    % Horizontal path in its own window. The whole log is drawn grey and the time window on top of
    % it. The view is set once per source; after that zoom (scroll), pan (left-drag) and rotation
    % (right-drag, about the centre of the view) are the user's, so moving the time window never
    % moves the view. A double-click of the wheel button shows the whole path north up again.

    properties (SetAccess = private)
        Figure
        Nav
    end

    properties (Access = private)
        Source
        Info
        Axes
        Choices = struct('name', {}, 'convert', {})
        Path
        HSel
        HStart
        HEnd
        HCursor
        Frame                       % hgtransform holding the plotted path
        Start = eye(4)              % frame matrix when the current right-drag started
        North = ''                  % where north points while the map is turned
        App
    end

    properties (Constant, Access = private)
        DRAW_STEP = 0.1             % s between drawn samples
    end

    methods
        function obj = PathView(app)
            obj.App = app;
            obj.Figure = uifigure('Name', 'mapper - path', 'Position', [1480 60 700 700], ...
                'CloseRequestFcn', @(~, ~) delete(obj));
            g = uigridlayout(obj.Figure, [2 1]);
            g.RowHeight = {26, '1x'};
            bar = uigridlayout(g, [1 3]);
            bar.ColumnWidth = {320, '1x', 30};
            bar.Padding = [0 0 0 0];
            obj.Source = uidropdown(bar, 'Items', {'No log loaded'}, 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) obj.loadSource());
            obj.Info = uilabel(bar, 'Text', '', 'HorizontalAlignment', 'right');
            uibutton(bar, 'Text', char(10005), 'Tooltip', 'Close the map', ...
                'ButtonPushedFcn', @(~, ~) delete(obj));
            ax = uiaxes(g);
            grid(ax, 'on'); box(ax, 'on');
            xlabel(ax, 'East (m)'); ylabel(ax, 'North (m)');
            obj.Axes = ax;
            obj.Nav = mapper.ui.MouseNav(ax, 'xy');
            obj.Nav.Home = @() obj.showAll();
            obj.Nav.HomeButton = 'middle';
            obj.Nav.RotateStart = @() obj.rotateStart();
            obj.Nav.Rotate = @(centre, angle) obj.rotate(centre, angle);
            obj.Figure.WindowButtonDownFcn = @(src, ~) obj.press(src);
            obj.Figure.WindowButtonMotionFcn = @(~, ~) obj.Nav.move();
            obj.Figure.WindowButtonUpFcn = @(~, ~) obj.Nav.up();
            obj.Figure.WindowScrollWheelFcn = @(~, e) obj.Nav.scroll(e);
            mapper.ui.applyTheme(obj.Figure, app.Theme);
        end

        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end

        function onLoad(obj, app)
            obj.Path = [];
            cla(obj.Axes);
            obj.Info.Text = '';
            S = mapper.path.sources();
            obj.Choices = struct('name', {}, 'convert', {});
            items = {};
            for k = 1:numel(S)
                if ~app.Log.has(S(k).type), continue; end
                for inst = app.Log.instances(S(k).type)
                    obj.Choices(end + 1) = struct('name', inst{1}, 'convert', S(k).convert);
                    items{end + 1} = sprintf('%s  (%s)', S(k).label, inst{1}); %#ok<AGROW>
                end
            end
            if isempty(items)
                obj.Source.Items = {'No position messages (XKF1, NKF1, POS, GPS)'};
                obj.Source.Enable = 'off';
                return
            end
            obj.Source.Items = items;
            obj.Source.ItemsData = 1:numel(items);
            obj.Source.Value = 1;
            obj.Source.Enable = 'on';
            obj.loadSource();
        end

        function selectSource(obj, name)
            % Shows the path of message name, e.g. 'XKF1[1]' or 'GPS'
            i = find(strcmp({obj.Choices.name}, name), 1);
            if isempty(i)
                error('mapper: no path source %s; available: %s', name, strjoin({obj.Choices.name}, ', '));
            end
            obj.Source.Value = i;
            obj.loadSource();
        end

        function onRange(obj, app)
            if isempty(obj.Path) || isempty(obj.Path.t), return; end
            p = obj.Path;
            i = p.t >= app.Range(1) & p.t <= app.Range(2);
            set(obj.HSel, 'XData', p.east(i), 'YData', p.north(i));
            j = find(i, 1); k = find(i, 1, 'last');
            if isempty(j)
                set([obj.HStart obj.HEnd], 'XData', NaN, 'YData', NaN);
            else
                set(obj.HStart, 'XData', p.east(j), 'YData', p.north(j));
                set(obj.HEnd, 'XData', p.east(k), 'YData', p.north(k));
            end
            obj.Info.Text = sprintf('%.1f s, path %.1f m', diff(app.Range), mapper.path.pathLength(p, i));
            if ~isempty(obj.North), obj.Info.Text = [obj.Info.Text '   |   ' obj.North]; end
        end

        function onCursor(obj, ~, t)
            if isempty(obj.Path) || isempty(obj.Path.t), return; end
            [~, i] = min(abs(obj.Path.t - t));
            set(obj.HCursor, 'XData', obj.Path.east(i), 'YData', obj.Path.north(i));
        end
    end

    methods (Access = private)
        function press(obj, fig)
            if ~mapper.ui.overLegend(obj.Axes, fig), obj.Nav.down(fig); end
        end

        function rotateStart(obj)
            if ~isempty(obj.Frame), obj.Start = obj.Frame.Matrix; end
        end

        function loadSource(obj)
            c = obj.Choices(obj.Source.Value);
            p = c.convert(obj.App.Log.read(c.name));
            obj.Path = mapper.path.decimate(p, obj.DRAW_STEP);
            ax = obj.Axes;
            cla(ax);
            if isempty(obj.Path.t)
                obj.Info.Text = sprintf('%s has no valid positions', c.name);
                return
            end
            hold(ax, 'on');
            T = obj.App.Theme;
            % everything is drawn in one frame so that a right-drag can rotate it as a whole
            obj.Frame = hgtransform(ax);
            whole = plot(ax, obj.Path.east, obj.Path.north, '-', 'Color', T.muted, 'DisplayName', 'Whole log', ...
                'Parent', obj.Frame);
            obj.HSel = plot(ax, NaN, NaN, '-', 'Color', T.accent, 'LineWidth', 1.5, ...
                'DisplayName', 'Time window', 'Parent', obj.Frame);
            obj.HStart = plot(ax, NaN, NaN, 'o', 'Color', T.foreground, 'MarkerFaceColor', T.panel, ...
                'MarkerSize', 7, 'DisplayName', 'Start', 'Parent', obj.Frame);
            obj.HEnd = plot(ax, NaN, NaN, 'o', 'Color', T.foreground, 'MarkerFaceColor', T.foreground, ...
                'MarkerSize', 7, 'DisplayName', 'End', 'Parent', obj.Frame);
            obj.HCursor = plot(ax, NaN, NaN, 'o', 'Color', T.cursor, 'MarkerFaceColor', T.cursor, ...
                'MarkerSize', 7, 'HandleVisibility', 'off', 'Parent', obj.Frame);
            legend(ax, [whole obj.HSel obj.HStart obj.HEnd], 'Location', 'northeast');
            mapper.ui.applyTheme(obj.Figure, T);
            axis(ax, 'equal');
            obj.showAll();
            obj.onRange(obj.App);
        end

        function showAll(obj)
            % North up, whole path in view
            if isempty(obj.Path) || isempty(obj.Path.t), return; end
            obj.Frame.Matrix = eye(4);
            obj.rotated();
            e = [min(obj.Path.east) max(obj.Path.east)];
            n = [min(obj.Path.north) max(obj.Path.north)];
            m = max([diff(e), diff(n), 2])*0.05;
            obj.Axes.XLim = e + [-m m];
            obj.Axes.YLim = n + [-m m];
        end

        function rotate(obj, centre, angle)
            % Turns the frame it had when the drag started by angle (rad) about centre
            if isempty(obj.Frame) || ~isvalid(obj.Frame), return; end
            T = makehgtform('translate', [centre 0]) * makehgtform('zrotate', angle) * ...
                makehgtform('translate', [-centre 0]);
            obj.Frame.Matrix = T * obj.Start;
            obj.rotated();
        end

        function rotated(obj)
            % Axis numbers are east and north only while north is up; when turned they are hidden
            % and the bar says where north points instead
            M = obj.Frame.Matrix;
            heading = mod(-atan2d(M(2, 1), M(1, 1)), 360);  % clockwise from screen up
            up = heading < 0.05 || heading > 359.95;
            ax = obj.Axes;
            if up
                ax.XTickLabelMode = 'auto'; ax.YTickLabelMode = 'auto';
                xlabel(ax, 'East (m)'); ylabel(ax, 'North (m)');
                obj.North = '';
            else
                ax.XTickLabel = {}; ax.YTickLabel = {};
                xlabel(ax, ''); ylabel(ax, '');
                obj.North = sprintf('north %.0f%s clockwise from up, grid in m', heading, char(176));
            end
            obj.onRange(obj.App);
        end
    end
end
