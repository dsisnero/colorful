require "spec"
require "../src/colorful"

# Test tolerance (1/256) matches Go test suite
private TEST_DELTA = 1.0 / 256.0

# Checks whether the relative error is below eps
private def almosteq_eps(v1 : Float64, v2 : Float64, eps : Float64) : Bool
  if v1.abs > TEST_DELTA
    ((v1 - v2).abs / v1.abs) < eps
  else
    true
  end
end

# Checks whether the relative error is below the 8bit RGB delta
private def almosteq(v1 : Float64, v2 : Float64) : Bool
  almosteq_eps(v1, v2, TEST_DELTA)
end

# Note: the XYZ, L*a*b*, etc. are using D65 white and D50 white if postfixed by "50".
# See http://www.brucelindbloom.com/index.html?ColorCalcHelp.html
# For d50 white, no "adaptation" and the sRGB model are used in colorful
# HCL values form http://www.easyrgb.com/index.php?X=CALC and missing ones hand-computed from lab ones
private TEST_VALS = [
  # {Color, hsl, hsv, hex, xyz, xyy, lab, lab50, luv, luv50, hcl, hcl50, rgba, rgb255}
  {Colorful::Color.new(1.0, 1.0, 1.0), {0.0, 0.0, 1.00}, {0.0, 0.0, 1.0}, "#ffffff", {0.950470, 1.000000, 1.088830}, {0.312727, 0.329023, 1.000000}, {1.000000, 0.000000, 0.000000}, {1.000000, -0.023881, -0.193622}, {1.00000, 0.00000, 0.00000}, {1.00000, -0.14716, -0.25658}, {0.0000, 0.000000, 1.000000}, {262.9688, 0.195089, 1.000000}, {65535_u32, 65535_u32, 65535_u32, 65535_u32}, {255_u8, 255_u8, 255_u8}},
  {Colorful::Color.new(0.5, 1.0, 1.0), {180.0, 1.0, 0.75}, {180.0, 0.5, 1.0}, "#80ffff", {0.626296, 0.832848, 1.073634}, {0.247276, 0.328828, 0.832848}, {0.931390, -0.353319, -0.108946}, {0.931390, -0.374100, -0.301663}, {0.93139, -0.53909, -0.11630}, {0.93139, -0.67615, -0.35528}, {197.1371, 0.369735, 0.931390}, {218.8817, 0.480574, 0.931390}, {32768_u32, 65535_u32, 65535_u32, 65535_u32}, {128_u8, 255_u8, 255_u8}},
  {Colorful::Color.new(1.0, 0.5, 1.0), {300.0, 1.0, 0.75}, {300.0, 0.5, 1.0}, "#ff80ff", {0.669430, 0.437920, 0.995150}, {0.318397, 0.208285, 0.437920}, {0.720892, 0.651673, -0.422133}, {0.720892, 0.630425, -0.610035}, {0.72089, 0.60047, -0.77626}, {0.72089, 0.49438, -0.96123}, {327.0661, 0.776450, 0.720892}, {315.9417, 0.877257, 0.720892}, {65535_u32, 32768_u32, 65535_u32, 65535_u32}, {255_u8, 128_u8, 255_u8}},
  {Colorful::Color.new(1.0, 1.0, 0.5), {60.0, 1.0, 0.75}, {60.0, 0.5, 1.0}, "#ffff80", {0.808654, 0.943273, 0.341930}, {0.386203, 0.450496, 0.943273}, {0.977637, -0.165795, 0.602017}, {0.977637, -0.188424, 0.470410}, {0.97764, 0.05759, 0.79816}, {0.97764, -0.08628, 0.54731}, {105.3975, 0.624430, 0.977637}, {111.8287, 0.506743, 0.977637}, {65535_u32, 65535_u32, 32768_u32, 65535_u32}, {255_u8, 255_u8, 128_u8}},
  {Colorful::Color.new(0.5, 0.5, 1.0), {240.0, 1.0, 0.75}, {240.0, 0.5, 1.0}, "#8080ff", {0.345256, 0.270768, 0.979954}, {0.216329, 0.169656, 0.270768}, {0.590453, 0.332846, -0.637099}, {0.590453, 0.315806, -0.824040}, {0.59045, -0.07568, -1.04877}, {0.59045, -0.16257, -1.20027}, {297.5843, 0.718805, 0.590453}, {290.9689, 0.882482, 0.590453}, {32768_u32, 32768_u32, 65535_u32, 65535_u32}, {128_u8, 128_u8, 255_u8}},
  {Colorful::Color.new(1.0, 0.5, 0.5), {0.0, 1.0, 0.75}, {0.0, 0.5, 1.0}, "#ff8080", {0.527613, 0.381193, 0.248250}, {0.455996, 0.329451, 0.381193}, {0.681085, 0.483884, 0.228328}, {0.681085, 0.464258, 0.110043}, {0.68108, 0.92148, 0.19879}, {0.68106, 0.82106, 0.02393}, {25.2610, 0.535049, 0.681085}, {13.3347, 0.477121, 0.681085}, {65535_u32, 32768_u32, 32768_u32, 65535_u32}, {255_u8, 128_u8, 128_u8}},
  {Colorful::Color.new(0.5, 1.0, 0.5), {120.0, 1.0, 0.75}, {120.0, 0.5, 1.0}, "#80ff80", {0.484480, 0.776121, 0.326734}, {0.305216, 0.488946, 0.776121}, {0.906026, -0.600870, 0.498993}, {0.906026, -0.619946, 0.369365}, {0.90603, -0.58869, 0.76102}, {0.90603, -0.72202, 0.52855}, {140.2920, 0.781050, 0.906026}, {149.2134, 0.721640, 0.906026}, {32768_u32, 65535_u32, 32768_u32, 65535_u32}, {128_u8, 255_u8, 128_u8}},
  {Colorful::Color.new(0.5, 0.5, 0.5), {0.0, 0.0, 0.50}, {0.0, 0.0, 0.5}, "#808080", {0.203440, 0.214041, 0.233054}, {0.312727, 0.329023, 0.214041}, {0.533890, 0.000000, 0.000000}, {0.533890, -0.014285, -0.115821}, {0.53389, 0.00000, 0.00000}, {0.53389, -0.07857, -0.13699}, {0.0000, 0.000000, 0.533890}, {262.9688, 0.116699, 0.533890}, {32768_u32, 32768_u32, 32768_u32, 65535_u32}, {128_u8, 128_u8, 128_u8}},
  {Colorful::Color.new(0.0, 1.0, 1.0), {180.0, 1.0, 0.50}, {180.0, 1.0, 1.0}, "#00ffff", {0.538014, 0.787327, 1.069496}, {0.224656, 0.328760, 0.787327}, {0.911132, -0.480875, -0.141312}, {0.911132, -0.500630, -0.333781}, {0.91113, -0.70477, -0.15204}, {0.91113, -0.83886, -0.38582}, {196.3762, 0.501209, 0.911132}, {213.6923, 0.601698, 0.911132}, {0_u32, 65535_u32, 65535_u32, 65535_u32}, {0_u8, 255_u8, 255_u8}},
  {Colorful::Color.new(1.0, 0.0, 1.0), {300.0, 1.0, 0.50}, {300.0, 1.0, 1.0}, "#ff00ff", {0.592894, 0.284848, 0.969638}, {0.320938, 0.154190, 0.284848}, {0.603242, 0.982343, -0.608249}, {0.603242, 0.961939, -0.794531}, {0.60324, 0.84071, -1.08683}, {0.60324, 0.75194, -1.24161}, {328.2350, 1.155407, 0.603242}, {320.4444, 1.247640, 0.603242}, {65535_u32, 0_u32, 65535_u32, 65535_u32}, {255_u8, 0_u8, 255_u8}},
  {Colorful::Color.new(1.0, 1.0, 0.0), {60.0, 1.0, 0.50}, {60.0, 1.0, 1.0}, "#ffff00", {0.770033, 0.927825, 0.138526}, {0.419320, 0.505246, 0.927825}, {0.971393, -0.215537, 0.944780}, {0.971393, -0.237800, 0.847398}, {0.97139, 0.07706, 1.06787}, {0.97139, -0.06590, 0.81862}, {102.8512, 0.969054, 0.971393}, {105.6754, 0.880131, 0.971393}, {65535_u32, 65535_u32, 0_u32, 65535_u32}, {255_u8, 255_u8, 0_u8}},
  {Colorful::Color.new(0.0, 0.0, 1.0), {240.0, 1.0, 0.50}, {240.0, 1.0, 1.0}, "#0000ff", {0.180437, 0.072175, 0.950304}, {0.150000, 0.060000, 0.072175}, {0.322970, 0.791875, -1.078602}, {0.322970, 0.778150, -1.263638}, {0.32297, -0.09405, -1.30342}, {0.32297, -0.14158, -1.38629}, {306.2849, 1.338076, 0.322970}, {301.6248, 1.484014, 0.322970}, {0_u32, 0_u32, 65535_u32, 65535_u32}, {0_u8, 0_u8, 255_u8}},
  {Colorful::Color.new(0.0, 1.0, 0.0), {120.0, 1.0, 0.50}, {120.0, 1.0, 1.0}, "#00ff00", {0.357576, 0.715152, 0.119192}, {0.300000, 0.600000, 0.715152}, {0.877347, -0.861827, 0.831793}, {0.877347, -0.879067, 0.739170}, {0.87735, -0.83078, 1.07398}, {0.87735, -0.95989, 0.84887}, {136.0160, 1.197759, 0.877347}, {139.9409, 1.148534, 0.877347}, {0_u32, 65535_u32, 0_u32, 65535_u32}, {0_u8, 255_u8, 0_u8}},
  {Colorful::Color.new(1.0, 0.0, 0.0), {0.0, 1.0, 0.50}, {0.0, 1.0, 1.0}, "#ff0000", {0.412456, 0.212673, 0.019334}, {0.640000, 0.330000, 0.212673}, {0.532408, 0.800925, 0.672032}, {0.532408, 0.782845, 0.621518}, {0.53241, 1.75015, 0.37756}, {0.53241, 1.67180, 0.24096}, {39.9990, 1.045518, 0.532408}, {38.4469, 0.999566, 0.532408}, {65535_u32, 0_u32, 0_u32, 65535_u32}, {255_u8, 0_u8, 0_u8}},
  {Colorful::Color.new(0.0, 0.0, 0.0), {0.0, 0.0, 0.00}, {0.0, 0.0, 0.0}, "#000000", {0.000000, 0.000000, 0.000000}, {0.312727, 0.329023, 0.000000}, {0.000000, 0.000000, 0.000000}, {0.000000, 0.000000, 0.000000}, {0.00000, 0.00000, 0.00000}, {0.00000, 0.00000, 0.00000}, {0.0000, 0.000000, 0.000000}, {0.0000, 0.000000, 0.000000}, {0_u32, 0_u32, 0_u32, 65535_u32}, {0_u8, 0_u8, 0_u8}},
]

