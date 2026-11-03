// HeroBot.cs -- Hero's Land vision + input engine
// Build: PowerShell  Add-Type -Path .\HeroBot.cs -ReferencedAssemblies System.Drawing
// Target: .NET Framework 4.x / C# 5
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class HB
{
    // ---------------- Win32 ----------------
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int L, T, R, B; }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X, Y; }

    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] p, int cb);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT { public uint type; public InputUnion U; }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    public struct HARDWAREINPUT { public uint uMsg; public ushort wParamL; public ushort wParamH; }

    const uint INPUT_MOUSE = 0, INPUT_KEYBOARD = 1;
    const uint KEYEVENTF_SCANCODE = 0x0008, KEYEVENTF_KEYUP = 0x0002;
    const uint MOUSEEVENTF_MOVE = 0x0001, MOUSEEVENTF_ABSOLUTE = 0x8000;
    const uint MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004;

    public static bool Inited = false;

    public static void Init()
    {
        if (Inited) return;
        try { SetProcessDPIAware(); } catch { }
        Inited = true;
    }

    // ---------------- window ----------------
    public static IntPtr FindGameWindow(string procName)
    {
        foreach (System.Diagnostics.Process p in System.Diagnostics.Process.GetProcessesByName(procName))
            if (p.MainWindowHandle != IntPtr.Zero) return p.MainWindowHandle;
        return IntPtr.Zero;
    }

    public static int[] ClientSize(IntPtr hwnd)
    {
        RECT r; GetClientRect(hwnd, out r);
        return new int[] { r.R - r.L, r.B - r.T };
    }

    public static bool Focus(IntPtr hwnd)
    {
        if (IsIconic(hwnd)) ShowWindow(hwnd, 9);
        return SetForegroundWindow(hwnd);
    }

    public static bool IsForeground(IntPtr hwnd) { return GetForegroundWindow() == hwnd; }

    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);

    // plain SetForegroundWindow is refused for background processes; this is the usual workaround
    public static void ForceForeground(IntPtr hwnd)
    {
        try
        {
            IntPtr fg = GetForegroundWindow();
            uint fgThread = GetWindowThreadProcessId(fg, IntPtr.Zero);
            uint myThread = GetCurrentThreadId();
            bool attached = false;
            if (fgThread != 0 && fgThread != myThread) attached = AttachThreadInput(fgThread, myThread, true);
            if (IsIconic(hwnd)) ShowWindow(hwnd, 9);
            BringWindowToTop(hwnd);
            SetWindowPos(hwnd, (IntPtr)(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040);
            SetWindowPos(hwnd, (IntPtr)(-2), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040);
            SetForegroundWindow(hwnd);
            if (attached) AttachThreadInput(fgThread, myThread, false);
        }
        catch { }
    }

    // ---------------- capture ----------------
    public static Bitmap CaptureClient(IntPtr hwnd)
    {
        int[] sz = ClientSize(hwnd);
        int w = sz[0], h = sz[1];
        if (w <= 0 || h <= 0) return null;
        Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            IntPtr hdc = g.GetHdc();
            try { PrintWindow(hwnd, hdc, 3); }   // PW_CLIENTONLY | PW_RENDERFULLCONTENT
            finally { g.ReleaseHdc(hdc); }
        }
        return bmp;
    }

    public static int[] ToPixels(Bitmap bmp, out int w, out int h)
    {
        w = bmp.Width; h = bmp.Height;
        int[] px = new int[w * h];
        BitmapData bd = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try { Marshal.Copy(bd.Scan0, px, 0, w * h); }
        finally { bmp.UnlockBits(bd); }
        return px;
    }

    public static Bitmap LoadPng(string path)
    {
        using (Bitmap b = new Bitmap(path)) return new Bitmap(b);
    }

    // frame cache
    static int[] _px; static int _W, _H; static Bitmap _bmp;

    public static bool Grab(IntPtr hwnd)
    {
        Bitmap b = CaptureClient(hwnd);
        if (b == null) return false;
        if (_bmp == null || _bmp.Width != b.Width || _bmp.Height != b.Height)
        {
            if (_bmp != null) _bmp.Dispose();
            _bmp = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
        }
        using (Graphics g = Graphics.FromImage(_bmp)) g.DrawImageUnscaled(b, 0, 0);
        b.Dispose();
        _W = _bmp.Width; _H = _bmp.Height;
        _px = ToPixels(_bmp, out _W, out _H);
        ComputeMotion();
        return true;
    }

    public static Bitmap FrameCopy() { return _bmp == null ? null : new Bitmap(_bmp); }

    // ---- world motion: the camera keeps the player centred, so "am I moving?"
    //      can only be answered by how much the background scrolls between frames ----
    static int[] _prevSample;
    public static double LastMotion = 0;

    static void ComputeMotion()
    {
        if (_px == null) return;
        const int step = 5;
        int x0 = (int)(_W * 0.15), x1 = (int)(_W * 0.85);
        int y0 = (int)(_H * 0.10), y1 = (int)(_H * 0.85);
        int cols = (x1 - x0) / step, rows = (y1 - y0) / step;
        int n = cols * rows;
        if (n <= 0) return;
        int[] cur = new int[n];
        int k = 0;
        for (int y = 0; y < rows; y++)
        {
            int rowBase = (y0 + y * step) * _W + x0;
            for (int x = 0; x < cols; x++)
            {
                int c = _px[rowBase + x * step];
                cur[k++] = ((c >> 16) & 255) | (((c >> 8) & 255) << 8) | ((c & 255) << 16);
            }
        }
        if (_prevSample != null && _prevSample.Length == n)
        {
            int diff = 0;
            for (int i = 0; i < n; i++)
            {
                int a = _prevSample[i], b = cur[i];
                int dr = Math.Abs((a & 255) - (b & 255));
                int dg = Math.Abs(((a >> 8) & 255) - ((b >> 8) & 255));
                int db = Math.Abs(((a >> 16) & 255) - ((b >> 16) & 255));
                if (dr + dg + db > 24) diff++;
            }
            LastMotion = (double)diff / n;
        }
        _prevSample = cur;
    }

    public static Scene DetectFrame(double scale)
    {
        if (_px == null) return new Scene();
        List<Bar> bars = FindBars(_px, _W, _H, scale);
        Scene sc = Classify(bars, _W, _H, scale);
        sc.labels = FindGroundLabels(_px, _W, _H, scale, bars);
        sc.drops = FindDrops(_px, _W, _H, scale, sc.self);
        sc.chests = FindChests(_px, _W, _H, scale);
        sc.portal = FindPortal(_px, _W, _H, scale);
        return sc;
    }

    // ---------------- color tests ----------------
    static bool IsRed(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return r >= 195 && g >= 40 && g <= 105 && b >= 45 && b <= 120 && (r - g) >= 105 && (r - b) >= 95;
    }
    static bool IsGreen(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return g >= 150 && r <= 110 && b <= 130 && (g - r) >= 80 && (g - b) >= 60;
    }
    static bool IsBlue(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return b >= 150 && r <= 110 && (b - r) >= 70 && (b - g) >= 35;
    }
    static bool IsOrange(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return r >= 230 && g >= 100 && g <= 190 && b <= 85 && (r - b) >= 145;
    }
    static bool IsMagenta(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return r >= 165 && b >= 165 && g <= 120 && (r - g) >= 85 && (b - g) >= 85;
    }
    static bool IsTrack(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        int mx = Math.Max(r, Math.Max(g, b)), mn = Math.Min(r, Math.Min(g, b));
        int v = (r + g + b) / 3;
        return (mx - mn) <= 16 && v >= 60 && v <= 140;
    }
    static bool IsWhiteish(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        int mn = Math.Min(r, Math.Min(g, b)), mx = Math.Max(r, Math.Max(g, b));
        return mn >= 185 && (mx - mn) <= 50;
    }
    static bool IsDark(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return r <= 85 && g <= 85 && b <= 95;
    }

    // ---------------- connected components ----------------
    static List<int[]> Components(byte[] m, int w, int h, int minPix)
    {
        List<int[]> res = new List<int[]>();
        int[] stack = new int[w * h];
        for (int i = 0; i < m.Length; i++)
        {
            if (m[i] != 1) continue;
            int sp = 0; stack[sp++] = i; m[i] = 2;
            int x0 = int.MaxValue, y0 = int.MaxValue, x1 = -1, y1 = -1, cnt = 0;
            while (sp > 0)
            {
                int p = stack[--sp];
                int py = p / w, pxx = p - py * w;
                cnt++;
                if (pxx < x0) x0 = pxx; if (pxx > x1) x1 = pxx;
                if (py < y0) y0 = py; if (py > y1) y1 = py;
                if (pxx > 0 && m[p - 1] == 1) { m[p - 1] = 2; stack[sp++] = p - 1; }
                if (pxx < w - 1 && m[p + 1] == 1) { m[p + 1] = 2; stack[sp++] = p + 1; }
                if (py > 0 && m[p - w] == 1) { m[p - w] = 2; stack[sp++] = p - w; }
                if (py < h - 1 && m[p + w] == 1) { m[p + w] = 2; stack[sp++] = p + w; }
            }
            if (cnt >= minPix) res.Add(new int[] { x0, y0, x1, y1, cnt });
        }
        return res;
    }

    public class Bar
    {
        public int x0, y0, x1, y1;
        public int color;      // 0 red, 1 green, 2 blue(shield), 3 orange(stamina)
        public double fill;
        public bool badge;     // level badge on the left
        public bool nameTag;   // name plate
        public bool stacked;   // player-style multi bar plate
        public int cx, cy;
        public string ColorName() { return color == 0 ? "red" : color == 1 ? "green" : color == 2 ? "blue" : color == 3 ? "orange" : color == 5 ? "elite" : "track"; }
        public int Width { get { return x1 - x0 + 1; } }
    }

    public class Scene
    {
        public List<Bar> monsters = new List<Bar>();
        public List<Bar> players = new List<Bar>();
        public List<Bar> named = new List<Bar>();
        public List<Bar> allies = new List<Bar>();
        public Bar self = null;
        public List<Label> labels = new List<Label>();
        public List<Drop> drops = new List<Drop>();
        public List<Chest> chests = new List<Chest>();
        public Portal portal = null;
        public Bar stamina = null;      // stamina bar under the self plate
        public Bar hudStamina = null;   // stamina bar in the bottom HUD
    }

    static bool InUi(double fx, double fy)
    {
        if (fy < 0.055) return true;                                  // top resource strip
        if (fy > 0.900) return true;                                  // bottom skill bar
        if (fx < 0.120) return true;                                  // left avatar/leaderboard
        if (fx > 0.905) return true;                                  // right minimap/bag
        if (fx > 0.38 && fx < 0.62 && fy > 0.845) return true;        // bottom hp/energy HUD
        if (fx < 0.235 && fy > 0.700) return true;                    // chat box
        if (fx < 0.165 && fy < 0.620) return true;                    // leaderboard
        return false;
    }

    public static bool PointInUi(int x, int y, int w, int h) { return InUi((double)x / w, (double)y / h); }

    public static List<Bar> FindBars(int[] px, int W, int H, double scale)
    {
        double s = scale;
        int roiX0 = (int)(W * 0.100), roiX1 = (int)(W * 0.920);
        int roiY0 = (int)(H * 0.045), roiY1 = (int)(H * 0.925);
        int rw = roiX1 - roiX0, rh = roiY1 - roiY0;
        if (rw <= 0 || rh <= 0) return new List<Bar>();

        byte[] mR = new byte[rw * rh], mG = new byte[rw * rh], mB = new byte[rw * rh], mO = new byte[rw * rh], mT = new byte[rw * rh], mP = new byte[rw * rh];
        for (int y = 0; y < rh; y++)
        {
            int src = (y + roiY0) * W + roiX0, dst = y * rw;
            for (int x = 0; x < rw; x++)
            {
                int c = px[src + x];
                if (IsRed(c)) mR[dst + x] = 1;
                else if (IsGreen(c)) mG[dst + x] = 1;
                else if (IsBlue(c)) mB[dst + x] = 1;
                else if (IsOrange(c)) mO[dst + x] = 1;
                else if (IsMagenta(c)) mP[dst + x] = 1;
                else if (IsTrack(c)) mT[dst + x] = 1;
            }
        }

        int minH = Math.Max(3, (int)(4 * s)), maxH = (int)(26 * s);
        int minW = Math.Max(24, (int)(46 * s)), maxW = (int)(460 * s);
        List<Bar> bars = new List<Bar>();

        for (int ci = 0; ci < 6; ci++)
        {
            byte[] m = ci == 0 ? mR : ci == 1 ? mG : ci == 2 ? mB : ci == 3 ? mO : ci == 4 ? mT : mP;
            List<int[]> comps = Components(m, rw, rh, Math.Max(30, (int)(70 * s)));
            foreach (int[] c in comps)
            {
                int w = c[2] - c[0] + 1, h = c[3] - c[1] + 1, cnt = c[4];
                if (h < minH || h > maxH || w < minW || w > maxW) continue;
                if ((double)w / h < 3.0) continue;
                if ((double)cnt / (w * h) < 0.45) continue;

                Bar b = new Bar();
                b.x0 = c[0] + roiX0; b.x1 = c[2] + roiX0;
                b.y0 = c[1] + roiY0; b.y1 = c[3] + roiY0;
                b.color = ci;
                b.cx = (b.x0 + b.x1) / 2; b.cy = (b.y0 + b.y1) / 2;
                if (InUi((double)b.cx / W, (double)b.cy / H)) continue;
                b.fill = (ci == 4) ? 0.0 : FillRatio(px, W, H, b, ci, s);   // track only = HP is empty
                b.badge = HasBadge(px, W, H, b, s);
                b.nameTag = HasNamePill(px, W, H, b, s);
                bars.Add(b);
            }
        }

        // the red fill and its dark remainder can both be detected: keep the red one
        List<Bar> filtered = new List<Bar>();
        foreach (Bar b in bars)
        {
            bool dup = false;
            if (b.color == 4)
            {
                foreach (Bar o in bars)
                    if (o.color == 0 && Math.Abs(o.cx - b.cx) < 26 && Math.Abs(o.cy - b.cy) < 13) { dup = true; break; }
            }
            if (!dup) filtered.Add(b);
        }
        bars = filtered;

        // player plates carry a blue shield bar and/or an orange stamina bar
        foreach (Bar b in bars)
        {
            foreach (Bar o in bars)
            {
                if (ReferenceEquals(b, o)) continue;
                if (o.color != 2 && o.color != 3) continue;
                // player plates are tightly aligned and equally wide; a monster bar standing
                // next to the player must NOT be mistaken for a player plate
                if (Math.Abs(o.cx - b.cx) > (int)(14 * s)) continue;
                int dy = o.cy - b.cy;
                if (Math.Abs(dy) < (int)(8 * s) || Math.Abs(dy) > (int)(28 * s)) continue;
                double wr = (double)o.Width / Math.Max(1, b.Width);
                if (wr < 0.70 || wr > 1.45) continue;
                b.stacked = true; break;
            }
        }
        return bars;
    }

    static double FillRatio(int[] px, int W, int H, Bar b, int color, double s)
    {
        int x0 = b.x0 + (int)(14 * s), x1 = b.x1 - (int)(3 * s);
        if (x1 <= x0) { x0 = b.x0 + (int)(3 * s); x1 = b.x1 - (int)(3 * s); }
        if (x1 <= x0) return 1;
        int yA = b.y0 + (b.y1 - b.y0) / 3, yB = b.y1 - (b.y1 - b.y0) / 3;
        double best = 0;
        for (int y = yA; y <= yB; y++)
        {
            int hit = 0, tot = 0;
            for (int x = x0; x <= x1; x++)
            {
                int c = px[y * W + x];
                bool ok = color == 0 ? IsRed(c) : color == 1 ? IsGreen(c) : color == 2 ? IsBlue(c) : color == 4 ? IsTrack(c) : color == 5 ? IsMagenta(c) : IsOrange(c);
                if (ok) hit++;
                tot++;
            }
            double fr = tot > 0 ? (double)hit / tot : 0;
            if (fr > best) best = fr;
        }
        return best;
    }

    // level badge = a compact dark disc/square with white digits inside, sitting left of the bar.
    // Stone props and decorations have wide, irregular dark areas and are rejected.
    static bool HasBadge(int[] px, int W, int H, Bar b, double s)
    {
        int x0 = Math.Max(0, b.x0 - (int)(42 * s)), x1 = b.x0 - 2;
        int y0 = Math.Max(0, b.y0 - (int)(8 * s)), y1 = Math.Min(H - 1, b.y1 + (int)(8 * s));
        if (x1 <= x0 || y1 <= y0) return false;
        int w = x1 - x0 + 1, h = y1 - y0 + 1;
        byte[] m = new byte[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                if (IsDark(px[(y0 + y) * W + x0 + x])) m[y * w + x] = 1;
        List<int[]> comps = Components(m, w, h, 60);
        foreach (int[] c in comps)
        {
            int bw = c[2] - c[0] + 1, bh = c[3] - c[1] + 1;
            if (bw < (int)(16 * s) || bw > (int)(42 * s)) continue;
            if (bh < (int)(16 * s) || bh > (int)(42 * s)) continue;
            if ((double)c[4] / (bw * bh) < 0.45) continue;
            int white = 0;
            for (int y = c[1]; y <= c[3]; y++)
                for (int x = c[0]; x <= c[2]; x++)
                    if (IsWhiteish(px[(y0 + y) * W + x0 + x])) white++;
            if (white >= (int)(6 * s * s)) return true;
        }
        return false;
    }
    static bool HasNamePill(int[] px, int W, int H, Bar b, double s)
    {
        int up = BandText(px, W, H, b.x0, b.x1, b.y0 - (int)(30 * s), b.y0 - (int)(2 * s));
        int dn = BandText(px, W, H, b.x0, b.x1, b.y1 + (int)(2 * s), b.y1 + (int)(26 * s));
        return up > 60 || dn > 60;
    }

    // name plate = bright glyphs on a dark pill, spread across most of the bar width
    static int BandText(int[] px, int W, int H, int x0, int x1, int y0, int y1)
    {
        if (y1 <= y0 || x1 <= x0) return 0;
        if (x0 < 0) x0 = 0; if (x1 >= W) x1 = W - 1;
        if (y0 < 0) y0 = 0; if (y1 >= H) y1 = H - 1;
        int white = 0, dark = 0, tot = 0;
        int wpx = x1 - x0 + 1;
        bool[] cols = new bool[wpx];
        int colCount = 0;
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                int c = px[y * W + x]; tot++;
                if (IsWhiteish(c))
                {
                    white++;
                    if (!cols[x - x0]) { cols[x - x0] = true; colCount++; }
                }
                else if (IsDark(c)) dark++;
            }
        if (tot == 0) return 0;
        if ((double)dark / tot < 0.22) return 0;
        if (colCount < wpx * 0.40) return 0;
        return white;
    }

    public static bool DarkStripAt(int x0, int y0, int x1, int y1)
    {
        if (_px == null) return false;
        return HasDarkStrip(_px, _W, _H, x0, y0, x1, y1);
    }

    // ---------------- "is that bar still there?" ----------------
    // A damaged monster keeps a dark grey track where the red fill used to be;
    // a chest keeps a segmented dark bar above it until it is opened.
    public static bool HasDarkStrip(int[] px, int W, int H, int x0, int y0, int x1, int y1)
    {
        if (x1 <= x0 || y1 <= y0) return false;
        if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0;
        if (x1 >= W) x1 = W - 1; if (y1 >= H) y1 = H - 1;
        int rows = 0, good = 0;
        for (int y = y0; y <= y1; y++)
        {
            int dark = 0, tot = 0;
            for (int x = x0; x <= x1; x++)
            {
                int c = px[y * W + x];
                int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
                int mx = Math.Max(r, Math.Max(g, b)), mn = Math.Min(r, Math.Min(g, b));
                int v = (r + g + b) / 3;
                if ((mx - mn) <= 22 && v >= 45 && v <= 110) dark++;
                tot++;
            }
            rows++;
            if (tot > 0 && (double)dark / tot >= 0.55) good++;
        }
        return rows > 0 && good >= Math.Max(2, rows / 2);
    }
    // ---------------- safe zone: the big blue portal ----------------
    public class Portal
    {
        public int cx, cy, r;
    }

    public static Portal FindPortal(int[] px, int W, int H, double s)
    {
        byte[] m = new byte[W * H];
        for (int y = (int)(H * 0.06); y < (int)(H * 0.92); y++)
        {
            int row = y * W;
            for (int x = (int)(W * 0.06); x < (int)(W * 0.94); x++)
            {
                int c = px[row + x];
                int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
                if (b >= 200 && g >= 125 && b - r >= 105 && b - g >= 25) m[row + x] = 1;
            }
        }
        List<int[]> comps = Components(m, W, H, Math.Max(300, (int)(700 * s)));
        Portal best = null;
        foreach (int[] c in comps)
        {
            int w = c[2] - c[0] + 1, h = c[3] - c[1] + 1, cnt = c[4];
            if (w < (int)(90 * s) || h < (int)(90 * s)) continue;
            if (w > (int)(520 * s) || h > (int)(520 * s)) continue;
            double ar = (double)w / h;
            if (ar < 0.55 || ar > 1.80) continue;
            double fill = (double)cnt / (w * h);
            if (fill < 0.12 || fill > 0.92) continue;
            int cx = (c[0] + c[2]) / 2, cy = (c[1] + c[3]) / 2;
            if (InUi((double)cx / W, (double)cy / H)) continue;
            if (best == null || c[4] > best.r * best.r) { best = new Portal(); best.cx = cx; best.cy = cy; best.r = Math.Max(w, h) / 2; }
        }
        return best;
    }
    // ---------------- respawn scene: the SPIN wheel at the base ----------------
    // the wheel's cream ring is a large, very specific colour patch in the top-left area;
    // it only shows up on the respawn/base screen, so it doubles as a "you died" signal
    // crop the "(x, y)" label, binarize + pad + upscale, save as PNG for OCR
    public static string SaveCoordImage(string path)
    {
        if (_px == null) return null;
        int w = _W, h = _H;
        int rx = (int)(w * 0.845), ry = (int)(h * 0.135);
        int rw = (int)(w * 0.155), rh = (int)(h * 0.055);
        int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1;
        bool[,] on = new bool[rw, rh];
        for (int y = 0; y < rh; y++)
            for (int x = 0; x < rw; x++)
            {
                int c = _px[(ry + y) * w + (rx + x)];
                int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
                if (r >= 200 && g >= 200 && b >= 200)
                {
                    on[x, y] = true;
                    if (x < minX) minX = x; if (x > maxX) maxX = x;
                    if (y < minY) minY = y; if (y > maxY) maxY = y;
                }
            }
        if (maxX < 0) return null;
        int tw = maxX - minX + 1, th = maxY - minY + 1;
        int scale = 6, pad = 40;
        using (Bitmap outb = new Bitmap(tw * scale + pad * 2, th * scale + pad * 2, PixelFormat.Format32bppArgb))
        {
            using (Graphics g = Graphics.FromImage(outb))
            {
                g.Clear(Color.Black);
                using (SolidBrush br = new SolidBrush(Color.White))
                    for (int y = 0; y < th; y++)
                        for (int x = 0; x < tw; x++)
                            if (on[minX + x, minY + y])
                                g.FillRectangle(br, pad + x * scale, pad + y * scale, scale, scale);
            }
            outb.Save(path, ImageFormat.Png);
        }
        return path;
    }
    public static bool IsRespawnScene()
    {
        if (_px == null) return false;
        return HasSpinWheel(_px, _W, _H);
    }
    public static bool HasSpinWheel(int[] px, int W, int H)
    {
        int x0 = (int)(W * 0.18), x1 = (int)(W * 0.40);
        int y0 = 0, y1 = (int)(H * 0.25);
        int cream = 0;
        for (int y = y0; y < y1; y += 2)
        {
            int row = y * W;
            for (int x = x0; x < x1; x += 2)
            {
                int c = px[row + x];
                int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
                if (r >= 235 && g >= 215 && b >= 135 && b <= 210 && (r - b) >= 45 && (g - b) >= 35) cream++;
            }
        }
        return cream >= 900;   // ~3600 real pixels at 1080p
    }
    // ---------------- chests: wooden body with a stone frame, needs 2 hits ----------------
    public class Chest
    {
        public int x0, y0, x1, y1;
        public int cx, cy;
        public bool purple;
    }

    static bool IsWood(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return r >= 120 && r <= 245 && g >= 55 && g <= 175 && b <= 115 && (r - g) >= 35 && (g - b) >= 20;
    }
    static bool IsPurple(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        return r >= 45 && r <= 215 && g >= 18 && g <= 155 && b >= 85 && b <= 252 && (b - g) >= 30 && (b - r) >= 12;
    }
    static bool IsGrayStone(int c)
    {
        int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        int mx = Math.Max(r, Math.Max(g, b)), mn = Math.Min(r, Math.Min(g, b));
        int v = (r + g + b) / 3;
        return (mx - mn) <= 26 && v >= 70 && v <= 205;
    }

    public static List<Chest> FindChests(int[] px, int W, int H, double s)
    {
        List<Chest> res = new List<Chest>();
        const int ds = 3;                       // work on a 1/3 mask so planks merge into one blob
        int mw = W / ds, mh = H / ds;
        for (int pass = 0; pass < 2; pass++)
        {
            byte[] m = new byte[mw * mh];
            for (int y = 0; y < mh; y++)
            {
                for (int x = 0; x < mw; x++)
                {
                    bool hit = false;
                    for (int yy = 0; yy < ds && !hit; yy++)
                        for (int xx = 0; xx < ds && !hit; xx++)
                        {
                            int c = px[(y * ds + yy) * W + x * ds + xx];
                            if (pass == 0 ? IsWood(c) : IsPurple(c)) hit = true;
                        }
                    if (hit) m[y * mw + x] = 1;
                }
            }
            // horizontal closing: merge the narrow plank strips into one body blob
            for (int it = 0; it < 3; it++)
            {
                byte[] m2 = (byte[])m.Clone();
                for (int y = 0; y < mh; y++)
                    for (int x = 0; x < mw; x++)
                        if (m[y * mw + x] == 1)
                        {
                            if (x > 0) m2[y * mw + x - 1] = 1;
                            if (x < mw - 1) m2[y * mw + x + 1] = 1;
                        }
                m = m2;
            }
            List<int[]> comps = Components(m, mw, mh, Math.Max(20, (int)(40 * s)));
            foreach (int[] c in comps)
            {
                int x0 = c[0] * ds, y0 = c[1] * ds;
                int x1 = Math.Min(W - 1, c[2] * ds + ds - 1), y1 = Math.Min(H - 1, c[3] * ds + ds - 1);
                int w = x1 - x0 + 1, h = y1 - y0 + 1;
                double area = (double)w * h;
                double fill = (double)c[4] * ds * ds / area;
                if (w < (int)(40 * s) || w > (int)(200 * s)) continue;
                if (h < (int)(38 * s) || h > (int)(200 * s)) continue;
                double ar = (double)w / h;
                if (ar < 0.60 || ar > 1.85) continue;
                if (fill < 0.16) continue;

                // stone frame must sit on BOTH sides of the body
                int pad = Math.Max(6, (int)(14 * s));
                int bandW = Math.Max(6, (int)(0.30 * w));
                int lx0 = Math.Max(0, x0 - pad), lx1 = Math.Max(0, x0 + bandW);
                int rx0 = Math.Min(W - 1, x1 - bandW), rx1 = Math.Min(W - 1, x1 + pad);
                int yy0 = Math.Max(0, y0), yy1 = Math.Min(H - 1, y1);
                int leftGray = 0, rightGray = 0, tot = 0;
                for (int y = yy0; y <= yy1; y++)
                {
                    for (int x = lx0; x <= lx1; x++) if (IsGrayStone(px[y * W + x])) leftGray++;
                    for (int x = rx0; x <= rx1; x++) if (IsGrayStone(px[y * W + x])) rightGray++;
                    tot += (lx1 - lx0 + 1);
                }
                if (tot == 0) continue;
                if (leftGray < tot * 0.18 || rightGray < tot * 0.18) continue;

                int cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
                if (InUi((double)cx / W, (double)cy / H)) continue;
                Chest ch = new Chest();
                ch.x0 = x0; ch.y0 = y0; ch.x1 = x1; ch.y1 = y1;
                ch.cx = cx; ch.cy = cy; ch.purple = (pass == 1);
                res.Add(ch);
            }
        }
        return res;
    }
    // ---------------- drops: the coloured light beam above each item ----------------
    public class Drop
    {
        public int x0, y0, x1, y1;   // bounding box of the beam
        public int cx, cy;           // cy = bottom of the beam = the item itself
    }

    public static List<Drop> FindDrops(int[] px, int W, int H, double s, Bar self)
    {
        List<Drop> res = new List<Drop>();
        byte[] m = new byte[W * H];
        int ry0 = (int)(H * 0.12), ry1 = (int)(H * 0.86);
        int rx0 = (int)(W * 0.14), rx1 = (int)(W * 0.86);
        for (int y = ry0; y < ry1; y++)
        {
            int row = y * W;
            for (int x = rx0; x < rx1; x++)
            {
                int c = px[row + x];
                int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
                int mx = Math.Max(r, Math.Max(g, b)), mn = Math.Min(r, Math.Min(g, b));
                if (mx >= 170 && (mx - mn) >= 65) m[row + x] = 1;
            }
        }
        List<int[]> comps = Components(m, W, H, Math.Max(80, (int)(110 * s)));
        foreach (int[] c in comps)
        {
            int w = c[2] - c[0] + 1, h = c[3] - c[1] + 1, cnt = c[4];
            if (h < (int)(55 * s) || h > (int)(230 * s)) continue;
            if (w < (int)(8 * s) || w > (int)(70 * s)) continue;
            if ((double)h / w < 1.6) continue;
            if ((double)cnt / (w * h) < 0.30) continue;
            int cx = (c[0] + c[2]) / 2, cy = c[3];
            if (cy < (int)(H * 0.11)) continue;
            if (InUi((double)cx / W, (double)cy / H)) continue;
            // ignore the player's own fire aura / pet effects
            if (self != null && Math.Abs(cx - self.cx) < (int)(165 * s) && Math.Abs(cy - (self.cy + 40 * s)) < (int)(165 * s)) continue;
            Drop d = new Drop();
            d.x0 = c[0]; d.y0 = c[1]; d.x1 = c[2]; d.y1 = c[3]; d.cx = cx; d.cy = cy;
            res.Add(d);
        }
        return res;
    }
    // ---------------- ground labels (drops / chests) ----------------
    public class Label
    {
        public int x0, y0, x1, y1;
        public int cx, cy;
        public int Width { get { return x1 - x0 + 1; } }
        public int Height { get { return y1 - y0 + 1; } }
    }

    static List<Label> _prevLabels;

    // white bold text with black outline lying on the ground = item / chest label
    public static List<Label> FindGroundLabels(int[] px, int W, int H, double s, List<Bar> bars)
    {
        List<Label> res = new List<Label>();
        int x0 = (int)(W * 0.10), x1 = (int)(W * 0.92);
        int y0 = (int)(H * 0.15), y1 = (int)(H * 0.93);
        int w = x1 - x0, h = y1 - y0;
        if (w <= 0 || h <= 0) return res;

        byte[] m = new byte[w * h];
        for (int y = 0; y < h; y++)
        {
            int src = (y + y0) * W + x0, dst = y * w;
            for (int x = 0; x < w; x++)
                if (IsWhiteish(px[src + x])) m[dst + x] = 1;
        }
        List<int[]> comps = Components(m, w, h, Math.Max(4, (int)(10 * s)));
        if (comps.Count == 0) return res;

        // greedy line grouping by y and horizontal gap
        List<int[]> lines = new List<int[]>();   // x0,y0,x1,y1,count
        foreach (int[] c in comps)
        {
            int cx0 = c[0] + x0, cy0 = c[1] + y0, cx1 = c[2] + x0, cy1 = c[3] + y0;
            int ccy = (cy0 + cy1) / 2;
            bool merged = false;
            for (int i = 0; i < lines.Count; i++)
            {
                int[] L = lines[i];
                int lcy = (L[1] + L[3]) / 2;
                if (Math.Abs(lcy - ccy) > (int)(9 * s)) continue;
                if (cx0 - L[2] > (int)(16 * s) || L[0] - cx1 > (int)(16 * s)) continue;
                if (cx0 < L[0]) L[0] = cx0; if (cy0 < L[1]) L[1] = cy0;
                if (cx1 > L[2]) L[2] = cx1; if (cy1 > L[3]) L[3] = cy1;
                L[4] += c[4];
                merged = true; break;
            }
            if (!merged) lines.Add(new int[] { cx0, cy0, cx1, cy1, c[4] });
        }

        List<Label> cur = new List<Label>();
        foreach (int[] L in lines)
        {
            int lw = L[2] - L[0] + 1, lh = L[3] - L[1] + 1;
            if (lh < (int)(10 * s) || lh > (int)(34 * s)) continue;
            if (lw < (int)(26 * s) || lw > (int)(340 * s)) continue;
            if (L[4] < 2) continue;
            double fill = (double)L[4] / (lw * lh);
            if (fill < 0.08 || fill > 0.72) continue;
            int lcx = (L[0] + L[2]) / 2, lcy = (L[1] + L[3]) / 2;
            if (InUi((double)lcx / W, (double)lcy / H)) continue;
            bool nearBar = false;
            foreach (Bar b in bars)
            {
                if (b.x1 < L[0] - 20 || b.x0 > L[2] + 20) continue;
                if (b.y1 <= L[1] + 4 && b.y1 >= L[1] - (int)(46 * s)) { nearBar = true; break; }
                if (b.y0 >= L[3] - 4 && b.y0 <= L[3] + (int)(40 * s)) { nearBar = true; break; }
            }
            if (nearBar) continue;   // name plate, not a ground label
            // drops / chests sit low on the ground and have a bright glow right above the text
            if (lcx < (int)(W * 0.14) || lcx > (int)(W * 0.87)) continue;
            if (lcy < (int)(H * 0.30)) continue;
            int gx0 = Math.Max(0, lcx - (int)(55 * s)), gx1 = Math.Min(W - 1, lcx + (int)(55 * s));
            int gy0 = Math.Max(0, L[1] - (int)(80 * s)), gy1 = Math.Max(0, L[1] - (int)(4 * s));
            int vivid = 0;
            for (int yy = gy0; yy <= gy1; yy += 2)
                for (int xx = gx0; xx <= gx1; xx += 2)
                {
                    int c = px[yy * W + xx];
                    int rr = (c >> 16) & 255, gg = (c >> 8) & 255, bb = c & 255;
                    int mx2 = Math.Max(rr, Math.Max(gg, bb)), mn2 = Math.Min(rr, Math.Min(gg, bb));
                    if (mx2 > 150 && (mx2 - mn2) > 55) vivid++;
                }
            if (vivid < (int)(40 * s * s)) continue;
            Label lb = new Label();
            lb.x0 = L[0]; lb.y0 = L[1]; lb.x1 = L[2]; lb.y1 = L[3];
            lb.cx = lcx; lb.cy = lcy;
            cur.Add(lb);
        }

        // persistence: a real label is still there on the next frame, damage numbers are not
        if (_prevLabels == null) { res = cur; _prevLabels = cur; return res; }
        foreach (Label c in cur)
        {
            foreach (Label p in _prevLabels)
            {
                if (Math.Abs(p.cx - c.cx) < (int)(26 * s) && Math.Abs(p.cy - c.cy) < (int)(22 * s)) { res.Add(c); break; }
            }
        }
        _prevLabels = cur;
        return res;
    }
    public static Scene Classify(List<Bar> bars, int W, int H, double s)
    {
        Scene sc = new Scene();
        foreach (Bar b in bars)
        {
            if (b.color == 0)
            {
                if (b.stacked || b.nameTag) sc.players.Add(b);
                else if (b.badge) sc.monsters.Add(b);
                else sc.named.Add(b);
            }
            else if (b.color == 5)
            {
                if (b.badge || !b.nameTag) sc.monsters.Add(b);   // elite / advanced monster
                else sc.named.Add(b);
            }
            else if (b.color == 4)
            {
                // an empty HP bar is still a live monster, but the player's own shield/stamina
                // plate also shows as grey - exclude anything that sits next to a green HP bar
                bool plate = b.stacked;
                if (!plate)
                {
                    foreach (Bar o in bars)
                    {
                        if (o.color != 1) continue;
                        if (Math.Abs(o.cx - b.cx) > (int)(60 * s)) continue;
                        if (Math.Abs(o.cy - b.cy) <= (int)(45 * s)) { plate = true; break; }
                    }
                }
                if (!plate && b.badge) sc.monsters.Add(b);
                else if (plate) sc.players.Add(b);
            }
            else if (b.color == 1) sc.allies.Add(b);
        }
        double bestD = double.MaxValue;
        foreach (Bar a in sc.allies)
        {
            if (a.Width < 50 * s) continue;
            if (!(a.badge || a.nameTag)) continue;
            double dx = a.cx - W / 2.0, dy = a.cy - H / 2.0;
            double d = Math.Sqrt(dx * dx + dy * dy);
            if (d < bestD) { bestD = d; sc.self = a; }
        }
        foreach (Bar b in bars)
        {
            double fx = b.cx / (double)W, fy = b.cy / (double)H;
            if (b.color != 3) continue;
            if (fy < 0.70 || fx < 0.38 || fx > 0.62) continue;
            if (sc.hudStamina == null || b.Width > sc.hudStamina.Width) sc.hudStamina = b;
        }
        if (sc.self != null)
        {
            foreach (Bar o in bars)
            {
                if (o.color != 3) continue;
                if (Math.Abs(o.cx - sc.self.cx) > (int)(46 * s)) continue;
                int dy = o.cy - sc.self.cy;
                if (dy > 0 && dy <= (int)(36 * s)) { sc.stamina = o; break; }
            }
        }
        return sc;
    }

    public static void Annotate(Bitmap bmp, Scene sc, string path)
    {
        using (Graphics g = Graphics.FromImage(bmp))
        {
            Font f = new Font("Consolas", 14, FontStyle.Bold);
            DrawBars(g, sc.monsters, Color.Lime, "MON", f);
            DrawBars(g, sc.players, Color.Orange, "PLAYER", f);
            DrawBars(g, sc.named, Color.Gray, "NAMED", f);
            if (sc.self != null)
            {
                using (Pen p = new Pen(Color.Cyan, 2))
                    g.DrawRectangle(p, sc.self.x0 - 2, sc.self.y0 - 2, sc.self.Width + 4, sc.self.y1 - sc.self.y0 + 4);
                g.DrawString("SELF", f, Brushes.Cyan, sc.self.x0, sc.self.y1 + 2);
            }
            using (Pen pd = new Pen(Color.Magenta, 3))
            {
                foreach (Drop d in sc.drops)
                {
                    g.DrawRectangle(pd, d.x0, d.y0, Math.Max(1, d.x1 - d.x0), Math.Max(1, d.y1 - d.y0));
                    g.DrawString("DROP", f, Brushes.Magenta, d.x0, d.y1 + 2);
                }
            }
            if (sc.stamina != null)
                g.DrawString("STA " + (int)(sc.stamina.fill * 100) + "%", f, Brushes.Yellow, sc.stamina.x0, sc.stamina.y1 + 2);
        }
        bmp.Save(path, ImageFormat.Png);
    }

    static void DrawBars(Graphics g, List<Bar> list, Color col, string tag, Font f)
    {
        using (Pen p = new Pen(col, 2))
        {
            foreach (Bar b in list)
            {
                g.DrawRectangle(p, b.x0 - 2, b.y0 - 2, b.Width + 4, b.y1 - b.y0 + 4);
                g.DrawString(tag + " " + (int)(b.fill * 100) + "%", f, new SolidBrush(col), b.x0, b.y0 - 18);
            }
        }
    }

    // ---------------- input ----------------
    static ushort ScanOf(string n)
    {
        switch (n.ToUpperInvariant())
        {
            case "W": return 0x11; case "A": return 0x1E; case "S": return 0x1F; case "D": return 0x20;
            case "E": return 0x12; case "Q": return 0x10; case "R": return 0x13; case "F": return 0x21;
            case "SPACE": return 0x39; case "ESC": return 0x01;
            case "F9": return 0x43; case "F10": return 0x44;
        }
        return 0x39;
    }

    static void SendKey(ushort scan, bool up)
    {
        INPUT[] inp = new INPUT[1];
        inp[0].type = INPUT_KEYBOARD;
        inp[0].U.ki.wVk = 0;
        inp[0].U.ki.wScan = scan;
        inp[0].U.ki.dwFlags = KEYEVENTF_SCANCODE | (up ? KEYEVENTF_KEYUP : 0);
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void KeyDown(string name) { SendKey(ScanOf(name), false); }
    public static void KeyUp(string name) { SendKey(ScanOf(name), true); }
    public static void Tap(string name) { KeyDown(name); System.Threading.Thread.Sleep(35); KeyUp(name); }

    static void MouseAbs(int x, int y, uint flags)
    {
        int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
        int nx = (int)Math.Round(x * 65535.0 / Math.Max(1, sw - 1));
        int ny = (int)Math.Round(y * 65535.0 / Math.Max(1, sh - 1));
        INPUT[] inp = new INPUT[1];
        inp[0].type = INPUT_MOUSE;
        inp[0].U.mi.dx = nx; inp[0].U.mi.dy = ny;
        inp[0].U.mi.dwFlags = flags | MOUSEEVENTF_ABSOLUTE;
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void MoveTo(IntPtr hwnd, int cx, int cy)
    {
        POINT p; p.X = cx; p.Y = cy;
        ClientToScreen(hwnd, ref p);
        MouseAbs(p.X, p.Y, MOUSEEVENTF_MOVE);
    }

    public static void MouseDown() { MouseAbs(0, 0, MOUSEEVENTF_LEFTDOWN); }
    public static void MouseUp() { MouseAbs(0, 0, MOUSEEVENTF_LEFTUP); }

    public static void ClickAt(int screenX, int screenY)
    {
        int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
        int nx = (int)Math.Round(screenX * 65535.0 / Math.Max(1, sw - 1));
        int ny = (int)Math.Round(screenY * 65535.0 / Math.Max(1, sh - 1));
        INPUT[] inp = new INPUT[3];
        inp[0].type = INPUT_MOUSE; inp[0].U.mi.dx = nx; inp[0].U.mi.dy = ny;
        inp[0].U.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
        inp[1].type = INPUT_MOUSE; inp[1].U.mi.dx = nx; inp[1].U.mi.dy = ny;
        inp[1].U.mi.dwFlags = MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_ABSOLUTE;
        inp[2].type = INPUT_MOUSE; inp[2].U.mi.dx = nx; inp[2].U.mi.dy = ny;
        inp[2].U.mi.dwFlags = MOUSEEVENTF_LEFTUP | MOUSEEVENTF_ABSOLUTE;
        SendInput(3, inp, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void ClientClick(IntPtr hwnd, int cx, int cy)
    {
        POINT p; p.X = cx; p.Y = cy;
        ClientToScreen(hwnd, ref p);
        ClickAt(p.X, p.Y);
    }

    public static void ClientHoldClick(IntPtr hwnd, int cx, int cy, int ms)
    {
        POINT p; p.X = cx; p.Y = cy;
        ClientToScreen(hwnd, ref p);
        MouseAbs(p.X, p.Y, MOUSEEVENTF_MOVE);
        MouseAbs(p.X, p.Y, MOUSEEVENTF_LEFTDOWN);
        System.Threading.Thread.Sleep(Math.Max(1, ms));
        MouseAbs(p.X, p.Y, MOUSEEVENTF_LEFTUP);
    }

    public static bool KeyPressed(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }
    public static int[] CursorPos() { POINT p; GetCursorPos(out p); return new int[] { p.X, p.Y }; }
}






























