function T = themes(name)
% Colour sets for the viewer. 'rainynight' follows the Omarchy theme of that name
% (~/.config/omarchy/themes/rainynight/colors.toml); 'light' is the plain MATLAB look.
%
% T = ardupilot_analyze.ui.themes('rainynight')

switch lower(name)
    case 'rainynight'
        T.mode = 'dark';
        T.background = hex('#1e1e2e');      % window
        T.panel = hex('#181825');           % plot areas, tree, inputs
        T.raised = hex('#313244');          % buttons
        T.foreground = hex('#cdd6f4');
        T.muted = hex('#585b70');           % the whole-log path, overview curves
        T.grid = hex('#45475a');
        T.accent = hex('#89b4fa');          % time window, selected path
        T.cursor = hex('#f38ba8');
        T.series = hex({'#89b4fa', '#fab387', '#a6e3a1', '#f38ba8', '#cba6f7', '#94e2d5', '#f9e2af'});
        % the 14 Catppuccin Mocha accents, which the theme's own colours are taken from
        T.palette = [T.series; hex({'#f5c2e7', '#74c7ec', '#eba0ac', '#b4befe', '#89dceb', ...
            '#f2cdcd', '#f5e0dc'})];
        T.modeText = hex('#11111b');        % labels on the pastel mode strip
    case 'light'
        T.mode = 'light';
        T.background = [0.94 0.94 0.94];
        T.panel = [1 1 1];
        T.raised = [0.96 0.96 0.96];
        T.foreground = [0.15 0.15 0.15];
        T.muted = [0.78 0.78 0.78];
        T.grid = [0.15 0.15 0.15];
        T.accent = [0.12 0.47 0.71];
        T.cursor = [0.84 0.15 0.16];
        T.series = lines(7);
        T.palette = [T.series; 0.8*hsv(7)];
        T.modeText = [1 1 1];
    otherwise
        error('ardupilot_analyze: unknown theme %s; use rainynight or light', name);
end
T.name = lower(name);
end

function c = hex(h)
if iscell(h)
    c = cell2mat(cellfun(@hex, h(:), 'UniformOutput', false));
    return
end
c = double(sscanf(h(2:end), '%2x', [1 3]))/255;
end