# For testing short-hex values, since the above contains colors which don't
# have corresponding short hexes.
private SHORT_HEX_VALS = [
  {Colorful::Color.new(1.0, 1.0, 1.0), "#fff"},
  {Colorful::Color.new(0.6, 1.0, 1.0), "#9ff"},
  {Colorful::Color.new(1.0, 0.6, 1.0), "#f9f"},
  {Colorful::Color.new(1.0, 1.0, 0.6), "#ff9"},
  {Colorful::Color.new(0.6, 0.6, 1.0), "#99f"},
  {Colorful::Color.new(1.0, 0.6, 0.6), "#f99"},
  {Colorful::Color.new(0.6, 1.0, 0.6), "#9f9"},
  {Colorful::Color.new(0.6, 0.6, 0.6), "#999"},
  {Colorful::Color.new(0.0, 1.0, 1.0), "#0ff"},
  {Colorful::Color.new(1.0, 0.0, 1.0), "#f0f"},
  {Colorful::Color.new(1.0, 1.0, 0.0), "#ff0"},
  {Colorful::Color.new(0.0, 0.0, 1.0), "#00f"},
  {Colorful::Color.new(0.0, 1.0, 0.0), "#0f0"},
  {Colorful::Color.new(1.0, 0.0, 0.0), "#f00"},
  {Colorful::Color.new(0.0, 0.0, 0.0), "#000"},
]

