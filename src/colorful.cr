module Colorful
  # Constants for color comparisons
  DELTA = 1.0 / 255.0

  # Constants for Lab/Luv conversions
  private EPSILON = 0.008856
  private KAPPA   =    903.3

  # Helper math functions
  def self.sq(v : Float64) : Float64
    v * v
  end

  def self.cub(v : Float64) : Float64
    v * v * v
  end

  # Utility used by Hxx color-spaces for interpolating between two angles in [0,360].
  def self.interp_angle(a0 : Float64, a1 : Float64, t : Float64) : Float64
    # Based on the answer here: http://stackoverflow.com/a/14498790/2366315
    # With potential proof that it works here: http://math.stackexchange.com/a/2144499
    delta = ((a1 - a0) % 360.0 + 540.0) % 360.0 - 180.0
    (a0 + t * delta + 360.0) % 360.0
  end

  # Reference white points (D65 and D50)
  private D65 = [0.95047, 1.00000, 1.08883]
  private D50 = [0.96422, 1.00000, 0.82521]

  # Matrix for converting Linear RGB to XYZ (sRGB, D65)
  private LINEAR_RGB_TO_XYZ = [
    [0.41239079926595948, 0.35758433938387796, 0.18048078840183429],
    [0.21263900587151036, 0.71516867876775593, 0.072192315360733715],
    [0.019330818715591851, 0.11919477979462599, 0.95053215224966058],
  ]

  # Matrix for converting XYZ to Linear RGB (sRGB, D65)
  private XYZ_TO_LINEAR_RGB = [
    [3.2409699419045214, -1.5373831775700935, -0.49861076029300328],
    [-0.96924363628087983, 1.8759675015077207, 0.041555057407175613],
    [0.055630079696993609, -0.20397695888897657, 1.0569715142428786],
  ]

  # Derived constants for Luv conversions (using D65)
  private REF_X = D65[0]
  private REF_Y = D65[1]
  private REF_Z = D65[2]
  private REF_U = (4.0 * REF_X) / (REF_X + 15.0 * REF_Y + 3.0 * REF_Z)
  private REF_V = (9.0 * REF_Y) / (REF_X + 15.0 * REF_Y + 3.0 * REF_Z)

  # Helper functions for Luv conversions (following Go implementation)
  private SIX_OVER_TWENTY_NINE      = 6.0 / 29.0
  private CUBE_SIX_OVER_TWENTY_NINE = SIX_OVER_TWENTY_NINE ** 3

  def self.xyz_to_uv(x : Float64, y : Float64, z : Float64) : Tuple(Float64, Float64)
    denom = x + 15.0 * y + 3.0 * z
    if denom == 0.0
      {0.0, 0.0}
    else
      {4.0 * x / denom, 9.0 * y / denom}
    end
  end

  def self.xyz_to_luv_white_ref(x : Float64, y : Float64, z : Float64, wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
    yr = y / wref[1]
    l = if yr <= CUBE_SIX_OVER_TWENTY_NINE
          yr * KAPPA / 100.0
        else
          1.16 * Math.cbrt(yr) - 0.16
        end
    ubis, vbis = xyz_to_uv(x, y, z)
    un, vn = xyz_to_uv(wref[0], wref[1], wref[2])
    u = 13.0 * l * (ubis - un)
    v = 13.0 * l * (vbis - vn)
    {l, u, v}
  end

  def self.luv_to_xyz_white_ref(l : Float64, u : Float64, v : Float64, wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
    if l <= 0.08
      y = wref[1] * l * 100.0 * SIX_OVER_TWENTY_NINE ** 3
    else
      y = wref[1] * ((l + 0.16) / 1.16) ** 3
    end
    un, vn = xyz_to_uv(wref[0], wref[1], wref[2])
    if l != 0.0
      ubis = u / (13.0 * l) + un
      vbis = v / (13.0 * l) + vn
      x = y * 9.0 * ubis / (4.0 * vbis)
      z = y * (12.0 - 3.0 * ubis - 20.0 * vbis) / (4.0 * vbis)
    else
      x = 0.0
      z = 0.0
    end
    {x, y, z}
  end

  # Helper functions for xyY conversions
  def self.xyz_to_xyy_white_ref(x : Float64, y : Float64, z : Float64, wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
    yout = y
    n = x + y + z
    if n.abs < 1e-14
      # When we have black, use reference white's chromacity for x and y
      xout = wref[0] / (wref[0] + wref[1] + wref[2])
      yout_xy = wref[1] / (wref[0] + wref[1] + wref[2])
    else
      xout = x / n
      yout_xy = y / n
    end
    {xout, yout_xy, yout}
  end

  def self.xyz_to_xyy(x : Float64, y : Float64, z : Float64) : Tuple(Float64, Float64, Float64)
    xyz_to_xyy_white_ref(x, y, z, D65)
  end

  def self.xyy_to_xyz(x_xy : Float64, y_xy : Float64, yy : Float64) : Tuple(Float64, Float64, Float64)
    y_out = yy
    if -1e-14 < y_xy && y_xy < 1e-14
      x = 0.0
      z = 0.0
    else
      x = yy / y_xy * x_xy
      z = yy / y_xy * (1.0 - x_xy - y_xy)
    end
    {x, y_out, z}
  end

  # Helper functions for Lab conversions
  private def self.lab_f(t : Float64) : Float64
    if t > (6.0/29.0) ** 3
      Math.cbrt(t)
    else
      t / (3.0 * (6.0/29.0) ** 2) + 4.0/29.0
    end
  end

  private def self.lab_finv(t : Float64) : Float64
    if t > 6.0/29.0
      t ** 3
    else
      3.0 * (6.0/29.0) ** 2 * (t - 4.0/29.0)
    end
  end

  def self.xyz_to_lab_white_ref(x : Float64, y : Float64, z : Float64, wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
    fy = lab_f(y / wref[1])
    l = 1.16 * fy - 0.16
    a = 5.0 * (lab_f(x / wref[0]) - fy)
    b = 2.0 * (fy - lab_f(z / wref[2]))
    {l, a, b}
  end

  def self.lab_to_xyz_white_ref(l : Float64, a : Float64, b : Float64, wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
    l2 = (l + 0.16) / 1.16
    x = wref[0] * lab_finv(l2 + a / 5.0)
    y = wref[1] * lab_finv(l2)
    z = wref[2] * lab_finv(l2 - b / 2.0)
    {x, y, z}
  end

  # Helper functions for HCL conversions (polar Lab)
  def self.lab_to_hcl(l : Float64, a : Float64, b : Float64) : Tuple(Float64, Float64, Float64)
    h = 0.0
    if (b - a).abs > 1e-4 && a.abs > 1e-4
      h = Math.atan2(b, a) * 180.0 / Math::PI
      h += 360.0 if h < 0.0
    end
    c = Math.sqrt(a * a + b * b)
    {h, c, l}
  end

  def self.hcl_to_lab(h : Float64, c : Float64, l : Float64) : Tuple(Float64, Float64, Float64)
    h_rad = h * Math::PI / 180.0
    a = c * Math.cos(h_rad)
    b = c * Math.sin(h_rad)
    {l, a, b}
  end

  struct Color
    getter r : Float64
    getter g : Float64
    getter b : Float64

    def initialize(@r : Float64, @g : Float64, @b : Float64)
    end

    def self.hex(input : String) : Color
      s = input.strip
      s = s[1..] if s.starts_with?('#')
      case s.size
      when 3
        r = s[0, 1].to_i(16)
        g = s[1, 1].to_i(16)
        b = s[2, 1].to_i(16)
        # Expand short hex: #rgb -> #rrggbb
        Color.new((r * 17) / 255.0, (g * 17) / 255.0, (b * 17) / 255.0)
      when 6
        r = s[0, 2].to_i(16)
        g = s[2, 2].to_i(16)
        b = s[4, 2].to_i(16)
        Color.new(r / 255.0, g / 255.0, b / 255.0)
      else
        raise ArgumentError.new("invalid hex color")
      end
    end

    def hex : String
      "##{channel_hex(@r)}#{channel_hex(@g)}#{channel_hex(@b)}"
    end

    # Checks whether the color exists in RGB space, i.e. all values are in [0..1]
    def valid? : Bool
      0.0 <= @r && @r <= 1.0 && 0.0 <= @g && @g <= 1.0 && 0.0 <= @b && @b <= 1.0
    end

    # Clamps the color into valid range, clamping each value to [0..1]
    # If the color is valid already, this is a no-op.
    def clamped : Color
      Color.new(clamp01(@r), clamp01(@g), clamp01(@b))
    end

    # Returns the color as 8-bit RGB values
    def rgb255 : Tuple(UInt8, UInt8, UInt8)
      r = (Math.max(0.0, Math.min(1.0, @r)) * 255.0 + 0.5).to_i
      g = (Math.max(0.0, Math.min(1.0, @g)) * 255.0 + 0.5).to_i
      b = (Math.max(0.0, Math.min(1.0, @b)) * 255.0 + 0.5).to_i
      {r.to_u8, g.to_u8, b.to_u8}
    end

    # Implement RGBA color interface (alpha always fully opaque)
    def rgba : Tuple(UInt32, UInt32, UInt32, UInt32)
      r = (Math.max(0.0, Math.min(1.0, @r)) * 65535.0 + 0.5).to_i
      g = (Math.max(0.0, Math.min(1.0, @g)) * 65535.0 + 0.5).to_i
      b = (Math.max(0.0, Math.min(1.0, @b)) * 65535.0 + 0.5).to_i
      {r.to_u32, g.to_u32, b.to_u32, 0xFFFF_u32}
    end

    private def clamp01(v : Float64) : Float64
      Math.max(0.0, Math.min(v, 1.0))
    end

    def blend_luv(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      l1, u1, v1 = luv
      l2, u2, v2 = other.luv
      l = l1 + (l2 - l1) * t_clamped
      u = u1 + (u2 - u1) * t_clamped
      v = v1 + (v2 - v1) * t_clamped
      Color.luv(l, u, v)
    end

    def blend_rgb(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      Color.new(
        @r + t_clamped * (other.r - @r),
        @g + t_clamped * (other.g - @g),
        @b + t_clamped * (other.b - @b)
      )
    end

    def blend_linear_rgb(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      r1, g1, b1 = linear_rgb
      r2, g2, b2 = other.linear_rgb
      Color.linear_rgb(
        r1 + t_clamped * (r2 - r1),
        g1 + t_clamped * (g2 - g1),
        b1 + t_clamped * (b2 - b1)
      )
    end

    def blend_hsv(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      h1, s1, v1 = hsv
      h2, s2, v2 = other.hsv

      # Handle edge cases when one saturation is zero (Go implementation)
      if s1 == 0.0 && s2 != 0.0
        h1 = h2
      elsif s2 == 0.0 && s1 != 0.0
        h2 = h1
      end

      Color.hsv(
        Colorful.interp_angle(h1, h2, t_clamped),
        s1 + t_clamped * (s2 - s1),
        v1 + t_clamped * (v2 - v1)
      )
    end

    def blend_lab(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      l1, a1, b1 = lab
      l2, a2, b2 = other.lab
      Color.lab(
        l1 + t_clamped * (l2 - l1),
        a1 + t_clamped * (a2 - a1),
        b1 + t_clamped * (b2 - b1)
      )
    end

    def blend_hcl(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      h1, c1, l1 = hcl
      h2, c2, l2 = other.hcl

      # Handle edge cases when one chroma is near zero (Go implementation)
      if c1 <= 0.00015 && c2 >= 0.00015
        h1 = h2
      elsif c2 <= 0.00015 && c1 >= 0.00015
        h2 = h1
      end

      Color.hcl(
        Colorful.interp_angle(h1, h2, t_clamped),
        c1 + t_clamped * (c2 - c1),
        l1 + t_clamped * (l2 - l1)
      ).clamped
    end

    # Returns the color in CIE L*u*v* space using D65 as reference white.
    # L* is in [0..1] and both u* and v* are in about [-1..1]
    def luv : Tuple(Float64, Float64, Float64)
      x, y, z = to_xyz
      Colorful.xyz_to_luv_white_ref(x, y, z, D65)
    end

    # Generates a color by using data given in CIE L*u*v* space using D65 as reference white.
    # L* is in [0..1] and both u* and v* are in about [-1..1]
    def self.luv(l : Float64, u : Float64, v : Float64) : Color
      x, y, z = Colorful.luv_to_xyz_white_ref(l, u, v, D65)
      from_xyz(x, y, z)
    end

    # Returns the color in CIE L*u*v* space, taking into account a given reference white.
    def luv_white_ref(wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
      x, y, z = to_xyz
      Colorful.xyz_to_luv_white_ref(x, y, z, wref)
    end

    # Generates a color by using data given in CIE L*u*v* space, taking into account a given reference white.
    def self.luv_white_ref(l : Float64, u : Float64, v : Float64, wref : Array(Float64)) : Color
      x, y, z = Colorful.luv_to_xyz_white_ref(l, u, v, wref)
      from_xyz(x, y, z)
    end

    # Returns the color in CIE L*a*b* space using D65 as reference white.
    # L* is in [0..1], a* and b* are in about [-1..1]
    def lab : Tuple(Float64, Float64, Float64)
      x, y, z = to_xyz
      Colorful.xyz_to_lab_white_ref(x, y, z, D65)
    end

    # Generates a color by using data given in CIE L*a*b* space using D65 as reference white.
    # L* is in [0..1], a* and b* are in about [-1..1]
    def self.lab(l : Float64, a : Float64, b : Float64) : Color
      x, y, z = Colorful.lab_to_xyz_white_ref(l, a, b, D65)
      from_xyz(x, y, z)
    end

    # Returns the color in CIE L*a*b* space, taking into account a given reference white.
    def lab_white_ref(wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
      x, y, z = to_xyz
      Colorful.xyz_to_lab_white_ref(x, y, z, wref)
    end

    # Generates a color by using data given in CIE L*a*b* space, taking into account a given reference white.
    def self.lab_white_ref(l : Float64, a : Float64, b : Float64, wref : Array(Float64)) : Color
      x, y, z = Colorful.lab_to_xyz_white_ref(l, a, b, wref)
      from_xyz(x, y, z)
    end

    # Returns the color in HCL space (polar Lab) using D65 as reference white.
    # H in [0..360], C in [0..1], L in [0..1]
    def hcl : Tuple(Float64, Float64, Float64)
      l, a, b = lab
      Colorful.lab_to_hcl(l, a, b)
    end

    # Generates a color by using data given in HCL space using D65 as reference white.
    # H in [0..360], C in [0..1], L in [0..1]
    def self.hcl(h : Float64, c : Float64, l : Float64) : Color
      l, a, b = Colorful.hcl_to_lab(h, c, l)
      lab(l, a, b)
    end

    # Returns the color in HCL space, taking into account a given reference white.
    def hcl_white_ref(wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
      l, a, b = lab_white_ref(wref)
      Colorful.lab_to_hcl(l, a, b)
    end

    # Generates a color by using data given in HCL space, taking into account a given reference white.
    def self.hcl_white_ref(h : Float64, c : Float64, l : Float64, wref : Array(Float64)) : Color
      l, a, b = Colorful.hcl_to_lab(h, c, l)
      lab_white_ref(l, a, b, wref)
    end

    # Returns the color in HSV space.
    # Hue in [0..360], Saturation and Value in [0..1]
    def hsv : Tuple(Float64, Float64, Float64)
      min = Math.min(Math.min(@r, @g), @b)
      v = Math.max(Math.max(@r, @g), @b)
      c = v - min

      s = 0.0
      s = c / v if v != 0.0

      h = 0.0
      if min != v
        if v == @r
          h = ((@g - @b) / c) % 6.0
        end
        if v == @g
          h = (@b - @r) / c + 2.0
        end
        if v == @b
          h = (@r - @g) / c + 4.0
        end
        h *= 60.0
        if h < 0.0
          h += 360.0
        end
      end
      {h, s, v}
    end

    # Creates a new Color given a Hue in [0..359], a Saturation and a Value in [0..1]
    def self.hsv(h : Float64, s : Float64, v : Float64) : Color
      hp = h / 60.0
      c = v * s
      x = c * (1.0 - (hp % 2.0 - 1.0).abs)
      m = v - c

      r = g = b = 0.0
      case hp
      when 0.0...1.0
        r = c
        g = x
      when 1.0...2.0
        r = x
        g = c
      when 2.0...3.0
        g = c
        b = x
      when 3.0...4.0
        g = x
        b = c
      when 4.0...5.0
        r = x
        b = c
      when 5.0...6.0
        r = c
        b = x
      end

      Color.new(m + r, m + g, m + b)
    end

    # Returns the color in HSL space.
    # Hue in [0..360], Saturation and Luminance in [0..1]
    def hsl : Tuple(Float64, Float64, Float64)
      min = Math.min(Math.min(@r, @g), @b)
      max = Math.max(Math.max(@r, @g), @b)

      l = (max + min) / 2.0

      if min == max
        s = 0.0
        h = 0.0
      else
        if l < 0.5
          s = (max - min) / (max + min)
        else
          s = (max - min) / (2.0 - max - min)
        end

        if max == @r
          h = (@g - @b) / (max - min)
        elsif max == @g
          h = 2.0 + (@b - @r) / (max - min)
        else
          h = 4.0 + (@r - @g) / (max - min)
        end

        h *= 60.0
        if h < 0.0
          h += 360.0
        end
      end
      {h, s, l}
    end

    # Creates a new Color given a Hue in [0..359], a Saturation and a Luminance in [0..1]
    def self.hsl(h : Float64, s : Float64, l : Float64) : Color
      if s == 0.0
        return Color.new(l, l, l)
      end

      var1 = if l < 0.5
               l * (1.0 + s)
             else
               (l + s) - (s * l)
             end
      var2 = 2.0 * l - var1

      hue_to_rgb = ->(v : Float64) do
        v = v % 1.0
        if 6.0 * v < 1.0
          var2 + (var1 - var2) * 6.0 * v
        elsif 2.0 * v < 1.0
          var1
        elsif 3.0 * v < 2.0
          var2 + (var1 - var2) * (0.666 - v) * 6.0
        else
          var2
        end
      end

      h_norm = h / 360.0
      r = hue_to_rgb.call(h_norm + 0.333)
      g = hue_to_rgb.call(h_norm)
      b = hue_to_rgb.call(h_norm - 0.333)

      Color.new(r, g, b)
    end

    # Returns the color in CIE XYZ space (D65)
    def xyz : Tuple(Float64, Float64, Float64)
      to_xyz
    end

    # Creates a new Color given CIE XYZ coordinates (D65)
    def self.xyz(x : Float64, y : Float64, z : Float64) : Color
      from_xyz(x, y, z)
    end

    # Returns the color in CIE xyY space (D65)
    def xyy : Tuple(Float64, Float64, Float64)
      x, y, z = to_xyz
      Colorful.xyz_to_xyy(x, y, z)
    end

    # Returns the color in CIE xyY space with given white reference
    def xyy_white_ref(wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
      x, y, z = to_xyz
      Colorful.xyz_to_xyy_white_ref(x, y, z, wref)
    end

    # Creates a new Color given CIE xyY coordinates (D65)
    def self.xyy(x : Float64, y : Float64, yy : Float64) : Color
      x_xyz, y_xyz, z_xyz = Colorful.xyy_to_xyz(x, y, yy)
      from_xyz(x_xyz, y_xyz, z_xyz)
    end

    # Returns the color in linear RGB space
    def linear_rgb : Tuple(Float64, Float64, Float64)
      {srgb_to_linear(@r), srgb_to_linear(@g), srgb_to_linear(@b)}
    end

    # Creates a new Color given linear RGB coordinates
    def self.linear_rgb(r : Float64, g : Float64, b : Float64) : Color
      Color.new(linear_to_srgb(r), linear_to_srgb(g), linear_to_srgb(b))
    end

    # Returns the color in linear RGB space using fast approximation
    def fast_linear_rgb : Tuple(Float64, Float64, Float64)
      {srgb_to_linear_fast(@r), srgb_to_linear_fast(@g), srgb_to_linear_fast(@b)}
    end

    # Creates a new Color given linear RGB coordinates using fast approximation
    def self.fast_linear_rgb(r : Float64, g : Float64, b : Float64) : Color
      Color.new(linear_to_srgb_fast(r), linear_to_srgb_fast(g), linear_to_srgb_fast(b))
    end

    # Distance calculations
    def distance_rgb(other : Color) : Float64
      Math.sqrt(Colorful.sq(@r - other.r) + Colorful.sq(@g - other.g) + Colorful.sq(@b - other.b))
    end

    def distance_linear_rgb(other : Color) : Float64
      r1, g1, b1 = linear_rgb
      r2, g2, b2 = other.linear_rgb
      Math.sqrt(Colorful.sq(r1 - r2) + Colorful.sq(g1 - g2) + Colorful.sq(b1 - b2))
    end

    def distance_riemersma(other : Color) : Float64
      r_avg = (@r + other.r) / 2.0
      d_r = @r - other.r
      d_g = @g - other.g
      d_b = @b - other.b
      Math.sqrt((2 + r_avg) * Colorful.sq(d_r) + 4 * Colorful.sq(d_g) + (2 + (1 - r_avg)) * Colorful.sq(d_b))
    end

    def almost_equal_rgb(other : Color) : Bool
      (Math.abs(@r - other.r) + Math.abs(@g - other.g) + Math.abs(@b - other.b)) < 3.0 * Colorful::DELTA
    end

    def distance_lab(other : Color) : Float64
      l1, a1, b1 = lab
      l2, a2, b2 = other.lab
      Math.sqrt(Colorful.sq(l1 - l2) + Colorful.sq(a1 - a2) + Colorful.sq(b1 - b2))
    end

    def distance_luv(other : Color) : Float64
      l1, u1, v1 = luv
      l2, u2, v2 = other.luv
      Math.sqrt(Colorful.sq(l1 - l2) + Colorful.sq(u1 - u2) + Colorful.sq(v1 - v2))
    end

    def distance_cie94(other : Color) : Float64
      l1, a1, b1 = lab
      l2, a2, b2 = other.lab

      # Scale up to match formula expectations (Lab values are normally 0-100)
      l1, a1, b1 = l1 * 100.0, a1 * 100.0, b1 * 100.0
      l2, a2, b2 = l2 * 100.0, a2 * 100.0, b2 * 100.0

      kl = 1.0 # 2.0 for textiles
      kc = 1.0
      kh = 1.0
      k1 = 0.045 # 0.048 for textiles
      k2 = 0.015 # 0.014 for textiles

      delta_l = l1 - l2
      c1 = Math.sqrt(Colorful.sq(a1) + Colorful.sq(b1))
      c2 = Math.sqrt(Colorful.sq(a2) + Colorful.sq(b2))
      delta_cab = c1 - c2

      # Not taking Sqrt here for stability, and it's unnecessary.
      delta_hab2 = Colorful.sq(a1 - a2) + Colorful.sq(b1 - b2) - Colorful.sq(delta_cab)

      sl = 1.0
      sc = 1.0 + k1 * c1
      sh = 1.0 + k2 * c1

      v_l2 = Colorful.sq(delta_l / (kl * sl))
      v_c2 = Colorful.sq(delta_cab / (kc * sc))
      v_h2 = delta_hab2 / Colorful.sq(kh * sh)

      Math.sqrt(v_l2 + v_c2 + v_h2) * 0.01
    end

    def distance_ciede2000(other : Color) : Float64
      distance_ciede2000_klch(other, 1.0, 1.0, 1.0)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def distance_ciede2000_klch(other : Color, kl : Float64, kc : Float64, kh : Float64) : Float64
      l1, a1, b1 = lab
      l2, a2, b2 = other.lab

      # Scale up to match formula expectations (Lab values are normally 0-100)
      l1, a1, b1 = l1 * 100.0, a1 * 100.0, b1 * 100.0
      l2, a2, b2 = l2 * 100.0, a2 * 100.0, b2 * 100.0

      cab1 = Math.sqrt(Colorful.sq(a1) + Colorful.sq(b1))
      cab2 = Math.sqrt(Colorful.sq(a2) + Colorful.sq(b2))
      cabmean = (cab1 + cab2) / 2.0

      g = 0.5 * (1.0 - Math.sqrt((cabmean ** 7) / ((cabmean ** 7) + (25.0 ** 7))))
      ap1 = (1.0 + g) * a1
      ap2 = (1.0 + g) * a2
      cp1 = Math.sqrt(Colorful.sq(ap1) + Colorful.sq(b1))
      cp2 = Math.sqrt(Colorful.sq(ap2) + Colorful.sq(b2))

      hp1 = 0.0
      if b1 != ap1 || ap1 != 0.0
        hp1 = Math.atan2(b1, ap1)
        hp1 += 2.0 * Math::PI if hp1 < 0.0
        hp1 *= 180.0 / Math::PI
      end

      hp2 = 0.0
      if b2 != ap2 || ap2 != 0.0
        hp2 = Math.atan2(b2, ap2)
        hp2 += 2.0 * Math::PI if hp2 < 0.0
        hp2 *= 180.0 / Math::PI
      end

      delta_lp = l2 - l1
      delta_cp = cp2 - cp1
      dhp = 0.0
      cp_product = cp1 * cp2
      if cp_product != 0.0
        dhp = hp2 - hp1
        if dhp > 180.0
          dhp -= 360.0
        elsif dhp < -180.0
          dhp += 360.0
        end
      end
      delta_hp = 2.0 * Math.sqrt(cp_product) * Math.sin(dhp / 2.0 * Math::PI / 180.0)

      lpmean = (l1 + l2) / 2.0
      cpmean = (cp1 + cp2) / 2.0
      hpmean = hp1 + hp2
      if cp_product != 0.0
        hpmean /= 2.0
        if (hp1 - hp2).abs > 180.0
          if hp1 + hp2 < 360.0
            hpmean += 180.0
          else
            hpmean -= 180.0
          end
        end
      end

      t = 1.0 - 0.17 * Math.cos((hpmean - 30.0) * Math::PI / 180.0) +
          0.24 * Math.cos(2.0 * hpmean * Math::PI / 180.0) +
          0.32 * Math.cos((3.0 * hpmean + 6.0) * Math::PI / 180.0) -
          0.2 * Math.cos((4.0 * hpmean - 63.0) * Math::PI / 180.0)

      delta_theta = 30.0 * Math.exp(-Colorful.sq((hpmean - 275.0) / 25.0))
      rc = 2.0 * Math.sqrt((cpmean ** 7) / ((cpmean ** 7) + (25.0 ** 7)))
      sl = 1.0 + (0.015 * Colorful.sq(lpmean - 50.0)) / Math.sqrt(20.0 + Colorful.sq(lpmean - 50.0))
      sc = 1.0 + 0.045 * cpmean
      sh = 1.0 + 0.015 * cpmean * t
      rt = -Math.sin(2.0 * delta_theta * Math::PI / 180.0) * rc

      Math.sqrt(
        Colorful.sq(delta_lp / (kl * sl)) +
        Colorful.sq(delta_cp / (kc * sc)) +
        Colorful.sq(delta_hp / (kh * sh)) +
        rt * (delta_cp / (kc * sc)) * (delta_hp / (kh * sh))
      ) * 0.01
    end

    # Convert sRGB to XYZ using exact D65 sRGB matrix
    private def to_xyz : Tuple(Float64, Float64, Float64)
      r, g, b = linear_rgb
      x = LINEAR_RGB_TO_XYZ[0][0]*r + LINEAR_RGB_TO_XYZ[0][1]*g + LINEAR_RGB_TO_XYZ[0][2]*b
      y = LINEAR_RGB_TO_XYZ[1][0]*r + LINEAR_RGB_TO_XYZ[1][1]*g + LINEAR_RGB_TO_XYZ[1][2]*b
      z = LINEAR_RGB_TO_XYZ[2][0]*r + LINEAR_RGB_TO_XYZ[2][1]*g + LINEAR_RGB_TO_XYZ[2][2]*b
      {x, y, z}
    end

    # Convert XYZ to sRGB using exact D65 sRGB matrix
    private def self.from_xyz(x : Float64, y : Float64, z : Float64) : Color
      r = XYZ_TO_LINEAR_RGB[0][0]*x + XYZ_TO_LINEAR_RGB[0][1]*y + XYZ_TO_LINEAR_RGB[0][2]*z
      g = XYZ_TO_LINEAR_RGB[1][0]*x + XYZ_TO_LINEAR_RGB[1][1]*y + XYZ_TO_LINEAR_RGB[1][2]*z
      b = XYZ_TO_LINEAR_RGB[2][0]*x + XYZ_TO_LINEAR_RGB[2][1]*y + XYZ_TO_LINEAR_RGB[2][2]*z
      Color.new(linear_to_srgb(r), linear_to_srgb(g), linear_to_srgb(b))
    end

    private def srgb_to_linear(c : Float64) : Float64
      c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
    end

    private def self.linear_to_srgb(c : Float64) : Float64
      c <= 0.0031308 ? c * 12.92 : 1.055 * (c ** (1.0 / 2.4)) - 0.055
    end

    private def srgb_to_linear_fast(c : Float64) : Float64
      v1 = c - 0.5
      v2 = v1 * v1
      v3 = v2 * v1
      v4 = v2 * v2
      -0.248750514614486 + 0.925583310193438*c + 1.16740237321695*v2 + 0.280457026598666*v3 - 0.0757991963780179*v4
    end

    private def self.linear_to_srgb_fast(c : Float64) : Float64
      if c > 0.2
        v1 = c - 0.6
        v2 = v1 * v1
        v3 = v2 * v1
        v4 = v2 * v2
        v5 = v3 * v2
        0.442430344268235 + 0.592178981271708*c - 0.287864782562636*v2 + 0.253214392068985*v3 - 0.272557158129811*v4 + 0.325554383321718*v5
      elsif c > 0.03
        v1 = c - 0.115
        v2 = v1 * v1
        v3 = v2 * v1
        v4 = v2 * v2
        v5 = v3 * v2
        0.194915592891669 + 1.55227076330229*c - 3.93691860257828*v2 + 18.0679839248761*v3 - 101.468750302746*v4 + 632.341487393927*v5
      else
        v1 = c - 0.015
        v2 = v1 * v1
        v3 = v2 * v1
        v4 = v2 * v2
        v5 = v3 * v2
        0.0519565234928877 + 5.09316778537561*c - 99.0338180489702*v2 + 3484.52322764895*v3 - 150028.083412663*v4 + 7168008.42971613*v5
      end
    end

    private def channel_hex(channel : Float64) : String
      value = (channel.clamp(0.0, 1.0) * 255.0).round.to_i
      value.to_s(16).rjust(2, '0')
    end
  end

  def self.hex(input : String) : Color
    Color.hex(input)
  end

  def self.make_color(input : Color) : Color
    input
  end
end
