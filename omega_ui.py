import tkinter as tk
import time
import math
import sys


class Easing:
    """Collection of mathematical easing functions. All accept t in [0,1] and return an eased value."""

    # --- In ---
    @staticmethod
    def linear(t): return t
    @staticmethod
    def ease_in_sine(t): return 1 - math.cos((t * math.pi) / 2)
    @staticmethod
    def ease_in_quad(t): return t * t
    @staticmethod
    def ease_in_cubic(t): return t * t * t
    @staticmethod
    def ease_in_quart(t): return t ** 4
    @staticmethod
    def ease_in_quint(t): return t ** 5
    @staticmethod
    def ease_in_expo(t): return 0.0 if t == 0 else 2 ** (10 * t - 10)
    @staticmethod
    def ease_in_circ(t): return 1 - math.sqrt(max(0, 1 - t * t))
    @staticmethod
    def ease_in_back(t, s=1.70158): return t * t * ((s + 1) * t - s)
    @staticmethod
    def ease_in_elastic(t):
        if t == 0: return 0
        if t == 1: return 1
        return -(2 ** (10 * t - 10)) * math.sin((t * 10 - 10.75) * (2 * math.pi) / 3)
    @staticmethod
    def ease_in_bounce(t): return 1 - Easing.ease_out_bounce(1 - t)

    # --- Out ---
    @staticmethod
    def ease_out_sine(t): return math.sin((t * math.pi) / 2)
    @staticmethod
    def ease_out_quad(t): return 1 - (1 - t) ** 2
    @staticmethod
    def ease_out_cubic(t): return 1 - (1 - t) ** 3  # matches framework default
    @staticmethod
    def ease_out_quart(t): return 1 - (1 - t) ** 4
    @staticmethod
    def ease_out_quint(t): return 1 - (1 - t) ** 5
    @staticmethod
    def ease_out_expo(t): return 1.0 if t == 1 else 1 - 2 ** (-10 * t)
    @staticmethod
    def ease_out_circ(t): return math.sqrt(max(0, 1 - (t - 1) ** 2))
    @staticmethod
    def ease_out_back(t, s=1.70158): return 1 + (s + 1) * (t - 1) ** 3 + s * (t - 1) ** 2
    @staticmethod
    def ease_out_elastic(t):
        if t == 0: return 0
        if t == 1: return 1
        return 2 ** (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
    @staticmethod
    def ease_out_bounce(t):
        n1, d1 = 7.5625, 2.75
        if t < 1 / d1: return n1 * t * t
        elif t < 2 / d1: t -= 1.5 / d1; return n1 * t * t + 0.75
        elif t < 2.5 / d1: t -= 2.25 / d1; return n1 * t * t + 0.9375
        else: t -= 2.625 / d1; return n1 * t * t + 0.984375

    # --- InOut ---
    @staticmethod
    def ease_inout_sine(t): return -(math.cos(math.pi * t) - 1) / 2
    @staticmethod
    def ease_inout_quad(t): return 2 * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 2 / 2
    @staticmethod
    def ease_inout_cubic(t): return 4 * t ** 3 if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2
    @staticmethod
    def ease_inout_quart(t): return 8 * t ** 4 if t < 0.5 else 1 - (-2 * t + 2) ** 4 / 2
    @staticmethod
    def ease_inout_quint(t): return 16 * t ** 5 if t < 0.5 else 1 - (-2 * t + 2) ** 5 / 2
    @staticmethod
    def ease_inout_expo(t):
        if t == 0: return 0
        if t == 1: return 1
        if t < 0.5: return 2 ** (20 * t - 10) / 2
        return (2 - 2 ** (-20 * t + 10)) / 2
    @staticmethod
    def ease_inout_circ(t):
        if t < 0.5: return (1 - math.sqrt(max(0, 1 - (2 * t) ** 2))) / 2
        return (math.sqrt(max(0, 1 - (-2 * t + 2) ** 2)) + 1) / 2
    @staticmethod
    def ease_inout_back(t, s=1.70158):
        s2 = s * 1.525
        if t < 0.5: return ((2 * t) ** 2 * ((s2 + 1) * 2 * t - s2)) / 2
        return ((2 * t - 2) ** 2 * ((s2 + 1) * (2 * t - 2) + s2) + 2) / 2
    @staticmethod
    def ease_inout_elastic(t):
        if t == 0: return 0
        if t == 1: return 1
        if t < 0.5: return -(2 ** (20 * t - 10) * math.sin((20 * t - 11.125) * (2 * math.pi) / 4.5)) / 2
        return (2 ** (-20 * t + 10) * math.sin((20 * t - 11.125) * (2 * math.pi) / 4.5)) / 2 + 1
    @staticmethod
    def ease_inout_bounce(t):
        if t < 0.5: return (1 - Easing.ease_out_bounce(1 - 2 * t)) / 2
        return (1 + Easing.ease_out_bounce(2 * t - 1)) / 2


class DeviceDisplay:
    """Detects native display refresh rate and initializes high-precision OS timing."""
    _refresh_rate = 60
    _initialized = False

    @classmethod
    def initialize(cls):
        if cls._initialized: return
        cls._initialized = True
        if sys.platform == 'win32':
            import ctypes
            try:
                # Enable 1ms OS timer resolution on Windows to eliminate scheduling jitter
                ctypes.windll.winmm.timeBeginPeriod(1)
                user32 = ctypes.windll.user32
                hdc = user32.GetDC(0)
                VREFRESH = 116
                refresh = ctypes.windll.gdi32.GetDeviceCaps(hdc, VREFRESH)
                user32.ReleaseDC(0, hdc)
                if refresh and refresh > 30:
                    cls._refresh_rate = refresh
            except Exception:
                pass

    @classmethod
    def get_refresh_rate(cls):
        cls.initialize()
        return cls._refresh_rate

    @classmethod
    def get_frame_delay_ms(cls):
        rate = cls.get_refresh_rate()
        return max(1, int(1000 / rate))


class TweenService:
    """A plug-and-play asynchronous tweening engine for Tkinter, running safely on the main thread."""
    
    @staticmethod
    def hex_to_rgb(hex_str):
        named_colors = {
            'magenta': '#FF00FF', 'gray': '#808080', 'white': '#FFFFFF', 
            'black': '#000000', 'lime': '#00FF00', 'green': '#008000', 'red': '#FF0000',
            'cyan': '#00E5FF'
        }
        hex_str = named_colors.get(str(hex_str).lower(), hex_str)
        if not str(hex_str).startswith('#'):
            return (0, 0, 0)
        hex_str = hex_str.lstrip('#')
        if len(hex_str) == 3:
            hex_str = ''.join(c + c for c in hex_str)
        return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))

    @staticmethod
    def rgb_to_hex(rgb):
        return '#{:02x}{:02x}{:02x}'.format(int(max(0, min(255, rgb[0]))), int(max(0, min(255, rgb[1]))), int(max(0, min(255, rgb[2]))))

    @staticmethod
    def TweenColor(widget, attr, end_hex, duration=0.15, start_hex=None, is_canvas_item=False, item_id=None):
        """Tweens a color property using high-precision delta time."""
        target_key = f"_tween_target_{attr}_{item_id}" if is_canvas_item else f"_tween_target_{attr}"
        setattr(widget, target_key, end_hex)

        if not start_hex:
            try:
                start_hex = widget.itemcget(item_id, attr) if is_canvas_item else widget.cget(attr)
            except Exception:
                start_hex = '#000000'
                
        start_rgb = TweenService.hex_to_rgb(start_hex)
        end_rgb = TweenService.hex_to_rgb(end_hex)
        
        if start_rgb == end_rgb:
            if is_canvas_item:
                widget.itemconfig(item_id, **{attr: end_hex})
            else:
                widget.config(**{attr: end_hex})
            return

        start_time = time.perf_counter()
        frame_delay = DeviceDisplay.get_frame_delay_ms()
        duration = max(1e-6, duration)
        
        def animate():
            if getattr(widget, target_key, None) != end_hex:
                return
            
            elapsed = time.perf_counter() - start_time
            t = min(1.0, elapsed / duration)
            ease_t = 1 - pow(1 - t, 3)
            
            current_rgb = (
                start_rgb[0] + (end_rgb[0] - start_rgb[0]) * ease_t,
                start_rgb[1] + (end_rgb[1] - start_rgb[1]) * ease_t,
                start_rgb[2] + (end_rgb[2] - start_rgb[2]) * ease_t
            )
            current_hex = TweenService.rgb_to_hex(current_rgb)
            
            try:
                if is_canvas_item:
                    widget.itemconfig(item_id, **{attr: current_hex})
                else:
                    widget.config(**{attr: current_hex})
            except tk.TclError:
                return 
            
            if t < 1.0:
                widget.after(frame_delay, animate)

        animate()

    @staticmethod
    def TweenCoords(canvas, item_id, end_coords, duration=0.15):
        """Tweens the coordinates of a Canvas item using delta time."""
        target_key = f"_tween_coords_{item_id}"
        setattr(canvas, target_key, end_coords)

        try:
            start_coords = canvas.coords(item_id)
        except tk.TclError:
            return
            
        if not start_coords or len(start_coords) != len(end_coords):
            canvas.coords(item_id, *end_coords)
            return

        start_time = time.perf_counter()
        frame_delay = DeviceDisplay.get_frame_delay_ms()
        duration = max(1e-6, duration)

        def animate():
            if getattr(canvas, target_key, None) != end_coords:
                return

            elapsed = time.perf_counter() - start_time
            t = min(1.0, elapsed / duration)
            ease_t = 1 - pow(1 - t, 3)

            current_coords = [
                sc + (ec - sc) * ease_t for sc, ec in zip(start_coords, end_coords)
            ]

            try:
                canvas.coords(item_id, *current_coords)
            except tk.TclError:
                return

            if t < 1.0:
                canvas.after(frame_delay, animate)

        animate()

    @staticmethod
    def TweenCustom(widget, tween_id, duration, update_func):
        """Runs a custom interpolation function synced to device refresh rate using delta time."""
        target_key = f"_tween_custom_{tween_id}"
        
        # Increment an animation sequence ID to abort older conflicting tweens
        current_seq = getattr(widget, target_key, 0) + 1
        setattr(widget, target_key, current_seq)

        start_time = time.perf_counter()
        frame_delay = DeviceDisplay.get_frame_delay_ms()
        duration = max(1e-6, duration)

        def animate():
            if getattr(widget, target_key, 0) != current_seq:
                return

            elapsed = time.perf_counter() - start_time
            t = min(1.0, elapsed / duration)
            ease_t = 1 - pow(1 - t, 3)

            try:
                update_func(ease_t)
            except Exception:
                return

            if t < 1.0:
                widget.after(frame_delay, animate)

        animate()

    @staticmethod
    def TweenValue(widget, tween_id, start, end, duration, update_cb, easing=None):
        """Interpolates a generic numeric value, calling update_cb(value) each frame."""
        if easing is None: easing = Easing.ease_out_cubic
        TweenService.TweenCustom(widget, tween_id, duration,
                                  lambda t: update_cb(start + (end - start) * easing(t)))

    @staticmethod
    def TweenRGB(canvas, item_id, attr, start_hex, end_hex, duration, easing=None):
        """TweenColor with explicit easing control using high-precision delta time."""
        if easing is None: easing = Easing.ease_out_cubic
        target_key = f"_tween_target_{attr}_{item_id}"
        setattr(canvas, target_key, end_hex)
        sr, sg, sb = TweenService.hex_to_rgb(start_hex)
        er, eg, eb = TweenService.hex_to_rgb(end_hex)
        
        start_time = time.perf_counter()
        frame_delay = DeviceDisplay.get_frame_delay_ms()
        duration = max(1e-6, duration)

        def _animate():
            if getattr(canvas, target_key, None) != end_hex: return
            elapsed = time.perf_counter() - start_time
            t_ratio = min(1.0, elapsed / duration)
            t = easing(t_ratio)
            color = TweenService.rgb_to_hex((sr + (er-sr)*t, sg + (eg-sg)*t, sb + (eb-sb)*t))
            try: canvas.itemconfig(item_id, **{attr: color})
            except tk.TclError: return
            if t_ratio < 1.0: canvas.after(frame_delay, _animate)
        _animate()

    @staticmethod
    def TweenSize(widget, end_w, end_h, duration, easing=None):
        """Tweens a widget's size via geometry()."""
        if easing is None: easing = Easing.ease_out_cubic
        try: start_w, start_h = widget.winfo_width(), widget.winfo_height()
        except: return
        def _upd(t):
            try: widget.geometry(f"{int(start_w+(end_w-start_w)*t)}x{int(start_h+(end_h-start_h)*t)}")
            except: pass
        TweenService.TweenCustom(widget, "_sz", duration, lambda t: _upd(easing(t)))

    @staticmethod
    def TweenPosition(widget, end_x, end_y, duration, easing=None):
        """Tweens a widget's screen position via geometry()."""
        if easing is None: easing = Easing.ease_out_cubic
        try: start_x, start_y = widget.winfo_x(), widget.winfo_y()
        except: return
        def _upd(t):
            try: widget.geometry(f"+{int(start_x+(end_x-start_x)*t)}+{int(start_y+(end_y-start_y)*t)}")
            except: pass
        TweenService.TweenCustom(widget, "_pos", duration, lambda t: _upd(easing(t)))

    @staticmethod
    def TweenSizeAndPosition(widget, end_x, end_y, end_w, end_h, duration, easing=None):
        """Tweens size and position simultaneously."""
        if easing is None: easing = Easing.ease_out_cubic
        try:
            sx, sy = widget.winfo_x(), widget.winfo_y()
            sw, sh = widget.winfo_width(), widget.winfo_height()
        except: return
        def _upd(t):
            try:
                widget.geometry(f"{int(sw+(end_w-sw)*t)}x{int(sh+(end_h-sh)*t)}"
                                f"+{int(sx+(end_x-sx)*t)}+{int(sy+(end_y-sy)*t)}")
            except: pass
        TweenService.TweenCustom(widget, "_geo", duration, lambda t: _upd(easing(t)))

    @staticmethod
    def TweenAlpha(widget, end_alpha, duration, easing=None):
        """Tweens a Toplevel window's -alpha attribute."""
        if easing is None: easing = Easing.ease_out_cubic
        try: start_alpha = float(widget.attributes('-alpha'))
        except: start_alpha = 1.0
        def _upd(t):
            try: widget.attributes('-alpha', max(0.0, min(1.0, start_alpha + (end_alpha - start_alpha) * t)))
            except: pass
        TweenService.TweenCustom(widget, "_alpha", duration, lambda t: _upd(easing(t)))


