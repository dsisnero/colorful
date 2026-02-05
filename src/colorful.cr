module Colorful
  private EPSILON = 0.008856
  private KAPPA = 903.3
  private REF_X = 0.95047
  private REF_Y = 1.0
  private REF_Z = 1.08883
  private REF_U = (4.0 * REF_X) / (REF_X + 15.0 * REF_Y + 3.0 * REF_Z)
  private REF_V = (9.0 * REF_Y) / (REF_X + 15.0 * REF_Y + 3.0 * REF_Z)

  struct Color
    getter r : Float64
    getter g : Float64
    getter b : Float64

    def initialize(@r : Float64, @g : Float64, @b : Float64)
    end

    def self.hex(input : String) : Color
      s = input.strip
      s = s[1..] if s.starts_with?('#')
      raise ArgumentError.new("invalid hex color") unless s.size == 6
      r = s[0, 2].to_i(16)
      g = s[2, 2].to_i(16)
      b = s[4, 2].to_i(16)
      Color.new(r / 255.0, g / 255.0, b / 255.0)
    end

    def hex : String
      "##{channel_hex(@r)}#{channel_hex(@g)}#{channel_hex(@b)}"
    end

    def blend_luv(other : Color, t : Float64) : Color
      t_clamped = t.clamp(0.0, 1.0)
      l1, u1, v1 = to_luv
      l2, u2, v2 = other.to_luv
      l = l1 + (l2 - l1) * t_clamped
      u = u1 + (u2 - u1) * t_clamped
      v = v1 + (v2 - v1) * t_clamped
      Color.from_luv(l, u, v)
    end

    def to_luv : Tuple(Float64, Float64, Float64)
      x, y, z = to_xyz
      denom = x + 15.0 * y + 3.0 * z
      u_prime = denom == 0 ? 0.0 : (4.0 * x / denom)
      v_prime = denom == 0 ? 0.0 : (9.0 * y / denom)

      yr = y / REF_Y
      l = if yr > EPSILON
            116.0 * Math.cbrt(yr) - 16.0
          else
            KAPPA * yr
          end

      u = 13.0 * l * (u_prime - REF_U)
      v = 13.0 * l * (v_prime - REF_V)
      {l, u, v}
    end

    def self.from_luv(l : Float64, u : Float64, v : Float64) : Color
      return Color.new(0.0, 0.0, 0.0) if l <= 0.0

      u_prime = u / (13.0 * l) + REF_U
      v_prime = v / (13.0 * l) + REF_V

      y = if l > KAPPA * EPSILON
            Math.cbrt((l + 16.0) / 116.0) ** 3 * REF_Y
          else
            (l / KAPPA) * REF_Y
          end

      x = if v_prime == 0
            0.0
          else
            y * 9.0 * u_prime / (4.0 * v_prime)
          end
      z = if v_prime == 0
            0.0
          else
            y * (12.0 - 3.0 * u_prime - 20.0 * v_prime) / (4.0 * v_prime)
          end

      from_xyz(x, y, z)
    end

    private def to_xyz : Tuple(Float64, Float64, Float64)
      r = srgb_to_linear(@r)
      g = srgb_to_linear(@g)
      b = srgb_to_linear(@b)

      x = r * 0.4124 + g * 0.3576 + b * 0.1805
      y = r * 0.2126 + g * 0.7152 + b * 0.0722
      z = r * 0.0193 + g * 0.1192 + b * 0.9505
      {x, y, z}
    end

    private def self.from_xyz(x : Float64, y : Float64, z : Float64) : Color
      r = x * 3.2406 + y * -1.5372 + z * -0.4986
      g = x * -0.9689 + y * 1.8758 + z * 0.0415
      b = x * 0.0557 + y * -0.2040 + z * 1.0570
      Color.new(
        linear_to_srgb(r).clamp(0.0, 1.0),
        linear_to_srgb(g).clamp(0.0, 1.0),
        linear_to_srgb(b).clamp(0.0, 1.0)
      )
    end

    private def srgb_to_linear(c : Float64) : Float64
      c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
    end

    private def self.linear_to_srgb(c : Float64) : Float64
      c <= 0.0031308 ? c * 12.92 : 1.055 * (c ** (1.0 / 2.4)) - 0.055
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
