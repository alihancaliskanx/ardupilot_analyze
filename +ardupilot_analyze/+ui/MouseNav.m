classdef MouseNav < handle
    % Scroll-wheel zoom around the pointer, left-drag pan and double-click reset for one axes, and
    % right-drag rotation about the centre of the view when Rotate is set.
    % The window's mouse callbacks call down/move/up/scroll. MATLAB's own axes interactions are
    % switched off so that they do not compete with those callbacks.

    properties
        Home = []           % called on double-click, e.g. to show everything again
        HomeButton = 'any'  % 'middle': only a double-click of the wheel button calls Home
        Rotate = []         % @(centre, angle): right-drag turned the pointer by angle (rad) about centre
        RotateStart = []    % called when a right-drag starts
    end

    properties (SetAccess = private)
        Axes
        Dims                % 'x' or 'xy'
    end

    properties (Access = private)
        Anchor = []         % data point under the pointer when the drag started
        LastClick = ''      % SelectionType of the previous press
        Centre = []         % view centre while rotating
        Angle0 = 0          % pointer angle about Centre when the right-drag started
    end

    properties (Constant, Access = private)
        STEP = 1.2          % zoom factor per wheel notch
    end

    methods
        function obj = MouseNav(ax, dims)
            obj.Axes = ax;
            obj.Dims = dims;
            disableDefaultInteractivity(ax);
            ax.Interactions = [];
            ax.Toolbar.Visible = 'off';
        end

        function tf = isOver(obj)
            p = obj.point();
            xl = obj.Axes.XLim; yl = obj.Axes.YLim;
            tf = p(1) >= xl(1) && p(1) <= xl(2) && p(2) >= yl(1) && p(2) <= yl(2);
        end

        function tf = down(obj, fig)
            tf = obj.isOver();
            if ~tf, return; end
            % A double-click arrives as 'open' whatever the button, so the press before it tells
            % which button it was: 'extend' is the middle button, 'normal' the left one
            type = fig.SelectionType;
            previous = obj.LastClick;
            obj.LastClick = type;
            switch type
                case 'open'
                    obj.Anchor = [];
                    wanted = strcmp(obj.HomeButton, 'any') || strcmp(previous, 'extend');
                    if wanted && ~isempty(obj.Home), obj.Home(); end
                case 'normal'
                    obj.Anchor = obj.point();
                case 'alt'
                    if isempty(obj.Rotate), return; end
                    obj.Centre = [mean(obj.Axes.XLim), mean(obj.Axes.YLim)];
                    obj.Angle0 = obj.angle();
                    if ~isempty(obj.RotateStart), obj.RotateStart(); end
            end
        end

        function tf = move(obj)
            if ~isempty(obj.Centre)
                tf = true;
                % the pointer is read in the axes frame, which rotation does not touch, so the
                % angle is measured against a fixed centre
                obj.Rotate(obj.Centre, obj.angle() - obj.Angle0);
                return
            end
            tf = ~isempty(obj.Anchor);
            if ~tf, return; end
            % the anchor is in data units, so it stays under the pointer while the limits move
            d = obj.Anchor - obj.point();
            obj.Axes.XLim = obj.Axes.XLim + d(1);
            if strcmp(obj.Dims, 'xy')
                obj.Axes.YLim = obj.Axes.YLim + d(2);
            end
        end

        function up(obj)
            obj.Anchor = [];
            obj.Centre = [];
        end

        function tf = scroll(obj, evt)
            tf = obj.isOver();
            if ~tf, return; end
            f = obj.STEP^evt.VerticalScrollCount;
            p = obj.point();
            obj.Axes.XLim = p(1) + (obj.Axes.XLim - p(1))*f;
            if strcmp(obj.Dims, 'xy')
                obj.Axes.YLim = p(2) + (obj.Axes.YLim - p(2))*f;
            end
        end
    end

    methods (Access = protected)
        function p = point(obj)
            cp = obj.Axes.CurrentPoint;
            p = cp(1, 1:2);
        end

        function a = angle(obj)
            d = obj.point() - obj.Centre;
            a = atan2(d(2), d(1));
        end
    end
end