class GDIPlusRenderer:
    """Native Windows GDI+ helper for 8x subpixel anti-aliased vector drawing."""
    _initialized = False

    @classmethod
    def initialize(cls):
        if cls._initialized: return
        cls._initialized = True
        if sys.platform == 'win32':
            import ctypes
            try:
                gdiplus = ctypes.windll.gdiplus
                class GdiplusStartupInput(ctypes.Structure):
                    _fields_ = [("GdiplusVersion", ctypes.c_uint32),
                                ("DebugEventCallback", ctypes.c_void_p),
                                ("SuppressBackgroundThread", ctypes.c_int),
                                ("SuppressExternalCodecs", ctypes.c_int)]
                buf = GdiplusStartupInput(1, None, 0, 0)
                token = ctypes.c_ulong()
                gdiplus.GdiplusStartup(ctypes.byref(token), ctypes.byref(buf), None)
            except Exception:
                pass


class CanvasUtils:
    """Global utility class for drawing complex shapes on Tkinter Canvases."""
    
    @staticmethod
    def create_antialiased_arc(canvas, cx, cy, radius, start_deg, extent_deg,
                                stroke_width=3, color=None, bg_color=None, tags=''):
        """Renders a 3-pass Gaussian subpixel anti-aliased circular arc using dense trigonometric sampling."""
        if color is None: color = Theme.ACCENT
        if bg_color is None: bg_color = Theme.BG

        if radius <= 0: return []

        # High resolution 0.5-degree sampling for butter-smooth curvature
        step = 0.5
        pts = []
        curr = float(start_deg)
        end = start_deg + extent_deg
        while curr <= end + 1e-5:
            rad = math.radians(curr)
            pts.append((cx + radius * math.cos(rad), cy - radius * math.sin(rad)))
            curr += step

        if len(pts) < 2: return []
        flat_pts = [coord for pt in pts for coord in pt]

        items = []
        sr, sg, sb = TweenService.hex_to_rgb(color)
        br, bg_g, bb = TweenService.hex_to_rgb(bg_color)

        # Multi-pass Gaussian subpixel alpha falloff colors
        fringe_col1 = TweenService.rgb_to_hex((sr * 0.20 + br * 0.80,
                                              sg * 0.20 + bg_g * 0.80,
                                              sb * 0.20 + bb * 0.80))
        fringe_col2 = TweenService.rgb_to_hex((sr * 0.55 + br * 0.45,
                                              sg * 0.55 + bg_g * 0.45,
                                              sb * 0.55 + bb * 0.45))

        # Pass 1: Outer Subpixel Fringe (20% opacity)
        items.append(canvas.create_line(*flat_pts, fill=fringe_col1, width=stroke_width + 1.8,
                                        capstyle=tk.ROUND, joinstyle=tk.ROUND, tags=tags))
        # Pass 2: Mid Subpixel Fringe (55% opacity)
        items.append(canvas.create_line(*flat_pts, fill=fringe_col2, width=stroke_width + 0.9,
                                        capstyle=tk.ROUND, joinstyle=tk.ROUND, tags=tags))
        # Pass 3: Core Stroke (100% opacity)
        items.append(canvas.create_line(*flat_pts, fill=color, width=stroke_width,
                                        capstyle=tk.ROUND, joinstyle=tk.ROUND, tags=tags))
        return items

    @staticmethod
    def create_antialiased_circle(canvas, cx, cy, radius, stroke_width=2,
                                   fill='', outline=None, bg_color=None, tags=''):
        """Draws a subpixel anti-aliased circle or ring."""
        return CanvasUtils.create_antialiased_arc(canvas, cx, cy, radius, 0, 360,
                                                   stroke_width=stroke_width, color=outline,
                                                   bg_color=bg_color, tags=tags)

    @staticmethod
    def create_rounded_rect(canvas, x1, y1, x2, y2, radius=25, **kwargs):
        if 'joinstyle' not in kwargs:
            kwargs['joinstyle'] = tk.ROUND
        if radius <= 0:
            return canvas.create_rectangle(x1, y1, x2, y2, **kwargs)
        
        # Prevent radius from overflowing the bounds of the box
        width = x2 - x1
        height = y2 - y1
        radius = min(radius, width / 2, height / 2)
        
        points = []
        step = 5 # 5 degree resolution for perfectly smooth curves
        
        # Top-Left Corner
        for i in range(180, 270 + step, step):
            rad = math.radians(i)
            points.extend([x1 + radius + radius * math.cos(rad), y1 + radius + radius * math.sin(rad)])
            
        # Top-Right Corner
        for i in range(270, 360 + step, step):
            rad = math.radians(i)
            points.extend([x2 - radius + radius * math.cos(rad), y1 + radius + radius * math.sin(rad)])
            
        # Bottom-Right Corner
        for i in range(0, 90 + step, step):
            rad = math.radians(i)
            points.extend([x2 - radius + radius * math.cos(rad), y2 - radius + radius * math.sin(rad)])
            
        # Bottom-Left Corner
        for i in range(90, 180 + step, step):
            rad = math.radians(i)
            points.extend([x1 + radius + radius * math.cos(rad), y2 - radius + radius * math.sin(rad)])
            
        return canvas.create_polygon(points, smooth=False, **kwargs)

    @staticmethod
    def _rounded_rect_points(x1, y1, x2, y2, radius=8, step=5):
        """Returns coordinate pairs for a rounded-rect path (closed) — no canvas item created."""
        radius = min(radius, (x2 - x1) / 2, (y2 - y1) / 2)
        pts = []
        for i in range(180, 271, step):
            r = math.radians(i)
            pts.append((x1 + radius + radius * math.cos(r), y1 + radius + radius * math.sin(r)))
        for i in range(270, 361, step):
            r = math.radians(i)
            pts.append((x2 - radius + radius * math.cos(r), y1 + radius + radius * math.sin(r)))
        for i in range(0, 91, step):
            r = math.radians(i)
            pts.append((x2 - radius + radius * math.cos(r), y2 - radius + radius * math.sin(r)))
        for i in range(90, 181, step):
            r = math.radians(i)
            pts.append((x1 + radius + radius * math.cos(r), y2 - radius + radius * math.sin(r)))
        return pts

    @staticmethod
    def create_rounded_rect_stroked(canvas, x1, y1, x2, y2, radius=8,
                                     stroke_width=2, stroke_align='center',
                                     fill='', stroke_color=None, **kwargs):
        """Rounded rect with inner/center/outer stroke alignment."""
        items = []
        if fill:
            items.append(CanvasUtils.create_rounded_rect(canvas, x1, y1, x2, y2,
                                                          radius=radius, fill=fill, outline=''))
        if stroke_color and stroke_width > 0:
            hw = stroke_width / 2
            if stroke_align == 'inner':   ox1,oy1,ox2,oy2 = x1+hw, y1+hw, x2-hw, y2-hw
            elif stroke_align == 'outer': ox1,oy1,ox2,oy2 = x1-hw, y1-hw, x2+hw, y2+hw
            else:                         ox1,oy1,ox2,oy2 = x1,    y1,    x2,    y2
            items.append(CanvasUtils.create_rounded_rect(canvas, ox1, oy1, ox2, oy2,
                                                          radius=radius, fill='',
                                                          outline=stroke_color, width=stroke_width))
        return items

    @staticmethod
    def create_dashed_rounded_rect(canvas, x1, y1, x2, y2, radius=8,
                                    dash=6, gap=4, color=None, width=2):
        """Dashed stroke along the perimeter of a rounded rectangle."""
        if color is None: color = Theme.ACCENT
        pts = CanvasUtils._rounded_rect_points(x1, y1, x2, y2, radius)
        if not pts: return []
        closed = pts + [pts[0]]
        items = []
        draw_on, remaining = True, dash
        for i in range(len(closed) - 1):
            p0, p1 = closed[i], closed[i + 1]
            seg_len = math.hypot(p1[0]-p0[0], p1[1]-p0[1])
            if seg_len == 0: continue
            pos = 0.0
            while pos < seg_len:
                chunk = min(remaining, seg_len - pos)
                t0, t1 = pos / seg_len, (pos + chunk) / seg_len
                if draw_on:
                    items.append(canvas.create_line(
                        p0[0]+(p1[0]-p0[0])*t0, p0[1]+(p1[1]-p0[1])*t0,
                        p0[0]+(p1[0]-p0[0])*t1, p0[1]+(p1[1]-p0[1])*t1,
                        fill=color, width=width, capstyle=tk.ROUND))
                pos += chunk
                remaining -= chunk
                if remaining <= 0:
                    draw_on = not draw_on
                    remaining = dash if draw_on else gap
        return items

    @staticmethod
    def create_gradient_border(canvas, x1, y1, x2, y2, radius=8,
                                color_start=None, color_end=None, steps=20, width=2):
        """Draws a linear gradient-colored stroke along a rounded rect perimeter (original behavior)."""
        if color_start is None: color_start = Theme.ACCENT
        if color_end is None: color_end = Theme.BTN
        sr, sg, sb = TweenService.hex_to_rgb(color_start)
        er, eg, eb = TweenService.hex_to_rgb(color_end)
        pts = CanvasUtils._rounded_rect_points(x1, y1, x2, y2, radius)
        closed = pts + [pts[0]]
        n = len(closed) - 1
        items = []
        for s in range(steps):
            i  = int(s * n / steps)
            i2 = min(int((s + 1) * n / steps), n)
            t  = s / steps
            col = TweenService.rgb_to_hex((sr+(er-sr)*t, sg+(eg-sg)*t, sb+(eb-sb)*t))
            if i < len(closed) - 1:
                items.append(canvas.create_line(
                    closed[i][0], closed[i][1], closed[i2][0], closed[i2][1],
                    fill=col, width=width, capstyle=tk.ROUND))
        return items

    @staticmethod
    def _resample_path_by_arclength(pts, steps=60):
        """Resamples a closed polygon path into `steps` evenly spaced points by arc length."""
        if not pts: return []
        closed = pts + [pts[0]]
        lengths = [math.hypot(closed[i+1][0]-closed[i][0], closed[i+1][1]-closed[i][1])
                   for i in range(len(closed)-1)]
        total_len = sum(lengths)
        if total_len == 0: return [pts[0]] * (steps + 1)

        step_len = total_len / steps
        resampled = [closed[0]]
        curr_seg = 0
        dist_in_seg = 0.0

        for s in range(1, steps + 1):
            target_dist = s * step_len
            while curr_seg < len(lengths) and dist_in_seg + lengths[curr_seg] < target_dist:
                dist_in_seg += lengths[curr_seg]
                curr_seg += 1
            if curr_seg >= len(lengths):
                resampled.append(closed[-1])
                break
            seg_len = lengths[curr_seg]
            t = (target_dist - dist_in_seg) / seg_len if seg_len > 0 else 0
            p0, p1 = closed[curr_seg], closed[curr_seg + 1]
            resampled.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t))
        return resampled

    @staticmethod
    def create_seamless_gradient_border(canvas, x1, y1, x2, y2, radius=8,
                                         color_start=None, color_end=None, steps=60, width=2,
                                         loop=True):
        """Draws a seamless gradient-colored stroke along a rounded rect perimeter using arc-length sampling."""
        if color_start is None: color_start = Theme.ACCENT
        if color_end is None: color_end = Theme.BTN
        sr, sg, sb = TweenService.hex_to_rgb(color_start)
        er, eg, eb = TweenService.hex_to_rgb(color_end)

        pts = CanvasUtils._rounded_rect_points(x1, y1, x2, y2, radius)
        sampled = CanvasUtils._resample_path_by_arclength(pts, steps=steps)
        items = []

        total_segments = len(sampled) - 1
        for i in range(total_segments):
            # Evaluate parameter at segment midpoint for smooth color sampling
            t_param = (i + 0.5) / total_segments
            if loop:
                # Symmetric ping-pong blend: 0 -> 1 -> 0
                k = 1.0 - abs(2.0 * t_param - 1.0)
            else:
                k = t_param

            col = TweenService.rgb_to_hex((sr + (er - sr) * k,
                                          sg + (eg - sg) * k,
                                          sb + (eb - sb) * k))
            items.append(canvas.create_line(
                sampled[i][0], sampled[i][1], sampled[i+1][0], sampled[i+1][1],
                fill=col, width=width, capstyle=tk.ROUND))
        return items