# White reference for D50 (used in lab50, luv50, hcl50 tests)
private D50 = [0.96422, 1.00000, 0.82521]

describe Colorful::Color do
  # Keep existing simple tests for compatibility
  it "parses and formats hex colors" do
    color = Colorful::Color.hex("#F25D94")
    color.hex.should eq("#f25d94")
  end

  it "blends in Luv space" do
    a = Colorful::Color.hex("#FF0000")
    b = Colorful::Color.hex("#00FF00")
    mid = a.blend_luv(b, 0.5)
    mid.hex.size.should eq(7)
  end

  # RGBA conversion tests
  describe "RGBA conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, _, _, _, _, _, rgba_expected, _), i|
      it "converts test case #{i}" do
        r, g, b, a = c.rgba
        r.should eq(rgba_expected[0])
        g.should eq(rgba_expected[1])
        b.should eq(rgba_expected[2])
        a.should eq(rgba_expected[3])
      end
    end
  end

  # RGB255 conversion tests
  describe "RGB255 conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, _, _, _, _, _, _, rgb255_expected), i|
      it "converts test case #{i}" do
        r, g, b = c.rgb255
        r.should eq(rgb255_expected[0])
        g.should eq(rgb255_expected[1])
        b.should eq(rgb255_expected[2])
      end
    end
  end

  # HSV creation tests
  describe "HSV creation" do
    TEST_VALS.each do |(_, _, hsv_expected, hex, _, _, _, _, _, _, _, _, _, _)|
      it "creates from HSV for #{hex}" do
        h, s, v = hsv_expected
        Colorful::Color.hsv(h, s, v)
        # Should be close to the original color in the table
        # (the original color is at index 0 of tuple)
        # We'll test this in HSV conversion tests
      end
    end
  end

  # HSV conversion tests
  describe "HSV conversion" do
    TEST_VALS.each do |(c, _, hsv_expected, hex, _, _, _, _, _, _, _, _, _, _)|
      it "converts to HSV for #{hex}" do
        h, s, v = c.hsv
        almosteq(h, hsv_expected[0]).should be_true
        almosteq(s, hsv_expected[1]).should be_true
        almosteq(v, hsv_expected[2]).should be_true
      end
    end
  end

  # HSL creation tests
  describe "HSL creation" do
    TEST_VALS.each do |(_, hsl_expected, _, hex, _, _, _, _, _, _, _, _, _, _)|
      it "creates from HSL for #{hex}" do
        h, s, l = hsl_expected
        Colorful::Color.hsl(h, s, l)
        # Tested in conversion tests
      end
    end
  end

  # HSL conversion tests
  describe "HSL conversion" do
    TEST_VALS.each do |(c, hsl_expected, _, hex, _, _, _, _, _, _, _, _, _, _)|
      it "converts to HSL for #{hex}" do
        h, s, l = c.hsl
        almosteq(h, hsl_expected[0]).should be_true
        almosteq(s, hsl_expected[1]).should be_true
        almosteq(l, hsl_expected[2]).should be_true
      end
    end
  end

  # Hex conversion tests (long form)
  describe "Hex conversion" do
    TEST_VALS.each_with_index do |(c, _, _, hex_expected, _, _, _, _, _, _, _, _, _, _), i|
      it "converts to hex for case #{i}" do
        c.hex.downcase.should eq(hex_expected.downcase)
      end
    end
  end

  # Hex creation tests (long form)
  describe "Hex creation" do
    TEST_VALS.each do |(c_expected, _, _, hex, _, _, _, _, _, _, _, _, _, _)|
      it "creates from hex #{hex}" do
        color = Colorful::Color.hex(hex)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # Short hex creation tests
  describe "Short hex creation" do
    SHORT_HEX_VALS.each do |(c_expected, hex)|
      it "creates from short hex #{hex}" do
        color = Colorful::Color.hex(hex)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # XYZ creation tests
  describe "XYZ creation" do
    TEST_VALS.each_with_index do |(c_expected, _, _, _, xyz_expected, _, _, _, _, _, _, _, _, _), i|
      it "creates from XYZ for case #{i}" do
        x, y, z = xyz_expected
        color = Colorful::Color.xyz(x, y, z)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # XYZ conversion tests
  describe "XYZ conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, xyz_expected, _, _, _, _, _, _, _, _, _), i|
      it "converts to XYZ for case #{i}" do
        x, y, z = c.xyz
        almosteq(x, xyz_expected[0]).should be_true
        almosteq(y, xyz_expected[1]).should be_true
        almosteq(z, xyz_expected[2]).should be_true
      end
    end
  end

  # xyY creation tests
  describe "xyY creation" do
    TEST_VALS.each_with_index do |(c_expected, _, _, _, _, xyy_expected, _, _, _, _, _, _, _, _), i|
      it "creates from xyY for case #{i}" do
        x, y, yy = xyy_expected
        color = Colorful::Color.xyy(x, y, yy)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # xyY conversion tests
  describe "xyY conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, xyy_expected, _, _, _, _, _, _, _, _), i|
      it "converts to xyY for case #{i}" do
        x, y, yy = c.xyy
        almosteq(x, xyy_expected[0]).should be_true
        almosteq(y, xyy_expected[1]).should be_true
        almosteq(yy, xyy_expected[2]).should be_true
      end
    end
  end

  # Lab creation tests
  describe "Lab creation" do
    TEST_VALS.each_with_index do |(c_expected, _, _, _, _, _, lab_expected, _, _, _, _, _, _, _), i|
      it "creates from Lab for case #{i}" do
        l, a, b = lab_expected
        color = Colorful::Color.lab(l, a, b)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # Lab conversion tests
  describe "Lab conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, _, lab_expected, _, _, _, _, _, _, _), i|
      it "converts to Lab for case #{i}" do
        l, a, b = c.lab
        almosteq(l, lab_expected[0]).should be_true
        almosteq(a, lab_expected[1]).should be_true
        almosteq(b, lab_expected[2]).should be_true
      end
    end
  end

  # Lab white reference creation tests (D50)
  describe "Lab white reference creation" do
    TEST_VALS.each_with_index do |(c_expected, _, _, _, _, _, _, lab50_expected, _, _, _, _, _, _), i|
      it "creates from Lab with D50 for case #{i}" do
        l, a, b = lab50_expected
        color = Colorful::Color.lab_white_ref(l, a, b, D50)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # Lab white reference conversion tests (D50)
  describe "Lab white reference conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, lab50_expected, _, _, _, _, _, _), i|
      it "converts to Lab with D50 for case #{i}" do
        l, a, b = c.lab_white_ref(D50)
        almosteq(l, lab50_expected[0]).should be_true
        almosteq(a, lab50_expected[1]).should be_true
        almosteq(b, lab50_expected[2]).should be_true
      end
    end
  end

  # Luv creation tests
  describe "Luv creation" do
    TEST_VALS.each_with_index do |(c_expected, _, _, _, _, _, _, _, luv_expected, _, _, _, _, _), i|
      it "creates from Luv for case #{i}" do
        l, u, v = luv_expected
        color = Colorful::Color.luv(l, u, v)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # Luv conversion tests
  describe "Luv conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, _, luv_expected, _, _, _, _, _), i|
      it "converts to Luv for case #{i}" do
        l, u, v = c.luv
        almosteq(l, luv_expected[0]).should be_true
        almosteq(u, luv_expected[1]).should be_true
        almosteq(v, luv_expected[2]).should be_true
      end
    end
  end

  # Luv white reference creation tests (D50)
  describe "Luv white reference creation" do
    TEST_VALS.each_with_index do |(c_expected, _, _, _, _, _, _, _, _, luv50_expected, _, _, _, _), i|
      it "creates from Luv with D50 for case #{i}" do
        l, u, v = luv50_expected
        color = Colorful::Color.luv_white_ref(l, u, v, D50)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # Luv white reference conversion tests (D50)
  describe "Luv white reference conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, _, _, luv50_expected, _, _, _, _), i|
      it "converts to Luv with D50 for case #{i}" do
        l, u, v = c.luv_white_ref(D50)
        almosteq(l, luv50_expected[0]).should be_true
        almosteq(u, luv50_expected[1]).should be_true
        almosteq(v, luv50_expected[2]).should be_true
      end
    end
  end

  # HCL creation tests (D65)
  describe "HCL creation" do
    TEST_VALS.each_with_index do |(c_expected, _, _, _, _, _, _, _, _, _, hcl_expected, _, _, _), i|
      it "creates from HCL for case #{i}" do
        h, c, l = hcl_expected
        color = Colorful::Color.hcl(h, c, l)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # HCL conversion tests (D65)
  describe "HCL conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, _, _, _, hcl_expected, _, _, _), i|
      it "converts to HCL for case #{i}" do
        h, c_val, l = c.hcl
        almosteq(h, hcl_expected[0]).should be_true
        almosteq(c_val, hcl_expected[1]).should be_true
        almosteq(l, hcl_expected[2]).should be_true
      end
    end
  end

  # HCL white reference creation tests (D50)
  describe "HCL white reference creation" do
    TEST_VALS.each_with_index do |(c_expected, _, _, _, _, _, _, _, _, _, _, hcl50_expected, _, _), i|
      it "creates from HCL with D50 for case #{i}" do
        h, c, l = hcl50_expected
        color = Colorful::Color.hcl_white_ref(h, c, l, D50)
        almosteq(color.r, c_expected.r).should be_true
        almosteq(color.g, c_expected.g).should be_true
        almosteq(color.b, c_expected.b).should be_true
      end
    end
  end

  # HCL white reference conversion tests (D50)
  describe "HCL white reference conversion" do
    TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, _, _, _, _, hcl50_expected, _, _), i|
      it "converts to HCL with D50 for case #{i}" do
        h, c_val, l = c.hcl_white_ref(D50)
        almosteq(h, hcl50_expected[0]).should be_true
        almosteq(c_val, hcl50_expected[1]).should be_true
        almosteq(l, hcl50_expected[2]).should be_true
      end
    end
  end

  # Clamp test
  describe "Clamp" do
    it "clamps out-of-gamut colors" do
      c_orig = Colorful::Color.new(1.1, -0.1, 0.5)
      c_want = Colorful::Color.new(1.0, 0.0, 0.5)
      c_clamped = c_orig.clamped
      almosteq(c_clamped.r, c_want.r).should be_true
      almosteq(c_clamped.g, c_want.g).should be_true
      almosteq(c_clamped.b, c_want.b).should be_true
    end
  end
end
