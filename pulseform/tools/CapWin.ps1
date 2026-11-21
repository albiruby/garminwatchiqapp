# Simulator window grab + device extraction (adapted from Batik Watchface/tools/capture.ps1).
if (-not ("CapW5" -as [type])) {
Add-Type -ReferencedAssemblies System.Drawing @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
using System.Collections.Generic;
public static class CapW5 {
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
    public static Bitmap Grab(IntPtr h) {
        ShowWindow(h, 9); MoveWindow(h, 50, 20, 760, 900, true); System.Threading.Thread.Sleep(800);
        var bm = new Bitmap(760, 900, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bm)) { var dc = g.GetHdc(); PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
        return bm;
    }
    static bool Near(Color a, Color b, int t) { return Math.Abs(a.R-b.R) <= t && Math.Abs(a.G-b.G) <= t && Math.Abs(a.B-b.B) <= t; }
    // Keep only the device: drop menu/status bars, flood-fill the backdrop to transparent, trim.
    public static Bitmap Extract(Bitmap src) {
        int y0 = 54, y1 = src.Height - 52;
        Color bg = src.GetPixel(14, y0 + 4);
        int x1 = 14; while (x1 < src.Width - 1 && Near(src.GetPixel(x1, y0 + 4), bg, 6)) x1++;
        bool dark = bg.R + bg.G + bg.B < 60;
        if (!dark) {
            // some devices have a shorter panel with black window area below: stop at the panel edge
            int yb = y0 + 4; while (yb < y1 && Near(src.GetPixel(14, yb), bg, 6)) yb++;
            if (yb < y1) y1 = yb;
        }
        if (dark || x1 > src.Width - 20) x1 = src.Width - 10;   // backdrop spans the whole window
        int w = x1 - 10, h = y1 - y0;
        var bm = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) bm.SetPixel(x, y, src.GetPixel(x + 10, y + y0));
        if (dark) {
            // Black backdrop: clear only pure black touching the border (the device body is never
            // pure black at its outline), then crop to what is left.
            var sn = new bool[w, h]; var dq = new Queue<Point>();
            for (int x = 0; x < w; x++) { dq.Enqueue(new Point(x, 0)); dq.Enqueue(new Point(x, h - 1)); }
            for (int y = 0; y < h; y++) { dq.Enqueue(new Point(0, y)); dq.Enqueue(new Point(w - 1, y)); }
            while (dq.Count > 0) {
                var p = dq.Dequeue();
                if (p.X < 0 || p.Y < 0 || p.X >= w || p.Y >= h || sn[p.X, p.Y]) continue;
                sn[p.X, p.Y] = true;
                var c0 = bm.GetPixel(p.X, p.Y);
                if (c0.R + c0.G + c0.B > 6) continue;
                bm.SetPixel(p.X, p.Y, Color.Transparent);
                dq.Enqueue(new Point(p.X + 1, p.Y)); dq.Enqueue(new Point(p.X - 1, p.Y));
                dq.Enqueue(new Point(p.X, p.Y + 1)); dq.Enqueue(new Point(p.X, p.Y - 1));
            }
            int dl = w, dt = h, dr = 0, db = 0;
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) { var c = bm.GetPixel(x, y);
                if (c.A > 0 && c.R + c.G + c.B > 6) { if (x < dl) dl = x; if (x > dr) dr = x; if (y < dt) dt = y; if (y > db) db = y; } }
            var dc = bm.Clone(new Rectangle(dl, dt, dr - dl + 1, db - dt + 1), PixelFormat.Format32bppArgb);
            bm.Dispose(); return dc;
        }
        var seen = new bool[w, h]; var q = new Queue<Point>();
        for (int x = 0; x < w; x++) { q.Enqueue(new Point(x, 0)); q.Enqueue(new Point(x, h - 1)); }
        for (int y = 0; y < h; y++) { q.Enqueue(new Point(0, y)); q.Enqueue(new Point(w - 1, y)); }
        while (q.Count > 0) {
            var p = q.Dequeue();
            if (p.X < 0 || p.Y < 0 || p.X >= w || p.Y >= h || seen[p.X, p.Y]) continue;
            seen[p.X, p.Y] = true;
            if (!Near(bm.GetPixel(p.X, p.Y), bg, bg.R + bg.G + bg.B < 60 ? 1 : 10)) continue;
            bm.SetPixel(p.X, p.Y, Color.Transparent);
            q.Enqueue(new Point(p.X + 1, p.Y)); q.Enqueue(new Point(p.X - 1, p.Y));
            q.Enqueue(new Point(p.X, p.Y + 1)); q.Enqueue(new Point(p.X, p.Y - 1));
        }
        int l = w, t = h, r = 0, b = 0;
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) if (bm.GetPixel(x, y).A > 0) {
            if (x < l) l = x; if (x > r) r = x; if (y < t) t = y; if (y > b) b = y; }
        var crop = bm.Clone(new Rectangle(l, t, r - l + 1, b - t + 1), PixelFormat.Format32bppArgb);
        bm.Dispose(); return Clean(crop);
    }
    // Second pass: strip light window-border lines touching the edge, then trim again.
    public static Bitmap Clean(Bitmap bm) {
        int w = bm.Width, h = bm.Height;
        var seen = new bool[w, h]; var q = new Queue<Point>();
        for (int x = 0; x < w; x++) { q.Enqueue(new Point(x, 0)); q.Enqueue(new Point(x, h - 1)); }
        for (int y = 0; y < h; y++) { q.Enqueue(new Point(0, y)); q.Enqueue(new Point(w - 1, y)); }
        while (q.Count > 0) {
            var p = q.Dequeue();
            if (p.X < 0 || p.Y < 0 || p.X >= w || p.Y >= h || seen[p.X, p.Y]) continue;
            seen[p.X, p.Y] = true;
            var c = bm.GetPixel(p.X, p.Y);
            bool light = c.A == 0 || (Math.Min(c.R, Math.Min(c.G, c.B)) >= 185 && Math.Max(c.R, Math.Max(c.G, c.B)) - Math.Min(c.R, Math.Min(c.G, c.B)) < 30);
            if (!light) continue;
            bm.SetPixel(p.X, p.Y, Color.Transparent);
            q.Enqueue(new Point(p.X + 1, p.Y)); q.Enqueue(new Point(p.X - 1, p.Y));
            q.Enqueue(new Point(p.X, p.Y + 1)); q.Enqueue(new Point(p.X, p.Y - 1));
        }
        int l = w, t = h, r = 0, b = 0;
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) if (bm.GetPixel(x, y).A > 0) {
            if (x < l) l = x; if (x > r) r = x; if (y < t) t = y; if (y > b) b = y; }
        var crop = bm.Clone(new Rectangle(l, t, r - l + 1, b - t + 1), PixelFormat.Format32bppArgb);
        bm.Dispose(); return crop;
    }
}
"@
}