class ImageUtils:
    """Utility for processing icons and images to ensure clean alpha-blended rendering in Tkinter."""
    @staticmethod
    def clean_icon(icon_path, size=(16, 16), bg_hex=None):
        """
        Loads an icon with robust alpha transparency support.
        Iterates through ICO frames to find the best resolution RGBA layer.
        Composites the result onto a theme-matched background plate to eliminate halos.
        """
        try:
            from PIL import Image
            import os
            if not os.path.exists(icon_path):
                return None
            
            # Load the icon file
            img = Image.open(icon_path)
            
            # Multi-layer ICO handling: find the best quality RGBA layer
            best_img = None
            try:
                n_frames = getattr(img, "n_frames", 1)
                for i in range(n_frames):
                    img.seek(i)
                    frame = img.copy().convert("RGBA")
                    # Prefer layers that match or exceed our target size and have variation (transparency)
                    if frame.size[0] >= size[0]:
                        if best_img is None or frame.size[0] > best_img.size[0]:
                            best_img = frame
                img = best_img if best_img else img.convert("RGBA")
            except Exception:
                img = img.convert("RGBA")
            
            # Bake the icon onto specified bg color (or default title bar theme)
            # This is the most effective way to solve "halo" outlines and black boxes.
            target_bg = bg_hex if bg_hex else Theme.TITLE_BAR
            bg_rgb = TweenService.hex_to_rgb(target_bg)
            
            # Create a 24-bit canvas with the theme color to 'absorb' the alpha blending
            canvas = Image.new("RGB", img.size, bg_rgb)
            
            # Use the image's alpha channel as the transparency mask for the paste
            # This ensures that semi-transparent pixels blend into the background color
            canvas.paste(img, (0, 0), img)
            
            # Downscale using LANCZOS for maximum clarity
            canvas = canvas.resize(size, Image.Resampling.LANCZOS)
            
            return canvas
        except Exception:
            return None


class Theme:
    """Centralized color palette."""
    BG = '#0A1128'
    PANEL = '#111D3B'
    TEXT = '#E2E8F0'
    ACCENT = '#00E5FF'
    DANGER = '#EF4444'
    DANGER_HOVER = '#DC2626'
    SUCCESS = '#10B981'
    SUCCESS_HOVER = '#059669'
    BTN = '#1E3A8A'
    BTN_HOVER = '#2563EB'
    DISABLED = '#4B5563'
    DISABLED_HOVER = '#374151'
    TITLE_BAR = '#050814'


