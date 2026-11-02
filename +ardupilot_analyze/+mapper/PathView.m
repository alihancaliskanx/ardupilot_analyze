classdef PathView < ardupilot_analyze.ui.Panel
    % Horizontal path in its own window. The whole log is drawn grey and the time window on top of
    % it. The view is set once per source; after that zoom (scroll), pan (left-drag) and rotation
    % (right-drag, about the centre of the view) are the user's, so moving the time window never
    % moves the view. A double-click of the wheel button shows the whole path north up again.
    % One error ellipse of a position covariance is drawn: at the time under the pointer in the
    % time plot, or at the end of the time window while the pointer has not been there (or that
    % time is outside the window). It holds the chosen probability of a 2-D Gaussian, 95 % by
    % default. The covariance is the EKF's (see covariance) unless setCovariance gives another,
    % e.g. a model's.

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
        Cov = []                    % struct(t, varN, varE, covNE), [] when there is none
        HEll                        % patch with the ellipse
        CursorT = []                % time under the pointer in the time plot, s
        EllOn = true
        Conf = 0.95                 % probability inside an ellipse
        UiEll                       % ellipse controls: checkbox and confidence
    end

    properties (Constant, Access = private)
        DRAW_STEP = 0.1             % s between drawn samples
    end

    methods
        function obj = PathView(app)
            obj.App = app;
            obj.Figure = uifigure('Name', 'mapper', 'Position', [1480 60 700 700], ...
                'CloseRequestFcn', @(~, ~) delete(obj));
            g = uigridlayout(obj.Figure, [3 1]);
            g.RowHeight = {26, 26, '1x'};
            bar = uigridlayout(g, [1 3]);
            bar.ColumnWidth = {320, '1x', 30};
            bar.Padding = [0 0 0 0];
            obj.Source = uidropdown(bar, 'Items', {'No log loaded'}, 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) obj.loadSource());
            obj.Info = uilabel(bar, 'Text', '', 'HorizontalAlignment', 'right');
            uibutton(bar, 'Text', char(10005), 'Tooltip', 'Close the map', ...
                'ButtonPushedFcn', @(~, ~) delete(obj));
            ell = uigridlayout(g, [1 4]);
            ell.ColumnWidth = {110, 75, 70, '1x'};
            ell.Padding = [0 0 0 0];
            obj.UiEll.On = uicheckbox(ell, 'Text', 'Error ellipses', 'Value', obj.EllOn, ...
                'ValueChangedFcn', @(src, ~) obj.setEllipses(src.Value, obj.Conf));
            uilabel(ell, 'Text', 'confidence', 'HorizontalAlignment', 'right');
            obj.UiEll.Conf = uidropdown(ell, 'Items', {'68 %', '95 %', '99 %'}, ...
                'ItemsData', [0.68 0.95 0.99], 'Value', obj.Conf, ...
                'ValueChangedFcn', @(src, ~) obj.setEllipses(obj.EllOn, src.Value));
            ax = uiaxes(g);
            grid(ax, 'on'); box(ax, 'on');
            xlabel(ax, 'East (m)'); ylabel(ax, 'North (m)');
            obj.Axes = ax;
            obj.Nav = ardupilot_analyze.ui.MouseNav(ax, 'xy');
            obj.Nav.Home = @() obj.showAll();
            obj.Nav.HomeButton = 'middle';
            obj.Nav.RotateStart = @() obj.rotateStart();
            obj.Nav.Rotate = @(centre, angle) obj.rotate(centre, angle);
            obj.Figure.WindowButtonDownFcn = @(src, ~) obj.press(src);
            obj.Figure.WindowButtonMotionFcn = @(~, ~) obj.Nav.move();
            obj.Figure.WindowButtonUpFcn = @(~, ~) obj.Nav.up();
            obj.Figure.WindowScrollWheelFcn = @(~, e) obj.Nav.scroll(e);
            ardupilot_analyze.ui.applyTheme(obj.Figure, app.Theme);
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
            S = ardupilot_analyze.mapper.sources();
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

        function setEllipses(obj, on, conf)
            % Error ellipse on or off and its probability (0..1)
            obj.EllOn = logical(on);
            obj.Conf = conf;
            obj.UiEll.On.Value = obj.EllOn;
            if ismember(conf, obj.UiEll.Conf.ItemsData), obj.UiEll.Conf.Value = conf; end
            if ~isempty(obj.Path), obj.onRange(obj.App); end
        end

        function setCovariance(obj, c)
            % Draws the ellipses from c = struct(t, varN, varE, covNE) instead of the source's own
            % covariance, until another source is chosen; [] goes back to having none
            obj.Cov = c;
            if ~isempty(obj.Path), obj.onRange(obj.App); end
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
            obj.Info.Text = sprintf('%.1f s, path %.1f m', diff(app.Range), ardupilot_analyze.mapper.pathLength(p, i));
            if ~isempty(obj.North), obj.Info.Text = [obj.Info.Text '   |   ' obj.North]; end
            if obj.EllOn && isempty(obj.Cov)
                obj.Info.Text = [obj.Info.Text '   |   no covariance for this source'];
            end
            obj.drawEllipse(app.Range);
        end

        function onCursor(obj, ~, t)
            if isempty(obj.Path) || isempty(obj.Path.t), return; end
            [~, i] = min(abs(obj.Path.t - t));
            set(obj.HCursor, 'XData', obj.Path.east(i), 'YData', obj.Path.north(i));
            obj.CursorT = t;
            obj.drawEllipse(obj.App.Range);
        end
    end

    methods (Access = private)
        function press(obj, fig)
            if ~ardupilot_analyze.ui.overLegend(obj.Axes, fig), obj.Nav.down(fig); end
        end

        function rotateStart(obj)
            if ~isempty(obj.Frame), obj.Start = obj.Frame.Matrix; end
        end

        function loadSource(obj)
            c = obj.Choices(obj.Source.Value);
            p = c.convert(obj.App.Log.read(c.name));
            obj.Cov = ardupilot_analyze.mapper.covariance(obj.App.Log, c.name);
            obj.CursorT = [];
            obj.Path = ardupilot_analyze.mapper.decimate(p, obj.DRAW_STEP);
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
            obj.HEll = patch(ax, 'Vertices', zeros(0, 2), 'Faces', zeros(0, 3), 'FaceColor', T.ellipse, ...
                'FaceAlpha', 0.15, 'EdgeColor', T.ellipse, 'LineWidth', 1.5, 'Parent', obj.Frame);
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
            legend(ax, [whole obj.HSel obj.HStart obj.HEnd obj.HEll], 'Location', 'northeast');
            ardupilot_analyze.ui.applyTheme(obj.Figure, T);
            axis(ax, 'equal');
            obj.showAll();
            obj.onRange(obj.App);
        end

        function drawEllipse(obj, range)
            show = obj.EllOn && ~isempty(obj.Cov);
            obj.HEll.Visible = matlab.lang.OnOffSwitchState(show);
            obj.HEll.DisplayName = sprintf('%g %% error ellipse', 100*obj.Conf);
            if ~show, return; end
            t = obj.CursorT;
            if isempty(t) || t < range(1) || t > range(2), t = range(2); end
            [V, F] = obj.ellipsesAt(t);
            set(obj.HEll, 'Vertices', V, 'Faces', F);
        end

        function [V, F] = ellipsesAt(obj, t)
            % Ellipses at times t: position from the path, covariance held from its last sample
            V = zeros(0, 2); F = zeros(0, 3);
            if ~obj.EllOn || isempty(obj.Cov) || isempty(obj.Path), return; end
            p = obj.Path;
            e = interp1(p.t, p.east, t);
            n = interp1(p.t, p.north, t);
            c = obj.Cov;
            C = [interp1(c.t, c.varE, t, 'previous'); interp1(c.t, c.varN, t, 'previous'); ...
                interp1(c.t, c.covNE, t, 'previous')]';
            ok = isfinite(e(:)) & isfinite(n(:)) & all(isfinite(C), 2);
            if ~any(ok), return; end
            [V, F] = ardupilot_analyze.mapper.ellipses(e(ok), n(ok), C(ok, :), obj.Conf);
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
