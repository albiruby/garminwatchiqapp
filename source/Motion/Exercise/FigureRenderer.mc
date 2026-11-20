import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Draws an exercise figure (mirrors render() in tools/motion/motion_model.py).
//!
//! Styles: SILHOUETTE (default) = tapered limb polygons with rounded joints;
//! SKELETAL (low detail) = 2 px bones with joint dots. Draw order: props, far
//! limbs (dark grey), torso, head, near limbs (light grey), highlights in green,
//! then range and direction indicators. All buffers are preallocated, so a
//! frame allocates nothing.
class FigureRenderer {

    const SILHOUETTE = 0;
    const SKELETAL = 1;

    const C_NEAR = 0xC9CEC9;
    const C_FAR = 0x6E7570;
    const C_PROP = 0x3A423D;

    // Limb widths (figure units)
    const W_TORSO_HIP = 10.0;
    const W_TORSO_CHEST = 12.0;
    const W_NECK = 4.4;
    const W_THIGH = 8.0;
    const W_KNEE = 6.0;
    const W_SHIN = 5.6;
    const W_ANKLE = 3.8;
    const W_UARM = 4.6;
    const W_ELBOW = 3.8;
    const W_WRIST = 3.0;
    const W_HEEL = 3.2;
    const W_TOE = 2.2;

    const TORSO_STEPS = 6;
    const ARROW_LINE = 0;
    const ARROW_ARC = 1;
    const ON_HOLD = 9;

    hidden var _j as Array;
    hidden var _quad as Array;
    hidden var _tri as Array;
    hidden var _torso as Array;
    hidden var _style as Number = SILHOUETTE;

    // per-draw mapping
    hidden var _camX = 0.0;
    hidden var _camY = 0.0;
    hidden var _scale = 1.0;
    hidden var _cx = 0;
    hidden var _cy = 0;
    hidden var _mirror as Boolean = false;
    hidden var _highlight as Number = 0;
    hidden var _parts as Number = 1023;   // body parts to draw (all by default)
    hidden var _px = 1.0;

    function initialize() {
        _j = Skeleton.newJointBuffer();
        _quad = [[0, 0], [0, 0], [0, 0], [0, 0]];
        _tri = [[0, 0], [0, 0], [0, 0]];
        _torso = new [2 * (TORSO_STEPS + 1)];
        for (var i = 0; i < _torso.size(); i++) {
            _torso[i] = [0, 0];
        }
    }

    function setStyle(style as Number) as Void {
        _style = style;
    }

    function sx(x) as Float { return Skeleton.screenX(x, _camX, _scale, _cx, _mirror); }
    function sy(y) as Float { return Skeleton.screenY(y, _camY, _scale, _cy); }
    function jx(j as Number) as Float { return sx(_j[2 * j]); }
    function jy(j as Number) as Float { return sy(_j[2 * j + 1]); }

    //! Draw the sampler's current pose centred at (cx, cy) in screen px.
    //! pxScale = screen px per 390-px design unit (Theme.px(dc, 1) as Float).
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
        _parts = (def[:parts] != null) ? def[:parts] : 1023;
        Skeleton.fk(sampler.pose, _j);

        var clip = def[:clip];
        if (clip != null) {
            dc.setClip(cx + (clip[0] * pxScale).toNumber(), cy + (clip[1] * pxScale).toNumber(),
                (clip[2] * pxScale).toNumber(), (clip[3] * pxScale).toNumber());
        }
        drawProps(dc, def);

