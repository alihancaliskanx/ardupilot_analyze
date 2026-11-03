classdef RangeTimeline < ardupilot_analyze.ui.Panel
    % Whole-log timeline with the flight modes and a draggable window, like the range slider of
    % plot.ardupilot.org. Drag an edge to move it, drag inside to shift the window, drag elsewhere
    % to draw a new one; double-click selects the whole log. A right-press moves the nearer edge to
    % the pointer and keeps moving it while the button is held.

    properties (Access = private)
        Axes
        Window
        EdgeL
        EdgeR
        Drag = ''
        Grab = 0
        Anchor = 0
        Prev = [0 1]
    end

    properties (Constant, Access = private)
        EDGE_TOL = 0.01             % fraction of the log length that counts as on an edge
        BAND = [1.08 1.35]          % y range of the mode strip; the overview uses 0..1
        OVERVIEW_BUCKETS = 1000     % about the strip's width in pixels
    end

    methods
        function obj = RangeTimeline(parent)
            ax = uiaxes(parent);
            disableDefaultInteractivity(ax);
            ax.Toolbar.Visible = 'off';
            ax.YTick = [];
            box(ax, 'on');
            obj.Axes = ax;
        end

        function onLoad(obj, app)
            ax = obj.Axes;
            cla(ax);
            hold(ax, 'on');
            ax.XLim = app.Span;
            ax.YLim = [-0.05 obj.BAND(2)];
            obj.drawModes(app);
            c = app.Theme.accent;
            obj.Window = patch(ax, NaN(1, 4), [ax.YLim(1) ax.YLim(1) ax.YLim(2) ax.YLim(2)], c, ...
                'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HitTest', 'off', 'PickableParts', 'none');
            obj.EdgeL = xline(ax, app.Span(1), 'Color', c, 'LineWidth', 2, 'HitTest', 'off');
            obj.EdgeR = xline(ax, app.Span(2), 'Color', c, 'LineWidth', 2, 'HitTest', 'off');
        end

        function onSelection(obj, app)
            % Overview of the plotted series, each scaled to 0..1
            delete(findobj(obj.Axes, 'Tag', 'overview'));
            for k = 1:numel(app.Selection)
                [t, v] = app.seriesData(k);
                if isempty(t), continue; end
                [t, v] = ardupilot_analyze.plot.envelope(t, v, obj.OVERVIEW_BUCKETS);
                v = (v - min(v))/max(max(v) - min(v), eps);
                h = plot(obj.Axes, t, v, 'Color', app.Theme.muted, 'Tag', 'overview', ...
                    'HitTest', 'off', 'PickableParts', 'none');
                uistack(h, 'bottom');
            end
        end

        function onRange(obj, app)
            if isempty(obj.Window), return; end
            r = app.Range;
            obj.Window.XData = [r(1) r(2) r(2) r(1)];
            obj.EdgeL.Value = r(1);
            obj.EdgeR.Value = r(2);
        end

        function tf = isOver(obj)
            [~, tf] = obj.pointer();
        end

        function handled = mouseDown(obj, app)
            % True when the click was on the timeline
            [x, handled] = obj.pointer();
            if handled, obj.press(app, x, app.Figure.SelectionType); end
        end

        function handled = mouseMove(obj, app)
            % True when the event belongs to the timeline (dragging, or the pointer is over it)
            [x, inside] = obj.pointer();
            if isempty(obj.Drag)
                handled = inside;
                app.Figure.Pointer = obj.pointerShape(x, inside, app);
                return
            end
            handled = true;
            obj.dragTo(app, x);
        end

        function mouseUp(obj, app)
            obj.release(app);
        end

        % press, dragTo and release hold the logic, with the pointer time and the button
        % ('normal', 'alt' for the right button, 'open' for a double-click) passed in, so scripts
        % and tests can drive the timeline without a mouse

        function press(obj, app, x, type)
            if strcmp(type, 'open')
                obj.Drag = '';
                app.setRange(app.Span);
                return
            end
            obj.Prev = app.Range;
            r = app.Range;
            tol = obj.EDGE_TOL*diff(app.Span);
            if strcmp(type, 'alt')
                if abs(x - r(1)) <= abs(x - r(2)), obj.Drag = 'L'; else, obj.Drag = 'R'; end
                obj.dragTo(app, x);
            elseif abs(x - r(1)) <= tol
                obj.Drag = 'L';
            elseif abs(x - r(2)) <= tol
                obj.Drag = 'R';
            elseif x > r(1) && x < r(2)
                obj.Drag = 'M';
                obj.Grab = x - r(1);
            else
                obj.Drag = 'N';
                obj.Anchor = x;
            end
        end

        function dragTo(obj, app, x)
            r = app.Range;
            x = min(max(x, app.Span(1)), app.Span(2));
            switch obj.Drag
                case 'L'
                    if x > r(2), obj.Drag = 'R'; end
                    app.setRange([x r(2)]);
                case 'R'
                    if x < r(1), obj.Drag = 'L'; end
                    app.setRange([r(1) x]);
                case 'M'
                    w = diff(r);
                    s = min(max(x - obj.Grab, app.Span(1)), app.Span(2) - w);
                    app.setRange([s s + w]);
                case 'N'
                    app.setRange([obj.Anchor x]);
            end
        end

        function release(obj, app)
            if isempty(obj.Drag), return; end
            % a click without a drag would leave a near-zero window
            if strcmp(obj.Drag, 'N') && diff(app.Range) < obj.EDGE_TOL*diff(app.Span)
                app.setRange(obj.Prev);
            end
            obj.Drag = '';
        end
    end

    methods (Access = private)
        function [x, inside] = pointer(obj)
            cp = obj.Axes.CurrentPoint;
            x = cp(1, 1); y = cp(1, 2);
            xl = obj.Axes.XLim; yl = obj.Axes.YLim;
            inside = x >= xl(1) && x <= xl(2) && y >= yl(1) && y <= yl(2);
        end

        function shape = pointerShape(obj, x, inside, app)
            r = app.Range;
            tol = obj.EDGE_TOL*diff(app.Span);
            if ~inside
                shape = 'arrow';
            elseif abs(x - r(1)) <= tol
                shape = 'left';
            elseif abs(x - r(2)) <= tol
                shape = 'right';
            elseif x > r(1) && x < r(2)
                shape = 'fleur';
            else
                shape = 'crosshair';
            end
        end

        function drawModes(obj, app)
            if ~app.Log.has('MODE'), return; end
            m = app.Log.read('MODE');
            names = ardupilot_analyze.vehicle.modeNames(app.Log.Vehicle);
            edges = [m.t; app.Span(2)];
            cmap = app.Theme.series;
            b = obj.BAND;
            for k = 1:numel(m.Mode)
                x0 = max(edges(k), app.Span(1)); x1 = edges(k + 1);
                if x1 <= x0, continue; end
                patch(obj.Axes, [x0 x1 x1 x0], [b(1) b(1) b(2) b(2)], cmap(mod(m.Mode(k), size(cmap, 1)) + 1, :), ...
                    'EdgeColor', 'none', 'HitTest', 'off', 'PickableParts', 'none');
                if x1 - x0 > 0.04*diff(app.Span)
                    if isKey(names, m.Mode(k)), label = names(m.Mode(k)); else, label = num2str(m.Mode(k)); end
                    text(obj.Axes, (x0 + x1)/2, mean(b), label, 'FontSize', 8, 'Color', app.Theme.modeText, ...
                        'HorizontalAlignment', 'center', 'HitTest', 'off', 'Clipping', 'on');
                end
            end
        end
    end
end
