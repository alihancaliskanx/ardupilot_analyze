classdef AxisDrag < handle
    % Dragging a y-axis by its tick-label strip, as on plot.ardupilot.org: the middle of the strip
    % pans the axis, the top end moves the upper limit with the lower one fixed, the bottom end
    % the other way round. The wheel over the strip scales it about the value under the pointer.
    % A double-click on the strip calls Auto (or gives automatic limits).
    % The strip is the given width in pixels left of the axes' plot box.

    properties
        Auto = []           % called on a double-click instead of LimitsMode = 'auto'
        Changed = []        % called after the limits were changed by a drag
    end

    properties (SetAccess = private)
        Axes
    end

    properties (Access = private)
        Strip               % px left of the plot box that count as the axis
        Part = ''           % 'pan', 'top' or 'bottom' while dragging
        F0 = 0              % pointer height when the drag started, as a fraction of the plot box
        L0 = [0 1]          % limits when the drag started
    end

    properties (Constant, Access = private)
        ENDS = 0.2          % fraction of the strip height at each end that scales
    end

    methods
        function obj = AxisDrag(ax, stripPx)
            obj.Axes = ax;
            obj.Strip = stripPx;
        end

        function part = over(obj)
            % 'pan', 'top' or 'bottom' when the pointer is on the strip, '' otherwise
            part = '';
            [fx, fy] = obj.fraction();
            w = obj.Strip/max(obj.Axes.InnerPosition(3), 1);
            if fy < 0 || fy > 1 || fx >= 0 || fx < -w, return; end
            if fy > 1 - obj.ENDS, part = 'top';
            elseif fy < obj.ENDS, part = 'bottom';
            else, part = 'pan';
            end
        end

        function tf = down(obj, fig)
            part = obj.over();
            tf = ~isempty(part);
            if ~tf, return; end
            switch fig.SelectionType
                case 'open'
                    obj.Part = '';
                    if isempty(obj.Auto), obj.Axes.YLimMode = 'auto'; else, obj.Auto(); end
                case 'normal'
                    obj.Part = part;
                    [~, obj.F0] = obj.fraction();
                    obj.L0 = obj.Axes.YLim;
            end
        end

        function tf = move(obj)
            tf = ~isempty(obj.Part);
            if ~tf, return; end
            % fractions of the plot box do not depend on the limits, so the new limits are always
            % worked out from the ones at the press
            [~, f] = obj.fraction();
            L = obj.L0;
            span = diff(L);
            v0 = L(1) + obj.F0*span;            % value that was under the pointer at the press
            switch obj.Part
                case 'pan'
                    L = L + (obj.F0 - f)*span;
                case 'top'
                    L(2) = L(1) + (v0 - L(1))/max(f, 0.02);
                case 'bottom'
                    L(1) = L(2) - (L(2) - v0)/(1 - min(f, 0.98));
            end
            if all(isfinite(L)) && diff(L) > 0
                obj.Axes.YLim = L;
                if ~isempty(obj.Changed), obj.Changed(); end
            end
        end

        function up(obj)
            obj.Part = '';
        end

        function tf = zoom(obj, f)
            % Wheel over the strip: scales the axis by f about the value under the pointer
            tf = ~isempty(obj.over());
            if ~tf, return; end
            [~, fy] = obj.fraction();
            L = obj.Axes.YLim;
            v = L(1) + fy*diff(L);
            obj.Axes.YLim = v + (L - v)*f;
            if ~isempty(obj.Changed), obj.Changed(); end
        end

        function shape = pointerShape(obj)
            % Figure pointer for the strip part under the pointer, or '' when it is not on the strip
            switch obj.over()
                case 'pan', shape = 'fleur';
                case 'top', shape = 'top';
                case 'bottom', shape = 'bottom';
                otherwise, shape = '';
            end
        end
    end

    methods (Access = protected)
        function [fx, fy] = fraction(obj)
            % Pointer position as fractions of the plot box (0..1 inside it)
            cp = obj.Axes.CurrentPoint;
            xl = obj.Axes.XLim;
            yl = obj.Axes.YLim;
            fx = (cp(1, 1) - xl(1))/diff(xl);
            fy = (cp(1, 2) - yl(1))/diff(yl);
        end
    end
end