def create_omega_window(title="Omega Window", width=400, height=300, topmost=False):
    """Creates a visually borderless Tkinter window with taskbar support.

    Platform behaviour:
      Windows — Uses overrideredirect(True) and Win32 API to force taskbar presence.
      Linux   — Uses overrideredirect(True) with EWMH hints so the window manager
                still shows the window in the taskbar / panel.
    """
    window = tk.Tk()
    window.title(title)
    window.geometry(f"{width}x{height}")
    window.configure(bg=Theme.BG)
    if topmost:
        window.attributes('-topmost', True)

    window.overrideredirect(True)

    # Force an update so the window is mapped
    window.update_idletasks()

    if sys.platform == 'win32':
        import ctypes
        try:
            hwnd = ctypes.windll.user32.GetParent(window.winfo_id())
            GWL_EXSTYLE = -20
            WS_EX_APPWINDOW = 0x00040000
            WS_EX_TOOLWINDOW = 0x00000080
            style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            style = (style & ~WS_EX_TOOLWINDOW) | WS_EX_APPWINDOW
            ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style)
            window.withdraw()
            window.deiconify()
            ctypes.windll.uxtheme.SetWindowTheme(hwnd, "", "")
        except Exception:
            pass
    else:
        # Linux / X11 — set EWMH window-type hint so the panel lists the window
        try:
            window.attributes('-type', 'normal')
        except tk.TclError:
            pass
        # Withdraw/deiconify cycle helps some WMs register the window
        window.withdraw()
        window.after(50, window.deiconify)

    return window

class ToolTip:
    """Floating tooltip for widgets."""
    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self.tooltip_window = None
        self.id = None
        self.x = self.y = 0
        self.widget.bind("<Enter>", self.enter, add="+")
        self.widget.bind("<Leave>", self.leave, add="+")
        self.widget.bind("<ButtonPress>", self.leave, add="+")

    def enter(self, event=None):
        self.schedule()

    def leave(self, event=None):
        self.unschedule()
        self.hide()

    def schedule(self):
        self.unschedule()
        self.id = self.widget.after(500, self.show)

    def unschedule(self):
        id = self.id
        self.id = None
        if id:
            self.widget.after_cancel(id)

    def show(self):
        self.x = self.widget.winfo_rootx() + 20
        self.y = self.widget.winfo_rooty() + self.widget.winfo_height() + 5
        self.tooltip_window = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.attributes('-topmost', True) # Force tooltip to top layer
        tw.wm_geometry(f"+{self.x}+{self.y}")
        
        label = tk.Label(tw, text=self.text, justify='left',
                         background=Theme.TITLE_BAR, foreground=Theme.ACCENT, 
                         relief='flat', borderwidth=0, font=("Segoe UI", 8, "normal"),
                         padx=8, pady=4)
        label.pack(ipadx=1)

    def hide(self):
        tw = self.tooltip_window
        self.tooltip_window = None
        if tw:
            tw.destroy()


class OmegaButton(tk.Canvas):
    """A stylized Canvas button with customizable rounded corners, borders, hover animations and tooltip."""
    def __init__(self, parent, text, command, bg_color=Theme.BTN, hover_color=Theme.BTN_HOVER, 
                 text_color="white", tooltip=None, corner_radius=8, border_width=0, 
                 border_color=Theme.ACCENT, parent_bg=Theme.BG, height=32, width=150, **kwargs):
        super().__init__(parent, bg=parent_bg, highlightthickness=0, height=height, width=width, cursor="hand2", **kwargs)
        
        self.command = command
        self.default_bg = bg_color
        self.hover_bg = hover_color
        self.corner_radius = corner_radius
        self.border_width = border_width
        self.border_color = border_color
        
        self.text = text
        self.text_color = text_color
        self.text_font = ("Segoe UI", 9, "bold")

        self.bg_item = None
        self.text_item = None

        self.bind("<Configure>", self._on_resize)
        self.bind("<Enter>", self.on_enter, add="+")
        self.bind("<Leave>", self.on_leave, add="+")
        self.bind("<ButtonRelease-1>", self.on_click)

        if tooltip:
            ToolTip(self, tooltip)

    def _on_resize(self, event):
        self.delete("all")
        w = event.width
        h = event.height
        
        bw = self.border_width
        outline_color = self.border_color if bw > 0 else ""
        
        # Inset coordinates so strokes never clip against canvas bounds
        if bw > 0:
            offset = max(2.0, bw + 1.0)
            x1 = offset
            y1 = offset
            x2 = max(x1 + 1, w - offset)
            y2 = max(y1 + 1, h - offset)
        else:
            x1 = 0
            y1 = 0
            x2 = w
            y2 = h
        
        self.bg_item = CanvasUtils.create_rounded_rect(
            self, x1, y1, x2, y2, 
            radius=self.corner_radius, fill=self.default_bg, outline=outline_color, width=bw
        )
        
        self.text_item = self.create_text(w/2, h/2, text=self.text, fill=self.text_color, font=self.text_font)

    def on_enter(self, e):
        TweenService.TweenColor(self, 'fill', self.hover_bg, duration=0.15, start_hex=self.default_bg, is_canvas_item=True, item_id=self.bg_item)
        
    def on_leave(self, e):
        TweenService.TweenColor(self, 'fill', self.default_bg, duration=0.15, start_hex=self.hover_bg, is_canvas_item=True, item_id=self.bg_item)

    def on_click(self, e):
        if self.command:
            self.command()

    def config(self, **kwargs):
        """Overrides standard config to dynamically update text and colors on the fly"""
        if 'text' in kwargs:
            self.text = kwargs.pop('text')
            if self.text_item is not None:
                self.itemconfig(self.text_item, text=self.text)
        if 'bg' in kwargs:
            self.default_bg = kwargs.pop('bg')
            if self.bg_item is not None:
                self.itemconfig(self.bg_item, fill=self.default_bg)
        if kwargs:
            super().config(**kwargs)


class OmegaToggle(tk.Canvas):
    """Animated Canvas-based toggle switch with customizable borders."""
    def __init__(self, parent, variable, command=None, tooltip=None, border_width=0, border_color=Theme.ACCENT, **kwargs):
        super().__init__(parent, width=40, height=20, bg=Theme.BG, highlightthickness=0, cursor="hand2", **kwargs)
        self.variable = variable
        self.command = command
        
        bw = border_width
        outline = border_color if bw > 0 else ""
        
        # Draw pill background
        self.bg_item = CanvasUtils.create_rounded_rect(
            self, 2 + bw/2, 2 + bw/2, 38 - bw/2, 18 - bw/2, 
            radius=8, fill=Theme.DISABLED, outline=outline, width=bw
        )
        
        # Draw knob
        knob_x = 22 if self.variable.get() else 4
        self.knob_item = self.create_oval(knob_x, 4, knob_x + 14, 16, fill="white", outline="")
        
        # Set initial color
        initial_color = Theme.SUCCESS if self.variable.get() else Theme.DISABLED
        self.itemconfig(self.bg_item, fill=initial_color)

        self.bind("<Button-1>", self.toggle)
        
        if tooltip:
            ToolTip(self, tooltip)

    def toggle(self, event=None):
        current = self.variable.get()
        new_state = not current
        self.variable.set(new_state)
        
        target_color = Theme.SUCCESS if new_state else Theme.DISABLED
        target_coords = [22, 4, 36, 16] if new_state else [4, 4, 18, 16]
        
        TweenService.TweenColor(self, 'fill', target_color, duration=0.2, is_canvas_item=True, item_id=self.bg_item)
        TweenService.TweenCoords(self, self.knob_item, target_coords, duration=0.2)
        
        if self.command:
            self.command()


class OmegaSlider(tk.Canvas):
    """Modern Canvas-based slider with track borders, optional detent snapping and tick marks."""
    def __init__(self, parent, variable, from_=0, to=100, command=None, width=150,
                 tooltip=None, border_width=0, border_color=Theme.ACCENT,
                 detents=None, snap_radius=None, show_ticks=False, **kwargs):
        self.detents = detents or []
        self.show_ticks = show_ticks and bool(self.detents)
        _h = 26 if self.show_ticks else 20
        super().__init__(parent, width=width, height=_h, bg=Theme.BG, highlightthickness=0, **kwargs)
        self.variable = variable
        self.command = command
        self.min_val = from_
        self.max_val = to
        self.slider_width = width
        val_range = max(1e-9, to - from_)
        self.snap_radius = snap_radius if snap_radius is not None else val_range * 0.05

        outline = border_color if border_width > 0 else ""
        ty = 18 if self.show_ticks else 10  # vertical centre of track
        self._track_y = ty

        # Tick marks above the track
        if self.show_ticks:
            for dv in self.detents:
                dt = (dv - from_) / val_range
                tx = 10 + dt * (width - 20)
                self.create_line(tx, 3, tx, 11, fill=Theme.DISABLED, width=1)

        self.track = CanvasUtils.create_rounded_rect(
            self, 10, ty-2, self.slider_width-10, ty+2,
            radius=2, fill=Theme.DISABLED, outline=outline, width=border_width)
        self.fill_track = self.create_line(10, ty, 10, ty, fill=Theme.ACCENT, width=4, capstyle=tk.ROUND)
        self.handle = self.create_oval(5, ty-5, 15, ty+5, fill="white", outline=Theme.ACCENT, width=2)

        self.bind("<B1-Motion>", self.drag)
        self.bind("<Button-1>", self.drag)

        if tooltip:
            ToolTip(self, tooltip)

        self.update_visuals()

    def drag(self, event):
        x = max(10, min(event.x, self.slider_width - 10))
        percentage = (x - 10) / (self.slider_width - 20)

        val_range = self.max_val - self.min_val
        if isinstance(self.variable, tk.IntVar):
            new_val = int(self.min_val + (val_range * percentage))
        else:
            new_val = round(self.min_val + (val_range * percentage), 2)

        # Snap to nearest detent within snap_radius
        if self.detents:
            for dv in self.detents:
                if abs(new_val - dv) <= self.snap_radius:
                    new_val = dv
                    break

        self.variable.set(new_val)
        self.update_visuals()

        if self.command:
            self.command(new_val)

    def update_visuals(self, x=None):
        ty = self._track_y
        if x is None:
            span = max(1e-9, self.max_val - self.min_val)
            percentage = (self.variable.get() - self.min_val) / span
            x = 10 + (percentage * (self.slider_width - 20))

        self.coords(self.fill_track, 10, ty, x, ty)
        self.coords(self.handle, x-5, ty-5, x+5, ty+5)


