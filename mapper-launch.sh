#!/bin/sh
# Starts the log viewer without the MATLAB desktop. MATLAB exits when the viewer window is closed.
# Extra arguments are passed to mapper as MATLAB text, e.g.  mapper-launch.sh "'00000028.BIN'"
# -batch would be simpler, but it refuses blocking dialogs, so Open... could not show the file picker.
# Output goes to ${TMPDIR:-/tmp}/mapper.log, since a launcher has no terminal to show errors in.

cd "$(dirname "$(readlink -f "$0")")" || exit 1
MATLAB_BIN=${MATLAB_BIN:-$(command -v matlab || echo "$HOME/MATLAB/R2026b/bin/matlab")}
exec "$MATLAB_BIN" -nodesktop -logfile "${TMPDIR:-/tmp}/mapper.log" \
    -r "try, app = mapper($*); waitfor(app.Figure); catch err, disp(getReport(err)); end; exit" < /dev/null
