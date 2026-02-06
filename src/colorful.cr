# JSON and YAML support for HexColor serialization
require "json"
require "yaml"

module Colorful
  # Constants for color comparisons
  DELTA = 1.0 / 255.0

  # Constants for Lab/Luv conversions
  private EPSILON = 0.0088564516790356308
  private KAPPA   =     903.2962962962963
  # Constants for HSLuv conversions
  private HSLUV_KAPPA   =     903.2962962962963
  private HSLUV_EPSILON = 0.0088564516790356308
  private HSLUV_M       = [
    [3.2409699419045214, -1.5373831775700935, -0.49861076029300328],
    [-0.96924363628087983, 1.8759675015077207, 0.041555057407175613],
    [0.055630079696993609, -0.20397695888897657, 1.0569715142428786],
  ]

  # Helper math functions
  def self.sq(v : Float64) : Float64
    v * v
  end

  def self.cub(v : Float64) : Float64
    v * v * v
  end

  def self.clamp01(v : Float64) : Float64
    v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v)
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
  # HSLuv uses a rounded version of D65 for internal accuracy
  private HSLUV_D65 = [0.95045592705167, 1.0, 1.089057750759878]

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
  private SIX_OVER_TWENTY_NINE        = 6.0 / 29.0
  private CUBE_SIX_OVER_TWENTY_NINE   = SIX_OVER_TWENTY_NINE ** 3
  private THREE_OVER_TWENTY_NINE      = 3.0 / 29.0
  private CUBE_THREE_OVER_TWENTY_NINE = THREE_OVER_TWENTY_NINE ** 3

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
    l = if yr <= EPSILON
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
      y = wref[1] * l * 100.0 * CUBE_THREE_OVER_TWENTY_NINE
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

  # Helper functions for RGB/XYZ conversions
  def self.xyz_to_linear_rgb(x : Float64, y : Float64, z : Float64) : Tuple(Float64, Float64, Float64)
    r = XYZ_TO_LINEAR_RGB[0][0]*x + XYZ_TO_LINEAR_RGB[0][1]*y + XYZ_TO_LINEAR_RGB[0][2]*z
    g = XYZ_TO_LINEAR_RGB[1][0]*x + XYZ_TO_LINEAR_RGB[1][1]*y + XYZ_TO_LINEAR_RGB[1][2]*z
    b = XYZ_TO_LINEAR_RGB[2][0]*x + XYZ_TO_LINEAR_RGB[2][1]*y + XYZ_TO_LINEAR_RGB[2][2]*z
    {r, g, b}
  end

  def self.linear_rgb_to_xyz(r : Float64, g : Float64, b : Float64) : Tuple(Float64, Float64, Float64)
    x = LINEAR_RGB_TO_XYZ[0][0]*r + LINEAR_RGB_TO_XYZ[0][1]*g + LINEAR_RGB_TO_XYZ[0][2]*b
    y = LINEAR_RGB_TO_XYZ[1][0]*r + LINEAR_RGB_TO_XYZ[1][1]*g + LINEAR_RGB_TO_XYZ[1][2]*b
    z = LINEAR_RGB_TO_XYZ[2][0]*r + LINEAR_RGB_TO_XYZ[2][1]*g + LINEAR_RGB_TO_XYZ[2][2]*b
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

  # Helper functions for LuvLCh conversions (polar Luv)
  def self.luv_to_luv_lch(l : Float64, u : Float64, v : Float64) : Tuple(Float64, Float64, Float64)
    # Oops, floating point workaround necessary if u ~= v and both are very small (i.e. almost zero).
    h = 0.0
    if (v - u).abs > 1e-4 && u.abs > 1e-4
      h = Math.atan2(v, u) * 180.0 / Math::PI
      h += 360.0 if h < 0.0
    end
    c = Math.sqrt(u * u + v * v)
    {l, c, h}
  end

  def self.luv_lch_to_luv(l : Float64, c : Float64, h : Float64) : Tuple(Float64, Float64, Float64)
    h_rad = h * Math::PI / 180.0
    u = c * Math.cos(h_rad)
    v = c * Math.sin(h_rad)
    {l, u, v}
  end

  # Helper functions for HSLuv/HPLuv conversions
  def self.luv_lch_to_hsluv(l : Float64, c : Float64, h : Float64) : Tuple(Float64, Float64, Float64)
    # [-1..1] but the code expects it to be [-100..100]
    c *= 100.0
    l *= 100.0

    s = 0.0
    max = 0.0
    if l > 99.9999999 || l < 0.00000001
      s = 0.0
    else
      max = max_chroma_for_lh(l, h)
      s = c / max * 100.0
    end
    {h, clamp01(s / 100.0), clamp01(l / 100.0)}
  end

  def self.hsluv_to_luv_lch(h : Float64, s : Float64, l : Float64) : Tuple(Float64, Float64, Float64)
    l *= 100.0
    s *= 100.0

    c = 0.0
    max = 0.0
    if l > 99.9999999 || l < 0.00000001
      c = 0.0
    else
      max = max_chroma_for_lh(l, h)
      c = max / 100.0 * s
    end

    # c is [-100..100], but for LCh it's supposed to be almost [-1..1]
    {clamp01(l / 100.0), c / 100.0, h}
  end

  def self.luv_lch_to_hpluv(l : Float64, c : Float64, h : Float64) : Tuple(Float64, Float64, Float64)
    # [-1..1] but the code expects it to be [-100..100]
    c *= 100.0
    l *= 100.0

    s = 0.0
    max = 0.0
    if l > 99.9999999 || l < 0.00000001
      s = 0.0
    else
      max = max_safe_chroma_for_l(l)
      s = c / max * 100.0
    end
    {h, s / 100.0, l / 100.0}
  end

  def self.hpluv_to_luv_lch(h : Float64, s : Float64, l : Float64) : Tuple(Float64, Float64, Float64)
    # [-1..1] but the code expects it to be [-100..100]
    l *= 100.0
    s *= 100.0

    c = 0.0
    max = 0.0
    if l > 99.9999999 || l < 0.00000001
      c = 0.0
    else
      max = max_safe_chroma_for_l(l)
      c = max / 100.0 * s
    end
    {l / 100.0, c / 100.0, h}
  end

  # Helper functions for OkLab conversions
  def self.xyz_to_oklab(x : Float64, y : Float64, z : Float64) : Tuple(Float64, Float64, Float64)
    l_ = Math.cbrt(0.8189330101*x + 0.3618667424*y - 0.1288597137*z)
    m_ = Math.cbrt(0.0329845436*x + 0.9293118715*y + 0.0361456387*z)
    s_ = Math.cbrt(0.0482003018*x + 0.2643662691*y + 0.6338517070*z)
    l = 0.2104542553*l_ + 0.7936177850*m_ - 0.0040720468*s_
    a = 1.9779984951*l_ - 2.4285922050*m_ + 0.4505937099*s_
    b = 0.0259040371*l_ + 0.7827717662*m_ - 0.8086757660*s_
    {l, a, b}
  end

  def self.oklab_to_xyz(l : Float64, a : Float64, b : Float64) : Tuple(Float64, Float64, Float64)
    l_ = 0.9999999984505196*l + 0.39633779217376774*a + 0.2158037580607588*b
    m_ = 1.0000000088817607*l - 0.10556134232365633*a - 0.0638541747717059*b
    s_ = 1.0000000546724108*l - 0.08948418209496574*a - 1.2914855378640917*b

    ll = l_ ** 3
    mm = m_ ** 3
    ss = s_ ** 3

    x = 1.2268798733741557*ll - 0.5578149965554813*mm + 0.28139105017721594*ss
    y = -0.04057576262431372*ll + 1.1122868293970594*mm - 0.07171106666151696*ss
    z = -0.07637294974672142*ll - 0.4214933239627916*mm + 1.5869240244272422*ss
    {x, y, z}
  end

  def self.oklab_to_oklch(l : Float64, a : Float64, b : Float64) : Tuple(Float64, Float64, Float64)
    c = Math.sqrt((a * a) + (b * b))
    h = Math.atan2(b, a)
    if h < 0
      h += 2 * Math::PI
    end
    {l, c, h * 180 / Math::PI}
  end

  def self.oklch_to_oklab(l : Float64, c : Float64, h : Float64) : Tuple(Float64, Float64, Float64)
    h_rad = h * Math::PI / 180
    a = c * Math.cos(h_rad)
    b = c * Math.sin(h_rad)
    {l, a, b}
  end

  private def self.max_chroma_for_lh(l : Float64, h : Float64) : Float64
    h_rad = h / 360.0 * Math::PI * 2.0
    min_length = Float64::MAX
    get_bounds(l).each do |line|
      length = length_of_ray_until_intersect(h_rad, line[0], line[1])
      if length > 0.0 && length < min_length
        min_length = length
      end
    end
    min_length
  end

  private def self.get_bounds(l : Float64) : Array(Array(Float64))
    sub2 = 0.0
    ret = Array.new(6) { [0.0, 0.0] }
    sub1 = ((l + 16.0) ** 3) / 1560896.0
    if sub1 > HSLUV_EPSILON
      sub2 = sub1
    else
      sub2 = l / HSLUV_KAPPA
    end
    (0...3).each do |i|
      (0...2).each do |k|
        top1 = (284517.0 * HSLUV_M[i][0] - 94839.0 * HSLUV_M[i][2]) * sub2
        top2 = (838422.0 * HSLUV_M[i][2] + 769860.0 * HSLUV_M[i][1] + 731718.0 * HSLUV_M[i][0]) * l * sub2 - 769860.0 * k.to_f * l
        bottom = (632260.0 * HSLUV_M[i][2] - 126452.0 * HSLUV_M[i][1]) * sub2 + 126452.0 * k.to_f
        ret[i * 2 + k][0] = top1 / bottom
        ret[i * 2 + k][1] = top2 / bottom
      end
    end
    ret
  end

  private def self.length_of_ray_until_intersect(theta : Float64, x : Float64, y : Float64) : Float64
    y / (Math.sin(theta) - x * Math.cos(theta))
  end

  private def self.max_safe_chroma_for_l(l : Float64) : Float64
    min_length = Float64::MAX
    get_bounds(l).each do |line|
      m1 = line[0]
      b1 = line[1]
      x = intersect_line_line(m1, b1, -1.0 / m1, 0.0)
      dist = distance_from_pole(x, b1 + x * m1)
      if dist < min_length
        min_length = dist
      end
    end
    min_length
  end

  private def self.intersect_line_line(x1 : Float64, y1 : Float64, x2 : Float64, y2 : Float64) : Float64
    (y1 - y2) / (x2 - x1)
  end

  private def self.distance_from_pole(x : Float64, y : Float64) : Float64
    Math.sqrt(x * x + y * y)
  end

  # ColorConvertible interface for types that can be converted to Color
  module ColorConvertible
    abstract def rgba : Tuple(UInt32, UInt32, UInt32, UInt32)
  end

  # Simple color types matching Go's standard library color types
  struct RGBA
    include ColorConvertible
    property r, g, b, a : UInt8

    def initialize(@r : UInt8, @g : UInt8, @b : UInt8, @a : UInt8)
    end

    def rgba : Tuple(UInt32, UInt32, UInt32, UInt32)
      # RGBA stores non-alpha-premultiplied values, color.Color.RGBA() returns premultiplied
      if a == 0
        return {0_u32, 0_u32, 0_u32, 0_u32}
      end
      r32 = (r.to_u32 * 0xFFFF) // 0xFF
      g32 = (g.to_u32 * 0xFFFF) // 0xFF
      b32 = (b.to_u32 * 0xFFFF) // 0xFF
      a32 = (a.to_u32 * 0xFFFF) // 0xFF
      {r32 * a32 // 0xFFFF, g32 * a32 // 0xFFFF, b32 * a32 // 0xFFFF, a32}
    end
  end

  struct NRGBA
    include ColorConvertible
    property r, g, b, a : UInt8

    def initialize(@r : UInt8, @g : UInt8, @b : UInt8, @a : UInt8)
    end

    def rgba : Tuple(UInt32, UInt32, UInt32, UInt32)
      # NRGBA stores non-alpha-premultiplied values, color.Color.RGBA() returns premultiplied
      if a == 0
        return {0_u32, 0_u32, 0_u32, 0_u32}
      end
      r32 = (r.to_u32 * 0xFFFF) // 0xFF
      g32 = (g.to_u32 * 0xFFFF) // 0xFF
      b32 = (b.to_u32 * 0xFFFF) // 0xFF
      a32 = (a.to_u32 * 0xFFFF) // 0xFF
      {r32 * a32 // 0xFFFF, g32 * a32 // 0xFFFF, b32 * a32 // 0xFFFF, a32}
    end
  end

  struct RGBA64
    include ColorConvertible
    property r, g, b, a : UInt16

    def initialize(@r : UInt16, @g : UInt16, @b : UInt16, @a : UInt16)
    end

    def rgba : Tuple(UInt32, UInt32, UInt32, UInt32)
      # RGBA64 stores non-alpha-premultiplied 16-bit values
      if a == 0
        return {0_u32, 0_u32, 0_u32, 0_u32}
      end
      r32 = (r.to_u32 * 0xFFFF) // 0xFFFF
      g32 = (g.to_u32 * 0xFFFF) // 0xFFFF
      b32 = (b.to_u32 * 0xFFFF) // 0xFFFF
      a32 = (a.to_u32 * 0xFFFF) // 0xFFFF
      {r32 * a32 // 0xFFFF, g32 * a32 // 0xFFFF, b32 * a32 // 0xFFFF, a32}
    end
  end

  struct NRGBA64
    include ColorConvertible
    property r, g, b, a : UInt16

    def initialize(@r : UInt16, @g : UInt16, @b : UInt16, @a : UInt16)
    end

    def rgba : Tuple(UInt32, UInt32, UInt32, UInt32)
      # NRGBA64 stores non-alpha-premultiplied 16-bit values
      if a == 0
        return {0_u32, 0_u32, 0_u32, 0_u32}
      end
      r32 = (r.to_u32 * 0xFFFF) // 0xFFFF
      g32 = (g.to_u32 * 0xFFFF) // 0xFFFF
      b32 = (b.to_u32 * 0xFFFF) // 0xFFFF
      a32 = (a.to_u32 * 0xFFFF) // 0xFFFF
      {r32 * a32 // 0xFFFF, g32 * a32 // 0xFFFF, b32 * a32 // 0xFFFF, a32}
    end
  end

  struct Gray
    include ColorConvertible
    property y : UInt8

    def initialize(@y : UInt8)
    end

    def rgba : Tuple(UInt32, UInt32, UInt32, UInt32)
      # Gray stores luminance, color.Color.RGBA() returns premultiplied gray
      if y == 0
        return {0_u32, 0_u32, 0_u32, 0_u32}
      end
      y32 = (y.to_u32 * 0xFFFF) // 0xFF
      {y32, y32, y32, 0xFFFF_u32}
    end
  end

  struct Gray16
    include ColorConvertible
    property y : UInt16

    def initialize(@y : UInt16)
    end

    def rgba : Tuple(UInt32, UInt32, UInt32, UInt32)
      # Gray16 stores 16-bit luminance
      if y == 0
        return {0_u32, 0_u32, 0_u32, 0_u32}
      end
      y32 = (y.to_u32 * 0xFFFF) // 0xFFFF
      {y32, y32, y32, 0xFFFF_u32}
    end
  end

  struct Color
    include ColorConvertible
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

    # Returns the color in LuvLCh space (polar Luv) using D65 as reference white.
    # H in [0..360], C in [0..1], L in [0..1]
    def luv_lch : Tuple(Float64, Float64, Float64)
      l, u, v = luv
      Colorful.luv_to_luv_lch(l, u, v)
    end

    # Generates a color by using data given in LuvLCh space using D65 as reference white.
    # H in [0..360], C in [0..1], L in [0..1]
    def self.luv_lch(l : Float64, c : Float64, h : Float64) : Color
      l, u, v = Colorful.luv_lch_to_luv(l, c, h)
      luv(l, u, v)
    end

    # Returns the color in LuvLCh space, taking into account a given reference white.
    def luv_lch_white_ref(wref : Array(Float64)) : Tuple(Float64, Float64, Float64)
      l, u, v = luv_white_ref(wref)
      Colorful.luv_to_luv_lch(l, u, v)
    end

    # Generates a color by using data given in LuvLCh space, taking into account a given reference white.
    def self.luv_lch_white_ref(l : Float64, c : Float64, h : Float64, wref : Array(Float64)) : Color
      l, u, v = Colorful.luv_lch_to_luv(l, c, h)
      luv_white_ref(l, u, v, wref)
    end

    # BlendLuvLCh blends two colors in the cylindrical CIELUV color space.
    # t == 0 results in c1, t == 1 results in c2
    def blend_luv_lch(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      l1, c1, h1 = luv_lch
      l2, c2, h2 = other.luv_lch
      Color.luv_lch(
        l1 + t_clamped * (l2 - l1),
        c1 + t_clamped * (c2 - c1),
        Colorful.interp_angle(h1, h2, t_clamped)
      ).clamped
    end

    # Returns the color in OkLab color space.
    # L is in [0..1], a and b are in about [-0.5..0.5]
    def oklab : Tuple(Float64, Float64, Float64)
      x, y, z = to_xyz
      Colorful.xyz_to_oklab(x, y, z)
    end

    # Generates a color by using data given in OkLab space.
    def self.oklab(l : Float64, a : Float64, b : Float64) : Color
      x, y, z = Colorful.oklab_to_xyz(l, a, b)
      from_xyz(x, y, z)
    end

    # Returns the color in OkLch color space (polar OkLab).
    # H in [0..360], C in [0..1], L in [0..1]
    def oklch : Tuple(Float64, Float64, Float64)
      l, a, b = oklab
      Colorful.oklab_to_oklch(l, a, b)
    end

    # Generates a color by using data given in OkLch space.
    def self.oklch(l : Float64, c : Float64, h : Float64) : Color
      l, a, b = Colorful.oklch_to_oklab(l, c, h)
      oklab(l, a, b)
    end

    # BlendOkLab blends two colors in the OkLab color-space.
    # t == 0 results in c1, t == 1 results in c2
    def blend_oklab(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      l1, a1, b1 = oklab
      l2, a2, b2 = other.oklab
      Color.oklab(
        l1 + t_clamped * (l2 - l1),
        a1 + t_clamped * (a2 - a1),
        b1 + t_clamped * (b2 - b1)
      ).clamped
    end

    # BlendOkLch blends two colors in the OkLch color-space.
    # t == 0 results in c1, t == 1 results in c2
    def blend_oklch(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      l1, c1, h1 = oklch
      l2, c2, h2 = other.oklch

      # Handle low chroma cases (from go-colorful PR #60)
      if c1 <= 0.00015 && c2 >= 0.00015
        h1 = h2
      elsif c2 <= 0.00015 && c1 >= 0.00015
        h2 = h1
      end

      Color.oklch(
        l1 + t_clamped * (l2 - l1),
        c1 + t_clamped * (c2 - c1),
        Colorful.interp_angle(h1, h2, t_clamped)
      ).clamped
    end

    # Returns the color in HSLuv color space.
    # Hue in [0..360], Saturation and Luminance in [0..1]
    def hsluv : Tuple(Float64, Float64, Float64)
      l, c, h = luv_lch_white_ref(HSLUV_D65)
      Colorful.luv_lch_to_hsluv(l, c, h)
    end

    # Returns the color in HPLuv color space.
    # Hue in [0..360], Saturation and Luminance in [0..1]
    # Note that HPLuv can only represent pastel colors, and so the Saturation
    # value could be much larger than 1 for colors it can't represent.
    def hpluv : Tuple(Float64, Float64, Float64)
      l, c, h = luv_lch_white_ref(HSLUV_D65)
      Colorful.luv_lch_to_hpluv(l, c, h)
    end

    # Creates a new Color from values in the HSLuv color space.
    # Hue in [0..360], Saturation [0..1], Luminance (lightness) in [0..1].
    # The returned color values are clamped (using .clamped), so this will never output
    # an invalid color.
    def self.hsluv(h : Float64, s : Float64, l : Float64) : Color
      # HSLuv -> LuvLCh -> CIELUV -> CIEXYZ -> Linear RGB -> sRGB
      l_lch, c, h_lch = Colorful.hsluv_to_luv_lch(h, s, l)
      l_luv, u, v = Colorful.luv_lch_to_luv(l_lch, c, h_lch)
      x, y, z = Colorful.luv_to_xyz_white_ref(l_luv, u, v, HSLUV_D65)
      r, g, b = Colorful.xyz_to_linear_rgb(x, y, z)
      Color.linear_rgb(r, g, b).clamped
    end

    # Creates a new Color from values in the HPLuv color space.
    # Hue in [0..360], Saturation [0..1], Luminance (lightness) in [0..1].
    # The returned color values are clamped (using .clamped), so this will never output
    # an invalid color.
    def self.hpluv(h : Float64, s : Float64, l : Float64) : Color
      # HPLuv -> LuvLCh -> CIELUV -> CIEXYZ -> Linear RGB -> sRGB
      l_lch, c, h_lch = Colorful.hpluv_to_luv_lch(h, s, l)
      l_luv, u, v = Colorful.luv_lch_to_luv(l_lch, c, h_lch)
      x, y, z = Colorful.luv_to_xyz_white_ref(l_luv, u, v, HSLUV_D65)
      r, g, b = Colorful.xyz_to_linear_rgb(x, y, z)
      Color.linear_rgb(r, g, b).clamped
    end

    # DistanceHSLuv calculates Euclidean distance in the HSLuv colorspace. No idea
    # how useful this is.
    #
    # The Hue value is divided by 100 before the calculation, so that H, S, and L
    # have the same relative ranges.
    def distance_hsluv(other : Color) : Float64
      h1, s1, l1 = hsluv
      h2, s2, l2 = other.hsluv
      Math.sqrt(Colorful.sq((h1 - h2) / 100.0) + Colorful.sq(s1 - s2) + Colorful.sq(l1 - l2))
    end

    # DistanceHPLuv calculates Euclidean distance in the HPLuv colorspace. No idea
    # how useful this is.
    #
    # The Hue value is divided by 100 before the calculation, so that H, S, and L
    # have the same relative ranges.
    def distance_hpluv(other : Color) : Float64
      h1, s1, l1 = hpluv
      h2, s2, l2 = other.hpluv
      Math.sqrt(Colorful.sq((h1 - h2) / 100.0) + Colorful.sq(s1 - s2) + Colorful.sq(l1 - l2))
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

  # Constructs a Color from something implementing ColorConvertible (similar to Go's color.Color).
  # Returns a tuple of {Color, Bool} where the bool indicates success (alpha > 0).
  def self.make_color(col : ColorConvertible) : {Color, Bool}
    r, g, b, a = col.rgba
    if a == 0
      return {Color.new(0.0, 0.0, 0.0), false}
    end

    # Since color.Color is alpha pre-multiplied, we need to divide the
    # RGB values by alpha again in order to get back the original RGB.
    r64 = r.to_u64 * 0xFFFF_u64
    g64 = g.to_u64 * 0xFFFF_u64
    b64 = b.to_u64 * 0xFFFF_u64
    a64 = a.to_u64

    r_unpremultiplied = (r64 // a64).to_u32
    g_unpremultiplied = (g64 // a64).to_u32
    b_unpremultiplied = (b64 // a64).to_u32

    {Color.new(r_unpremultiplied.to_f / 65535.0, g_unpremultiplied.to_f / 65535.0, b_unpremultiplied.to_f / 65535.0), true}
  end

  def self.make_color(input : Color) : Color
    input
  end

  # A HexColor is a Color stored as a hex string "#rrggbb". It implements
  # JSON and YAML serialization interfaces.
  struct HexColor
    property color : Color

    def initialize(@color : Color)
    end

    def initialize(hex : String)
      @color = Color.hex(hex)
    end

    def initialize(r : Float64, g : Float64, b : Float64)
      @color = Color.new(r, g, b)
    end

    # Parse a hex string into a HexColor
    def self.parse(hex : String) : HexColor
      new(hex)
    end

    # Convert to hex string
    def to_s : String
      @color.hex
    end

    # Convert to Color
    def to_color : Color
      @color
    end

    # Scan implements database/sql.Scanner interface (Go compatibility).
    # Parses a hex string and sets the color.
    def scan(value : String) : Nil
      @color = Color.hex(value)
    end

    # Value implements database/sql/driver.Value interface (Go compatibility).
    # Returns the hex string representation.
    def value : String
      to_s
    end

    # Decode implements envconfig decoder interface (Go compatibility).
    # Parses a hex string and sets the color.
    def decode(hex_code : String) : Nil
      @color = Color.hex(hex_code)
    end

    # For compatibility with Go's HexColor type which has R, G, B fields
    def r : Float64
      @color.r
    end

    def g : Float64
      @color.g
    end

    def b : Float64
      @color.b
    end

    # JSON deserialization constructor for JSON::Serializable
    def self.new(pull : JSON::PullParser)
      from_json(pull)
    end

    # JSON serialization
    def to_json : String
      JSON.build do |json|
        to_json(json)
      end
    end

    def to_json(json : JSON::Builder) : Nil
      json.string(to_s)
    end

    def self.from_json(string : String) : HexColor
      pull = JSON::PullParser.new(string)
      from_json(pull)
    end

    def self.from_json(pull : JSON::PullParser) : HexColor
      hex = pull.read_string
      new(hex)
    end

    # YAML serialization
    def to_yaml(yaml : YAML::Nodes::Builder) : Nil
      yaml.scalar(to_s)
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : HexColor
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar for hex color"
      end
      hex = node.value
      new(hex)
    end
  end

  # Color generation functions (ported from go-colorful/colorgens.go)

  # Creates a random dark, "warm" color through a restricted HSV space.
  def self.fast_warm_color_with_rand(rand : Random) : Color
    Color.hsv(
      rand.rand * 360.0,
      0.5 + rand.rand * 0.3,
      0.3 + rand.rand * 0.3
    )
  end

  def self.fast_warm_color : Color
    fast_warm_color_with_rand(Random.new)
  end

  # Creates a random dark, "warm" color through restricted HCL space.
  # This is slower than FastWarmColor but will likely give you colors which have
  # the same "warmness" if you run it many times.
  def self.warm_color_with_rand(rand : Random) : Color
    c = random_warm_with_rand(rand)
    until c.valid?
      c = random_warm_with_rand(rand)
    end
    c
  end

  def self.warm_color : Color
    warm_color_with_rand(Random.new)
  end

  private def self.random_warm_with_rand(rand : Random) : Color
    Color.hcl(
      rand.rand * 360.0,
      0.1 + rand.rand * 0.3,
      0.2 + rand.rand * 0.3
    )
  end

  # Creates a random bright, "pimpy" color through a restricted HSV space.
  def self.fast_happy_color_with_rand(rand : Random) : Color
    Color.hsv(
      rand.rand * 360.0,
      0.7 + rand.rand * 0.3,
      0.6 + rand.rand * 0.3
    )
  end

  def self.fast_happy_color : Color
    fast_happy_color_with_rand(Random.new)
  end

  # Creates a random bright, "pimpy" color through restricted HCL space.
  # This is slower than FastHappyColor but will likely give you colors which
  # have the same "brightness" if you run it many times.
  def self.happy_color_with_rand(rand : Random) : Color
    c = random_pimp_with_rand(rand)
    until c.valid?
      c = random_pimp_with_rand(rand)
    end
    c
  end

  def self.happy_color : Color
    happy_color_with_rand(Random.new)
  end

  private def self.random_pimp_with_rand(rand : Random) : Color
    Color.hcl(
      rand.rand * 360.0,
      0.5 + rand.rand * 0.3,
      0.5 + rand.rand * 0.3
    )
  end

  # Soft palette generation functions (ported from go-colorful/soft_palettegen.go)

  # The algorithm works in L*a*b* color space and converts to RGB in the end.
  # L* in [0..1], a* and b* in [-1..1]
  private struct LabT
    property l : Float64
    property a : Float64
    property b : Float64

    def initialize(@l : Float64, @a : Float64, @b : Float64)
    end
  end

  struct SoftPaletteSettings
    # A function which can be used to restrict the allowed color-space.
    property check_color : (Float64, Float64, Float64 -> Bool)?

    # The higher, the better quality but the slower. Usually two figures.
    property iterations : Int32

    # Use up to 160000 or 8000 samples of the L*a*b* space (and thus calls to CheckColor).
    # Set this to true only if your CheckColor shapes the Lab space weirdly.
    property? many_samples : Bool

    def initialize(@check_color = nil, @iterations = 50, @many_samples = false)
    end
  end

  # Yeah, windows-stype Foo, FooEx, screw you golang...
  # Uses K-means to cluster the color-space and return the means of the clusters
  # as a new palette of distinctive colors. Falls back to K-medoid if the mean
  # happens to fall outside of the color-space, which can only happen if you
  # specify a CheckColor function.
  def self.soft_palette_ex_with_rand(colors_count : Int32, settings : SoftPaletteSettings, rand : Random) : Array(Color)
    # Checks whether it's a valid RGB and also fulfills the potentially provided constraint.
    check = ->(col : LabT) : Bool {
      c = Color.lab(col.l, col.a, col.b)
      return false unless c.valid?
      if check_color = settings.check_color
        return check_color.call(col.l, col.a, col.b)
      end
      true
    }

    # Sample the color space. These will be the points k-means is run on.
    dl = settings.many_samples? ? 0.01 : 0.05
    dab = settings.many_samples? ? 0.05 : 0.1

    samples = [] of LabT
    l = 0.0
    while l <= 1.0
      a = -1.0
      while a <= 1.0
        b = -1.0
        while b <= 1.0
          if check.call(LabT.new(l, a, b))
            samples << LabT.new(l, a, b)
          end
          b += dab
        end
        a += dab
      end
      l += dl
    end

    # That would cause some infinite loops down there...
    if samples.size < colors_count
      raise ArgumentError.new("palettegen: more colors requested (#{colors_count}) than samples available (#{samples.size}). Your requested color count may be wrong, you might want to use many samples or your constraint function makes the valid color space too small")
    elsif samples.size == colors_count
      return labs_to_colors(samples) # Oops?
    end

    # We take the initial means out of the samples, so they are in fact medoids.
    # This helps us avoid infinite loops or arbitrary cutoffs with too restrictive constraints.
    means = Array(LabT).new(colors_count)
    colors_count.times do |i|
      mean = samples[rand.rand(samples.size)]
      while in_array(means, i, mean)
        mean = samples[rand.rand(samples.size)]
      end
      means << mean
    end

    clusters = Array(Int32).new(samples.size, 0)
    samples_used = Array(Bool).new(samples.size, false)

    # The actual k-means/medoid iterations
    settings.iterations.times do
      # Reassigning the samples to clusters, i.e. to their closest mean.
      # By the way, also check if any sample is used as a medoid and if so, mark that.
      samples.each_with_index do |sample, isample|
        samples_used[isample] = false
        mindist = Float64::INFINITY
        means.each_with_index do |mean, imean|
          dist = lab_dist(sample, mean)
          if dist < mindist
            mindist = dist
            clusters[isample] = imean
          end

          # Mark samples which are used as a medoid.
          if lab_eq(sample, mean)
            samples_used[isample] = true
          end
        end
      end

      # Compute new means according to the samples.
      means.each_with_index do |_, imean|
        # The new mean is the average of all samples belonging to it.
        nsamples = 0
        newmean = LabT.new(0.0, 0.0, 0.0)
        samples.each_with_index do |sample, isample|
          if clusters[isample] == imean
            nsamples += 1
            newmean.l += sample.l
            newmean.a += sample.a
            newmean.b += sample.b
          end
        end

        if nsamples > 0
          newmean.l /= nsamples.to_f
          newmean.a /= nsamples.to_f
          newmean.b /= nsamples.to_f
        else
          # That mean doesn't have any samples? Get a new mean from the sample list!
          inewmean = rand.rand(samples_used.size)
          while samples_used[inewmean]
            inewmean = rand.rand(samples_used.size)
          end
          newmean = samples[inewmean]
          samples_used[inewmean] = true
        end

        # But now we still need to check whether the new mean is an allowed color.
        if nsamples > 0 && check.call(newmean)
          # It does, life's good (TM)
          means[imean] = newmean
        else
          # New mean isn't an allowed color or doesn't have any samples!
          # Switch to medoid mode and pick the closest (unused) sample.
          # This should always find something thanks to len(samples) >= colorsCount
          mindist = Float64::INFINITY
          samples.each_with_index do |sample, isample|
            if !samples_used[isample]
              dist = lab_dist(sample, newmean)
              if dist < mindist
                mindist = dist
                newmean = sample
              end
            end
          end
          means[imean] = newmean
        end
      end
    end

    labs_to_colors(means)
  end

  def self.soft_palette_ex(colors_count : Int32, settings : SoftPaletteSettings) : Array(Color)
    soft_palette_ex_with_rand(colors_count, settings, Random.new)
  end

  # A wrapper which uses common parameters.
  def self.soft_palette_with_rand(colors_count : Int32, rand : Random) : Array(Color)
    settings = SoftPaletteSettings.new(nil, 50, false)
    soft_palette_ex_with_rand(colors_count, settings, rand)
  end

  def self.soft_palette(colors_count : Int32) : Array(Color)
    soft_palette_with_rand(colors_count, Random.new)
  end

  # Helper functions
  private def self.in_array(haystack : Array(LabT), upto : Int32, needle : LabT) : Bool
    limit = Math.min(upto, haystack.size)
    limit.times do |i|
      return true if haystack[i] == needle
    end
    false
  end

  private LAB_DELTA = 1e-6

  private def self.lab_eq(lab1 : LabT, lab2 : LabT) : Bool
    (lab1.l - lab2.l).abs < LAB_DELTA &&
      (lab1.a - lab2.a).abs < LAB_DELTA &&
      (lab1.b - lab2.b).abs < LAB_DELTA
  end

  # That's faster than using colorful's DistanceLab since we would have to
  # convert back and forth for that. Here is no conversion.
  private def self.lab_dist(lab1 : LabT, lab2 : LabT) : Float64
    Math.sqrt(sq(lab1.l - lab2.l) + sq(lab1.a - lab2.a) + sq(lab1.b - lab2.b))
  end

  private def self.labs_to_colors(labs : Array(LabT)) : Array(Color)
    labs.map { |v| Color.lab(v.l, v.a, v.b) }
  end

  # Color sorting functions (ported from go-colorful/sort.go)

  # An element represents a single element of a set. It is used to
  # implement a disjoint-set forest.
  private class Element
    property parent : Element # Parent element
    property rank : Int32     # Rank (approximate depth) of the subtree with this element as root

    def initialize
      @parent = uninitialized Element
      @rank = 0
      @parent = self
    end

    # find returns an arbitrary element of a set when invoked on any element of
    # the set. The important feature is that it returns the same value when
    # invoked on any element of the set. Consequently, it can be used to test if
    # two elements belong to the same set.
    def find : Element
      e = self
      while e.parent != e
        e.parent = e.parent.parent
        e = e.parent
      end
      e
    end
  end

  # union establishes the union of two sets when given an element from each set.
  # Afterwards, the original sets no longer exist as separate entities.
  private def self.union(e1 : Element, e2 : Element) : Nil
    # Ensure the two elements aren't already part of the same union.
    e1_root = e1.find
    e2_root = e2.find
    return if e1_root == e2_root

    # Create a union by making the shorter tree point to the root of the
    # larger tree.
    if e1_root.rank < e2_root.rank
      e1_root.parent = e2_root
    elsif e1_root.rank > e2_root.rank
      e2_root.parent = e1_root
    else
      e2_root.parent = e1_root
      e1_root.rank += 1
    end
  end

  # An edge_idxs describes an edge in a graph or tree. The vertices in the edge
  # are indexes into a list of Color values.
  private struct EdgeIdxs
    property u : Int32
    property v : Int32

    def initialize(@u : Int32, @v : Int32)
    end

    def ==(other : self) : Bool
      @u == other.u && @v == other.v
    end

    def_hash @u, @v
  end

  # An edge_distance is a map from an edge (pair of indices) to a distance
  # between the two vertices.
  private alias EdgeDistance = Hash(EdgeIdxs, Float64)

  # all_to_all_distances_ciede2000 computes the CIEDE2000 distance between each pair of
  # colors. It returns a map from a pair of indices (u, v) with u < v to a
  # distance.
  private def self.all_to_all_distances_ciede2000(cs : Array(Color)) : EdgeDistance
    nc = cs.size
    m = EdgeDistance.new
    (0...nc - 1).each do |u_idx|
      ((u_idx + 1)...nc).each do |v_idx|
        m[EdgeIdxs.new(u_idx, v_idx)] = cs[u_idx].distance_ciede2000(cs[v_idx])
      end
    end
    m
  end

  # sort_edges sorts all edges in a distance map by increasing vertex distance.
  private def self.sort_edges(m : EdgeDistance) : Array(EdgeIdxs)
    es = m.keys.sort_by! { |edge| m[edge] }
    es
  end

  # min_span_tree computes a minimum spanning tree from a vertex count and a
  # distance-sorted edge list. It returns the subset of edges that belong to
  # the tree, including both (u, v) and (v, u) for each edge.
  private def self.min_span_tree(nc : Int32, es : Array(EdgeIdxs)) : Set(EdgeIdxs)
    # Start with each vertex in its own set.
    elts = Array(Element).new(nc) { Element.new }

    # Run Kruskal's algorithm to construct a minimal spanning tree.
    mst = Set(EdgeIdxs).new
    es.each do |edge|
      from_vertex, to_vertex = edge.u, edge.v
      if elts[from_vertex].find == elts[to_vertex].find
        next # Same set: edge would introduce a cycle.
      end
      mst.add(edge)
      mst.add(EdgeIdxs.new(to_vertex, from_vertex))
      union(elts[from_vertex], elts[to_vertex])
    end
    mst
  end

  # traverse_mst walks a minimum spanning tree in prefix order.
  private def self.traverse_mst(mst : Set(EdgeIdxs), root : Int32) : Array(Int32)
    # Compute a list of neighbors for each vertex.
    neighs = Hash(Int32, Array(Int32)).new { |hash, key| hash[key] = [] of Int32 }
    mst.each do |edge|
      from_vertex, to_vertex = edge.u, edge.v
      neighs[from_vertex] << to_vertex
    end

    neighs.each do |vertex, neighbors|
      neighs[vertex] = neighbors.sort
    end

    # Walk the tree from a given vertex.
    order = [] of Int32
    visited = Set(Int32).new

    # Define recursive walk function using closure
    walk_from = uninitialized Proc(Int32, Nil)
    walk_from = ->(r : Int32) do
      # Visit the starting vertex.
      order << r
      visited.add(r)

      # Recursively visit each child in turn.
      neighs[r].each do |child|
        unless visited.includes?(child)
          walk_from.call(child)
        end
      end
    end

    walk_from.call(root)
    order
  end

  # Sorted sorts a list of Color values. Sorting is not a well-defined operation
  # for colors so the intention here primarily is to order colors so that the
  # transition from one to the next is fairly smooth.
  def self.sorted(cs : Array(Color)) : Array(Color)
    # Do nothing in trivial cases.
    new_cs = Array(Color).new(cs.size)
    if cs.size < 2
      cs.each { |color| new_cs << color }
      return new_cs
    end

    # Compute the distance from each color to every other color.
    dists = all_to_all_distances_ciede2000(cs)

    # Produce a list of edges in increasing order of the distance between
    # their vertices.
    edges = sort_edges(dists)

    # Construct a minimum spanning tree from the list of edges.
    mst = min_span_tree(cs.size, edges)

    # Find the darkest color in the list.
    black = Color.new(0.0, 0.0, 0.0)
    d_idx = 0            # Index of darkest color
    light = Float64::MAX # Lightness of darkest color (distance from black)
    cs.each_with_index do |color, i|
      d = black.distance_ciede2000(color)
      if d < light
        d_idx = i
        light = d
      end
    end

    # Traverse the tree starting from the darkest color.
    idxs = traverse_mst(mst, d_idx)

    # Convert the index list to a list of colors, overwriting the input.
    idxs.each do |idx|
      new_cs << cs[idx]
    end
    new_cs
  end
end
