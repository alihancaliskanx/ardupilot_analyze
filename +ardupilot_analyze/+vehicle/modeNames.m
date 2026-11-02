function m = modeNames(vehicle)
% Flight mode number -> name for one vehicle type (as returned by DataFlashLog.Vehicle).
% An unknown vehicle gets an empty map; callers then show the number.

m = containers.Map('KeyType', 'double', 'ValueType', 'char');
switch vehicle
    case 'copter'
        t = {0 'STABILIZE'; 1 'ACRO'; 2 'ALT_HOLD'; 3 'AUTO'; 4 'GUIDED'; 5 'LOITER'; 6 'RTL';
            7 'CIRCLE'; 9 'LAND'; 11 'DRIFT'; 13 'SPORT'; 14 'FLIP'; 15 'AUTOTUNE'; 16 'POSHOLD';
            17 'BRAKE'; 18 'THROW'; 19 'AVOID_ADSB'; 20 'GUIDED_NOGPS'; 21 'SMART_RTL'; 22 'FLOWHOLD';
            23 'FOLLOW'; 24 'ZIGZAG'; 25 'SYSTEMID'; 26 'AUTOROTATE'; 27 'AUTO_RTL'; 28 'TURTLE'};
    case 'plane'
        t = {0 'MANUAL'; 1 'CIRCLE'; 2 'STABILIZE'; 3 'TRAINING'; 4 'ACRO'; 5 'FBWA'; 6 'FBWB';
            7 'CRUISE'; 8 'AUTOTUNE'; 10 'AUTO'; 11 'RTL'; 12 'LOITER'; 13 'TAKEOFF'; 14 'AVOID_ADSB';
            15 'GUIDED'; 16 'INITIALISING'; 17 'QSTABILIZE'; 18 'QHOVER'; 19 'QLOITER'; 20 'QLAND';
            21 'QRTL'; 22 'QAUTOTUNE'; 23 'QACRO'; 24 'THERMAL'; 25 'LOITER_ALT_QLAND'};
    case 'rover'
        t = {0 'MANUAL'; 1 'ACRO'; 3 'STEERING'; 4 'HOLD'; 5 'LOITER'; 6 'FOLLOW'; 7 'SIMPLE';
            8 'DOCK'; 9 'CIRCLE'; 10 'AUTO'; 11 'RTL'; 12 'SMART_RTL'; 15 'GUIDED'; 16 'INITIALISING'};
    case 'sub'
        t = {0 'STABILIZE'; 1 'ACRO'; 2 'ALT_HOLD'; 3 'AUTO'; 4 'GUIDED'; 7 'CIRCLE'; 9 'SURFACE';
            16 'POSHOLD'; 19 'MANUAL'; 20 'MOTOR_DETECT'; 21 'SURFTRAK'};
    case 'tracker'
        t = {0 'MANUAL'; 1 'STOP'; 2 'SCAN'; 3 'SERVO_TEST'; 10 'AUTO'; 16 'INITIALISING'};
    otherwise
        return
end
for k = 1:size(t, 1)
    m(t{k, 1}) = t{k, 2};
end
end
