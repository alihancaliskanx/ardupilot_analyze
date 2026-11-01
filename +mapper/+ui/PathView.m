classdef PathView < mapper.ui.Panel
    % Horizontal path in its own window, north up. The whole log is drawn grey and the time window
    % on top of it. The view is set once per source; after that zoom (scroll) and pan (drag) are
    % the user's, so moving the time window never moves the view. Double-click shows the whole path.

    properties (SetAccess = private)
        Figure
    end

    properties (Access = private)
        Source
        Info
        Axes
        Nav
        Choices = struct('name', {}, 'convert', {})
        Path
        HSel
        HStart
        HEnd
        HCursor
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
            if exist('theme', 'file'), theme(obj.Figure, 'light'); end
            g = uigridlayout(obj.Figure, [2 1]);
            g.RowHeight = {26, '1x'};
            bar = uigridlayout(g, [1 2]);
            bar.ColumnWidth = {320, '1x'};
            bar.Padding = [0 0 0 0];
            obj.Source = uidropdown(bar, 'Items', {'No log loaded'}, 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) obj.loadSource());
            obj.Info = uilabel(bar, 'Text', '', 'HorizontalAlignment', 'right');
            ax = uiaxes(g);
            grid(ax, 'on'); box(ax, 'on');
            xlabel(ax, 'East (m)'); ylabel(ax, 'North (m)');
            obj.Axes = ax;
            obj.Nav = mapper.ui.MouseNav(ax, 'xy');
            obj.Nav.Home = @() obj.showAll();
            obj.Figure.WindowButtonDownFcn = @(src, ~) obj.Nav.down(src);
            obj.Figure.WindowButtonMotionFcn = @(~, ~) obj.Nav.move();
            obj.Figure.WindowButtonUpFcn = @(~, ~) obj.Nav.up();
            obj.Figure.WindowScrollWheelFcn = @(~, e) obj.Nav.scroll(e);
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
        end

        function onCursor(obj, ~, t)
            if isempty(obj.Path) || isempty(obj.Path.t), return; end
            [~, i] = min(abs(obj.Path.t - t));
            set(obj.HCursor, 'XData', obj.Path.east(i), 'YData', obj.Path.north(i));
        end
    end

    methods (Access = private)
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
            plot(ax, obj.Path.east, obj.Path.north, '-', 'Color', [0.78 0.78 0.78], 'DisplayName', 'Whole log');
            obj.HSel = plot(ax, NaN, NaN, '-', 'Color', [0.12 0.47 0.71], 'LineWidth', 1.5, ...
                'DisplayName', 'Time window');
            obj.HStart = plot(ax, NaN, NaN, 'o', 'Color', 'k', 'MarkerFaceColor', 'w', 'MarkerSize', 7, ...
                'DisplayName', 'Start');
            obj.HEnd = plot(ax, NaN, NaN, 'o', 'Color', 'k', 'MarkerFaceColor', 'k', 'MarkerSize', 7, ...
                'DisplayName', 'End');
            obj.HCursor = plot(ax, NaN, NaN, 'o', 'Color', [0.84 0.15 0.16], ...
                'MarkerFaceColor', [0.84 0.15 0.16], 'MarkerSize', 7, 'HandleVisibility', 'off');
            legend(ax, 'Location', 'northeast');
            axis(ax, 'equal');
            obj.showAll();
            obj.onRange(obj.App);
        end

        function showAll(obj)
            if isempty(obj.Path) || isempty(obj.Path.t), return; end
            e = [min(obj.Path.east) max(obj.Path.east)];
            n = [min(obj.Path.north) max(obj.Path.north)];
            m = max([diff(e), diff(n), 2])*0.05;
            obj.Axes.XLim = e + [-m m];
            obj.Axes.YLim = n + [-m m];
        end
    end
end
