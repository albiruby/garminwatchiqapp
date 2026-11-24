import Toybox.Lang;
import Toybox.Math;

//! Side-view human skeleton and forward kinematics (mirrors
//! tools/motion/motion_model.py). Figure units: standing height ~ 100.
//! Angles are absolute degrees, counter-clockwise from +x, y up; the figure
//! faces +x. Results are written into a caller-owned buffer (no allocation).
module Skeleton {

    // Segment lengths (figure units)
    const TORSO = 30.0;
    const NECK = 5.0;
    const HEAD_R = 6.5;
    const UARM = 16.0;
    const FARM = 15.0;
    const THIGH = 25.0;
    const SHIN = 24.0;
    const FOOT = 10.0;
    const HEEL_LX = -0.7;   // heel in the foot frame (x along ankle -> toe)
    const HEEL_LY = -4.7;

    // Pose vector layout
    const P_X = 0;
    const P_Y = 1;
    const P_SPINE = 2;
    const P_TORSO = 3;
    const P_HEAD = 4;
    const P_UAN = 5;
    const P_FAN = 6;
    const P_UAF = 7;
    const P_FAF = 8;
    const P_THN = 9;
    const P_SHN = 10;
    const P_FTN = 11;
    const P_THF = 12;
    const P_SHF = 13;
    const P_FTF = 14;
    const POSE_LEN = 15;

    // Joint layout in the output buffer (x at 2*j, y at 2*j + 1)
    const J_HIP = 0;
    const J_SHOULDER = 1;
    const J_HEAD = 2;
    const J_ELBOW_N = 3;
    const J_WRIST_N = 4;
    const J_ELBOW_F = 5;
    const J_WRIST_F = 6;
    const J_KNEE_N = 7;
    const J_ANKLE_N = 8;
    const J_TOE_N = 9;
    const J_HEEL_N = 10;
    const J_KNEE_F = 11;
    const J_ANKLE_F = 12;
    const J_TOE_F = 13;
    const J_HEEL_F = 14;
    const J_SPINE_C = 15;
    const JOINTS = 16;

    // Body parts (bit flags) for highlighting
    const PART_TORSO = 1;
    const PART_HEAD = 2;
    const PART_ARM_N = 4;
    const PART_ARM_F = 8;
    const PART_THIGH_N = 16;
    const PART_SHIN_N = 32;
    const PART_FOOT_N = 64;
    const PART_THIGH_F = 128;
    const PART_SHIN_F = 256;
    const PART_FOOT_F = 512;

    const DEG = 0.017453292519943295;

    function newJointBuffer() as Array {
        var b = new [JOINTS * 2];
        for (var i = 0; i < b.size(); i++) {
            b[i] = 0.0;
        }
        return b;
    }

    function setJ(out as Array, j as Number, x, y) as Void {
        out[2 * j] = x;
        out[2 * j + 1] = y;
    }

    //! Two-segment chain from joint `base`: writes the middle and end joints.
    function chain(out as Array, base as Number, a1, l1, a2, l2, mid as Number, tip as Number) as Void {
        var bx = out[2 * base];
        var by = out[2 * base + 1];
        var mx = bx + l1 * Math.cos(a1 * DEG);
        var my = by + l1 * Math.sin(a1 * DEG);
        setJ(out, mid, mx, my);
        setJ(out, tip, mx + l2 * Math.cos(a2 * DEG), my + l2 * Math.sin(a2 * DEG));
    }

    //! Toe and heel from the ankle and foot angle.
    function foot(out as Array, ankle as Number, a, toe as Number, heel as Number) as Void {
        var ax = out[2 * ankle];
        var ay = out[2 * ankle + 1];
        var fx = Math.cos(a * DEG);
        var fy = Math.sin(a * DEG);
        setJ(out, toe, ax + FOOT * fx, ay + FOOT * fy);
        setJ(out, heel, ax + HEEL_LX * fx - HEEL_LY * fy, ay + HEEL_LX * fy + HEEL_LY * fx);
    }

    //! Forward kinematics: pose vector -> joint buffer.
    function fk(p as Array, out as Array) as Void {
        var hx = p[P_X];
        var hy = p[P_Y];
        var tx = Math.cos(p[P_TORSO] * DEG);
        var ty = Math.sin(p[P_TORSO] * DEG);
        var sx = hx + TORSO * tx;
        var sy = hy + TORSO * ty;
        setJ(out, J_HIP, hx, hy);
        setJ(out, J_SHOULDER, sx, sy);
        setJ(out, J_HEAD, sx + (NECK + HEAD_R) * Math.cos(p[P_HEAD] * DEG), sy + (NECK + HEAD_R) * Math.sin(p[P_HEAD] * DEG));
        // spine control point: chord midpoint pushed along the left normal
        var s = p[P_SPINE];
        setJ(out, J_SPINE_C, (hx + sx) / 2 - s * ty, (hy + sy) / 2 + s * tx);
        chain(out, J_SHOULDER, p[P_UAN], UARM, p[P_FAN], FARM, J_ELBOW_N, J_WRIST_N);
        chain(out, J_SHOULDER, p[P_UAF], UARM, p[P_FAF], FARM, J_ELBOW_F, J_WRIST_F);
        chain(out, J_HIP, p[P_THN], THIGH, p[P_SHN], SHIN, J_KNEE_N, J_ANKLE_N);
        foot(out, J_ANKLE_N, p[P_FTN], J_TOE_N, J_HEEL_N);
        chain(out, J_HIP, p[P_THF], THIGH, p[P_SHF], SHIN, J_KNEE_F, J_ANKLE_F);
        foot(out, J_ANKLE_F, p[P_FTF], J_TOE_F, J_HEEL_F);
    }

    //! Figure x -> screen x (mirror = face left; used for left/right sides).
    function screenX(x, camX, scale, cx as Number, mirror as Boolean) as Float {
        var d = (x - camX) * scale;
        return (mirror ? cx - d : cx + d).toFloat();
    }

    function screenY(y, camY, scale, cy as Number) as Float {
        return (cy - (y - camY) * scale).toFloat();
    }
}