class OmegaTitleBar(tk.Frame):
    """Custom Borderless Title Bar featuring optional bottom separator line."""
    def __init__(self, parent, title="Omega Window", on_close=None, border_width=0, border_color=Theme.ACCENT, icon_path=None):
        super().__init__(parent, bg=Theme.TITLE_BAR, relief=tk.FLAT, height=30)
        self.parent = parent
        self.win = None
        self.on_close = on_close
        
        self.pack(side=tk.TOP, fill=tk.X)
        self.pack_propagate(False)
        
        # Add bottom border frame first so it neatly anchors to the bottom
        if border_width > 0:
            self.bottom_border = tk.Frame(self, bg=border_color, height=border_width)
            self.bottom_border.pack(side=tk.BOTTOM, fill=tk.X)
            
        icon_pad = 10
        if icon_path:
            try:
                from PIL import ImageTk
                img = ImageUtils.clean_icon(icon_path, size=(16, 16))
                if img:
                    self.icon_img = ImageTk.PhotoImage(img) # Keep reference to prevent GC
                    self.icon_label = tk.Label(self, image=self.icon_img, bg=Theme.TITLE_BAR, borderwidth=0, highlightthickness=0)
                    self.icon_label.pack(side=tk.LEFT, padx=(10, 0))
                    self.icon_label.bind("<ButtonPress-1>", self.start_drag)
                    icon_pad = 5
            except Exception:
                pass
        
        self.title_label = tk.Label(self, text=title, bg=Theme.TITLE_BAR, fg=Theme.TEXT, font=("Segoe UI", 9, "bold"))
        self.title_label.pack(side=tk.LEFT, padx=(icon_pad, 10))
        
        # Close Button
        self.close_btn = tk.Button(self, text="✕", bg=Theme.TITLE_BAR, fg=Theme.TEXT, font=("Segoe UI", 10), 
                                   relief=tk.FLAT, borderwidth=0, command=self.close_window, cursor="hand2")
        self.close_btn.pack(side=tk.RIGHT, ipadx=10, fill=tk.Y)
        
        self.close_btn.bind("<Enter>", lambda e: TweenService.TweenColor(self.close_btn, 'bg', Theme.DANGER, duration=0.15, start_hex=Theme.TITLE_BAR))
        self.close_btn.bind("<Leave>", lambda e: TweenService.TweenColor(self.close_btn, 'bg', Theme.TITLE_BAR, duration=0.15, start_hex=Theme.DANGER))

        # Minimize Button
        self.min_btn = tk.Button(self, text="_", bg=Theme.TITLE_BAR, fg=Theme.TEXT, font=("Segoe UI", 10), 
                                 relief=tk.FLAT, borderwidth=0, command=self.minimize_window, cursor="hand2")
        self.min_btn.pack(side=tk.RIGHT, ipadx=10, fill=tk.Y)
        
        self.min_btn.bind("<Enter>", lambda e: TweenService.TweenColor(self.min_btn, 'bg', Theme.DISABLED, duration=0.15, start_hex=Theme.TITLE_BAR))
        self.min_btn.bind("<Leave>", lambda e: TweenService.TweenColor(self.min_btn, 'bg', Theme.TITLE_BAR, duration=0.15, start_hex=Theme.DISABLED))

        # Drag bindings
        self.bind("<ButtonPress-1>", self.start_drag)
        self.title_label.bind("<ButtonPress-1>", self.start_drag)

        # Automatic Window & Taskbar Icon Setup
        if icon_path:
            self._apply_taskbar_icon(icon_path)

    def _get_window(self):
        if not self.win:
            self.win = self.winfo_toplevel()
        return self.win

    def _apply_taskbar_icon(self, icon_path):
        """Sets the taskbar and window icon for both standard and overrideredirect windows."""
        try:
            import os
            if not os.path.isfile(icon_path):
                return
            abs_icon = os.path.abspath(icon_path)
            win = self._get_window()

            # Standard Tkinter wm_iconbitmap
            try:
                win.iconbitmap(abs_icon)
            except Exception:
                pass

            if sys.platform == 'win32':
                import ctypes
                user32 = ctypes.windll.user32

                # Set explicit AppUserModelID so Windows taskbar groups under this app icon
                try:
                    app_id = f"OmegaUI.{os.path.splitext(os.path.basename(abs_icon))[0]}"
                    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(app_id)
                except Exception:
                    pass

                IMAGE_ICON = 1
                LR_LOADFROMFILE = 0x0010
                LR_DEFAULTSIZE = 0x0040
                hicon_sm = user32.LoadImageW(None, abs_icon, IMAGE_ICON, 16, 16, LR_LOADFROMFILE)
                hicon_lg = user32.LoadImageW(None, abs_icon, IMAGE_ICON, 32, 32, LR_LOADFROMFILE)
                if not hicon_lg:
                    hicon_lg = user32.LoadImageW(None, abs_icon, IMAGE_ICON, 0, 0, LR_LOADFROMFILE | LR_DEFAULTSIZE)

                WM_SETICON = 0x0080
                ICON_SMALL = 0
                ICON_BIG = 1
                GCLP_HICON = -14
                GCLP_HICONSM = -34

                def _set_icons():
                    try:
                        win_id = win.winfo_id()
                        parent_id = user32.GetParent(win_id) if win_id else 0
                        ancestor_id = user32.GetAncestor(win_id, 2) if win_id else 0 # GA_ROOT = 2
                        targets = set(filter(None, [win_id, parent_id, ancestor_id]))
                        for wid in targets:
                            if hicon_sm:
                                user32.SendMessageW(wid, WM_SETICON, ICON_SMALL, hicon_sm)
                                try: user32.SetClassLongPtrW(wid, GCLP_HICONSM, hicon_sm)
                                except Exception: pass
                            if hicon_lg:
                                user32.SendMessageW(wid, WM_SETICON, ICON_BIG, hicon_lg)
                                try: user32.SetClassLongPtrW(wid, GCLP_HICON, hicon_lg)
                                except Exception: pass
                    except Exception:
                        pass

                _set_icons()
                win.after(100, _set_icons)
        except Exception:
            pass

    def close_window(self):
        if self.on_close:
            self.on_close()
        else:
            self._get_window().destroy()

    def minimize_window(self):
        win = self._get_window()
        if sys.platform == 'win32':
            import ctypes
            try:
                hwnd = ctypes.windll.user32.GetParent(win.winfo_id())
                # SW_MINIMIZE = 6
                ctypes.windll.user32.ShowWindow(hwnd, 6)
                self._map_id = win.bind("<Map>", self._on_restore, "+")
                return
            except Exception:
                pass
        # Linux / fallback — standard Tk minimize
        win.overrideredirect(False)
        win.iconify()
        # Delay binding to avoid immediate mapping events from WM when overriding redirect
        win.after(200, self._bind_restore)

    def _bind_restore(self):
        win = self._get_window()
        self._map_id = win.bind("<Map>", self._on_restore, "+")

    def _on_restore(self, event=None):
        win = self._get_window()
        # Ignore events from child widgets bubbling up to the root window
        if event and event.widget != win:
            return
            
        try:
            if hasattr(self, '_map_id'):
                win.unbind("<Map>", self._map_id)
                delattr(self, '_map_id')
            else:
                win.unbind("<Map>")
                
            # Re-apply borderless mode after restoring on Linux
            if sys.platform != 'win32':
                win.overrideredirect(True)
            win.update_idletasks()
        except Exception:
            pass

    def start_drag(self, event):
        win = self._get_window()
        self._drag_start_x = event.x_root
        self._drag_start_y = event.y_root
        self._win_start_x = win.winfo_x()
        self._win_start_y = win.winfo_y()
        event.widget.bind("<B1-Motion>", self.on_drag)
        event.widget.bind("<ButtonRelease-1>", self.stop_drag)

    def on_drag(self, event):
        win = self._get_window()
        dx = event.x_root - self._drag_start_x
        dy = event.y_root - self._drag_start_y
        win.geometry(f"+{self._win_start_x + dx}+{self._win_start_y + dy}")

    def stop_drag(self, event):
        event.widget.unbind("<B1-Motion>")
        event.widget.unbind("<ButtonRelease-1>")


