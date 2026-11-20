import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Draws an anatomical exercise figure (mirrors render() in
//! tools/motion/motion_model.py; shapes come from FigureShapes.mc).
//!
//! SILHOUETTE (default): every segment is a smooth polygon built from
//! asymmetric half-width profiles (calf bulge behind the tibia, quads vs
//! hamstrings, biceps vs triceps), a torso that follows the spine curve with
//! glute, waist, chest and shoulder-blade contour, a shaped foot (heel, arch,
//! ball, toes), palms, and a head with a jaw so the face direction reads.
//! Rounded joints come from circles spanning both sides of the segment end.
//! Anti-aliasing is switched on where the device supports it.
//! SKELETAL (low detail): 2 px bones with joint dots.
//!
//! Draw order: props, far limbs (dark grey), torso, head, near limbs (light
//! grey), highlights in green, then range and direction guides. All point
//! buffers are preallocated, so a frame allocates nothing.
class FigureRenderer {

    const SILHOUETTE = 0;
    const SKELETAL = 1;

    const C_NEAR = 0xC9CEC9;
    const C_FAR = 0x6E7570;
    const C_PROP = 0x3A423D;

    const ARROW_LINE = 0;
    const ARROW_ARC = 1;
    const ON_HOLD = 9;
    const ALL_PARTS = 1023;
    const NECK_EXTRA = 2.0;   // neck profile reaches into the skull

    hidden var _j as Array;
    hidden var _prof as Array;    // 2 * PROFILE_T points
    hidden var _torso as Array;   // 2 * (TORSO_N + 1) points
    hidden var _foot as Array;    // FOOT_OUTLINE points
    hidden var _tri as Array;     // arrow heads
    hidden var _style as Number = SILHOUETTE;

    // per-draw mapping and options
    hidden var _camX = 0.0;
    hidden var _camY = 0.0;
    hidden var _scale = 1.0;
    hidden var _px = 1.0;
    hidden var _cx = 0;
    hidden var _cy = 0;
    hidden var _mirror as Boolean = false;
    hidden var _highlight as Number = 0;
    hidden var _parts as Number = ALL_PARTS;
    hidden var _handBend = 0.0;

    function initialize() {
        _j = Skeleton.newJointBuffer();
        _prof = points(2 * FigureShapes.PROFILE_T.size());
        _torso = points(2 * (FigureShapes.TORSO_N + 1));
        _foot = points(FigureShapes.FOOT_OUTLINE.size());
        _tri = points(3);
    }

    hidden function points(n as Number) as Array {
        var a = new [n];
        for (var i = 0; i < n; i++) {
            a[i] = [0, 0];
        }
        return a;
    }

    function setStyle(style as Number) as Void {
        _style = style;
    }

    function sx(x) as Float { return Skeleton.screenX(x, _camX, _scale, _cx, _mirror); }
    function sy(y) as Float { return Skeleton.screenY(y, _camY, _scale, _cy); }
    function jx(j as Number) as Float { return sx(_j[2 * j]); }
    function jy(j as Number) as Float { return sy(_j[2 * j + 1]); }

    //! Draw the sampler's current pose centred at (cx, cy) in screen px.
    //! pxScale = screen px per 390-px design unit.
    function draw(dc as Graphics.Dc, sampler as PoseSampler, cx as Number, cy as Number, pxScale,
            mirror as Boolean, showGuides as Boolean) as Void {
        var def = sampler.def;
        var cam = def[:cam];
        _camX = cam[0];
        _camY = cam[1];
        _scale = cam[2] * pxScale;
        _px = pxScale;
        _cx = cx;
        _cy = cy;
        _mirror = mirror;
        _highlight = def[:highlight];
        _parts = (def[:parts] != null) ? def[:parts] : ALL_PARTS;
        _handBend = (def[:handBend] != null) ? def[:handBend] : 0.0;
        var p = sampler.pose;
        Skeleton.fk(p, _j);

        var aa = (dc has :setAntiAlias);
        if (aa) {
            dc.setAntiAlias(true);
        }
        var clip = def[:clip];
        if (clip != null) {
            dc.setClip(cx + (clip[0] * pxScale).toNumber(), cy + (clip[1] * pxScale).toNumber(),
                (clip[2] * pxScale).toNumber(), (clip[3] * pxScale).toNumber());
        }
        drawProps(dc, def);

        // far side
        arm(dc, Skeleton.J_ELBOW_F, Skeleton.J_WRIST_F, p[Skeleton.P_FAF], Skeleton.PART_ARM_F, C_FAR);
        leg(dc, Skeleton.J_KNEE_F, Skeleton.J_ANKLE_F, p[Skeleton.P_FTF],
            Skeleton.PART_THIGH_F, Skeleton.PART_SHIN_F, Skeleton.PART_FOOT_F, C_FAR);
        if ((_parts & Skeleton.PART_TORSO) != 0) {
            torso(dc, color(Skeleton.PART_TORSO, C_NEAR));
        }
        if ((_parts & Skeleton.PART_HEAD) != 0) {
            head(dc, p[Skeleton.P_HEAD], color(Skeleton.PART_HEAD, C_NEAR));
        }
        // near side
        leg(dc, Skeleton.J_KNEE_N, Skeleton.J_ANKLE_N, p[Skeleton.P_FTN],
            Skeleton.PART_THIGH_N, Skeleton.PART_SHIN_N, Skeleton.PART_FOOT_N, C_NEAR);
        arm(dc, Skeleton.J_ELBOW_N, Skeleton.J_WRIST_N, p[Skeleton.P_FAN], Skeleton.PART_ARM_N, C_NEAR);

        if (showGuides) {
            drawRange(dc, def);
            drawArrows(dc, def, sampler);
        }
        if (clip != null) {
            dc.clearClip();
        }
        if (aa) {
            dc.setAntiAlias(false);
        }
    }

    hidden function color(part as Number, base as Number) as Number {
        return ((_highlight & part) != 0) ? Theme.GREEN : base;
    }

    hidden function setPt(pt as Array, x, y) as Void {
        pt[0] = x.toNumber();
        pt[1] = y.toNumber();
    }

    hidden function drawProps(dc as Graphics.Dc, def) as Void {
        var props = def[:props];
        dc.setColor(C_PROP, Graphics.COLOR_TRANSPARENT);
        if ((props & 1) != 0) {
            var fh = (def[:floorHalf] != null) ? def[:floorHalf] : 40.0;
            dc.setPenWidth(2);
            dc.drawLine(sx(_camX - fh).toNumber(), sy(0).toNumber(), sx(_camX + fh).toNumber(), sy(0).toNumber());
        }
        if ((props & 2) != 0 && def[:wallX] != null) {
            dc.setPenWidth(3);
            dc.drawLine(sx(def[:wallX]).toNumber(), sy(56).toNumber(), sx(def[:wallX]).toNumber(), sy(90).toNumber());
        }
        dc.setPenWidth(1);
    }

    //! Segment (ax,ay) -> (bx,by) in figure units with asymmetric half-width
    //! profiles for its left / right normal; optional rounded caps.
    hidden function profile(dc as Graphics.Dc, ax, ay, bx, by, left as Array, right as Array, c as Number,
            caps as Boolean) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        if (_style == SKELETAL) {
            dc.setPenWidth(2);
            dc.drawLine(sx(ax).toNumber(), sy(ay).toNumber(), sx(bx).toNumber(), sy(by).toNumber());
            dc.setPenWidth(1);
            if (caps) {
                dc.fillCircle(sx(ax).toNumber(), sy(ay).toNumber(), 2);
            }
            return;
        }
        var dx = bx - ax;
        var dy = by - ay;
        var ln = Math.sqrt(dx * dx + dy * dy);
        if (ln < 0.001) {
            return;
        }
        var nx = -dy / ln;
        var ny = dx / ln;
        var ts = FigureShapes.PROFILE_T;
        var n = ts.size();
        for (var i = 0; i < n; i++) {
            var px = ax + dx * ts[i];
            var py = ay + dy * ts[i];
            setPt(_prof[i], sx(px + nx * left[i]), sy(py + ny * left[i]));
            setPt(_prof[2 * n - 1 - i], sx(px - nx * right[i]), sy(py - ny * right[i]));
        }
        dc.fillPolygon(_prof);
        if (caps) {
            cap(dc, ax, ay, nx, ny, left[0], right[0]);
            cap(dc, bx, by, nx, ny, left[n - 1], right[n - 1]);
        }
    }

    //! Round joint: circle spanning both sides of a segment end.
    hidden function cap(dc as Graphics.Dc, x, y, nx, ny, l, r) as Void {
        var off = (l - r) / 2;
        var rad = ((l + r) / 2 * _scale).toNumber();
        dc.fillCircle(sx(x + nx * off).toNumber(), sy(y + ny * off).toNumber(), (rad < 1) ? 1 : rad);
    }

    hidden function leg(dc as Graphics.Dc, kn as Number, an as Number, footAngle,
            pThigh as Number, pShin as Number, pFoot as Number, base as Number) as Void {
        if ((_parts & pThigh) != 0) {
            profile(dc, _j[0], _j[1], _j[2 * kn], _j[2 * kn + 1], FigureShapes.THIGH_L, FigureShapes.THIGH_R,
                color(pThigh, base), true);
        }
        if ((_parts & pShin) != 0) {
            profile(dc, _j[2 * kn], _j[2 * kn + 1], _j[2 * an], _j[2 * an + 1], FigureShapes.SHIN_L, FigureShapes.SHIN_R,
                color(pShin, base), true);
        }
        if ((_parts & pFoot) != 0) {
            foot(dc, an, footAngle, color(pFoot, base));
        }
    }

    //! Shaped foot: outline in the foot frame rotated by the foot angle.
    hidden function foot(dc as Graphics.Dc, an as Number, angle, c as Number) as Void {
        var ax = _j[2 * an];
        var ay = _j[2 * an + 1];
        var fx = Math.cos(angle * Skeleton.DEG);
        var fy = Math.sin(angle * Skeleton.DEG);
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        if (_style == SKELETAL) {
            dc.setPenWidth(2);
            dc.drawLine(sx(ax).toNumber(), sy(ay).toNumber(), sx(ax + Skeleton.FOOT * fx).toNumber(),
                sy(ay + Skeleton.FOOT * fy).toNumber());
            dc.setPenWidth(1);
            return;
        }
        var outline = FigureShapes.FOOT_OUTLINE;
        for (var i = 0; i < outline.size(); i++) {
            var lx = outline[i][0];
            var ly = outline[i][1];
            setPt(_foot[i], sx(ax + lx * fx - ly * fy), sy(ay + lx * fy + ly * fx));
        }
        dc.fillPolygon(_foot);
    }

    //! Upper arm, forearm and a palm that continues the forearm by handBend
    //! (e.g. 90 deg = flat on the floor in quadruped, 45 deg = flat on a wall).
    hidden function arm(dc as Graphics.Dc, el as Number, wr as Number, forearmAngle, part as Number,
            base as Number) as Void {
        if ((_parts & part) == 0) {
            return;
        }
        var c = color(part, base);
        var sh = Skeleton.J_SHOULDER;
        profile(dc, _j[2 * sh], _j[2 * sh + 1], _j[2 * el], _j[2 * el + 1], FigureShapes.UARM_L, FigureShapes.UARM_R, c, true);
        profile(dc, _j[2 * el], _j[2 * el + 1], _j[2 * wr], _j[2 * wr + 1], FigureShapes.FARM_L, FigureShapes.FARM_R, c, true);
        var ha = (forearmAngle + _handBend) * Skeleton.DEG;
        var wx = _j[2 * wr];
        var wy = _j[2 * wr + 1];
        profile(dc, wx, wy, wx + FigureShapes.HAND_LEN * Math.cos(ha), wy + FigureShapes.HAND_LEN * Math.sin(ha),
            FigureShapes.HAND_L, FigureShapes.HAND_R, c, false);
    }

    //! Torso along the spine curve (quadratic through the control point):
    //! back profile on the left normal, front profile on the right.
    hidden function torso(dc as Graphics.Dc, c as Number) as Void {
        var hx = _j[2 * Skeleton.J_HIP];
        var hy = _j[2 * Skeleton.J_HIP + 1];
        var shx = _j[2 * Skeleton.J_SHOULDER];
        var shy = _j[2 * Skeleton.J_SHOULDER + 1];
        var qx = 2 * _j[2 * Skeleton.J_SPINE_C] - (hx + shx) / 2;
        var qy = 2 * _j[2 * Skeleton.J_SPINE_C + 1] - (hy + shy) / 2;
        var n = FigureShapes.TORSO_N;
        var back = FigureShapes.TORSO_BACK;
        var front = FigureShapes.TORSO_FRONT;
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        if (_style == SKELETAL) {
            dc.setPenWidth(3);
            var px0 = sx(hx);
            var py0 = sy(hy);
            for (var i = 1; i <= n; i++) {
                var t = i.toFloat() / n;
                var u = 1.0 - t;
                var nx0 = sx(u * u * hx + 2 * u * t * qx + t * t * shx);
                var ny0 = sy(u * u * hy + 2 * u * t * qy + t * t * shy);
                dc.drawLine(px0.toNumber(), py0.toNumber(), nx0.toNumber(), ny0.toNumber());
                px0 = nx0;
                py0 = ny0;
            }
            dc.setPenWidth(1);
            return;
        }
        for (var i = 0; i <= n; i++) {
            var t = i.toFloat() / n;
            var u = 1.0 - t;
            var fx = u * u * hx + 2 * u * t * qx + t * t * shx;
            var fy = u * u * hy + 2 * u * t * qy + t * t * shy;
            var tx = 2 * u * (qx - hx) + 2 * t * (shx - qx);
            var ty = 2 * u * (qy - hy) + 2 * t * (shy - qy);
            var ln = Math.sqrt(tx * tx + ty * ty);
            if (ln < 0.001) {
                ln = 1.0;
            }
            var nx = -ty / ln;          // left normal = back
            var ny = tx / ln;
            setPt(_torso[i], sx(fx + nx * back[i]), sy(fy + ny * back[i]));
            setPt(_torso[2 * (n + 1) - 1 - i], sx(fx - nx * front[i]), sy(fy - ny * front[i]));
        }
        dc.fillPolygon(_torso);
        var r0 = ((back[0] + front[0]) / 2 * _scale).toNumber();
        var r1 = ((back[n] + front[n]) / 2 * _scale).toNumber();
        dc.fillCircle(sx(hx).toNumber(), sy(hy).toNumber(), r0);
        dc.fillCircle(sx(shx).toNumber(), sy(shy).toNumber(), r1);
    }

    //! Neck, skull and jaw. The jaw sits on the face side (right normal of the
    //! neck direction), so the figure visibly looks where it faces.
    hidden function head(dc as Graphics.Dc, headAngle, c as Number) as Void {
        var hx = Math.cos(headAngle * Skeleton.DEG);
        var hy = Math.sin(headAngle * Skeleton.DEG);
        var sxp = _j[2 * Skeleton.J_SHOULDER];
        var syp = _j[2 * Skeleton.J_SHOULDER + 1];
        var reach = Skeleton.NECK + NECK_EXTRA;
        profile(dc, sxp, syp, sxp + reach * hx, syp + reach * hy, FigureShapes.NECK_L, FigureShapes.NECK_R, c, false);
        var cx = _j[2 * Skeleton.J_HEAD];
        var cy = _j[2 * Skeleton.J_HEAD + 1];
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        if (_style == SKELETAL) {
            dc.fillCircle(sx(cx).toNumber(), sy(cy).toNumber(), (FigureShapes.HEAD_DRAW_R * _scale * 0.8).toNumber());
            return;
        }
        dc.fillCircle(sx(cx).toNumber(), sy(cy).toNumber(), (FigureShapes.HEAD_DRAW_R * _scale).toNumber());
        var jx0 = cx + hy * 2.2 - hx * 2.6;    // face = (hy, -hx)
        var jy0 = cy - hx * 2.2 - hy * 2.6;
        dc.fillCircle(sx(jx0).toNumber(), sy(jy0).toNumber(), (FigureShapes.JAW_R * _scale).toNumber());
    }

    //! Movement range: thin arc around a joint between two angles.
    hidden function drawRange(dc as Graphics.Dc, def) as Void {
        var range = def[:range];
        if (range == null) {
            return;
        }
        var j = def[:rangeJoint];
        var a0 = range[1];
        var a1 = range[2];
        if (_mirror) {
            var t = 180 - a1;
            a1 = 180 - a0;
            a0 = t;
        }
        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(jx(j).toNumber(), jy(j).toNumber(), (range[0] * _scale).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE,
            Hud.deg(a0), Hud.deg(a1));
        dc.setPenWidth(1);
    }

    //! Direction arrows bound to the active segment, or ON_HOLD once held.
    hidden function drawArrows(dc as Graphics.Dc, def, sampler as PoseSampler) as Void {
        var arrows = def[:arrows];
        if (arrows == null) {
            return;
        }
        dc.setColor(Theme.GREEN, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < arrows.size(); i++) {
            var ar = arrows[i];
            var bind = ar[ar.size() - 1];
            var show = (bind == ON_HOLD) ? sampler.holding : (bind == sampler.segment && !sampler.holding);
            if (!show) {
                continue;
            }
            dc.setPenWidth(2);
            if (ar[0] == ARROW_LINE) {
                var ax = sx(ar[1]);
                var ay = sy(ar[2]);
                var bx = sx(ar[3]);
                var by = sy(ar[4]);
                dc.drawLine(ax.toNumber(), ay.toNumber(), bx.toNumber(), by.toNumber());
                var dx = bx - ax;
                var dy = by - ay;
                var ln = Math.sqrt(dx * dx + dy * dy);
                if (ln > 0.001) {
                    arrowHead(dc, bx, by, dx / ln, dy / ln);
                }
            } else {
                var ccx = sx(ar[1]);
                var ccy = sy(ar[2]);
                var r = ar[3] * _scale;
                var a0 = ar[4];
                var a1 = ar[5];
                if (_mirror) {
                    a0 = 180 - a0;
                    a1 = 180 - a1;
                }
                var ccw = a1 > a0;
                dc.drawArc(ccx.toNumber(), ccy.toNumber(), r.toNumber(),
                    ccw ? Graphics.ARC_COUNTER_CLOCKWISE : Graphics.ARC_CLOCKWISE, Hud.deg(a0), Hud.deg(a1));
                // tip at a1; screen tangent of travel: CCW (-sin, -cos), CW (sin, cos)
                var rad = a1 * Skeleton.DEG;
                var s = ccw ? -1.0 : 1.0;
                arrowHead(dc, ccx + r * Math.cos(rad), ccy - r * Math.sin(rad), s * Math.sin(rad), s * Math.cos(rad));
            }
            dc.setPenWidth(1);
        }
    }

    //! Filled arrow head at (x, y) pointing along unit (dx, dy).
    hidden function arrowHead(dc as Graphics.Dc, x, y, dx, dy) as Void {
        var s = 5.0 * _px;
        var bx = x - dx * s;
        var by = y - dy * s;
        setPt(_tri[0], x, y);
        setPt(_tri[1], bx - dy * s * 0.6, by + dx * s * 0.6);
        setPt(_tri[2], bx + dy * s * 0.6, by - dx * s * 0.6);
        dc.fillPolygon(_tri);
    }
}
