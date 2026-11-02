# ardupilot_analyze

A MATLAB viewer for ArduPilot DataFlash logs (`.BIN`), laid out like
[plot.ardupilot.org](https://plot.ardupilot.org): message tree, time plot with a range
timeline, presets, and a separate map window (`mapper`) that shows the horizontal path of the
selected time window. It reads logs of any ArduPilot vehicle (Copter, Plane, Rover, Sub) and
does not need GPS: the path can come from the EKF position, so DVL-based underwater logs work.

## Requirements

MATLAB R2024a or later, no toolboxes. Developed and tested with R2026b on Linux.

## Use

From this folder in MATLAB:

```matlab
ardupilot_analyze                                   % empty window; open a log with Open...
ardupilot_analyze('00000028.BIN')
ardupilot_analyze('File', '00000028.BIN', 'Select', {'XKF1[0].PN'; 'ATT.Yaw'}, 'Range', [800 1100])
ardupilot_analyze('Config', 'session.json')         % the same options from a JSON file
```

`help ardupilot_analyze.options` lists all options. `ardupilot_analyze.sh` starts the viewer
without the MATLAB desktop, for a desktop launcher.

| Part | Mouse |
|---|---|
| Time plot | wheel zooms time, drag pans, middle-button box sets time and series ranges, double-click undoes the box |
| Series rulers (left of the plot) | drag the middle to pan, the ends to scale; wheel scales; double-click resets that series |
| Timeline | drag the window or its edges; right-press moves the nearer edge; double-click selects the whole log |
| Map | wheel zooms, drag pans, right-drag rotates, wheel-button double-click resets |

Plot expressions combine fields as `MSG.FIELD` or `MSG[i].FIELD` with numbers, `+ - * / ^`
(or `**`) and functions such as `sqrt`, `hypot`, `atan2` and `degrees`, for example
`hypot(XKF1[0].VN, XKF1[0].VE)`.

## Layout

| Path | Contents |
|---|---|
| `+ardupilot_analyze/+io` | DataFlash reader |
| `+ardupilot_analyze/+plot` | expression evaluation and presets |
| `+ardupilot_analyze/+ui` | window, panels, theme |
| `+ardupilot_analyze/+mapper` | path sources and the map window |
| `+ardupilot_analyze/+vehicle` | flight mode names per vehicle |
| `presets` | native presets; custom presets are saved to `presets/user` |

## License

Copyright (C) 2026 Alihan Çalışkan

This program is free software: you can redistribute it and/or modify it under the terms of the
GNU General Public License as published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version. It is distributed in the hope that it will
be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See [LICENSE](LICENSE) for the full text.

The graph definitions in `presets/*.xml` come from ArduPilot's
[UAVLogViewer](https://github.com/ArduPilot/UAVLogViewer) (`src/assets`), which is licensed
under the GNU General Public License v3. They use the graph format of MAVProxy's MAVExplorer.