class OmegaScrollbar(tk.Canvas):
    """Custom Material Design scrollbar utilizing canvas drawing."""
    def __init__(self, parent, target_canvas, orient="vertical", bg_color=Theme.BG, thumb_color=Theme.DISABLED, hover_color=Theme.ACCENT, width=8, **kwargs):
        self.orient = orient
        if self.orient == "vertical":
            super().__init__(parent, bg=bg_color, width=width, highlightthickness=0, **kwargs)
        else:
            super().__init__(parent, bg=bg_color, height=width, highlightthickness=0, **kwargs)
            
        self.target = target_canvas
        self.thumb_color = thumb_color
        self.hover_color = hover_color
        self.thumb_radius = width / 2
        self.first = 0.0
        self.last = 1.0
        self.thumb = None

        self.bind("<Configure>", self.update_thumb)
        self.bind("<ButtonPress-1>", self.drag)
        self.bind("<B1-Motion>", self.drag)
        self.bind("<Enter>", self.on_enter)
        self.bind("<Leave>", self.on_leave)

        if self.orient == "vertical":
            self.target.configure(yscrollcommand=self.set)
        else:
            self.target.configure(xscrollcommand=self.set)

    def set(self, first, last):
        self.first = float(first)
        self.last = float(last)
        self.update_thumb()

    def update_thumb(self, event=None):
        self.delete("all")
        h = self.winfo_height()
        w = self.winfo_width()
        
        if self.orient == "vertical":
            if h <= 1: return
            thumb_h = max(20, h * (self.last - self.first))
            available_slide = h - thumb_h
            
            if self.last - self.first >= 1.0:
                y1 = 0
                thumb_h = h
            else:
                y1 = (self.first / (1.0 - (self.last - self.first))) * available_slide if (1.0 - (self.last - self.first)) > 0 else 0
                
            y2 = y1 + thumb_h
            self.thumb = CanvasUtils.create_rounded_rect(self, 0, y1, w, y2, radius=self.thumb_radius, fill=self.thumb_color, outline="")
        else:
            if w <= 1: return
            thumb_w = max(20, w * (self.last - self.first))
            available_slide = w - thumb_w
            
            if self.last - self.first >= 1.0:
                x1 = 0
                thumb_w = w
            else:
                x1 = (self.first / (1.0 - (self.last - self.first))) * available_slide if (1.0 - (self.last - self.first)) > 0 else 0
                
            x2 = x1 + thumb_w
            self.thumb = CanvasUtils.create_rounded_rect(self, x1, 0, x2, h, radius=self.thumb_radius, fill=self.thumb_color, outline="")

    def drag(self, event):
        if self.orient == "vertical":
            h = self.winfo_height()
            if h <= 1: return
            thumb_size_frac = self.last - self.first
            frac = (event.y / h) - (thumb_size_frac / 2)
            self.target.yview_moveto(max(0.0, min(1.0 - thumb_size_frac, frac)))
        else:
            w = self.winfo_width()
            if w <= 1: return
            thumb_size_frac = self.last - self.first
            frac = (event.x / w) - (thumb_size_frac / 2)
            self.target.xview_moveto(max(0.0, min(1.0 - thumb_size_frac, frac)))

    def on_enter(self, event):
        if self.thumb:
            TweenService.TweenColor(self, 'fill', self.hover_color, 0.15, self.thumb_color, is_canvas_item=True, item_id=self.thumb)

    def on_leave(self, event):
        if self.thumb:
            TweenService.TweenColor(self, 'fill', self.thumb_color, 0.15, self.hover_color, is_canvas_item=True, item_id=self.thumb)


class OmegaScrollFrame(tk.Frame):
    """A stylized, mouse-wheel enabled scrollable frame."""
    def __init__(self, parent, bg_color=Theme.BG, *args, **kwargs):
        super().__init__(parent, bg=bg_color, *args, **kwargs)

        self.canvas = tk.Canvas(self, bg=bg_color, highlightthickness=0)
        self.scrollbar = OmegaScrollbar(self, target_canvas=self.canvas, bg_color=bg_color, width=8)
        self.inner_frame = tk.Frame(self.canvas, bg=bg_color)

        self.inner_window = self.canvas.create_window((0, 0), window=self.inner_frame, anchor="nw")

        self.scrollbar.pack(side="right", fill="y", padx=2)
        self.canvas.pack(side="left", fill="both", expand=True)

        self.inner_frame.bind("<Configure>", self._on_frame_configure)
        self.canvas.bind("<Configure>", self._on_canvas_configure)
        
        self.canvas.bind("<Enter>", self._bind_mousewheel)
        self.canvas.bind("<Leave>", self._unbind_mousewheel)

    def _on_frame_configure(self, event=None):
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))

    def _on_canvas_configure(self, event):
        self.canvas.itemconfig(self.inner_window, width=event.width)

    def _bind_mousewheel(self, event):
        if sys.platform == 'win32':
            self.canvas.bind_all("<MouseWheel>", self._on_mousewheel)
        else:
            # Linux / X11 uses Button-4 (scroll up) and Button-5 (scroll down)
            self.canvas.bind_all("<Button-4>", self._on_mousewheel)
            self.canvas.bind_all("<Button-5>", self._on_mousewheel)

    def _unbind_mousewheel(self, event):
        if sys.platform == 'win32':
            self.canvas.unbind_all("<MouseWheel>")
        else:
            self.canvas.unbind_all("<Button-4>")
            self.canvas.unbind_all("<Button-5>")

    def _on_mousewheel(self, event):
        if sys.platform == 'win32':
            self.canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        else:
            # Button-4 = scroll up, Button-5 = scroll down
            if event.num == 4:
                self.canvas.yview_scroll(-3, "units")
            elif event.num == 5:
                self.canvas.yview_scroll(3, "units")


class OmegaDropdown(tk.Canvas):
    """Custom Dropdown leveraging native Windows coordinate mapping for absolute overlay positioning."""
    def __init__(self, parent, variable, values, width=150, height=32, corner_radius=2,
                 bg_color=Theme.BTN, hover_color=Theme.BTN_HOVER, text_color=Theme.TEXT,
                 menu_bg=Theme.PANEL, menu_hover=Theme.BTN, parent_bg=Theme.BG,
                 border_width=0, border_color=Theme.ACCENT, command=None, **kwargs):
        super().__init__(parent, bg=parent_bg, highlightthickness=0, height=height, width=width, cursor="hand2", **kwargs)
        
        self.variable = variable
        self.values = values
        self.command = command
        
        self.default_bg = bg_color
        self.hover_bg = hover_color
        self.text_color = text_color
        self.menu_bg = menu_bg
        self.menu_hover = menu_hover
        self.corner_radius = corner_radius
        self.border_width = border_width
        self.border_color = border_color
        
        self.text_font = ("Segoe UI", 9, "bold")
        self.is_open = False
        self.dropdown_window = None

        self.bg_item = None
        self.text_item = None
        self.arrow_item = None

        self.bind("<Configure>", self._on_resize)
        self.bind("<Enter>", self.on_enter)
        self.bind("<Leave>", self.on_leave)
        self.bind("<ButtonRelease-1>", self.toggle_menu)

        self.variable.trace_add("write", self._on_var_changed)

    def _on_var_changed(self, *args):
        if self.text_item is not None:
            self.itemconfig(self.text_item, text=str(self.variable.get()))

    def _on_resize(self, event):
        self.delete("all")
        w = event.width
        h = event.height
        
        bw = self.border_width
        outline_color = self.border_color if bw > 0 else ""
        
        self.bg_item = CanvasUtils.create_rounded_rect(
            self, bw/2, bw/2, w - bw/2, h - bw/2, 
            radius=self.corner_radius, fill=self.default_bg, outline=outline_color, width=bw
        )
        
        self.text_item = self.create_text(15, h/2, text=str(self.variable.get()), fill=self.text_color, font=self.text_font, anchor="w")
        
        ax = w - 20
        ay = h/2
        self.arrow_item = self.create_polygon(ax-4, ay-2, ax+4, ay-2, ax, ay+3, fill=self.text_color)

    def on_enter(self, e):
        if not self.is_open:
            TweenService.TweenColor(self, 'fill', self.hover_bg, duration=0.15, start_hex=self.default_bg, is_canvas_item=True, item_id=self.bg_item)
        
    def on_leave(self, e):
        if not self.is_open:
            TweenService.TweenColor(self, 'fill', self.default_bg, duration=0.15, start_hex=self.hover_bg, is_canvas_item=True, item_id=self.bg_item)

    def toggle_menu(self, e=None):
        if self.is_open:
            self.close_menu()
        else:
            self.open_menu()

    def get_absolute_rect(self):
        """Returns (left, top, right, bottom) in screen coordinates."""
        if sys.platform == 'win32':
            import ctypes
            class RECT(ctypes.Structure):
                _fields_ = [
                    ('left', ctypes.c_long),
                    ('top', ctypes.c_long),
                    ('right', ctypes.c_long),
                    ('bottom', ctypes.c_long)
                ]
            hwnd = self.winfo_id()
            rect = RECT()
            ctypes.windll.user32.GetWindowRect(hwnd, ctypes.byref(rect))
            return rect.left, rect.top, rect.right, rect.bottom
        # Linux / fallback — use Tk's own geometry helpers
        self.update_idletasks()
        left = self.winfo_rootx()
        top = self.winfo_rooty()
        right = left + self.winfo_width()
        bottom = top + self.winfo_height()
        return left, top, right, bottom

    def open_menu(self):
        self.is_open = True
        TweenService.TweenColor(self, 'fill', self.hover_bg, duration=0.15, is_canvas_item=True, item_id=self.bg_item)
        self.itemconfig(self.arrow_item, fill=self.border_color)

        self.dropdown_window = tk.Toplevel(self)
        self.dropdown_window.wm_overrideredirect(True)
        self.dropdown_window.attributes('-topmost', True)
        self.dropdown_window.config(bg=self.menu_bg, highlightbackground=self.border_color, highlightcolor=self.border_color, highlightthickness=1)

        left, top, right, bottom = self.get_absolute_rect()
        w = right - left
        
        item_height = 28
        total_height = len(self.values) * item_height
        if total_height > 200: total_height = 200
            
        self.dropdown_window.geometry(f"{w}x{total_height}+{left}+{bottom}")

        self.dropdown_window.bind("<FocusOut>", lambda e: self.close_menu())
        
        if len(self.values) > 7:
            scroll_frame = OmegaScrollFrame(self.dropdown_window, bg_color=self.menu_bg)
            scroll_frame.pack(fill=tk.BOTH, expand=True)
            container = scroll_frame.inner_frame
        else:
            container = self.dropdown_window

        for val in self.values:
            lbl = tk.Label(container, text=str(val), bg=self.menu_bg, fg=self.text_color, 
                           font=self.text_font, anchor="w", padx=15, pady=4, cursor="hand2")
            lbl.pack(fill=tk.X)
            lbl.bind("<Enter>", lambda e, l=lbl: l.config(bg=self.menu_hover))
            lbl.bind("<Leave>", lambda e, l=lbl: l.config(bg=self.menu_bg))
            lbl.bind("<ButtonRelease-1>", lambda e, v=val: self.select_item(v))

        self.dropdown_window.focus_set()

    def select_item(self, value):
        self.variable.set(value)
        if self.command:
            try:
                self.command(value)
            except TypeError:
                try:
                    self.command()
                except Exception as e:
                    print(f"[OmegaDropdown] Error executing command: {e}")
            except Exception as e:
                print(f"[OmegaDropdown] Error executing command: {e}")
        self.close_menu()

    def close_menu(self):
        self.is_open = False
        if self.dropdown_window:
            self.dropdown_window.destroy()
            self.dropdown_window = None
        TweenService.TweenColor(self, 'fill', self.default_bg, duration=0.15, is_canvas_item=True, item_id=self.bg_item)
        if self.arrow_item:
            self.itemconfig(self.arrow_item, fill=self.text_color)


