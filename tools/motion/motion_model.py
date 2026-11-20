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
    with_arms(hold, (40.5, 77.0), (40.0, 79.0))
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
    knee = (0.0, 2.0)
    hip = (knee[0], knee[1] + THIGH)
    torso = round(math.degrees(math.asin((UARM + FARM + 2.0 - hip[1]) / TORSO)), 1)
    base = dict(x=hip[0], y=hip[1], torso=torso, thn=-90, shn=180, ftn=192, thf=-90, shf=180, ftf=192)
    sh = (hip[0] + TORSO * math.cos(d2r(torso)), hip[1] + TORSO * math.sin(d2r(torso)))
    wrist = (sh[0], 2.0)
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


# Figure centre in the HUD ring (390-px units), shared with SessionPlayerView.
FIG_CY = 150.0

# Easing ids (shared with Easing.mc)
EASE_LINEAR, EASE_IN_OUT_SINE, EASE_OUT_CUBIC, EASE_IN_OUT_QUAD = 0, 1, 2, 3

# Animation types (shared with ExercisePoseData.mc)
A_STATIC, A_HOLD, A_REPETITION, A_SEQUENCE, A_BREATH_SYNC = 0, 1, 2, 3, 4

# Props
PROP_FLOOR, PROP_WALL = 1, 2

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
        type=A_HOLD, poses=calf_stretch_poses(),
        seq=[[0, 1, 1200, EASE_OUT_CUBIC, "SET UP"]], loop=False, holdLabel="HOLD",
        cam=[9.0, 46.0, 0.8], props=PROP_FLOOR | PROP_WALL, wallX=41.5,
        highlight=PART_SHIN_N, cue="Keep heel down",
        # arrow pressing the rear heel down (figure units), shown while holding
        arrows=[[ARROW_LINE, -22.0, 20.0, -22.0, 9.0, ON_HOLD]],
    ),
    "cat_cow": dict(
        type=A_BREATH_SYNC, poses=cat_cow_poses(),
        seq=[[0, 1, 4000, EASE_IN_OUT_SINE, "COW"], [1, 0, 4000, EASE_IN_OUT_SINE, "CAT"]], loop=True,
        cam=[2.0, 22.0, 1.2], props=PROP_FLOOR, highlight=PART_TORSO, cue="Flow with breath",
        # arc above the mid-back: direction follows the segment (down into cow, up into cat)
        arrows=[[ARROW_ARC, 14.0, 34.0, 13.0, 70.0, 110.0, 0], [ARROW_ARC, 14.0, 34.0, 13.0, 110.0, 70.0, 1]],
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
        if name == "calf_stretch":
            j = fk(a["poses"][1])
            if abs(j[J_HEEL_N][1]) > 0.8:
                problems.append("calf_stretch: rear heel not on the floor (%.2f)" % j[J_HEEL_N][1])
            for w in (J_WRIST_N, J_WRIST_F):
                if abs(j[w][0] - a["wallX"]) > 2.5:
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
W_TORSO_HIP, W_TORSO_CHEST, W_NECK = 10.0, 12.0, 4.4
W_THIGH, W_KNEE, W_SHIN, W_ANKLE = 8.0, 6.0, 5.6, 3.8
W_UARM, W_ELBOW, W_WRIST = 4.6, 3.8, 3.0
W_HEEL, W_TOE = 3.2, 2.2


class Ops:
    def __init__(self):
        self.ops = []

    def add(self, *op):
        self.ops.append(list(op))


def render(a, t_ms, box, mirror=False, reduced=False):
    """box = (cx, cy) screen centre of the figure area. Returns (ops, info)."""
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
        w0, w1 = S((a["wallX"], 56)), S((a["wallX"], 90))
        o.add("line", PROP, 3, w0[0], w0[1], w1[0], w1[1])

    hl = a["highlight"]
    parts = a.get("parts", ALL_PARTS)

    def col(part, base):
        return GREEN if hl & part else base

    def limb(pa, pb, wa, wb, color):
        A, B = S(pa), S(pb)
        dx, dy = B[0] - A[0], B[1] - A[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        ha, hb = wa * scale / 2, wb * scale / 2
        o.add("poly", color, [[A[0] + nx * ha, A[1] + ny * ha], [B[0] + nx * hb, B[1] + ny * hb],
                              [B[0] - nx * hb, B[1] - ny * hb], [A[0] - nx * ha, A[1] - ny * ha]])
        o.add("circle", color, A[0], A[1], ha)
        o.add("circle", color, B[0], B[1], hb)

    def foot(ankle, toe, heel, color):
        A, T, H = S(ankle), S(toe), S(heel)
        o.add("poly", color, [[A[0], A[1]], [T[0], T[1]], [H[0], H[1]]])
        o.add("circle", color, A[0], A[1], W_ANKLE * scale / 2)
        limb(heel, toe, W_HEEL, W_TOE, color)          # sole: gives the foot body

    def leg(kn, an, tn, hn, pth, psh, pft, color_base):
        if parts & pth:
            limb(j[J_HIP], j[kn], W_THIGH, W_KNEE, col(pth, color_base))
        if parts & psh:
            limb(j[kn], j[an], W_SHIN, W_ANKLE, col(psh, color_base))
        if parts & pft:
            foot(j[an], j[tn], j[hn], col(pft, color_base))

    def arm(el, wr, part, color_base):
        if not parts & part:
            return
        c = col(part, color_base)
        limb(j[J_SHOULDER], j[el], W_UARM, W_ELBOW, c)
        limb(j[el], j[wr], W_ELBOW, W_WRIST, c)

    # far side first
    arm(J_ELBOW_F, J_WRIST_F, PART_ARM_F, FAR)
    leg(J_KNEE_F, J_ANKLE_F, J_TOE_F, J_HEEL_F, PART_THIGH_F, PART_SHIN_F, PART_FOOT_F, FAR)
    # torso: quadratic curve hip -> shoulder through the spine control point
    draw_body = parts & PART_TORSO
    tc = col(PART_TORSO, SOFT)
    hip, sh, ctl = j[J_HIP], j[J_SHOULDER], j[J_SPINE_C]
    n = 6
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        # quadratic Bezier with the control point lifted so the curve passes through ctl at t=0.5
        qx, qy = 2 * ctl[0] - (hip[0] + sh[0]) / 2, 2 * ctl[1] - (hip[1] + sh[1]) / 2
        px_ = u * u * hip[0] + 2 * u * t * qx + t * t * sh[0]
        py_ = u * u * hip[1] + 2 * u * t * qy + t * t * sh[1]
        tx = 2 * u * (qx - hip[0]) + 2 * t * (sh[0] - qx)
        ty = 2 * u * (qy - hip[1]) + 2 * t * (sh[1] - qy)
        ln = math.hypot(tx, ty) or 1.0
        w = (W_TORSO_HIP + (W_TORSO_CHEST - W_TORSO_HIP) * t) / 2
        P = S((px_, py_))
        # normal in screen space (mirror flips x)
        nx, ny = -ty / ln, tx / ln
        nsx, nsy = m * nx, -ny
        left.append([P[0] + nsx * w * scale, P[1] + nsy * w * scale])
        right.append([P[0] - nsx * w * scale, P[1] - nsy * w * scale])
    if draw_body:
        o.add("poly", tc, left + right[::-1])
        H0, S0 = S(hip), S(sh)
        o.add("circle", tc, H0[0], H0[1], W_TORSO_HIP * scale / 2)
        o.add("circle", tc, S0[0], S0[1], W_TORSO_CHEST * scale / 2)
    # neck + head
    if parts & PART_HEAD:
        hc = col(PART_HEAD, SOFT)
        limb(sh, j[J_HEAD], W_NECK, W_NECK, hc)
        Hd = S(j[J_HEAD])
        o.add("circle", hc, Hd[0], Hd[1], HEAD_R * scale)
    # near side
    leg(J_KNEE_N, J_ANKLE_N, J_TOE_N, J_HEEL_N, PART_THIGH_N, PART_SHIN_N, PART_FOOT_N, SOFT)
    arm(J_ELBOW_N, J_WRIST_N, PART_ARM_N, SOFT)

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
    v = round(float(v), 1)
    if v == 0:
        v = 0.0                      # no "-0.0"
    return "%.1f" % v


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
        if "wallX" in a:
            out.append("            :wallX => %s," % mc_num(a["wallX"]))
        out.append("            :highlight => %d," % a["highlight"])
        if "parts" in a:
            out.append("            :parts => %d," % a["parts"])
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
    k = 2
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
            dr.text((i * cell * k + 10, 8), "%d ms  %s  rep %d" % (t, info["label"], info["reps"]), fill="#8A918C")
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
    with open(os.path.join(ROOT, "source", "Tests", "MotionGolden.mc"), "w") as f:
        f.write(gen_golden())
    with open(os.path.join(ROOT, "tools", "mockups", "figure_frames.js"), "w") as f:
        f.write(gen_js((195.0, FIG_CY)))
    previews()


if __name__ == "__main__":
    main()