        // far side
        arm(dc, Skeleton.J_ELBOW_F, Skeleton.J_WRIST_F, Skeleton.PART_ARM_F, C_FAR);
        leg(dc, Skeleton.J_KNEE_F, Skeleton.J_ANKLE_F, Skeleton.J_TOE_F, Skeleton.J_HEEL_F,
            Skeleton.PART_THIGH_F, Skeleton.PART_SHIN_F, Skeleton.PART_FOOT_F, C_FAR);
        if ((_parts & Skeleton.PART_TORSO) != 0) {
            torso(dc, color(Skeleton.PART_TORSO, C_NEAR));
        }
        if ((_parts & Skeleton.PART_HEAD) != 0) {
            var hc = color(Skeleton.PART_HEAD, C_NEAR);
            limb(dc, Skeleton.J_SHOULDER, Skeleton.J_HEAD, W_NECK, W_NECK, hc);
            dc.setColor(hc, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(jx(Skeleton.J_HEAD).toNumber(), jy(Skeleton.J_HEAD).toNumber(), radius(Skeleton.HEAD_R * 2));
        }
        // near side
        leg(dc, Skeleton.J_KNEE_N, Skeleton.J_ANKLE_N, Skeleton.J_TOE_N, Skeleton.J_HEEL_N,
            Skeleton.PART_THIGH_N, Skeleton.PART_SHIN_N, Skeleton.PART_FOOT_N, C_NEAR);
        arm(dc, Skeleton.J_ELBOW_N, Skeleton.J_WRIST_N, Skeleton.PART_ARM_N, C_NEAR);

        if (showGuides) {
            drawRange(dc, def);
            drawArrows(dc, def, sampler);
        }
        if (clip != null) {
            dc.clearClip();
        }
    }

    hidden function color(part as Number, base as Number) as Number {
        return ((_highlight & part) != 0) ? Theme.GREEN : base;
    }

