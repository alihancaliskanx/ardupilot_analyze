classdef TimePlot < mapper.ui.Panel
    % Selected fields against time. Its x-axis is the time window: zooming (scroll) or panning
    % (drag) here moves the window, and moving the window elsewhere sets the x-axis.
    % Double-click shows the whole log.

    properties (SetAccess = private)
        Axes
        Nav
    end

    properties (Access = private)
        App
        Cursor
        Updating = false
    end

    methods
        function obj = TimePlot(parent)
            ax = uiaxes(parent);
            grid(ax, 'on'); box(ax, 'on');
            xlabel(ax, 'Time since boot (s)');
            obj.Nav = mapper.ui.MouseNav(ax, 'x');
            addlistener(ax, 'XLim', 'PostSet', @(~, ~) obj.limitsChanged());
            obj.Axes = ax;
        end

        function onLoad(obj, app)
            obj.App = app;
            obj.Nav.Home = @() app.setRange(app.Span);
        end

        function onSelection(obj, app)
            ax = obj.Axes;
            obj.Updating = true;
            cla(ax);
            hold(ax, 'on');
            for k = 1:size(app.Selection, 1)
                [name, field] = app.Selection{k, :};
                s = app.Log.read(name);
                plot(ax, s.t, s.(field), 'DisplayName', [name '.' field]);
            end
            if isempty(app.Selection)
                legend(ax, 'off');
            else
                legend(ax, 'Interpreter', 'none', 'Location', 'northwest');
            end
            ax.YLimMode = 'auto';
            ax.XLim = app.Range;
            obj.Updating = false;
        end

        function onRange(obj, app)
            obj.Updating = true;
            obj.Axes.XLim = app.Range;
            obj.Updating = false;
        end

        function onCursor(obj, ~, t)
            if isempty(obj.Cursor) || ~isvalid(obj.Cursor)
                obj.Cursor = xline(obj.Axes, t, 'Color', [0.84 0.15 0.16], 'HandleVisibility', 'off');
            else
                obj.Cursor.Value = t;
            end
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
        function limitsChanged(obj)
            if obj.Updating || isempty(obj.App), return; end
            obj.App.setRange(obj.Axes.XLim);
        end
    end
end