# =============================================================================
# Z-INDEX AND LAYER MANAGEMENT
# =============================================================================

class LayerManager:
    """Manages z-index ordering of canvas items using integer layer constants."""

    BACKGROUND = 0
    CONTENT    = 10
    UI         = 20
    OVERLAY    = 30
    TOOLTIP    = 40

    def __init__(self, canvas):
        self._canvas = canvas
        self._layers = {}  # item_id -> layer int

    def set_layer(self, item_id, layer):
        """Assigns an item to a layer integer and re-sorts the canvas."""
        self._layers[item_id] = layer
        self._sort()

    def get_layer(self, item_id):
        """Returns the current layer integer of an item (defaults to CONTENT)."""
        return self._layers.get(item_id, self.CONTENT)

    def raise_to_layer(self, item_id, layer):
        self._layers[item_id] = layer
        self._sort()

    def lower_to_layer(self, item_id, layer):
        self._layers[item_id] = layer
        self._sort()

    def remove(self, item_id):
        """Unregisters an item without deleting it from the canvas."""
        self._layers.pop(item_id, None)

    def sort_all(self):
        """Re-sorts all registered items by their layer value."""
        self._sort()

    def _sort(self):
        sorted_items = sorted(self._layers.items(), key=lambda kv: kv[1])
        dead = []
        for item_id, _ in sorted_items:
            try:
                self._canvas.tag_raise(item_id)
            except tk.TclError:
                dead.append(item_id)
        for d in dead:
            self._layers.pop(d, None)


# =============================================================================
# VISUAL UTILITIES  (drop shadow + gradients)
# =============================================================================