    hidden function radius(widthUnits) as Number {
        var r = (widthUnits * _scale / 2).toNumber();
        return (r < 1) ? 1 : r;
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

    //! Tapered limb between joints a and b (widths in figure units).
    hidden function limb(dc as Graphics.Dc, a as Number, b as Number, wa, wb, c as Number) as Void {
        var ax = jx(a);
        var ay = jy(a);
        var bx = jx(b);
        var by = jy(b);
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        if (_style == SKELETAL) {
            dc.setPenWidth(2);
            dc.drawLine(ax.toNumber(), ay.toNumber(), bx.toNumber(), by.toNumber());
            dc.setPenWidth(1);
            dc.fillCircle(ax.toNumber(), ay.toNumber(), 2);
            return;
        }
        var dx = bx - ax;
        var dy = by - ay;
        var ln = Math.sqrt(dx * dx + dy * dy);
        if (ln < 0.001) {
            ln = 1.0;
        }
        var nx = -dy / ln;
        var ny = dx / ln;
        var ha = wa * _scale / 2;
        var hb = wb * _scale / 2;
        setPt(_quad[0], ax + nx * ha, ay + ny * ha);
        setPt(_quad[1], bx + nx * hb, by + ny * hb);
        setPt(_quad[2], bx - nx * hb, by - ny * hb);
        setPt(_quad[3], ax - nx * ha, ay - ny * ha);
        dc.fillPolygon(_quad);
        dc.fillCircle(ax.toNumber(), ay.toNumber(), radius(wa));
        dc.fillCircle(bx.toNumber(), by.toNumber(), radius(wb));
    }

    hidden function setPt(pt as Array, x, y) as Void {
        pt[0] = x.toNumber();
        pt[1] = y.toNumber();
    }

    hidden function leg(dc as Graphics.Dc, kn as Number, an as Number, tn as Number, hn as Number,
            pThigh as Number, pShin as Number, pFoot as Number, base as Number) as Void {
        if ((_parts & pThigh) != 0) {
            limb(dc, Skeleton.J_HIP, kn, W_THIGH, W_KNEE, color(pThigh, base));
        }
        if ((_parts & pShin) != 0) {
            limb(dc, kn, an, W_SHIN, W_ANKLE, color(pShin, base));
        }
        if ((_parts & pFoot) == 0) {
            return;
        }
        var fc = color(pFoot, base);
        dc.setColor(fc, Graphics.COLOR_TRANSPARENT);
        if (_style == SKELETAL) {
            dc.setPenWidth(2);
            dc.drawLine(jx(an).toNumber(), jy(an).toNumber(), jx(tn).toNumber(), jy(tn).toNumber());
            dc.setPenWidth(1);
            return;
        }
        setPt(_tri[0], jx(an), jy(an));
        setPt(_tri[1], jx(tn), jy(tn));
        setPt(_tri[2], jx(hn), jy(hn));
        dc.fillPolygon(_tri);
        dc.fillCircle(jx(an).toNumber(), jy(an).toNumber(), radius(W_ANKLE));
        limb(dc, hn, tn, W_HEEL, W_TOE, fc);       // sole: gives the foot body
    }

    hidden function arm(dc as Graphics.Dc, el as Number, wr as Number, part as Number, base as Number) as Void {
        if ((_parts & part) == 0) {
            return;
        }
        var c = color(part, base);
        limb(dc, Skeleton.J_SHOULDER, el, W_UARM, W_ELBOW, c);
        limb(dc, el, wr, W_ELBOW, W_WRIST, c);
    }

    //! Torso along a quadratic curve hip -> shoulder through the spine control
    //! point (lifted so the curve passes through it), tapering hip -> chest.
    hidden function torso(dc as Graphics.Dc, c as Number) as Void {
        var hx = _j[2 * Skeleton.J_HIP];
        var hy = _j[2 * Skeleton.J_HIP + 1];
        var sx0 = _j[2 * Skeleton.J_SHOULDER];
        var sy0 = _j[2 * Skeleton.J_SHOULDER + 1];
        var qx = 2 * _j[2 * Skeleton.J_SPINE_C] - (hx + sx0) / 2;
        var qy = 2 * _j[2 * Skeleton.J_SPINE_C + 1] - (hy + sy0) / 2;
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        if (_style == SKELETAL) {
            dc.setPenWidth(3);
            var px = sx(hx);
            var py = sy(hy);
            for (var i = 1; i <= TORSO_STEPS; i++) {
                var t = i.toFloat() / TORSO_STEPS;
                var u = 1.0 - t;
                var nx = sx(u * u * hx + 2 * u * t * qx + t * t * sx0);
                var ny = sy(u * u * hy + 2 * u * t * qy + t * t * sy0);
                dc.drawLine(px.toNumber(), py.toNumber(), nx.toNumber(), ny.toNumber());
                px = nx;
                py = ny;
            }
            dc.setPenWidth(1);
            return;
        }
        var m = _mirror ? -1.0 : 1.0;
        var n = TORSO_STEPS;
        for (var i = 0; i <= n; i++) {
            var t = i.toFloat() / n;
            var u = 1.0 - t;
            var fx = u * u * hx + 2 * u * t * qx + t * t * sx0;
            var fy = u * u * hy + 2 * u * t * qy + t * t * sy0;
            var tx = 2 * u * (qx - hx) + 2 * t * (sx0 - qx);
            var ty = 2 * u * (qy - hy) + 2 * t * (sy0 - qy);
            var ln = Math.sqrt(tx * tx + ty * ty);
            if (ln < 0.001) {
                ln = 1.0;
            }
            var w = (W_TORSO_HIP + (W_TORSO_CHEST - W_TORSO_HIP) * t) / 2 * _scale;
            var px = sx(fx);
            var py = sy(fy);
            var nsx = m * (-ty / ln);
            var nsy = -(tx / ln);
            setPt(_torso[i], px + nsx * w, py + nsy * w);
            setPt(_torso[2 * n + 1 - i], px - nsx * w, py - nsy * w);
        }
        dc.fillPolygon(_torso);
        dc.fillCircle(sx(hx).toNumber(), sy(hy).toNumber(), radius(W_TORSO_HIP));
        dc.fillCircle(sx(sx0).toNumber(), sy(sy0).toNumber(), radius(W_TORSO_CHEST));
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
                    head(dc, bx, by, dx / ln, dy / ln);
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
                var tipX = ccx + r * Math.cos(rad);
                var tipY = ccy - r * Math.sin(rad);
                var s = ccw ? -1.0 : 1.0;
                head(dc, tipX, tipY, s * Math.sin(rad), s * Math.cos(rad));
            }
            dc.setPenWidth(1);
        }
    }

    //! Filled arrow head at (x, y) pointing along unit (dx, dy).
    hidden function head(dc as Graphics.Dc, x, y, dx, dy) as Void {
        var s = 5.0 * _px;
        var bx = x - dx * s;
        var by = y - dy * s;
        setPt(_tri[0], x, y);
        setPt(_tri[1], bx - dy * s * 0.6, by + dx * s * 0.6);
        setPt(_tri[2], bx + dy * s * 0.6, by - dx * s * 0.6);
        dc.fillPolygon(_tri);
    }
}
