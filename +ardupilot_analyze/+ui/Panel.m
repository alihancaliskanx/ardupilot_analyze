classdef (Abstract) Panel < handle
    % Part of the viewer window. The App calls these when the shared state changes; a panel
    % overrides the ones it needs. The state itself (log, time range, selected fields) lives in
    % the App, so a panel never talks to another panel directly.

    methods
        function onLoad(~, ~)
            % A log was opened: app.Log, app.Span
        end

        function onRange(~, ~)
            % The time window changed: app.Range
        end

        function onSelection(~, ~)
            % The plotted fields changed: app.Selection
        end

        function onCursor(~, ~, ~)
            % The pointer is over time t (s) in the time plot
        end
    end
end
