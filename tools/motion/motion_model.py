#!/usr/bin/env python3
"""RESTORA exercise motion model: the single source of truth for poses.

Defines a side-view human skeleton, authors exercise poses (with 2-link IK so
feet and hands land where they should), validates them, and generates:

  source/Motion/Exercise/ExercisePoseData.mc   pose + animation data for Monkey C
  source/Tests/MotionGolden.mc                 golden values for unit tests
  tools/mockups/figure_frames.js               draw ops for the HTML mockups
  docs/mockups/motion-*.png                    frame-strip previews

The forward kinematics, sampling and drawing here mirror the Monkey C code in
source/Motion/ line for line, so the previews show what the watch draws.

Usage:  python3 tools/motion/motion_model.py
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ---------------------------------------------------------------------------
# Skeleton (figure units; standing height ~ 100). Angles are absolute degrees,
# counter-clockwise from +x, y up. The figure faces +x (right).
# ---------------------------------------------------------------------------
TORSO, NECK, HEAD_R = 30.0, 5.0, 6.5
UARM, FARM = 16.0, 15.0
THIGH, SHIN, FOOT = 25.0, 24.0, 10.0
HEEL_LOCAL = (-0.7, -4.7)          # heel in the foot frame (x along ankle->toe)
FLAT_FOOT = -23.6                  # foot angle that puts sole on the floor
NEUTRAL_ANKLE = 66.4               # foot - shin angle when standing (shin -90, flat foot)
ANKLE_H = 4.0                      # ankle height above floor with a flat foot

# Pose vector layout (shared with Monkey C, Skeleton.mc):
P_X, P_Y, P_SPINE, P_TORSO, P_HEAD = 0, 1, 2, 3, 4
P_UAN, P_FAN, P_UAF, P_FAF = 5, 6, 7, 8          # arms: near / far
P_THN, P_SHN, P_FTN, P_THF, P_SHF, P_FTF = 9, 10, 11, 12, 13, 14  # legs
POSE_LEN = 15

# Joint output layout (FK result, x/y pairs):
J_HIP, J_SHOULDER, J_HEAD = 0, 1, 2
J_ELBOW_N, J_WRIST_N, J_ELBOW_F, J_WRIST_F = 3, 4, 5, 6
J_KNEE_N, J_ANKLE_N, J_TOE_N, J_HEEL_N = 7, 8, 9, 10
J_KNEE_F, J_ANKLE_F, J_TOE_F, J_HEEL_F = 11, 12, 13, 14
J_SPINE_C = 15                     # spine control point (curve)
JOINTS = 16

# Body parts (bit flags) for highlighting.
PART_TORSO, PART_HEAD = 1, 2
PART_ARM_N, PART_ARM_F = 4, 8
PART_THIGH_N, PART_SHIN_N, PART_FOOT_N = 16, 32, 64
PART_THIGH_F, PART_SHIN_F, PART_FOOT_F = 128, 256, 512
ALL_PARTS = 1023


def d2r(a):
    return a * math.pi / 180.0


def dirv(a):
    return (math.cos(d2r(a)), math.sin(d2r(a)))


def fk(p):
    """Forward kinematics: pose vector -> list of joint (x, y)."""
    j = [None] * JOINTS
    hip = (p[P_X], p[P_Y])
    t = dirv(p[P_TORSO])
    sh = (hip[0] + TORSO * t[0], hip[1] + TORSO * t[1])
    hd = dirv(p[P_HEAD])
    head = (sh[0] + (NECK + HEAD_R) * hd[0], sh[1] + (NECK + HEAD_R) * hd[1])
    mid = ((hip[0] + sh[0]) / 2, (hip[1] + sh[1]) / 2)
    nrm = (-t[1], t[0])            # left normal of the spine (up when facing right)
    j[J_HIP], j[J_SHOULDER], j[J_HEAD] = hip, sh, head
    j[J_SPINE_C] = (mid[0] + p[P_SPINE] * nrm[0], mid[1] + p[P_SPINE] * nrm[1])

    def chain(base, a1, l1, a2, l2):
        u = dirv(a1)
        m = (base[0] + l1 * u[0], base[1] + l1 * u[1])
        v = dirv(a2)
        return m, (m[0] + l2 * v[0], m[1] + l2 * v[1])

    j[J_ELBOW_N], j[J_WRIST_N] = chain(sh, p[P_UAN], UARM, p[P_FAN], FARM)
    j[J_ELBOW_F], j[J_WRIST_F] = chain(sh, p[P_UAF], UARM, p[P_FAF], FARM)
    for (kn, an, tn, hn, th, shn, ft) in ((J_KNEE_N, J_ANKLE_N, J_TOE_N, J_HEEL_N, P_THN, P_SHN, P_FTN),
                                          (J_KNEE_F, J_ANKLE_F, J_TOE_F, J_HEEL_F, P_THF, P_SHF, P_FTF)):
        knee, ankle = chain(hip, p[th], THIGH, p[shn], SHIN)
        f = dirv(p[ft])
        toe = (ankle[0] + FOOT * f[0], ankle[1] + FOOT * f[1])
        heel = (ankle[0] + HEEL_LOCAL[0] * f[0] - HEEL_LOCAL[1] * f[1],
                ankle[1] + HEEL_LOCAL[0] * f[1] + HEEL_LOCAL[1] * f[0])
        j[kn], j[an], j[tn], j[hn] = knee, ankle, toe, heel
    return j


def ik(base, target, l1, l2, bend):
    """2-link IK. bend=+1 rotates the first link CCW from the base->target line."""
    dx, dy = target[0] - base[0], target[1] - base[1]
    d = min(math.hypot(dx, dy), l1 + l2 - 1e-6)
    a = math.degrees(math.atan2(dy, dx))
    c = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    alpha = math.degrees(math.acos(max(-1.0, min(1.0, c))))
    a1 = a + bend * alpha
    m = (base[0] + l1 * math.cos(d2r(a1)), base[1] + l1 * math.sin(d2r(a1)))
    a2 = math.degrees(math.atan2(target[1] - m[1], target[0] - m[0]))
    return round(a1, 1), round(a2, 1)


def pose(**kw):
    p = [0.0] * POSE_LEN
    for k, v in kw.items():
        p[globals()["P_" + k.upper()]] = float(v)
    return p


def shoulder_of(p):
    t = dirv(p[P_TORSO])
    return (p[P_X] + TORSO * t[0], p[P_Y] + TORSO * t[1])


def with_arms(p, near_target, far_target, bend=-1):
    sh = shoulder_of(p)
    p[P_UAN], p[P_FAN] = ik(sh, near_target, UARM, FARM, bend)
    p[P_UAF], p[P_FAF] = ik(sh, far_target, UARM, FARM, bend)
    return p


def with_leg(p, side, ankle_target, bend=1):
    th, sh = (P_THN, P_SHN) if side == "n" else (P_THF, P_SHF)
    p[th], p[sh] = ik((p[P_X], p[P_Y]), ankle_target, THIGH, SHIN, bend)
    return p


# ---------------------------------------------------------------------------
# Exercise poses
# ---------------------------------------------------------------------------
def calf_stretch_poses():
    # Hold: rear (near) leg straight back, heel down; front (far) knee bent;
    # hands on a wall at x = 41; torso leaning forward.
    rear = -115.0
    hip_y = ANKLE_H + (THIGH + SHIN) * -math.sin(d2r(rear))
    hold = pose(x=0, y=round(hip_y, 1), torso=62, head=52, thn=rear, shn=rear, ftn=FLAT_FOOT, ftf=FLAT_FOOT)
    with_leg(hold, "f", (14.0, ANKLE_H))
    with_arms(hold, (39.6, 75.0), (39.4, 77.0))      # wrists just off the wall; palms flat on it
    # Start: upright split stance with both feet already planted where the hold
    # keeps them, arms relaxed. The transition only leans in and reaches the wall.
    rear_ankle = (hold[P_X] + (THIGH + SHIN) * math.cos(d2r(rear)), ANKLE_H)
    sy = 49.6
    sx = rear_ankle[0] + math.sqrt((THIGH + SHIN) ** 2 - (sy - ANKLE_H) ** 2) * 0.999
    start = pose(x=round(sx, 1), y=sy, torso=86, head=84, ftn=FLAT_FOOT, ftf=FLAT_FOOT,
                 uan=-96, fan=-88, uaf=-94, faf=-86)
    with_leg(start, "n", rear_ankle)
    with_leg(start, "f", (14.0, ANKLE_H))
    return [start, hold]


def cat_cow_poses():
    # Quadruped: knees under hips, wrists under shoulders, shins on the floor.
    knee = (0.0, 2.9)                                 # tibia resting on the floor
    hip = (knee[0], knee[1] + THIGH)
    torso = round(math.degrees(math.asin((UARM + FARM + 2.0 - hip[1]) / TORSO)), 1)
    base = dict(x=hip[0], y=hip[1], torso=torso, thn=-90, shn=180, ftn=192, thf=-90, shf=180, ftf=192)
    sh = (hip[0] + TORSO * math.cos(d2r(torso)), hip[1] + TORSO * math.sin(d2r(torso)))
    wrist = (sh[0], 1.8)                              # palm flat on the floor
    cat = pose(spine=4.5, head=-62, **base)     # rounded back, head down
    cow = pose(spine=-3.5, head=28, **base)     # gentle extension, gaze forward/up
    for p in (cat, cow):
        with_arms(p, wrist, (wrist[0] - 1.0, wrist[1]), bend=1)
    return [cat, cow]


def ankle_pump_poses():
    # Lying on the back, legs straight; foot alternates point / flex.
    base = dict(x=0, y=4.6, torso=180, head=178, thn=0, shn=0, thf=0, shf=0, uan=178, fan=178, uaf=178, faf=178)
    flex = pose(ftn=NEUTRAL_ANKLE + 22, ftf=NEUTRAL_ANKLE + 22, **base)
    point = pose(ftn=NEUTRAL_ANKLE - 40, ftf=NEUTRAL_ANKLE - 40, **base)
    return [point, flex]


STAND_HIP_Y = ANKLE_H + THIGH + SHIN          # hip height standing straight
SUPINE = dict(y=5.6, torso=180, head=178, uan=178, fan=178, uaf=178, faf=178)   # lying on the back


def heel_raise_poses():
    # Standing, arms by the sides; rise onto the balls of the feet. The foot
    # pivots on the toe, so the ankle (and the whole body) moves up and a
    # little forward.
    arms = dict(uan=-92, fan=-86, uaf=-90, faf=-84, torso=90, head=90, spine=0)
    flat = pose(x=0, y=STAND_HIP_Y, thn=-90, shn=-90, thf=-90, shf=-90, ftn=FLAT_FOOT, ftf=FLAT_FOOT, **arms)
    toe = (FOOT * math.cos(d2r(FLAT_FOOT)), ANKLE_H + FOOT * math.sin(d2r(FLAT_FOOT)))
    up_ft = FLAT_FOOT - 30.0
    ankle = (toe[0] - FOOT * math.cos(d2r(up_ft)), toe[1] - FOOT * math.sin(d2r(up_ft)))
    up = pose(x=round(ankle[0], 2), y=round(ankle[1] + THIGH + SHIN, 2), thn=-90, shn=-90, thf=-90, shf=-90,
              ftn=up_ft, ftf=up_ft, **arms)
    return [flat, up]


def heel_slide_poses():
    # Lying on the back: the near heel slides along the floor toward the hip
    # (knee rises), then back out. The far leg stays straight.
    # Keyframes along the slide keep the heel on the floor: the ankle path is
    # sampled and the foot angle solved so the heel just touches the floor.
    frames = []
    y0 = SUPINE["y"]
    for s in (0.0, 0.25, 0.5, 0.75, 1.0):
        ax = (THIGH + SHIN) + (30.0 - (THIGH + SHIN)) * s
        ay = y0 + (ANKLE_H - y0) * s
        p = pose(x=0, thf=0, shf=0, ftf=NEUTRAL_ANKLE, ftn=NEUTRAL_ANKLE, **SUPINE)
        if s > 0.0:
            with_leg(p, "n", (ax, ay), bend=1)
            # foot angle within the ankle's range that brings the heel closest
            # to the floor, preferring a relaxed ankle
            best, cost = None, 1e9
            for k in range(-480, 300):
                dors = k * 0.1
                fa = p[P_SHN] + NEUTRAL_ANKLE + dors
                hy = ay + HEEL_LOCAL[0] * math.sin(d2r(fa)) + HEEL_LOCAL[1] * math.cos(d2r(fa))
                c = abs(hy - 0.2) + 0.02 * abs(dors)
                ty = ay + FOOT * math.sin(d2r(fa))
                if hy > -0.3 and ty > 0.4 and c < cost:
                    best, cost = fa, c
            p[P_FTN] = round(best, 1)
        frames.append(p)
    return frames


def childs_pose_poses():
    # From all fours, sink the hips back toward the heels, chest down, arms
    # long on the floor, forehead resting near the floor.
    # Keyframes are built geometrically at several points of the movement (knee
    # fixed on the floor, hands sliding forward on the floor) so the linear
    # blend between neighbours never pushes a knee or hand into the floor.
    knee = (0.0, 2.9)
    legs = dict(shn=180, ftn=192, shf=180, ftf=192)
    a_start, a_hold = 90.0, 180.0 - 36.87                # hip angle around the knee
    sh_start_y = UARM + FARM + 2.0
    wrist_start = None
    frames = []
    for s in (0.0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1.0):
        a = a_start + (a_hold - a_start) * s
        hip = (knee[0] + THIGH * math.cos(d2r(a)), knee[1] + THIGH * math.sin(d2r(a)))
        th = round(a - 180.0, 1)                         # hip -> knee
        sh_y = sh_start_y + (10.0 - sh_start_y) * s
        t = round(math.degrees(math.asin((sh_y - hip[1]) / TORSO)), 1)
        p = pose(x=round(hip[0], 2), y=round(hip[1], 2), torso=t, head=-20, thn=th, thf=th, spine=3.0 * s, **legs)
        sh = shoulder_of(p)
        if wrist_start is None:
            wrist_start = sh[0]
        wx = wrist_start + 9.0 * s                       # hands walk forward a little
        reach = min(UARM + FARM - 1.5, math.hypot(1, sh[1] - 1.8) + 0.0)
        wx = max(wx, sh[0] + math.sqrt(max(0.0, (UARM + FARM - 2.0) ** 2 - (sh[1] - 1.8) ** 2)) * s)
        with_arms(p, (wx, 2.6 + 3.2 * math.sin(math.pi * s)), (wx - 1.0, 2.6 + 3.2 * math.sin(math.pi * s)), bend=1)
        frames.append(p)
    return frames


def legs_wall_poses():
    # Lying on the back, hips close to the wall, legs resting up the wall.
    # Start with knees bent (feet on the wall), then straighten the legs up.
    hold = pose(x=0, thn=90, shn=90, thf=90, shf=90, ftn=90 + NEUTRAL_ANKLE - 20, ftf=90 + NEUTRAL_ANKLE - 20,
                **SUPINE)
    start = pose(x=0, ftn=90 + NEUTRAL_ANKLE - 40, ftf=90 + NEUTRAL_ANKLE - 40, **SUPINE)
    with_leg(start, "n", (2.0, 33.0), bend=1)
    with_leg(start, "f", (2.0, 33.0), bend=1)
    return [start, hold]


LEGS_CHAIR_SHIN_Y = 24.0


def legs_chair_poses(shin_y=None):
    # Lying on the back, calves resting on a support (chair seat, or a lower
    # stack of pillows), knees bent.
    if shin_y is None:
        shin_y = LEGS_CHAIR_SHIN_Y
    k_dy = shin_y - SUPINE["y"]
    k_dx = math.sqrt(THIGH ** 2 - k_dy ** 2)
    th = round(math.degrees(math.atan2(k_dy, k_dx)), 1)
    rest = pose(x=0, thn=th, shn=0, thf=th, shf=0, ftn=NEUTRAL_ANKLE - 15, ftf=NEUTRAL_ANKLE - 15, **SUPINE)
    return [rest]


PILLOW_SHIN_Y = 15.0


def pillow_support():
    # [x0, x1, top, backX, backTop]: a low block under the calves
    k_dx = math.sqrt(THIGH ** 2 - (PILLOW_SHIN_Y - SUPINE["y"]) ** 2)
    return [round(k_dx + 1.0, 1), round(k_dx + 27.0, 1), PILLOW_SHIN_Y - 3.0, 0.0, 0.0]


SEAT_Y = 23.0          # chair seat top for a seated figure (knee height ~28)


def seated_march_poses():
    # Sitting upright on a chair, hands on the thighs; lift one knee, lower,
    # then the other.
    hip = (0.0, ANKLE_H + SHIN)
    base = dict(x=hip[0], y=hip[1], torso=90, head=90, spine=0)

    def seated(lift_n, lift_f):
        p = pose(thn=lift_n, shn=-90, thf=lift_f, shf=-90, ftn=FLAT_FOOT, ftf=FLAT_FOOT, **base)
        kn = (hip[0] + THIGH * math.cos(d2r(lift_n)), hip[1] + THIGH * math.sin(d2r(lift_n)))
        kf = (hip[0] + THIGH * math.cos(d2r(lift_f)), hip[1] + THIGH * math.sin(d2r(lift_f)))
        # hands rest on the thighs, two thirds of the way to the knee
        with_arms(p, (hip[0] + (kn[0] - hip[0]) * 0.62, hip[1] + (kn[1] - hip[1]) * 0.62 + 4.5),
                  (hip[0] + (kf[0] - hip[0]) * 0.62 - 1.0, hip[1] + (kf[1] - hip[1]) * 0.62 + 4.5), bend=-1)
        return p
    return [seated(0, 0), seated(28, 0), seated(0, 28)]


def walk_poses():
    # Walking in place, side view: contact (near leg forward), passing, contact
    # (far leg forward), passing. Arms swing opposite to the legs.
    hy = 51.5
    up = dict(x=0, y=hy, torso=88, head=88, spine=0)

    def contact(front, back, arm_front_n):
        p = pose(**up)
        fs, bs = ("n", "f") if front == "n" else ("f", "n")
        with_leg(p, fs, (12.0, ANKLE_H + 1.0), bend=1)
        with_leg(p, bs, (-12.0, ANKLE_H + 5.0), bend=1)
        p[P_FTN if fs == "n" else P_FTF] = FLAT_FOOT + 4.0          # heel strike, toes up
        p[P_FTN if bs == "n" else P_FTF] = FLAT_FOOT - 20.0         # toe-off
        fwd, back_ = (-68.0, -52.0), (-112.0, -104.0)
        (p[P_UAN], p[P_FAN]), (p[P_UAF], p[P_FAF]) = (fwd, back_) if arm_front_n else (back_, fwd)
        return p

    def passing(stance):
        p = pose(uan=-90, fan=-84, uaf=-90, faf=-84, **up)
        p[P_Y] = hy + 1.0
        ss, ws = ("n", "f") if stance == "n" else ("f", "n")
        with_leg(p, ss, (0.0, ANKLE_H), bend=1)
        with_leg(p, ws, (2.0, 16.0), bend=1)
        p[P_FTN if ss == "n" else P_FTF] = FLAT_FOOT
        p[P_FTN if ws == "n" else P_FTF] = FLAT_FOOT - 6.0
        return p
    # near leg forward pairs with the far arm forward
    return [contact("n", "f", False), passing("n"), contact("f", "n", True), passing("f")]


def hamstring_poses():
    # Long sitting on the floor, legs straight, hinge forward from the hips
    # and reach toward the shins.
    legs = dict(thn=0, shn=0, thf=0, shf=0, ftn=NEUTRAL_ANKLE, ftf=NEUTRAL_ANKLE)
    start = pose(x=0, y=5.0, torso=90, head=88, **legs)
    with_arms(start, (16.0, 10.5), (15.0, 10.5), bend=-1)
    hold = pose(x=0, y=5.0, torso=42, head=22, spine=2.5, **legs)
    with_arms(hold, (40.0, 10.5), (39.0, 10.5), bend=-1)
    return [start, hold]


def quad_stretch_poses():
    # Standing on the far leg, one hand on a wall; the near knee bends so the
    # heel comes to the glute and the near hand holds the ankle. The shin and
    # foot angles are unwrapped (-260 rather than 100) so the blend swings the
    # heel backwards, not forwards through a kick.
    stand = dict(x=0, y=STAND_HIP_Y, torso=90, head=90, thf=-90, shf=-90, ftf=FLAT_FOOT)
    # weight already on the far leg, near foot just off the floor
    start = pose(ftn=FLAT_FOOT, uan=-92, fan=-88, **stand)
    with_leg(start, "n", (0.0, ANKLE_H + 3.0), bend=1)
    with_arms(start, (2.0, STAND_HIP_Y - 25.0), (24.0, 80.0), bend=-1)
    mid = pose(thn=-95.0, shn=-150.0, ftn=-150.0 + NEUTRAL_ANKLE, **stand)
    with_arms(mid, (-4.0, STAND_HIP_Y - 18.0), (24.0, 80.0), bend=-1)
    hold = pose(thn=-100.0, shn=-260.0, ftn=-260.0 + NEUTRAL_ANKLE - 40.0, **stand)
    j = fk(hold)
    with_arms(hold, (j[J_ANKLE_N][0] + 1.0, j[J_ANKLE_N][1] - 1.0), (24.0, 80.0), bend=-1)
    return [start, mid, hold]


def hip_flexor_poses():
    # Half kneeling: near knee down behind, far foot flat in front. The hips
    # shift forward to open the front of the near hip.
    knee = (-8.0, 2.9)
    front_ankle = (24.0, ANKLE_H)

    def kneel(thigh):
        hip = (knee[0] - THIGH * math.cos(d2r(thigh)), knee[1] - THIGH * math.sin(d2r(thigh)))
        p = pose(x=round(hip[0], 2), y=round(hip[1], 2), torso=90, head=90, thn=thigh, shn=180, ftn=192,
                 ftf=FLAT_FOOT)
        with_leg(p, "f", front_ankle, bend=1)
        j = fk(p)
        with_arms(p, (j[J_KNEE_F][0] - 3.0, j[J_KNEE_F][1] + 5.0), (j[J_KNEE_F][0] - 4.0, j[J_KNEE_F][1] + 5.0),
                  bend=-1)
        return p
    return [kneel(-90.0), kneel(-112.0)]


def knee_chest_poses():
    # Lying on the back; draw the near knee toward the chest and hold it
    # just below the knee with both hands. The far leg stays long.
    start = pose(x=0, thn=0, shn=0, thf=0, shf=0, ftn=NEUTRAL_ANKLE, ftf=NEUTRAL_ANKLE, **SUPINE)
    start[P_UAN], start[P_FAN], start[P_UAF], start[P_FAF] = -4.0, -2.0, -4.0, -2.0   # arms by the sides
    hold = pose(x=0, thn=132.0, shn=-6.0, thf=0, shf=0, ftn=-6.0 + NEUTRAL_ANKLE - 20.0, ftf=NEUTRAL_ANKLE,
                **SUPINE)
    j = fk(hold)
    with_arms(hold, (j[J_KNEE_N][0] + 3.0, j[J_KNEE_N][1] + 2.5), (j[J_KNEE_N][0] + 2.0, j[J_KNEE_N][1] + 2.5),
              bend=-1)
    return [start, hold]


def figure_four_poses():
    # Lying on the back, far foot flat with the knee bent; the near ankle
    # crosses over the far knee and the near knee opens out (figure four).
    arms = dict(uan=-4, fan=-2, uaf=-4, faf=-2)

    def base():
        p = pose(x=0, y=SUPINE["y"], torso=180, head=178, ftf=FLAT_FOOT, **arms)
        with_leg(p, "f", (30.0, ANKLE_H), bend=1)
        return p
    start = base()
    with_leg(start, "n", (29.0, ANKLE_H), bend=1)
    start[P_FTN] = FLAT_FOOT
    hold = base()
    kf = fk(hold)[J_KNEE_F]
    with_leg(hold, "n", (kf[0] - 1.0, kf[1] + 4.5), bend=1)
    hold[P_FTN] = hold[P_SHN] + NEUTRAL_ANKLE
    return [start, hold]


def transition_poses():
    # Slow transition: from lying on the back, roll up to sitting with the
    # hands beside the hips.
    lie = pose(x=0, y=SUPINE["y"], torso=180, head=178, thn=0, shn=0, thf=0, shf=0,
               ftn=NEUTRAL_ANKLE, ftf=NEUTRAL_ANKLE, uan=-4, fan=-2, uaf=-4, faf=-2)
    # Arms stay low and forward the whole way (no swing through the floor):
    # propped on the hands beside the hips, then hands resting on the thighs.
    legs = dict(thn=0, shn=0, thf=0, shf=0, ftn=NEUTRAL_ANKLE, ftf=NEUTRAL_ANKLE)
    prop = pose(x=0, y=5.3, torso=155, head=140, uan=-52, fan=-4, uaf=-54, faf=-6, **legs)
    sit = pose(x=0, y=5.0, torso=92, head=90, uan=-100, fan=-20, uaf=-102, faf=-22, **legs)
    return [lie, prop, sit]


def bust_pose(tilt=0.0, ll=0.0, lr=0.0):
    p = [0.0] * POSE_LEN
    p[0], p[1], p[2] = float(tilt), float(ll), float(lr)
    return p


def neck_side_poses():
    # Front view: ear toward the shoulder; the opposite shoulder stays down.
    return [bust_pose(), bust_pose(tilt=30.0, ll=0.0, lr=-1.0)]


def shoulder_roll_poses():
    # Front view: shoulders lift toward the ears, then roll back and down.
    return [bust_pose(), bust_pose(ll=7.0, lr=7.0), bust_pose(ll=3.0, lr=3.0)]


def ankle_circle_poses():
    # Lying, lower-leg close-up (as ankle pumps); the foot travels through
    # flex -> neutral -> point -> neutral, drawn with a circling arrow.
    base = dict(x=0, y=4.6, torso=180, head=178, thn=0, shn=0, thf=0, shf=0, uan=178, fan=178, uaf=178, faf=178)
    return [pose(ftn=NEUTRAL_ANKLE + d, ftf=NEUTRAL_ANKLE + d, **base) for d in (20.0, -8.0, -36.0, -8.0)]


def ankle_mob_poses():
    # Half kneeling: the front knee drives forward over the toes with the
    # front heel down (ankle dorsiflexion), then back.
    knee = (-14.0, 2.9)
    front_ankle = (16.0, ANKLE_H)

    def kneel(hip_x):
        hy = knee[1] + math.sqrt(THIGH ** 2 - (hip_x - knee[0]) ** 2)
        th = round(math.degrees(math.atan2(knee[1] - hy, knee[0] - hip_x)), 1)
        p = pose(x=hip_x, y=round(hy, 2), torso=88, head=88, thn=th, shn=180, ftn=192, ftf=FLAT_FOOT)
        with_leg(p, "f", front_ankle, bend=1)
        j = fk(p)
        with_arms(p, (j[J_KNEE_F][0] - 2.0, j[J_KNEE_F][1] + 4.0), (j[J_KNEE_F][0] - 3.0, j[J_KNEE_F][1] + 4.0),
                  bend=-1)
        return p
    return [kneel(x) for x in (-10.0, -6.0, -2.0, 2.0, 5.0)]


def thoracic_rot_poses():
    # All fours: the near arm opens up toward the ceiling (gaze follows),
    # then threads under the chest.
    knee = (0.0, 2.9)
    hip = (knee[0], knee[1] + THIGH)
    torso = round(math.degrees(math.asin((UARM + FARM + 2.0 - hip[1]) / TORSO)), 1)
    legs = dict(x=hip[0], y=hip[1], torso=torso, thn=-90, shn=180, ftn=192, thf=-90, shf=180, ftf=192)
    sh = (hip[0] + TORSO * math.cos(d2r(torso)), hip[1] + TORSO * math.sin(d2r(torso)))
    wrist = (sh[0], 1.8)

    def quad(head, near):
        p = pose(head=head, **legs)
        with_arms(p, wrist, (wrist[0] - 1.0, wrist[1]), bend=1)
        if near == "up":
            p[P_UAN], p[P_FAN] = 92.0, 90.0
        elif near == "under":
            with_arms(p, (sh[0] - 13.0, 5.0), (wrist[0] - 1.0, wrist[1]), bend=1)
        return p
    return [quad(-20, "floor"), quad(55, "up"), quad(-60, "under")]


def arm_circle_poses():
    # Standing; the near arm sweeps a full circle (down, forward, up, back).
    arms = dict(uaf=-90, faf=-86, torso=90, head=90, spine=0)
    base = dict(x=0, y=STAND_HIP_Y, thn=-90, shn=-90, thf=-90, shf=-90, ftn=FLAT_FOOT, ftf=FLAT_FOOT, **arms)
    return [pose(uan=a, fan=a, **base) for a in (-90.0, 0.0, 90.0, 180.0, 270.0)]


def toe_curl_poses():
    # Close-up of the lower leg and foot: the forefoot presses down (toes
    # curl) then lifts (toes spread). The foot is highlighted.
    base = dict(x=0, y=4.6, torso=180, head=178, thn=0, shn=0, thf=0, shf=0, uan=178, fan=178, uaf=178, faf=178)
    return [pose(ftn=NEUTRAL_ANKLE + 4, ftf=NEUTRAL_ANKLE + 4, **base),
            pose(ftn=NEUTRAL_ANKLE - 30, ftf=NEUTRAL_ANKLE - 30, **base)]


def savasana_poses():
    # Lying still on the back, arms long by the sides, feet falling open.
    p = pose(x=0, y=SUPINE["y"], torso=180, head=178, thn=0, shn=0, thf=0, shf=0,
             ftn=NEUTRAL_ANKLE - 25, ftf=NEUTRAL_ANKLE - 25, uan=-4, fan=-2, uaf=-4, faf=-2)
    return [p]


# Figure centre in the HUD ring (390-px units), shared with SessionPlayerView.
FIG_CY = 150.0

# Easing ids (shared with Easing.mc)
EASE_LINEAR, EASE_IN_OUT_SINE, EASE_OUT_CUBIC, EASE_IN_OUT_QUAD = 0, 1, 2, 3

# Animation types (shared with ExercisePoseData.mc)
A_STATIC, A_HOLD, A_REPETITION, A_SEQUENCE, A_BREATH_SYNC = 0, 1, 2, 3, 4

# Props
PROP_FLOOR, PROP_WALL, PROP_CHAIR = 1, 2, 4
VIEW_SIDE, VIEW_BUST = 0, 1          # side figure / front-view bust

# Arrow kinds: straight (x0,y0,x1,y1) / arc (cx,cy,r,a0,a1). The last field
# binds the arrow to a segment index, or ON_HOLD (shown once a HOLD is reached).
ARROW_LINE, ARROW_ARC = 0, 1
ON_HOLD = 9


def ease(kind, t):
    t = max(0.0, min(1.0, t))
    if kind == EASE_IN_OUT_SINE:
        return 0.5 - 0.5 * math.cos(math.pi * t)
    if kind == EASE_OUT_CUBIC:
        u = 1.0 - t
        return 1.0 - u * u * u
    if kind == EASE_IN_OUT_QUAD:
        return 2 * t * t if t < 0.5 else 1.0 - 2 * (1 - t) * (1 - t)
    return t


ANIMS = {
    # id: definition. seq = [[fromPose, toPose, durationMs, easing, phaseLabel], ...]
    "calf_stretch": dict(
        type=A_HOLD, poses=calf_stretch_poses(), handBend=45.0,
        seq=[[0, 1, 1200, EASE_OUT_CUBIC, "SET UP"]], loop=False, holdLabel="HOLD",
        cam=[9.0, 46.0, 0.8], props=PROP_FLOOR | PROP_WALL, wallX=41.5,
        highlight=PART_SHIN_N, cue="Keep heel down",
        # arrow pressing the rear heel down (figure units), shown while holding
        arrows=[[ARROW_LINE, -22.0, 20.0, -22.0, 9.0, ON_HOLD]],
    ),
    "cat_cow": dict(
        type=A_BREATH_SYNC, poses=cat_cow_poses(), handBend=90.0,
        seq=[[0, 1, 4000, EASE_IN_OUT_SINE, "COW"], [1, 0, 4000, EASE_IN_OUT_SINE, "CAT"]], loop=True,
        cam=[2.0, 22.0, 1.2], props=PROP_FLOOR, highlight=PART_TORSO, cue="Flow with breath",
        # arc above the mid-back: direction follows the segment (down into cow, up into cat)
        arrows=[[ARROW_ARC, 14.0, 30.0, 17.0, 66.0, 114.0, 0], [ARROW_ARC, 14.0, 30.0, 17.0, 114.0, 66.0, 1]],
    ),
    "ankle_pumps": dict(
        type=A_REPETITION, poses=ankle_pump_poses(),
        seq=[[0, 1, 1000, EASE_IN_OUT_SINE, "FLEX"], [1, 0, 1000, EASE_IN_OUT_SINE, "POINT"]], loop=True,
        # simplified lower-leg view: only the near shin and foot are drawn
        cam=[42.0, 6.0, 3.0], parts=PART_SHIN_N | PART_FOOT_N, floorHalf=18.0,
        props=PROP_FLOOR, highlight=PART_SHIN_N | PART_FOOT_N,
        cue="Keep moving",
        # range arc around the ankle covering point..flex, plus a direction arc per segment
        rangeJoint=J_ANKLE_N, range=[10.0, NEUTRAL_ANKLE - 40, NEUTRAL_ANKLE + 22],
        arrows=[[ARROW_ARC, 49.0, 4.6, 12.0, 34.0, 82.0, 0], [ARROW_ARC, 49.0, 4.6, 12.0, 82.0, 34.0, 1]],
    ),
    "heel_raises": dict(
        type=A_REPETITION, poses=heel_raise_poses(), handBend=10.0,
        seq=[[0, 1, 1200, EASE_IN_OUT_SINE, "RISE"], [1, 0, 1500, EASE_IN_OUT_SINE, "LOWER"]], loop=True,
        cam=[3.0, 52.0, 0.74], props=PROP_FLOOR, floorHalf=26.0,
        highlight=PART_SHIN_N | PART_SHIN_F, cue="Up on toes, lower slowly",
        arrows=[[ARROW_LINE, -9.0, 6.0, -9.0, 20.0, 0], [ARROW_LINE, -9.0, 20.0, -9.0, 6.0, 1]],
    ),
    "knee_bends": dict(
        type=A_REPETITION, poses=heel_slide_poses(),
        seq=[[0, 1, 500, EASE_LINEAR, "SLIDE IN"], [1, 2, 500, EASE_LINEAR, "SLIDE IN"],
             [2, 3, 500, EASE_LINEAR, "SLIDE IN"], [3, 4, 500, EASE_LINEAR, "SLIDE IN"],
             [4, 3, 500, EASE_LINEAR, "SLIDE OUT"], [3, 2, 500, EASE_LINEAR, "SLIDE OUT"],
             [2, 1, 500, EASE_LINEAR, "SLIDE OUT"], [1, 0, 500, EASE_LINEAR, "SLIDE OUT"]], loop=True,
        cam=[7.0, 14.0, 0.98], props=PROP_FLOOR, floorHalf=52.0,
        highlight=PART_THIGH_N | PART_SHIN_N, cue="Heel stays on the floor",
        arrows=[[ARROW_LINE, 50.0, -5.0, 34.0, -5.0, i] for i in range(4)]
               + [[ARROW_LINE, 34.0, -5.0, 50.0, -5.0, i] for i in range(4, 8)],
    ),
    "childs_pose": dict(
        type=A_HOLD, poses=childs_pose_poses(), handBend=80.0,
        seq=[[i, i + 1, 450, EASE_LINEAR, "SINK BACK"] for i in range(6)], loop=False, holdLabel="REST",
        cam=[8.0, 16.0, 1.2], props=PROP_FLOOR, floorHalf=46.0,
        highlight=PART_TORSO, cue="Breathe into the back",
    ),
    "legs_wall": dict(
        type=A_HOLD, poses=legs_wall_poses(),
        seq=[[0, 1, 2500, EASE_IN_OUT_SINE, "LEGS UP"]], loop=False, holdLabel="RELAX",
        cam=[-14.0, 27.0, 1.12], props=PROP_FLOOR | PROP_WALL, wallX=6.0, wallY=[0.0, 60.0], floorHalf=36.0,
        highlight=PART_THIGH_N | PART_SHIN_N, cue="Let the legs rest",
    ),
    "legs_chair": dict(
        type=A_STATIC, poses=legs_chair_poses(),
        seq=[[0, 0, 1000, EASE_LINEAR, "REST"]], loop=False, holdLabel="REST",
        cam=[2.0, 16.0, 1.05], props=PROP_FLOOR | PROP_CHAIR, chair=[14.0, 44.0, 21.0, 0.0, 0.0], floorHalf=50.0,
        highlight=PART_SHIN_N, cue="Calves rest on the seat",
    ),
    "supine_elev": dict(
        type=A_STATIC, poses=legs_chair_poses(PILLOW_SHIN_Y),
        seq=[[0, 0, 1000, EASE_LINEAR, "REST"]], loop=False, holdLabel="REST",
        cam=[2.0, 12.0, 1.05], props=PROP_FLOOR | PROP_CHAIR, chair=pillow_support(), floorHalf=50.0,
        highlight=PART_SHIN_N, cue="Legs on pillows, relax",
    ),
    "seated_march": dict(
        type=A_REPETITION, poses=seated_march_poses(), handBend=-20.0,
        seq=[[0, 1, 900, EASE_IN_OUT_SINE, "LIFT"], [1, 0, 900, EASE_IN_OUT_SINE, "LOWER"],
             [0, 2, 900, EASE_IN_OUT_SINE, "LIFT"], [2, 0, 900, EASE_IN_OUT_SINE, "LOWER"]], loop=True,
        cam=[6.0, 42.0, 0.95], props=PROP_FLOOR | PROP_CHAIR, chair=[-11.0, 10.0, SEAT_Y, -11.0, 54.0],
        floorHalf=34.0, highlight=PART_THIGH_N | PART_THIGH_F, cue="Lift knees, alternate",
    ),
    "walk_cool": dict(
        type=A_REPETITION, poses=walk_poses(), handBend=8.0,
        seq=[[0, 1, 450, EASE_LINEAR, "STEP"], [1, 2, 450, EASE_LINEAR, "STEP"],
             [2, 3, 450, EASE_LINEAR, "STEP"], [3, 0, 450, EASE_LINEAR, "STEP"]], loop=True,
        cam=[0.0, 50.0, 0.74], props=PROP_FLOOR, floorHalf=30.0,
        highlight=PART_THIGH_N | PART_SHIN_N, cue="Easy pace, loose arms",
    ),
    "hamstring": dict(
        type=A_HOLD, poses=hamstring_poses(), handBend=0.0,
        seq=[[0, 1, 2500, EASE_IN_OUT_SINE, "HINGE"]], loop=False, holdLabel="HOLD",
        cam=[22.0, 20.0, 1.12], props=PROP_FLOOR, floorHalf=36.0,
        highlight=PART_THIGH_N | PART_THIGH_F, cue="Hinge at hips, back long",
    ),
    "quad_stretch": dict(
        type=A_HOLD, poses=quad_stretch_poses(), handBend=20.0,
        seq=[[0, 1, 1000, EASE_IN_OUT_SINE, "HEEL UP"], [1, 2, 1000, EASE_IN_OUT_SINE, "HEEL UP"]], loop=False,
        holdLabel="HOLD",
        cam=[6.0, 48.0, 0.76], props=PROP_FLOOR | PROP_WALL, wallX=26.0, wallY=[50.0, 98.0], floorHalf=28.0,
        highlight=PART_THIGH_N, cue="Heel to glute, knees close",
    ),
    "hip_flexor": dict(
        type=A_HOLD, poses=hip_flexor_poses(), handBend=40.0,
        seq=[[0, 1, 2200, EASE_IN_OUT_SINE, "SHIFT"]], loop=False, holdLabel="HOLD",
        cam=[6.0, 35.0, 0.98], props=PROP_FLOOR, floorHalf=38.0,
        highlight=PART_THIGH_N, cue="Tuck pelvis, shift forward",
    ),
    "knee_chest": dict(
        type=A_HOLD, poses=knee_chest_poses(), handBend=40.0,
        seq=[[0, 1, 2200, EASE_IN_OUT_SINE, "DRAW IN"]], loop=False, holdLabel="HOLD",
        cam=[-12.0, 16.0, 1.0], props=PROP_FLOOR, floorHalf=40.0,
        highlight=PART_THIGH_N, cue="Hug knee in, back relaxed",
    ),
    "hip_mobility": dict(
        type=A_HOLD, poses=figure_four_poses(),
        seq=[[0, 1, 2200, EASE_IN_OUT_SINE, "CROSS"]], loop=False, holdLabel="HOLD",
        cam=[-6.0, 16.0, 1.05], props=PROP_FLOOR, floorHalf=44.0,
        highlight=PART_THIGH_N, cue="Figure four, ease into it",
    ),
    "transition": dict(
        type=A_HOLD, poses=transition_poses(), handBend=0.0,
        seq=[[0, 1, 2000, EASE_IN_OUT_SINE, "ROLL UP"], [1, 2, 2000, EASE_IN_OUT_SINE, "SIT UP"]], loop=False,
        holdLabel="SIT", cam=[-6.0, 18.0, 1.0], props=PROP_FLOOR, floorHalf=46.0,
        highlight=PART_TORSO, cue="Exit the position slowly",
    ),
    "neck_side": dict(
        type=A_HOLD, view=VIEW_BUST, poses=neck_side_poses(),
        seq=[[0, 1, 2200, EASE_IN_OUT_SINE, "TILT"]], loop=False, holdLabel="HOLD",
        cam=[0.0, 32.0, 1.05], props=0, highlight=2, cue="Ear toward shoulder, soft",
        arrows=[[ARROW_ARC, 0.0, 44.0, 26.0, 70.0, 104.0, 0]],
    ),
    "shoulder_rolls": dict(
        type=A_REPETITION, view=VIEW_BUST, poses=shoulder_roll_poses(),
        seq=[[0, 1, 1100, EASE_IN_OUT_SINE, "UP"], [1, 2, 900, EASE_IN_OUT_SINE, "BACK"],
             [2, 0, 900, EASE_IN_OUT_SINE, "DOWN"]], loop=True,
        cam=[0.0, 33.0, 0.97], props=0, highlight=2, cue="Roll shoulders back slowly",
        arrows=[[ARROW_ARC, -21.0, 38.0, 6.0, 270.0, 90.0, 0], [ARROW_ARC, -21.0, 38.0, 6.0, 90.0, 0.0, 1],
                [ARROW_ARC, -21.0, 38.0, 6.0, 0.0, -90.0, 2]],
    ),
    "ankle_circles": dict(
        type=A_REPETITION, poses=ankle_circle_poses(),
        seq=[[i, (i + 1) % 4, 700, EASE_IN_OUT_SINE, "CIRCLE"] for i in range(4)], loop=True,
        cam=[42.0, 6.0, 2.7], parts=PART_SHIN_N | PART_FOOT_N, floorHalf=18.0,
        props=PROP_FLOOR, highlight=PART_FOOT_N, cue="Circle the ankle slowly",
        arrows=[[ARROW_ARC, 51.0, 9.0, 8.0, 30.0 + 90.0 * i, 110.0 + 90.0 * i, i] for i in range(4)],
    ),
    "ankle_mob": dict(
        type=A_REPETITION, poses=ankle_mob_poses(), handBend=40.0,
        seq=[[i, i + 1, 375, EASE_LINEAR, "DRIVE"] for i in range(4)]
            + [[4 - i, 3 - i, 375, EASE_LINEAR, "BACK"] for i in range(4)], loop=True,
        cam=[2.0, 35.0, 0.98], props=PROP_FLOOR, floorHalf=36.0,
        highlight=PART_SHIN_F | PART_FOOT_F, cue="Knee over toes, heel down",
    ),
    "thoracic_rot": dict(
        type=A_REPETITION, poses=thoracic_rot_poses(), handBend=90.0,
        seq=[[0, 1, 1500, EASE_IN_OUT_SINE, "OPEN"], [1, 0, 1200, EASE_IN_OUT_SINE, "RETURN"],
             [0, 2, 1500, EASE_IN_OUT_SINE, "THREAD"], [2, 0, 1200, EASE_IN_OUT_SINE, "RETURN"]], loop=True,
        cam=[6.0, 28.0, 0.95], props=PROP_FLOOR, floorHalf=40.0,
        highlight=PART_TORSO | PART_ARM_N, cue="Open the chest to the side",
    ),
    "shoulder_mob": dict(
        type=A_REPETITION, poses=arm_circle_poses(), handBend=0.0,
        seq=[[i, i + 1, 800, EASE_LINEAR, "CIRCLE"] for i in range(4)], loop=True,
        cam=[3.0, 58.0, 0.66], props=PROP_FLOOR, floorHalf=26.0,
        highlight=PART_ARM_N, cue="Slow circles, easy range",
    ),
    "toe_curls": dict(
        type=A_REPETITION, poses=toe_curl_poses(),
        seq=[[0, 1, 900, EASE_IN_OUT_SINE, "CURL"], [1, 0, 900, EASE_IN_OUT_SINE, "SPREAD"]], loop=True,
        cam=[44.0, 6.0, 3.2], parts=PART_SHIN_N | PART_FOOT_N, floorHalf=16.0,
        props=PROP_FLOOR, highlight=PART_FOOT_N, cue="Curl, then spread the toes",
    ),
    "relax": dict(
        type=A_STATIC, poses=savasana_poses(),
        seq=[[0, 0, 1000, EASE_LINEAR, "REST"]], loop=False, holdLabel="REST",
        cam=[5.0, 8.0, 0.9], props=PROP_FLOOR, floorHalf=52.0,
        highlight=0, cue="Lie still, soften the body",
    ),
}

# Which content exercises use which animation (ExerciseLibrary ids).
EXERCISE_ANIM = {"calf_stretch": "calf_stretch", "cat_cow": "cat_cow", "ankle_pumps": "ankle_pumps"}


# ---------------------------------------------------------------------------
# Sampling (mirrors PoseSampler.mc)
# ---------------------------------------------------------------------------
def cycle_ms(a):
    return sum(s[2] for s in a["seq"])


def sample(a, t_ms, reduced=False):
    """Return (pose, segmentIndex, segmentPermille, reps)."""
    seq = a["seq"]
    total = cycle_ms(a)
    reps = 0
    if a["loop"]:
        reps = int(t_ms // total)
        t = t_ms % total
    else:
        t = min(t_ms, total)
    acc = 0
    for i, s in enumerate(seq):
        if t < acc + s[2] or i == len(seq) - 1:
            local = min(1.0, (t - acc) / s[2]) if s[2] > 0 else 1.0
            k = ease(s[3], local)
            if reduced:          # reduced motion: snap to the segment's target pose
                k = 1.0
            p0, p1 = a["poses"][s[0]], a["poses"][s[1]]
            return [p0[q] + (p1[q] - p0[q]) * k for q in range(POSE_LEN)], i, int(local * 1000), reps
        acc += s[2]
    return a["poses"][seq[-1][1]], len(seq) - 1, 1000, reps


# ---------------------------------------------------------------------------
# Validation: plausibility checks on every authored pose and sampled frames
# ---------------------------------------------------------------------------
def rel_angle(a, b):
    d = (b - a + 180) % 360 - 180
    return d


def validate():
    problems = []
    for name, a in ANIMS.items():
        if a.get("view") == VIEW_BUST:
            for p in a["poses"]:
                if abs(p[0]) > 40 or not (-2 <= p[1] <= 9) or not (-2 <= p[2] <= 9):
                    problems.append("%s: bust pose out of range %s" % (name, p[:3]))
            continue
        frames = [sample(a, t)[0] for t in range(0, cycle_ms(a) + 1, 50)] + a["poses"]
        for p in frames:
            j = fk(p)
            # nothing below the floor (allow 0.6 units for rounding / soft contact)
            for idx in (J_TOE_N, J_HEEL_N, J_TOE_F, J_HEEL_F, J_WRIST_N, J_WRIST_F, J_KNEE_N, J_KNEE_F):
                if j[idx][1] < -0.6:
                    problems.append("%s: joint %d below floor (%.1f)" % (name, idx, j[idx][1]))
            # knees and elbows only bend one way, within anatomical range
            for th, sh in ((P_THN, P_SHN), (P_THF, P_SHF)):
                flex = rel_angle(p[th], p[sh])          # knee flexion: shin rotates CW from thigh
                if not (-170 <= flex <= 2):
                    problems.append("%s: knee flexion out of range (%.1f)" % (name, flex))
            for ua, fa in ((P_UAN, P_FAN), (P_UAF, P_FAF)):
                e = abs(rel_angle(p[ua], p[fa]))
                if e > 150:
                    problems.append("%s: elbow out of range (%.1f)" % (name, e))
            # ankle: dorsiflexion (+) / plantarflexion (-) relative to standing neutral
            for sh, ft in ((P_SHN, P_FTN), (P_SHF, P_FTF)):
                dors = rel_angle(p[sh], p[ft]) - NEUTRAL_ANKLE
                if not (-56 <= dors <= 35):
                    problems.append("%s: ankle %+.1f deg outside -56..+35" % (name, dors))
        # body outline (not just joints) must not sink into the floor
        camy, scale = a["cam"][1], a["cam"][2]
        floor_y = camy * scale                 # screen y of the floor for box (0, 0)
        for t in range(0, cycle_ms(a) + 1, 100):
            ops, _ = render(a, t, (0.0, 0.0))
            deepest = 0.0
            for op in ops:
                if op[0] == "poly":
                    deepest = max(deepest, max(q[1] for q in op[2]) - floor_y)
                elif op[0] == "circle":
                    deepest = max(deepest, op[3] + op[4] - floor_y)
            if deepest > 0.9 * scale:
                problems.append("%s: body outline %.1f units below the floor at %d ms" % (name, deepest / scale, t))
        if name == "calf_stretch":
            j = fk(a["poses"][1])
            if abs(j[J_HEEL_N][1]) > 0.8:
                problems.append("calf_stretch: rear heel not on the floor (%.2f)" % j[J_HEEL_N][1])
            for w in (J_WRIST_N, J_WRIST_F):
                if abs(j[w][0] - a["wallX"]) > 3.0:
                    problems.append("calf_stretch: hand not at the wall (%.1f)" % j[w][0])
        if name == "cat_cow":
            for p in a["poses"]:
                j = fk(p)
                if abs(j[J_WRIST_N][0] - j[J_SHOULDER][0]) > 3:
                    problems.append("cat_cow: wrist not under shoulder")
                if abs(j[J_KNEE_N][0] - j[J_HIP][0]) > 1:
                    problems.append("cat_cow: knee not under hip")
    return sorted(set(problems))


# ---------------------------------------------------------------------------
# Drawing (mirrors FigureRenderer.mc). Output: draw ops in 390-px screen units.
# ---------------------------------------------------------------------------
SOFT, FAR, GREEN, TRACK, PROP = "#C9CEC9", "#6E7570", "#4FC97A", "#26302A", "#3A423D"

# ---- Anatomical profiles ---------------------------------------------------
# Half-widths (figure units) sampled at PROFILE_T along each segment, given
# separately for the segment's LEFT normal and RIGHT normal (figure space,
# before mirroring). For limbs pointing down (standing), left = front;
# for the torso and neck (pointing up), left = back.
PROFILE_T = [0.0, 0.25, 0.5, 0.75, 1.0]
THIGH_L, THIGH_R = [4.0, 4.4, 4.1, 3.3, 2.8], [4.8, 4.3, 3.8, 3.1, 2.8]   # quads / hamstrings + glute
SHIN_L, SHIN_R = [2.8, 2.9, 2.6, 2.1, 1.8], [3.0, 4.0, 3.4, 2.3, 1.8]     # tibia / calf bulge
UARM_L, UARM_R = [2.3, 2.5, 2.4, 2.0, 1.8], [2.5, 2.7, 2.4, 2.0, 1.8]     # biceps / triceps
FARM_L, FARM_R = [1.8, 2.1, 1.9, 1.6, 1.3], [1.9, 2.2, 1.8, 1.5, 1.3]
HAND_L, HAND_R = [1.3, 1.7, 1.7, 1.3, 0.7], [1.3, 1.6, 1.5, 1.2, 0.7]
NECK_L, NECK_R = [2.3, 2.2, 2.1, 2.1, 2.1], [2.0, 1.9, 1.9, 2.0, 2.0]     # nape / throat
HAND_LEN = 5.0
# Torso along the spine curve, 7 samples hip -> shoulder: back (glute, lumbar
# curve, shoulder blade) and front (belly, chest).
TORSO_N = 6
TORSO_BACK = [5.6, 5.0, 4.3, 4.5, 5.1, 5.3, 4.4]
TORSO_FRONT = [4.4, 5.0, 5.1, 4.9, 5.5, 5.3, 4.0]
HEAD_DRAW_R, JAW_R = 6.0, 3.8
# Foot outline in the foot frame (x along ankle -> toe), from a flat standing
# foot: heel, arch, ball, toes, instep. Built from world points by rotating
# by -FLAT_FOOT so that rotating by the foot angle reproduces them.
_FOOT_WORLD = [(-1.4, 1.0), (-2.6, -1.6), (-2.3, -3.5), (-1.0, -4.0), (3.0, -3.6), (6.2, -4.0),
               (8.6, -3.9), (9.4, -3.2), (8.5, -2.6), (4.6, -1.3), (1.6, 0.9)]
FOOT_OUTLINE = [(round(x * math.cos(d2r(-FLAT_FOOT)) - y * math.sin(d2r(-FLAT_FOOT)), 2),
                 round(x * math.sin(d2r(-FLAT_FOOT)) + y * math.cos(d2r(-FLAT_FOOT)), 2)) for x, y in _FOOT_WORLD]


class Ops:
    def __init__(self):
        self.ops = []

    def add(self, *op):
        self.ops.append(list(op))


# ---------------------------------------------------------------------------
# Front view (bust): head, neck, trapezius, shoulders, upper arms, chest.
# Pose vector reuse: [0] head tilt (deg, + = toward the screen left),
# [1] left shoulder lift, [2] right shoulder lift (figure units).
# Same numbers as FigureRenderer.drawBust in Monkey C.
# ---------------------------------------------------------------------------
B_SH_Y, B_SH_X, B_NECK_PIVOT, B_HEAD_R = 40.0, 19.0, 44.0, 8.5
B_ARM_LEN, B_ARM_W, B_CHEST_X = 30.0, 3.4, 14.0


def bust_rot(x, y, deg):
    c, sn = math.cos(d2r(deg)), math.sin(d2r(deg))
    return (x * c - (y - B_NECK_PIVOT) * sn, B_NECK_PIVOT + x * sn + (y - B_NECK_PIVOT) * c)


# Outline tables: [x, y, lift, k]. lift: 0 = left shoulder lift, 1 = right,
# 2 = shrug (0.8 * max lift), 3 = fixed. y += k * lift. NECK and HEAD also
# rotate by the head tilt around (0, B_NECK_PIVOT). Shared with Monkey C
# through FigureShapes.mc (generated).
def _mirror(side):
    out = []
    for x, y, lift, k in reversed(side):
        out.append([-x, y, {0: 1, 1: 0}.get(lift, lift), k])
    return out


_TORSO_L = [[-4.6, 46.0, 2, 1.0], [-9.5, 44.2, 0, 0.5], [-14.0, 42.6, 0, 1.0], [-17.5, 41.6, 0, 1.0],
            [-20.5, 39.8, 0, 1.0], [-22.2, 36.5, 0, 1.0], [-22.4, 32.0, 0, 1.0], [-20.6, 28.2, 0, 0.6],
            [-16.8, 27.0, 0, 0.3], [-16.2, 18.0, 3, 0.0], [-14.4, 9.0, 3, 0.0], [-13.2, 2.0, 3, 0.0],
            [-13.6, 0.0, 3, 0.0]]
BUST_TORSO = _TORSO_L + _mirror(_TORSO_L)
_ARM_L = [[-23.9, 34.0, 0, 1.0], [-25.0, 25.0, 0, 0.7], [-24.6, 15.0, 0, 0.4], [-24.2, 6.0, 0, 0.2],
          [-23.4, 1.0, 3, 0.0], [-20.4, 1.0, 3, 0.0], [-20.0, 6.0, 0, 0.2], [-19.7, 15.0, 0, 0.4],
          [-19.4, 24.0, 0, 0.7], [-19.8, 30.5, 0, 1.0]]
BUST_ARM_L = _ARM_L
BUST_ARM_R = _mirror(_ARM_L)
_TRAP_L = [[-4.6, 46.0, 2, 1.0], [-9.5, 44.2, 0, 0.5], [-14.0, 42.6, 0, 1.0], [-17.5, 41.6, 0, 1.0],
           [-15.0, 39.0, 0, 1.0], [-9.0, 40.6, 2, 0.5], [-4.2, 41.6, 2, 1.0]]
BUST_TRAP_L = _TRAP_L
BUST_TRAP_R = _mirror(_TRAP_L)
BUST_NECK = [[-4.4, 42.0, 2, 1.0], [-3.5, 47.0, 2, 1.0], [-3.3, 53.0, 2, 1.0], [3.3, 53.0, 2, 1.0],
             [3.5, 47.0, 2, 1.0], [4.4, 42.0, 2, 1.0]]
BUST_HEAD = []
for _i in range(20):
    _a = 2 * math.pi * _i / 20
    _sx, _sy = math.cos(_a), math.sin(_a)
    _taper = 1.0 - 0.22 * max(0.0, -_sy)            # narrower jaw and chin
    BUST_HEAD.append([round(7.0 * _sx * _taper, 2), round(60.5 + 9.0 * _sy, 2), 2, 1.0])


# 3/4 view: the figure turns toward screen left; its right side (x > 0) is
# foreshortened. Applied after the head tilt.
B_NEAR_K, B_FAR_K = 0.95, 0.6
BUST_NOSE = [[-6.2, 62.0, 2, 1.0], [-8.6, 59.2, 2, 1.0], [-6.4, 57.4, 2, 1.0]]


def bust_proj(pt):
    x, y = pt
    return (x * (B_FAR_K if x > 0 else B_NEAR_K), y)


def bust_lift(pt, ll, lr):
    lift = {0: ll, 1: lr, 2: 0.8 * max(ll, lr)}.get(pt[2], 0.0)
    return pt[0], pt[1] + pt[3] * lift


def bust_shapes(p):
    """(kind, part, points) in figure units. part 1 = body/arms, 2 = neck and trapezius, 0 = head."""
    tilt, ll, lr = p[0], p[1], p[2]
    out = []

    def flat(table):
        return [bust_proj(bust_lift(q, ll, lr)) for q in table]

    def turned(table):
        return [bust_proj(bust_rot(*bust_lift(q, ll, lr), tilt)) for q in table]
    out.append(("far", 1, flat(BUST_ARM_R)))          # far arm, behind and darker
    out.append(("poly", 1, flat(BUST_TORSO)))
    out.append(("poly", 1, flat(BUST_ARM_L)))
    out.append(("poly", 2, turned(BUST_NECK)))
    out.append(("trap", 2, flat(BUST_TRAP_L)))
    out.append(("trap", 2, flat(BUST_TRAP_R)))
    out.append(("poly", 0, turned(BUST_HEAD)))
    out.append(("poly", 0, turned(BUST_NOSE)))
    return out


def render_bust(a, t_ms, box, mirror, reduced):
    p, seg, permille, reps = sample(a, t_ms, reduced)
    camx, camy, scale = a["cam"]
    m = -1.0 if mirror else 1.0
    cx, cy = box

    def S(pt):
        return (cx + m * (pt[0] - camx) * scale, cy - (pt[1] - camy) * scale)
    o = Ops()
    hl = a["highlight"]
    for kind, part, data in bust_shapes(p):
        on = bool(part and (hl & part))
        if kind == "trap" and not on:
            continue
        col = FAR if kind == "far" else (GREEN if on else SOFT)
        o.add("poly", col, [list(S(q)) for q in data])
    holding = (not a["loop"]) and t_ms >= cycle_ms(a)
    for ar in a.get("arrows", []):
        if not ((ar[-1] == ON_HOLD and holding) or (ar[-1] == seg and not holding)):
            continue
        c = S((ar[1], ar[2]))
        a0, a1 = ar[4], ar[5]
        if mirror:
            a0, a1 = 180 - a0, 180 - a1
        o.add("arrow_arc", GREEN, c[0], c[1], ar[3] * scale, a0, a1)
    label = a["seq"][seg][4]
    if a["type"] == A_HOLD and t_ms >= cycle_ms(a):
        label = a.get("holdLabel", "HOLD")
    return o.ops, dict(segment=seg, permille=permille, reps=reps, label=label)


def render(a, t_ms, box, mirror=False, reduced=False):
    """box = (cx, cy) screen centre of the figure area. Returns (ops, info)."""
    if a.get("view") == VIEW_BUST:
        return render_bust(a, t_ms, box, mirror, reduced)
    p, seg, permille, reps = sample(a, t_ms, reduced)
    j = fk(p)
    camx, camy, scale = a["cam"]
    m = -1.0 if mirror else 1.0
    cx, cy = box

    def S(pt):
        return (cx + m * (pt[0] - camx) * scale, cy - (pt[1] - camy) * scale)

    o = Ops()
    if "clip" in a:
        c = a["clip"]
        o.add("clip", cx + c[0], cy + c[1], c[2], c[3])

    if a["props"] & PROP_FLOOR:
        fh = a.get("floorHalf", 40.0)
        x0, x1 = S((camx - fh, 0)), S((camx + fh, 0))
        o.add("line", PROP, 2, x0[0], x0[1], x1[0], x1[1])
    if a["props"] & PROP_WALL:
        wy = a.get("wallY", (56.0, 90.0))
        w0, w1 = S((a["wallX"], wy[0])), S((a["wallX"], wy[1]))
        o.add("line", PROP, 3, w0[0], w0[1], w1[0], w1[1])
    if a["props"] & PROP_CHAIR:
        c = a["chair"]
        s0, s1 = S((c[0], c[2])), S((c[1], c[2]))
        o.add("line", PROP, 3, s0[0], s0[1], s1[0], s1[1])
        for lx in (c[0] + 1.5, c[1] - 1.5):
            l0, l1 = S((lx, c[2])), S((lx, 0))
            o.add("line", PROP, 2, l0[0], l0[1], l1[0], l1[1])
        if c[4] > c[2]:
            b0, b1 = S((c[3], c[2])), S((c[3], c[4]))
            o.add("line", PROP, 3, b0[0], b0[1], b1[0], b1[1])

    hl = a["highlight"]
    parts = a.get("parts", ALL_PARTS)
    hand_bend = a.get("handBend", 0.0)

    def col(part, base):
        return GREEN if hl & part else base

    def profile(pa, pb, left, right, color, caps=True):
        """Segment pa -> pb with asymmetric half-width profiles."""
        dx, dy = pb[0] - pa[0], pb[1] - pa[1]
        ln = math.hypot(dx, dy) or 1.0
        ux, uy = dx / ln, dy / ln
        nx, ny = -uy, ux
        ls, rs = [], []
        for i, t in enumerate(PROFILE_T):
            bx, by = pa[0] + dx * t, pa[1] + dy * t
            ls.append(S((bx + nx * left[i], by + ny * left[i])))
            rs.append(S((bx - nx * right[i], by - ny * right[i])))
        o.add("poly", color, [list(q) for q in ls + rs[::-1]])
        if caps:   # rounded joints: circle spanning both sides at each end
            for i in (0, len(PROFILE_T) - 1):
                bx, by = pa[0] + dx * PROFILE_T[i], pa[1] + dy * PROFILE_T[i]
                off = (left[i] - right[i]) / 2
                C = S((bx + nx * off, by + ny * off))
                o.add("circle", color, C[0], C[1], (left[i] + right[i]) / 2 * scale)

    def foot(an, ft_angle, color):
        ax, ay = j[an]
        fx, fy = math.cos(d2r(ft_angle)), math.sin(d2r(ft_angle))
        pts = [S((ax + lx * fx - ly * fy, ay + lx * fy + ly * fx)) for lx, ly in FOOT_OUTLINE]
        o.add("poly", color, [list(q) for q in pts])

    def leg(kn, an, pth, psh, pft, ft_angle, color_base):
        if parts & pth:
            profile(j[J_HIP], j[kn], THIGH_L, THIGH_R, col(pth, color_base))
        if parts & psh:
            profile(j[kn], j[an], SHIN_L, SHIN_R, col(psh, color_base))
        if parts & pft:
            foot(an, ft_angle, col(pft, color_base))

    def arm(el, wr, fa_angle, part, color_base):
        if not parts & part:
            return
        c = col(part, color_base)
        profile(j[J_SHOULDER], j[el], UARM_L, UARM_R, c)
        profile(j[el], j[wr], FARM_L, FARM_R, c)
        ha = d2r(fa_angle + hand_bend)
        tip = (j[wr][0] + HAND_LEN * math.cos(ha), j[wr][1] + HAND_LEN * math.sin(ha))
        profile(j[wr], tip, HAND_L, HAND_R, c, caps=False)

    # far side first (darker)
    arm(J_ELBOW_F, J_WRIST_F, p[P_FAF], PART_ARM_F, FAR)
    leg(J_KNEE_F, J_ANKLE_F, PART_THIGH_F, PART_SHIN_F, PART_FOOT_F, p[P_FTF], FAR)

    # torso along the spine curve (hip -> shoulder through the control point)
    if parts & PART_TORSO:
        tc = col(PART_TORSO, SOFT)
        hip, sh, ctl = j[J_HIP], j[J_SHOULDER], j[J_SPINE_C]
        qx, qy = 2 * ctl[0] - (hip[0] + sh[0]) / 2, 2 * ctl[1] - (hip[1] + sh[1]) / 2
        back, front = [], []
        for i in range(TORSO_N + 1):
            t = i / TORSO_N
            u = 1 - t
            px_ = u * u * hip[0] + 2 * u * t * qx + t * t * sh[0]
            py_ = u * u * hip[1] + 2 * u * t * qy + t * t * sh[1]
            tx = 2 * u * (qx - hip[0]) + 2 * t * (sh[0] - qx)
            ty = 2 * u * (qy - hip[1]) + 2 * t * (sh[1] - qy)
            ln = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / ln, tx / ln          # left normal = back
            back.append(list(S((px_ + nx * TORSO_BACK[i], py_ + ny * TORSO_BACK[i]))))
            front.append(list(S((px_ - nx * TORSO_FRONT[i], py_ - ny * TORSO_FRONT[i]))))
        o.add("poly", tc, back + front[::-1])
        for i, pt in ((0, hip), (TORSO_N, sh)):
            r = (TORSO_BACK[i] + TORSO_FRONT[i]) / 2
            o.add("circle", tc, *S(pt), r * scale)

    # neck + head (skull + jaw, so the face direction reads)
    if parts & PART_HEAD:
        hc = col(PART_HEAD, SOFT)
        hd = dirv(p[P_HEAD])
        neck_end = (j[J_SHOULDER][0] + (NECK + 2.0) * hd[0], j[J_SHOULDER][1] + (NECK + 2.0) * hd[1])
        profile(j[J_SHOULDER], neck_end, NECK_L, NECK_R, hc, caps=False)
        Hd = S(j[J_HEAD])
        o.add("circle", hc, Hd[0], Hd[1], HEAD_DRAW_R * scale)
        face = (hd[1], -hd[0])                   # right normal of the neck = face side
        jaw = (j[J_HEAD][0] + face[0] * 2.2 - hd[0] * 2.6, j[J_HEAD][1] + face[1] * 2.2 - hd[1] * 2.6)
        Jw = S(jaw)
        o.add("circle", hc, Jw[0], Jw[1], JAW_R * scale)

    # near side
    leg(J_KNEE_N, J_ANKLE_N, PART_THIGH_N, PART_SHIN_N, PART_FOOT_N, p[P_FTN], SOFT)
    arm(J_ELBOW_N, J_WRIST_N, p[P_FAN], PART_ARM_N, SOFT)

    # range indicator
    if "range" in a and not reduced:
        r, a0, a1 = a["range"]
        c = S(j[a["rangeJoint"]])
        o.add("arc", TRACK, 2, c[0], c[1], r * scale, a0 if not mirror else 180 - a0, a1 if not mirror else 180 - a1,
              1 if mirror else 0)
    # direction arrows: bound to the active segment, or ON_HOLD once held
    holding = (not a["loop"]) and t_ms >= cycle_ms(a)
    for ar in a.get("arrows", []):
        if not ((ar[-1] == ON_HOLD and holding) or (ar[-1] == seg and not holding)):
            continue
        if ar[0] == ARROW_LINE:
            A, B = S((ar[1], ar[2])), S((ar[3], ar[4]))
            o.add("arrow_line", GREEN, A[0], A[1], B[0], B[1])
        else:
            c = S((ar[1], ar[2]))
            a0, a1 = ar[4], ar[5]
            if mirror:
                a0, a1 = 180 - a0, 180 - a1
            o.add("arrow_arc", GREEN, c[0], c[1], ar[3] * scale, a0, a1)
    if "clip" in a:
        o.add("unclip")
    label = a["seq"][seg][4]
    if a["type"] == A_HOLD and t_ms >= cycle_ms(a):
        label = a.get("holdLabel", "HOLD")
    return o.ops, dict(segment=seg, permille=permille, reps=reps, label=label)


# ---------------------------------------------------------------------------
# Monkey C generation
# ---------------------------------------------------------------------------
def mc_num(v):
    """Float literal with up to 2 decimals (keeps 0.25 exact, no "-0.0")."""
    v = round(float(v), 2)
    if v == 0:
        v = 0.0
    txt = ("%.2f" % v).rstrip("0")
    return txt + "0" if txt.endswith(".") else txt


def mc_arr(vals):
    return "[" + ", ".join(mc_num(v) for v in vals) + "]"


def gen_monkeyc():
    order = list(ANIMS.keys())
    out = []
    out.append("// GENERATED by tools/motion/motion_model.py - do not edit by hand.")
    out.append("import Toybox.Lang;\n")
    out.append("//! Exercise animation data: poses (Skeleton.POSE_LEN floats each), segments")
    out.append("//! [fromPose, toPose, durationMs, easing, label], camera [x, y, px per unit],")
    out.append("//! props, highlighted parts, cue, optional clip / range / arrows.")
    out.append("module ExercisePoseData {\n")
    out.append("    var _anims = null;\n")
    out.append("    //! Animation definition for a content exercise id, or null.")
    out.append("    function forExercise(exerciseId) {")
    out.append("        if (exerciseId == null) {\n            return null;\n        }")
    out.append("        if (_anims == null) {\n            _anims = build();\n        }")
    out.append("        return _anims.get(exerciseId);")
    out.append("    }\n")
    out.append("    function build() as Dictionary {")
    out.append("        var d = {};")
    for name in order:
        a = ANIMS[name]
        out.append("        d.put(\"%s\", {" % name)
        out.append("            :type => %d," % a["type"])
        out.append("            :poses => [")
        out.append(",\n".join("                %s" % mc_arr(p) for p in a["poses"]))
        out.append("            ],")
        segs = ", ".join("[%d, %d, %d, %d, \"%s\"]" % tuple(s) for s in a["seq"])
        out.append("            :seq => [%s]," % segs)
        out.append("            :loop => %s," % ("true" if a["loop"] else "false"))
        out.append("            :cam => %s," % mc_arr(a["cam"]))
        out.append("            :props => %d," % a["props"])
        if a.get("view"):
            out.append("            :view => %d," % a["view"])
        if "wallX" in a:
            out.append("            :wallX => %s," % mc_num(a["wallX"]))
        if "wallY" in a:
            out.append("            :wallY => %s," % mc_arr(a["wallY"]))
        if "chair" in a:
            out.append("            :chair => %s," % mc_arr(a["chair"]))
        out.append("            :highlight => %d," % a["highlight"])
        if "parts" in a:
            out.append("            :parts => %d," % a["parts"])
        if "handBend" in a:
            out.append("            :handBend => %s," % mc_num(a["handBend"]))
        if "floorHalf" in a:
            out.append("            :floorHalf => %s," % mc_num(a["floorHalf"]))
        out.append("            :cue => \"%s\"," % a["cue"])
        if "holdLabel" in a:
            out.append("            :holdLabel => \"%s\"," % a["holdLabel"])
        if "clip" in a:
            out.append("            :clip => [%s]," % ", ".join(str(int(v)) for v in a["clip"]))
        if "range" in a:
            out.append("            :rangeJoint => %d," % a["rangeJoint"])
            out.append("            :range => %s," % mc_arr(a["range"]))
        arrows = ", ".join("[%d, %s]" % (ar[0], ", ".join(mc_num(v) if i < len(ar) - 2 else str(int(v))
                                                           for i, v in enumerate(ar[1:]))) for ar in a.get("arrows", []))
        out.append("            :arrows => [%s]" % arrows)
        out.append("        });")
    out.append("        return d;")
    out.append("    }")
    out.append("}")
    return "\n".join(out) + "\n"


def bust_arr(t):
    return "[" + ", ".join("[%s, %s, %d, %s]" % (mc_num(q[0]), mc_num(q[1]), q[2], mc_num(q[3])) for q in t) + "]"


def gen_shapes():
    """Anatomical drawing constants for FigureRenderer.mc (same numbers as render())."""
    def arr(v):
        return mc_arr(v)
    foot = ", ".join("[%s, %s]" % (mc_num(x), mc_num(y)) for x, y in FOOT_OUTLINE)
    lines = ["// GENERATED by tools/motion/motion_model.py - do not edit by hand.",
             "import Toybox.Lang;\n",
             "//! Anatomical figure shapes. Half-widths (figure units) at PROFILE_T along",
             "//! each segment for its LEFT and RIGHT normal (limbs pointing down: left =",
             "//! front; torso/neck pointing up: left = back).",
             "module FigureShapes {",
             "    const PROFILE_T = %s;" % arr(PROFILE_T),
             "    const THIGH_L = %s;" % arr(THIGH_L), "    const THIGH_R = %s;" % arr(THIGH_R),
             "    const SHIN_L = %s;" % arr(SHIN_L), "    const SHIN_R = %s;" % arr(SHIN_R),
             "    const UARM_L = %s;" % arr(UARM_L), "    const UARM_R = %s;" % arr(UARM_R),
             "    const FARM_L = %s;" % arr(FARM_L), "    const FARM_R = %s;" % arr(FARM_R),
             "    const HAND_L = %s;" % arr(HAND_L), "    const HAND_R = %s;" % arr(HAND_R),
             "    const NECK_L = %s;" % arr(NECK_L), "    const NECK_R = %s;" % arr(NECK_R),
             "    const HAND_LEN = %s;" % mc_num(HAND_LEN),
             "    const TORSO_N = %d;" % TORSO_N,
             "    const TORSO_BACK = %s;" % arr(TORSO_BACK), "    const TORSO_FRONT = %s;" % arr(TORSO_FRONT),
             "    const HEAD_DRAW_R = %s;" % mc_num(HEAD_DRAW_R), "    const JAW_R = %s;" % mc_num(JAW_R),
             "    //! Front-view bust outlines [x, y, lift, k] (see bust_shapes()).",
             "    const BUST_TORSO = %s;" % bust_arr(BUST_TORSO),
             "    const BUST_ARM_L = %s;" % bust_arr(BUST_ARM_L),
             "    const BUST_ARM_R = %s;" % bust_arr(BUST_ARM_R),
             "    const BUST_TRAP_L = %s;" % bust_arr(BUST_TRAP_L),
             "    const BUST_TRAP_R = %s;" % bust_arr(BUST_TRAP_R),
             "    const BUST_NECK = %s;" % bust_arr(BUST_NECK),
             "    const BUST_HEAD = %s;" % bust_arr(BUST_HEAD),
             "    const BUST_NOSE = %s;" % bust_arr(BUST_NOSE),
             "    const BUST_NEAR_K = %s;" % mc_num(B_NEAR_K),
             "    const BUST_FAR_K = %s;" % mc_num(B_FAR_K),
             "    //! Foot outline in the foot frame (x along ankle -> toe).",
             "    const FOOT_OUTLINE = [%s];" % foot,
             "}"]
    return "\n".join(lines) + "\n"


def gen_golden():
    calf = ANIMS["calf_stretch"]
    cc = ANIMS["cat_cow"]
    ap = ANIMS["ankle_pumps"]
    j = fk(calf["poses"][1])
    mid, seg, pm, reps = sample(cc, 2000)
    mid_ap, _, _, reps_ap = sample(ap, 5500)
    lines = ["// GENERATED by tools/motion/motion_model.py - golden values for MotionTests.mc.",
             "import Toybox.Lang;\n",
             "(:debug)",
             "module MotionGolden {",
             "    // FK of calf_stretch hold pose (figure units)",
             "    const CALF_HEEL_N = %s;" % mc_arr(j[J_HEEL_N]),
             "    const CALF_WRIST_N = %s;" % mc_arr(j[J_WRIST_N]),
             "    const CALF_KNEE_F = %s;" % mc_arr(j[J_KNEE_F]),
             "    const CALF_HEAD = %s;" % mc_arr(j[J_HEAD]),
             "    // cat_cow sampled at 2000 ms: torso spine value and head angle",
             "    const CC_2000_SPINE = %s;" % mc_num(round(mid[P_SPINE], 1)),
             "    const CC_2000_HEAD = %s;" % mc_num(round(mid[P_HEAD], 1)),
             "    const CC_2000_SEGMENT = %d;" % seg,
             "    // ankle_pumps at 5500 ms: completed reps and near-foot angle",
             "    const AP_5500_REPS = %d;" % reps_ap,
             "    const AP_5500_FOOT = %s;" % mc_num(round(mid_ap[P_FTN], 1)),
             "}"]
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Previews (PIL) + JS frames for the HTML mockup
# ---------------------------------------------------------------------------
def draw_ops_pil(draw, ops, ox, oy, k):
    from PIL import ImageDraw  # noqa: F401

    def P(x, y):
        return (ox + x * k, oy + y * k)

    for op in ops:
        kind = op[0]
        if kind == "poly":
            draw.polygon([P(x, y) for x, y in op[2]], fill=op[1])
        elif kind == "circle":
            x, y, r = op[2], op[3], op[4] * k
            cx_, cy_ = P(x, y)
            draw.ellipse([cx_ - r, cy_ - r, cx_ + r, cy_ + r], fill=op[1])
        elif kind == "line":
            draw.line([P(op[3], op[4]), P(op[5], op[6])], fill=op[1], width=max(1, int(op[2] * k)))
        elif kind in ("arc", "arrow_arc"):
            if kind == "arc":
                _, color, wdt, cx_, cy_, r, a0, a1, _cw = op
            else:
                _, color, cx_, cy_, r, a0, a1 = op
                wdt = 2
            c = P(cx_, cy_)
            rr = r * k
            lo, hi = sorted((-a0, -a1))
            draw.arc([c[0] - rr, c[1] - rr, c[0] + rr, c[1] + rr], lo, hi, fill=color, width=max(1, int(wdt * k)))
            if kind == "arrow_arc":
                tip = (c[0] + rr * math.cos(d2r(-a1)), c[1] + rr * math.sin(d2r(-a1)))
                sgn = 1 if a1 > a0 else -1
                tang = d2r(-a1 - sgn * 90)
                _arrow_head(draw, tip, (math.cos(tang), math.sin(tang)), color, k)
        elif kind == "arrow_line":
            a, b = P(op[2], op[3]), P(op[4], op[5])
            draw.line([a, b], fill=op[1], width=max(1, int(2 * k)))
            d = (b[0] - a[0], b[1] - a[1])
            ln = math.hypot(*d) or 1
            _arrow_head(draw, b, (d[0] / ln, d[1] / ln), op[1], k)


def _arrow_head(draw, tip, d, color, k):
    s = 5 * k
    nx, ny = -d[1], d[0]
    base = (tip[0] - d[0] * s, tip[1] - d[1] * s)
    draw.polygon([tip, (base[0] + nx * s * 0.6, base[1] + ny * s * 0.6), (base[0] - nx * s * 0.6, base[1] - ny * s * 0.6)],
                 fill=color)


def previews():
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("PIL not available: skipping previews")
        return
    out_dir = os.path.join(ROOT, "docs", "mockups")
    os.makedirs(out_dir, exist_ok=True)
    k = 4
    for name, a in ANIMS.items():
        total = cycle_ms(a)
        times = [int(total * i / 7) for i in range(8)] if a["loop"] else [0, 300, 600, 900, 1200, 2000, 4000, 8000]
        cell = 170
        img = Image.new("RGB", (cell * len(times) * k, cell * k), "#000000")
        dr = ImageDraw.Draw(img)
        for i, t in enumerate(times):
            ops, info = render(a, t, (cell / 2, cell / 2))
            clip = next((op for op in ops if op[0] == "clip"), None)
            ops = [op for op in ops if op[0] not in ("clip", "unclip")]
            tile = Image.new("RGB", (cell * k, cell * k), "#000000")
            draw_ops_pil(ImageDraw.Draw(tile), ops, 0, 0, k)
            if clip:                                   # same clip rect the watch uses
                mask = Image.new("L", tile.size, 0)
                ImageDraw.Draw(mask).rectangle([clip[1] * k, clip[2] * k, (clip[1] + clip[3]) * k,
                                                (clip[2] + clip[4]) * k], fill=255)
                tile = Image.composite(tile, Image.new("RGB", tile.size, "#000000"), mask)
            img.paste(tile, (i * cell * k, 0))
            dr.text((i * cell * k + 16, 10), "%d ms  %s  rep %d" % (t, info["label"], info["reps"]), fill="#8A918C",
                    font_size=22)
        # supersampled: drawn at 2x, downsampled -> approximates on-device anti-aliasing
        img = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
        img.save(os.path.join(out_dir, "motion-%s.png" % name.replace("_", "-")))
    print("previews -> docs/mockups/motion-*.png")


def gen_js(box):
    """Frames for the HTML mockup HUD (one representative time per exercise)."""
    frames = {}
    for name, a in ANIMS.items():
        frames[name] = {}
        for t in (0, 600, 2000, 5500, 9000):
            for mirror in (False, True):
                ops, info = render(a, t, box, mirror=mirror)
                frames[name]["%d%s" % (t, "m" if mirror else "")] = dict(ops=ops, info=info)
    return "window.FIGURE_FRAMES = " + json.dumps(frames) + ";\n"


# HUD ring: centre y 186, inner edge r84; figures keep >= 6 px clear (r78).
RING_CY, RING_KEEP = 186.0, 78.0


def check_ring():
    """Every frame (50 ms steps, both sides) must stay inside the HUD ring."""
    problems = []
    for name, a in ANIMS.items():
        span = cycle_ms(a) + (2000 if not a["loop"] else 0)
        worst = 0.0
        for t in range(0, span + 1, 50):
            for mirror in (False, True):
                ops, _ = render(a, t, (195.0, FIG_CY), mirror=mirror)
                clip = next((op for op in ops if op[0] == "clip"), None)
                pts = []
                for op in ops:
                    if op[0] == "poly":
                        pts += op[2]
                    elif op[0] == "circle":
                        pts += [[op[2] + dx * op[4], op[3] + dy * op[4]] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                    elif op[0] in ("line", "arrow_line"):
                        o = op[3:] if op[0] == "line" else op[2:]
                        pts += [[o[0], o[1]], [o[2], o[3]]]
                    elif op[0] in ("arc", "arrow_arc"):
                        cx_, cy_, r = (op[3], op[4], op[5]) if op[0] == "arc" else (op[2], op[3], op[4])
                        a0, a1 = (op[6], op[7]) if op[0] == "arc" else (op[5], op[6])
                        for i in range(9):
                            ang = d2r(a0 + (a1 - a0) * i / 8)
                            pts.append([cx_ + r * math.cos(ang), cy_ - r * math.sin(ang)])
                for x, y in pts:
                    if clip:
                        x = min(max(x, clip[1]), clip[1] + clip[3])
                        y = min(max(y, clip[2]), clip[2] + clip[4])
                    d = math.hypot(x - 195.0, y - RING_CY)
                    worst = max(worst, d)
        if worst > RING_KEEP:
            problems.append("%s: figure reaches r%.1f from the ring centre (limit %.0f)" % (name, worst, RING_KEEP))
        print("  %-12s max radius %.1f / %.0f" % (name, worst, RING_KEEP))
    return problems


def main():
    problems = validate() + check_ring()
    if problems:
        print("POSE VALIDATION FAILED:")
        for p in problems:
            print("  " + p)
        sys.exit(1)
    print("pose validation: ok (%d animations)" % len(ANIMS))
    for name, a in ANIMS.items():
        print("  %-12s poses=%s" % (name, [[round(v, 1) for v in p] for p in a["poses"]]))
    mc_dir = os.path.join(ROOT, "source", "Motion", "Exercise")
    os.makedirs(mc_dir, exist_ok=True)
    with open(os.path.join(mc_dir, "ExercisePoseData.mc"), "w") as f:
        f.write(gen_monkeyc())
    with open(os.path.join(mc_dir, "FigureShapes.mc"), "w") as f:
        f.write(gen_shapes())
    with open(os.path.join(ROOT, "source", "Tests", "MotionGolden.mc"), "w") as f:
        f.write(gen_golden())
    with open(os.path.join(ROOT, "tools", "mockups", "figure_frames.js"), "w") as f:
        f.write(gen_js((195.0, FIG_CY)))
    previews()


if __name__ == "__main__":
    main()