class VisualUtils:
    """Cosmetic canvas utilities: drop shadows and linear/radial gradients."""

    @staticmethod
    def create_drop_shadow(canvas, x1, y1, x2, y2, radius=8,
                           layers=6, color='#000000', opacity_start=0.35,
                           offset_x=3, offset_y=3):
        """
        Simulates a soft drop shadow by stacking progressively lighter, offset polygons.
        Returns a list of canvas item IDs (render them before the panel itself).
        """
        try:    bg_hex = canvas.cget('bg')
        except: bg_hex = '#000000'
        br, bg_, bb = TweenService.hex_to_rgb(bg_hex)
        sr, sg, sb  = TweenService.hex_to_rgb(color)
        items = []
        for i in range(layers, 0, -1):
            alpha  = opacity_start * (i / layers)
            spread = (layers - i) * 1.5
            col = TweenService.rgb_to_hex((
                int(sr * alpha + br * (1 - alpha)),
                int(sg * alpha + bg_ * (1 - alpha)),
                int(sb * alpha + bb * (1 - alpha))
            ))
            items.append(CanvasUtils.create_rounded_rect(
                canvas,
                x1 + offset_x - spread, y1 + offset_y - spread,
                x2 + offset_x + spread, y2 + offset_y + spread,
                radius=radius + spread, fill=col, outline=''
            ))
        return items

    @staticmethod
    def draw_linear_gradient(canvas, x1, y1, x2, y2,
                              color_start=None, color_end=None,
                              direction='horizontal', steps=None):
        """
        Fills a bounding box with a smooth linear gradient using line strips.
        Returns a list of canvas item IDs.
        """
        if color_start is None: color_start = Theme.BTN
        if color_end   is None: color_end   = Theme.PANEL
        sr, sg, sb = TweenService.hex_to_rgb(color_start)
        er, eg, eb = TweenService.hex_to_rgb(color_end)
        items = []
        if direction == 'horizontal':
            span  = max(1, int(x2 - x1))
            steps = steps or max(1, span // 2)
            for i in range(steps):
                t   = i / max(1, steps - 1)
                col = TweenService.rgb_to_hex((sr+(er-sr)*t, sg+(eg-sg)*t, sb+(eb-sb)*t))
                px  = x1 + (x2 - x1) * t
                items.append(canvas.create_line(
                    px, y1, px, y2,
                    fill=col, width=max(1, int((x2 - x1) / steps) + 1)))
        else:  # vertical
            span  = max(1, int(y2 - y1))
            steps = steps or max(1, span // 2)
            for i in range(steps):
                t   = i / max(1, steps - 1)
                col = TweenService.rgb_to_hex((sr+(er-sr)*t, sg+(eg-sg)*t, sb+(eb-sb)*t))
                py  = y1 + (y2 - y1) * t
                items.append(canvas.create_line(
                    x1, py, x2, py,
                    fill=col, width=max(1, int((y2 - y1) / steps) + 1)))
        return items

    @staticmethod
    def draw_radial_gradient(canvas, cx, cy, radius,
                              color_start=None, color_end=None, bg_color=None, steps=None):
        """
        Fills a circle with a smooth radial gradient (center -> edge) and subpixel anti-aliased outer edge.
        Returns a list of canvas item IDs.
        """
        if color_start is None: color_start = Theme.ACCENT
        if color_end   is None: color_end   = Theme.PANEL
        if bg_color    is None: bg_color    = Theme.BG
        if steps is None: steps = max(1, int(radius * 1.5))
        sr, sg, sb = TweenService.hex_to_rgb(color_start)
        er, eg, eb = TweenService.hex_to_rgb(color_end)
        br, bg_g, bb = TweenService.hex_to_rgb(bg_color)

        items = []

        # Subpixel anti-aliased outer perimeter fringe rings
        fringe_col1 = TweenService.rgb_to_hex((er * 0.25 + br * 0.75,
                                              eg * 0.25 + bg_g * 0.75,
                                              eb * 0.25 + bb * 0.75))
        fringe_col2 = TweenService.rgb_to_hex((er * 0.65 + br * 0.35,
                                              eg * 0.65 + bg_g * 0.35,
                                              eb * 0.65 + bb * 0.35))

        r_f1 = radius + 0.8
        r_f2 = radius + 0.4
        items.append(canvas.create_oval(cx - r_f1, cy - r_f1, cx + r_f1, cy + r_f1, fill=fringe_col1, outline=''))
        items.append(canvas.create_oval(cx - r_f2, cy - r_f2, cx + r_f2, cy + r_f2, fill=fringe_col2, outline=''))

        for i in range(steps, 0, -1):
            t   = i / steps
            r   = radius * t
            col = TweenService.rgb_to_hex((sr + (er - sr) * (1 - t),
                                          sg + (eg - sg) * (1 - t),
                                          sb + (eb - sb) * (1 - t)))
            items.append(canvas.create_oval(cx - r, cy - r, cx + r, cy + r, fill=col, outline=''))
        return items


# =============================================================================
# PROGRESS INDICATORS
# =============================================================================

class OmegaProgressBar(tk.Canvas):
    """
    Multi-style progress bar.

    Styles:
        'smooth'    — rounded filled track animated with TweenValue
        'segmented' — N discrete colored blocks
        'detent'    — continuous fill with tick notches at milestone values

    Call set_indeterminate(True) for a bouncing animation on unknown wait times.
    """

    def __init__(self, parent, value=0.0, min_val=0.0, max_val=1.0,
                 style='smooth', segments=10, detents=None,
                 width=200, height=16,
                 track_color=None, fill_color=None, bg_color=None,
                 corner_radius=4, easing=None, segment_threshold=0.6, **kwargs):
        if bg_color    is None: bg_color    = Theme.BG
        if track_color is None: track_color = Theme.PANEL
        if fill_color  is None: fill_color  = Theme.ACCENT
        super().__init__(parent, width=width, height=height,
                         bg=bg_color, highlightthickness=0, **kwargs)
        self.min_val      = min_val
        self.max_val      = max_val
        self._value       = value
        self.style        = style
        self.segments     = segments
        self.detents      = detents or []
        self.track_color  = track_color
        self.fill_color   = fill_color
        self.corner_radius = corner_radius
        self.easing       = easing or Easing.ease_out_cubic
        self.segment_threshold = max(0.0, min(1.0, segment_threshold))
        self._indeterminate     = False
        self._indeterminate_seq = 0
        self._pad = 2

        self.bind('<Configure>', lambda e: self._draw())
        self._draw()

    # --- Public API ---

    def set_value(self, value, animated=True):
        """Sets the progress value, optionally tweening the transition."""
        target = max(self.min_val, min(self.max_val, value))
        if not animated:
            self._value = target
            self._draw()
            return
        start = self._value
        def _upd(v): self._value = v; self._draw()
        TweenService.TweenValue(self, '_prog', start, target, 0.3, _upd, self.easing)

    def set_indeterminate(self, active: bool):
        """Starts or stops the bouncing indeterminate animation."""
        if active == self._indeterminate: return
        self._indeterminate = active
        if active:
            self._indeterminate_seq += 1
            self._run_indeterminate(self._indeterminate_seq)

    # --- Internal ---

    def _get_segment_bounds(self):
        """Calculates segment boundaries for discrete segmented or detent styles."""
        style_norm = str(self.style).lower()
        if style_norm == 'detent' and self.detents:
            sorted_d = sorted([d for d in self.detents if self.min_val < d < self.max_val])
            span = max(1e-9, self.max_val - self.min_val)
            points = [0.0] + [(d - self.min_val) / span for d in sorted_d] + [1.0]
            return [(points[i], points[i+1]) for i in range(len(points)-1)]
        else:
            n = self.segments if (isinstance(self.segments, int) and self.segments > 0) else 10
            return [(i / n, (i + 1) / n) for i in range(n)]

    def _draw_flat_progress(self, p, w, h, r, x_left, x_right):
        """Draws a pure flat / modern continuous fill progress bar."""
        if x_right > x_left:
            px1 = p + (w - 2 * p) * x_left
            px2 = p + (w - 2 * p) * x_right
            if px2 > px1:
                CanvasUtils.create_rounded_rect(self, px1, p, px2, h - p,
                                                radius=r, fill=self.fill_color, outline='', tags='p')

    def _draw_segmented_progress(self, p, w, h, r, x_left, x_right, bounds):
        """Draws a progress bar with discrete locked sections (segmented or detent milestones)."""
        gap = 2
        n = len(bounds)
        if n <= 0: return
        avail_w = (w - 2 * p) - (n - 1) * gap

        for i, (b_start, b_end) in enumerate(bounds):
            sec_len = b_end - b_start
            thresh_right = b_start + sec_len * self.segment_threshold
            thresh_left  = b_start + sec_len * (1.0 - self.segment_threshold)

            # Determine lit state using thresholds
            if x_right >= 1.0 and x_left <= 0.0:
                is_lit = True
            elif x_right < thresh_right:
                is_lit = False
            elif x_left >= thresh_left:
                is_lit = False
            else:
                is_lit = True

            col = self.fill_color if is_lit else self.track_color

            style_norm = str(self.style).lower()
            if style_norm == 'detent':
                sx1 = p + (w - 2 * p) * b_start
                sx2 = p + (w - 2 * p) * b_end
            else:
                sw = avail_w / n
                sx1 = p + i * (sw + gap)
                sx2 = sx1 + sw

            CanvasUtils.create_rounded_rect(self, sx1, p, sx2, h - p,
                                            radius=max(1, r - 2), fill=col, outline='', tags='p')

            # Draw detent divider line if detent style
            if style_norm == 'detent' and i < n - 1:
                dx = p + (w - 2 * p) * b_end
                self.create_line(dx, p, dx, h - p, fill=Theme.BG, width=2, tags='p')

    def _draw(self, event=None):
        self.delete('p')
        w = self.winfo_width()  or int(self['width'])
        h = self.winfo_height() or int(self['height'])
        p = self._pad
        r = self.corner_radius

        CanvasUtils.create_rounded_rect(self, p, p, w-p, h-p,
                                        radius=r, fill=self.track_color, outline='', tags='p')

        if self._indeterminate:
            x_left  = getattr(self, '_indeterminate_left', 0.0)
            x_right = getattr(self, '_indeterminate_right', 0.0)
        else:
            span = max(1e-9, self.max_val - self.min_val)
            x_left  = 0.0
            x_right = max(0.0, min(1.0, (self._value - self.min_val) / span))

        style_norm = str(self.style).lower()
        if style_norm in ('smooth', 'flat', 'modern'):
            self._draw_flat_progress(p, w, h, r, x_left, x_right)
        elif style_norm in ('segmented', 'segment', 'detent'):
            bounds = self._get_segment_bounds()
            self._draw_segmented_progress(p, w, h, r, x_left, x_right, bounds)
        else:
            self._draw_flat_progress(p, w, h, r, x_left, x_right)

    def _run_indeterminate(self, seq):
        if not self._indeterminate or seq != self._indeterminate_seq: return

        duration = 0.9  # Total sweep cycle duration in seconds
        start_time = time.perf_counter()
        frame_delay = DeviceDisplay.get_frame_delay_ms()

        def _anim():
            if not self._indeterminate or seq != self._indeterminate_seq: return
            elapsed = time.perf_counter() - start_time
            t = (elapsed / duration) % 1.0

            if t <= 0.5:
                # Phase 1: Fill from left to right
                sub_t = t / 0.5
                e = Easing.ease_inout_sine(sub_t)
                self._indeterminate_left = 0.0
                self._indeterminate_right = e
            else:
                # Phase 2: Un-fill from left to right
                sub_t = (t - 0.5) / 0.5
                e = Easing.ease_inout_sine(sub_t)
                self._indeterminate_left = e
                self._indeterminate_right = 1.0

            self._draw()
            self.after(frame_delay, _anim)

        _anim()


class OmegaSpinner(tk.Canvas):
    """
    Circular arc throbber for indeterminate loading states.

        spinner = OmegaSpinner(parent, size=32)
        spinner.start()   # begin rotating
        spinner.stop()    # stop rotating
    """

    def __init__(self, parent, size=32, arc_color=None, track_color=None,
                 bg_color=None, speed=3.0, arc_length=270, stroke_width=3, **kwargs):
        if bg_color    is None: bg_color    = Theme.BG
        if arc_color   is None: arc_color   = Theme.ACCENT
        if track_color is None: track_color = Theme.PANEL
        super().__init__(parent, width=size, height=size,
                         bg=bg_color, highlightthickness=0, **kwargs)
        self.size         = size
        self.arc_color    = arc_color
        self.track_color  = track_color
        self.bg_color     = bg_color
        self.speed        = speed
        self.arc_length   = arc_length
        self.stroke_width = stroke_width
        self._angle       = 0.0
        self._spinning    = False
        self._spin_seq    = 0
        self._draw()

    def start(self):
        if self._spinning: return
        self._spinning = True
        self._spin_seq += 1
        self._spin_start_time = time.perf_counter()
        self._spin(self._spin_seq)

    def stop(self):
        self._spinning = False
        self._spin_seq += 1

    def _draw(self):
        self.delete('all')
        p = self.stroke_width
        s = self.size
        cx, cy = s / 2.0, s / 2.0
        r = (s - 2 * p) / 2.0
        if r > 0:
            CanvasUtils.create_antialiased_arc(self, cx, cy, r, 0, 360,
                                               stroke_width=self.stroke_width,
                                               color=self.track_color, bg_color=self.bg_color)
            CanvasUtils.create_antialiased_arc(self, cx, cy, r, self._angle, self.arc_length,
                                               stroke_width=self.stroke_width,
                                               color=self.arc_color, bg_color=self.bg_color)

    def _spin(self, seq):
        if not self._spinning or seq != self._spin_seq: return
        elapsed = time.perf_counter() - getattr(self, '_spin_start_time', time.perf_counter())
        # Smooth continuous sub-degree rotation
        self._angle = (elapsed * self.speed * 120.0) % 360.0
        self._draw()
        frame_delay = DeviceDisplay.get_frame_delay_ms()
        self.after(frame_delay, lambda: self._spin(seq))


# =============================================================================
# CHECKBOX
# =============================================================================

class OmegaCheckbox(tk.Canvas):
    """
    Animated checkbox with a mathematically drawn checkmark path.

    The checkmark animates in on check and fades out (box color resets) on uncheck.
    """

    def __init__(self, parent, variable=None, text='', command=None, size=18,
                 check_color=None, box_color=None, border_color=None,
                 text_color=None, bg_color=None, corner_radius=3, **kwargs):
        if bg_color     is None: bg_color     = Theme.BG
        if check_color  is None: check_color  = Theme.SUCCESS
        if box_color    is None: box_color    = Theme.PANEL
        if border_color is None: border_color = Theme.ACCENT
        if text_color   is None: text_color   = Theme.TEXT

        text_w = len(text) * 7 + 8 if text else 0
        super().__init__(parent, width=size + text_w, height=size,
                         bg=bg_color, highlightthickness=0, cursor='hand2', **kwargs)

        self.variable      = variable if variable is not None else tk.BooleanVar(value=False)
        self.command       = command
        self.size          = size
        self.check_color   = check_color
        self.box_color     = box_color
        self.border_color  = border_color
        self._check_lines  = []

        # Box background
        self._box = CanvasUtils.create_rounded_rect(
            self, 1, 1, size-1, size-1,
            radius=corner_radius, fill=box_color, outline=border_color, width=1)

        # Optional label
        if text:
            self.create_text(size + 6, size // 2, text=text, anchor='w',
                             fill=text_color, font=('Segoe UI', 9))

        self.bind('<Button-1>', self._toggle)
        self._draw_state(animated=False)

    def _toggle(self, event=None):
        self.variable.set(not self.variable.get())
        self._draw_state(animated=True)
        if self.command: self.command()

    def _draw_state(self, animated=True):
        checked = self.variable.get()

        # Box color transition
        target_box = self.check_color if checked else self.box_color
        TweenService.TweenColor(self, 'fill', target_box, 0.15, is_canvas_item=True, item_id=self._box)

        # Remove old checkmark lines
        for lid in self._check_lines:
            try: self.delete(lid)
            except: pass
        self._check_lines = []

        if not checked:
            return

        s = self.size
        # Checkmark: left leg (3, s*0.5) → (s*0.35, s*0.75)
        #            right leg (s*0.35, s*0.75) → (s*0.75, s*0.25)
        x1, y1 = 3,        s * 0.5
        xm, ym = s * 0.35, s * 0.75
        x2, y2 = s * 0.75, s * 0.25

        l1 = self.create_line(x1, y1, x1, y1, fill='white', width=2, capstyle=tk.ROUND)
        l2 = self.create_line(xm, ym, xm, ym, fill='white', width=2, capstyle=tk.ROUND)
        self._check_lines = [l1, l2]

        if animated:
            steps, step_ms = 12, 16

            def _anim(step=0):
                if step > steps: return
                t = step / steps
                if t <= 0.5:
                    lt = t * 2
                    self.coords(l1, x1, y1, x1+(xm-x1)*lt, y1+(ym-y1)*lt)
                else:
                    self.coords(l1, x1, y1, xm, ym)
                    lt = (t - 0.5) * 2
                    self.coords(l2, xm, ym, xm+(x2-xm)*lt, ym+(y2-ym)*lt)
                if step < steps:
                    self.after(step_ms, lambda: _anim(step + 1))

            _anim(0)
        else:
            self.coords(l1, x1, y1, xm, ym)
            self.coords(l2, xm, ym, x2, y2)