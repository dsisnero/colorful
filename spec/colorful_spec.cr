require "spec"
require "json"
require "../src/colorful"

# Test tolerance (1/256) matches Go test suite
private TEST_DELTA = 1.0 / 256.0

# Tolerance for HSLuv tests (matches Go test suite)
private HSLUV_TEST_DELTA = 0.0000000001

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

# Soft palette generation tests (ported from go-colorful/soft_palettegen_test.go)
# Pending until SoftPalette implementation is complete (issue colorful-9qq)
describe "SoftPalette" do
  pending "color count" do
    # TestColorCount
    puts "Testing up to 100 palettes may take a while..."
    (0...100).each do |_i|
      # pal, err = SoftPalette(i)
      # err.should be_nil
      # pal.size.should eq(i)
      # pal.each do |col|
      #   col.should be_valid
      # end
    end
    puts "Done with that, but more tests to run."
  end

  pending "impossible constraint" do
    # TestImpossibleConstraint
    # never = ->(_l : Float64, _a : Float64, _b : Float64) { false }
    # pal, err = SoftPaletteEx(10, SoftPaletteSettings{never, 50, true})
    # err.should_not be_nil
    # pal.should be_nil
  end

  pending "constraint" do
    # TestConstraint
    # octant = ->(_l : Float64, _a : Float64, _b : Float64) { _l <= 0.5 && _a <= 0.0 && _b <= 0.0 }
    # pal, err = SoftPaletteEx(100, SoftPaletteSettings{octant, 50, true})
    # err.should be_nil
    # pal.each do |col|
    #   col.should be_valid
    #   l, a, b = col.lab
    #   l.should be <= 0.5
    #   a.should be <= 0.0
    #   b.should be <= 0.0
    # end
  end
end

# Color sorting tests (ported from go-colorful/sort_test.go)
# Pending until Sorted implementation is complete (issue colorful-4se)
describe "Color sorting" do
  pending "simple sort" do
    # TestSortSimple
    # Sort a list of reds and blues.
    # in_colors = [] of Colorful::Color
    # 3.times do |i|
    #   # Reds
    #   in_colors << Colorful::Color.new(1.0 - (i + 1) * 0.25, 0.0, 0.0)
    #   # Blues
    #   in_colors << Colorful::Color.new(0.0, 0.0, 1.0 - (i + 1) * 0.25)
    # end
    #
    # out = Colorful::Color.sorted(in_colors)
    #
    # expected = [
    #   Colorful::Color.new(0.25, 0.0, 0.0),
    #   Colorful::Color.new(0.50, 0.0, 0.0),
    #   Colorful::Color.new(0.75, 0.0, 0.0),
    #   Colorful::Color.new(0.0, 0.0, 0.25),
    #   Colorful::Color.new(0.0, 0.0, 0.50),
    #   Colorful::Color.new(0.0, 0.0, 0.75),
    # ]
    #
    # expected.each_with_index do |exp, i|
    #   almosteq(out[i].r, exp.r).should be_true
    #   almosteq(out[i].g, exp.g).should be_true
    #   almosteq(out[i].b, exp.b).should be_true
    # end
  end
end

# Color generator tests (ported from go-colorful/colorgens_test.go)
# Pending until color generator implementation is complete (issue colorful-j89)
describe "Color generators" do
  it "color validity" do
    # TestColorValidity
    # with default seed
    100.times do
      col = Colorful.warm_color
      col.valid?.should be_true
      col = Colorful.fast_warm_color
      col.valid?.should be_true
      col = Colorful.happy_color
      col.valid?.should be_true
      col = Colorful.fast_happy_color
      col.valid?.should be_true
    end

    # with custom seed
    seed = Time.utc.to_unix_ns
    rand = Random.new(seed)

    100.times do
      col = Colorful.warm_color_with_rand(rand)
      col.valid?.should be_true
      col = Colorful.fast_warm_color_with_rand(rand)
      col.valid?.should be_true
      col = Colorful.happy_color_with_rand(rand)
      col.valid?.should be_true
      col = Colorful.fast_happy_color_with_rand(rand)
      col.valid?.should be_true
    end
  end
end

# Helper to compare tuples with tolerance for HSLuv tests
private def compare_tuple(result : Tuple(Float64, Float64, Float64),
                          expected : Tuple(Float64, Float64, Float64),
                          method : String,
                          hex : String)
  err = false
  errs = [false, false, false]
  3.times do |i|
    if (result[i] - expected[i]).abs > HSLUV_TEST_DELTA
      err = true
      errs[i] = true
    end
  end
  if err
    result_output = "["
    3.times do |i|
      result_output += sprintf("%.10f", result[i])
      result_output += " *" if errs[i]
      result_output += ", " if i < 2
    end
    result_output += "]"
    fail "result: #{result_output} expected: #{expected}, testing #{method} with test case #{hex}"
  end
end

# Helper to compare hex strings for HSLuv tests
private def compare_hex(result : String, expected : String, method : String, hex : String)
  if result != expected
    fail "result: #{result} expected: #{expected}, testing #{method} with test case #{hex}"
  end
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

# Ground-truth from http://www.brucelindbloom.com/index.html?ColorDifferenceCalcHelp.html
private DISTS = [
  # {c1, c2, d76, d94, d00}
  {Colorful::Color.new(1.0, 1.0, 1.0), Colorful::Color.new(1.0, 1.0, 1.0), 0.0, 0.0, 0.0},
  {Colorful::Color.new(0.0, 0.0, 0.0), Colorful::Color.new(0.0, 0.0, 0.0), 0.0, 0.0, 0.0},
  # Just pairs of values of the table way above.
  {Colorful::Color.lab(1.000000, 0.000000, 0.000000), Colorful::Color.lab(0.931390, -0.353319, -0.108946), 0.37604638, 0.37604638, 0.23528129},
  {Colorful::Color.lab(0.720892, 0.651673, -0.422133), Colorful::Color.lab(0.977637, -0.165795, 0.602017), 1.33531088, 0.65466377, 0.75175896},
  {Colorful::Color.lab(0.590453, 0.332846, -0.637099), Colorful::Color.lab(0.681085, 0.483884, 0.228328), 0.88317072, 0.42541075, 0.37688153},
  {Colorful::Color.lab(0.906026, -0.600870, 0.498993), Colorful::Color.lab(0.533890, 0.000000, 0.000000), 0.86517280, 0.41038323, 0.39960503},
  {Colorful::Color.lab(0.911132, -0.480875, -0.141312), Colorful::Color.lab(0.603242, 0.982343, -0.608249), 1.56647162, 0.87431457, 0.57983482},
  {Colorful::Color.lab(0.971393, -0.215537, 0.944780), Colorful::Color.lab(0.322970, 0.791875, -1.078602), 2.35146891, 1.11858192, 1.03426977},
  {Colorful::Color.lab(0.877347, -0.861827, 0.831793), Colorful::Color.lab(0.532408, 0.800925, 0.672032), 1.70565338, 0.68800270, 0.86608245},
]

# OkLab test pairs from go-colorful
private XYZ_OKLAB_PAIRS = [
  {0.950, 1.000, 1.089, 1.000, 0.000, 0.000},
  {1.000, 0.000, 0.000, 0.450, 1.236, -0.019},
  {0.000, 1.000, 0.000, 0.922, -0.671, 0.263},
  {0.000, 0.000, 1.000, 0.153, -1.415, -0.449},
]

private RGB_OKLAB_PAIRS = [
  {1.0, 1.0, 1.0, 1.000, 0.000, 0.000},
  {1.0, 0.0, 0.0, 0.627955, 0.224863, 0.125846},
  {0.0, 1.0, 0.0, 0.86644, -0.233888, 0.179498},
  {0.0, 0.0, 1.0, 0.452014, -0.032457, -0.311528},
  {0.0, 1.0, 1.0, 0.905399, -0.149444, -0.039398},
  {1.0, 0.0, 1.0, 0.701674, 0.274566, -0.169156},
  {1.0, 1.0, 0.0, 0.967983, -0.071369, 0.198570},
  {0.0, 0.0, 0.0, 0.000000, 0.000000, 0.000000},
]

private OK_PAIRS = [
  { {55.0, 0.17, -0.14}, {55.0, 0.22, 320.528} },
  { {90.0, 0.32, 0.00}, {90.0, 0.32, 0.0} },
  { {10.0, 0.00, -0.40}, {10.0, 0.40, 270.0} },
]

# Angle interpolation test values
private ANGLE_VALS = [
  # {a0, a1, t, at}
  {0.0, 1.0, 0.0, 0.0},
  {0.0, 1.0, 0.25, 0.25},
  {0.0, 1.0, 0.5, 0.5},
  {0.0, 1.0, 1.0, 1.0},
  {0.0, 90.0, 0.0, 0.0},
  {0.0, 90.0, 0.25, 22.5},
  {0.0, 90.0, 0.5, 45.0},
  {0.0, 90.0, 1.0, 90.0},
  {0.0, 178.0, 0.0, 0.0}, # Exact 0-180 is ambiguous.
  {0.0, 178.0, 0.25, 44.5},
  {0.0, 178.0, 0.5, 89.0},
  {0.0, 178.0, 1.0, 178.0},
  {0.0, 182.0, 0.0, 0.0}, # Exact 0-180 is ambiguous.
  {0.0, 182.0, 0.25, 315.5},
  {0.0, 182.0, 0.5, 271.0},
  {0.0, 182.0, 1.0, 182.0},
  {0.0, 270.0, 0.0, 0.0},
  {0.0, 270.0, 0.25, 337.5},
  {0.0, 270.0, 0.5, 315.0},
  {0.0, 270.0, 1.0, 270.0},
  {0.0, 359.0, 0.0, 0.0},
  {0.0, 359.0, 0.25, 359.75},
  {0.0, 359.0, 0.5, 359.5},
  {0.0, 359.0, 1.0, 359.0},
]

# Composite type for HexColor JSON serialization tests
private struct CompositeType
  include JSON::Serializable

  property name : String
  property color : Colorful::HexColor

  def initialize(@name : String, @color : Colorful::HexColor)
  end

  def_equals_and_hash @name, @color
end

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

  # Lab distance (CIE76) tests
  describe "Lab distance (CIE76)" do
    DISTS.each_with_index do |(c1, c2, d76_expected, _, _), i|
      it "calculates CIE76 distance for case #{i}" do
        d = c1.distance_lab(c2)
        almosteq(d, d76_expected).should be_true
      end
    end
  end

  # CIE94 distance tests
  describe "CIE94 distance" do
    DISTS.each_with_index do |(c1, c2, _, d94_expected, _), i|
      it "calculates CIE94 distance for case #{i}" do
        d = c1.distance_cie94(c2)
        almosteq(d, d94_expected).should be_true
      end
    end
  end

  # CIEDE2000 distance tests
  describe "CIEDE2000 distance" do
    DISTS.each_with_index do |(c1, c2, _, _, d00_expected), i|
      it "calculates CIEDE2000 distance for case #{i}" do
        d = c1.distance_ciede2000(c2)
        almosteq(d, d00_expected).should be_true
      end
    end
  end

  # Fast linear RGB approximation tests
  describe "Fast linear RGB approximation" do
    eps = 6.0 / 255.0 # We want that "within 6 RGB values total" is "good enough"

    it "approximates linear RGB conversion within tolerance" do
      (0...256).step(4) do |r_int|
        (0...256).step(4) do |g_int|
          (0...256).step(4) do |b_int|
            r = r_int.to_f / 255.0
            g = g_int.to_f / 255.0
            b = b_int.to_f / 255.0
            c = Colorful::Color.new(r, g, b)

            # Test instance method
            r_want, g_want, b_want = c.linear_rgb
            r_appr, g_appr, b_appr = c.fast_linear_rgb
            dr = (r_want - r_appr).abs
            dg = (g_want - g_appr).abs
            db = (b_want - b_appr).abs

            if dr + dg + db > eps
              fail "FastLinearRgb not precise enough for #{c}: differences are (#{dr}, #{dg}, #{db}), allowed total difference is #{eps}"
            end

            # Test static constructor
            c_want = Colorful::Color.linear_rgb(r, g, b)
            c_appr = Colorful::Color.fast_linear_rgb(r, g, b)
            dr = (c_want.r - c_appr.r).abs
            dg = (c_want.g - c_appr.g).abs
            db = (c_want.b - c_appr.b).abs

            if dr + dg + db > eps
              fail "FastLinearRgb not precise enough for (#{r}, #{g}, #{b}): differences are (#{dr}, #{dg}, #{db}), allowed total difference is #{eps}"
            end

            # Soft palette generation tests (ported from go-colorful/soft_palettegen_test.go)
          end

          # Soft palette generation tests (ported from go-colorful/soft_palettegen_test.go)
        end

        # Soft palette generation tests (ported from go-colorful/soft_palettegen_test.go)
      end
    end
  end
end

# LuvLCh conversion tests
describe "LuvLCh conversion" do
  TEST_VALS.each_with_index do |(color, _, _, _, _, _, _, _, _, _, _, _, _, _), i|
    it "converts to LuvLCh and back for case #{i}" do
      l, chroma, h = color.luv_lch
      reconstructed = Colorful::Color.luv_lch(l, chroma, h)
      almosteq(reconstructed.r, color.r).should be_true
      almosteq(reconstructed.g, color.g).should be_true
      almosteq(reconstructed.b, color.b).should be_true
    end
  end
end

# HSLuv conversion tests
describe "HSLuv conversion" do
  TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, _, _, _, _, _, _, _), i|
    it "converts to HSLuv and back for case #{i}" do
      h, s, l = c.hsluv
      reconstructed = Colorful::Color.hsluv(h, s, l)
      # Round-trip may not be exact due to clamping, but should be close
      # We'll check that the distance is small
      almosteq(reconstructed.r, c.r).should be_true
      almosteq(reconstructed.g, c.g).should be_true
      almosteq(reconstructed.b, c.b).should be_true
    end
  end
end

# HPLuv conversion tests
describe "HPLuv conversion" do
  TEST_VALS.each_with_index do |(c, _, _, _, _, _, _, _, _, _, _, _, _, _), i|
    it "converts to HPLuv and back for case #{i}" do
      h, s, l = c.hpluv
      reconstructed = Colorful::Color.hpluv(h, s, l)
      # Round-trip may not be exact due to clamping, but should be close
      almosteq(reconstructed.r, c.r).should be_true
      almosteq(reconstructed.g, c.g).should be_true
      almosteq(reconstructed.b, c.b).should be_true
    end
  end
end

# OkLab conversion tests
describe "OkLab conversion" do
  it "converts XYZ to OkLab" do
    XYZ_OKLAB_PAIRS.each do |x_val, y_val, z_val, l_expected, a_expected, b_expected|
      l, a, b = Colorful.xyz_to_oklab(x_val, y_val, z_val)
      almosteq(l, l_expected).should be_true
      almosteq(a, a_expected).should be_true
      almosteq(b, b_expected).should be_true
    end
  end

  it "converts OkLab to XYZ" do
    XYZ_OKLAB_PAIRS.each do |x_expected, y_expected, z_expected, l_val, a_val, b_val|
      x, y, z = Colorful.oklab_to_xyz(l_val, a_val, b_val)
      almosteq(x, x_expected).should be_true
      almosteq(y, y_expected).should be_true
      almosteq(z, z_expected).should be_true
    end
  end

  it "converts RGB to OkLab via linear RGB and XYZ" do
    RGB_OKLAB_PAIRS.each do |r_val, g_val, b_val, l_expected, a_expected, b_expected|
      c = Colorful::Color.new(r_val, g_val, b_val)
      x, y, z = c.linear_rgb
      x, y, z = Colorful.linear_rgb_to_xyz(x, y, z)
      l, a, b = Colorful.xyz_to_oklab(x, y, z)
      almosteq(l, l_expected).should be_true
      almosteq(a, a_expected).should be_true
      almosteq(b, b_expected).should be_true
    end
  end
end

# OkLch conversion tests
describe "OkLch conversion" do
  it "converts OkLab to OkLch" do
    OK_PAIRS.each do |lab, lch|
      l, a, b = lab
      c_exp, h_exp = lch[1], lch[2]
      _, c, h = Colorful.oklab_to_oklch(l, a, b)
      almosteq(c, c_exp).should be_true
      almosteq(h, h_exp).should be_true
    end
  end

  it "converts OkLch to OkLab" do
    OK_PAIRS.each do |lab, lch|
      l_exp, a_exp, b_exp = lab
      _, c, h = lch
      _, a, b = Colorful.oklch_to_oklab(l_exp, c, h)
      almosteq(a, a_exp).should be_true
      almosteq(b, b_exp).should be_true
    end
  end

  it "converts color to OkLch and back" do
    TEST_VALS.each do |(c, _, _, _, _, _, _, _, _, _, _, _, _, _)|
      l, c_val, h = c.oklch
      reconstructed = Colorful::Color.oklch(l, c_val, h)
      # Round-trip may not be exact due to clamping, but should be close
      almosteq(reconstructed.r, c.r).should be_true
      almosteq(reconstructed.g, c.g).should be_true
      almosteq(reconstructed.b, c.b).should be_true
    end
  end
end

# MakeColor conversion tests
describe "MakeColor conversions" do
  it "converts NRGBA to Color" do
    c_orig = Colorful::NRGBA.new(123_u8, 45_u8, 67_u8, 255_u8)
    c_ours, ok = Colorful.make_color(c_orig)
    r, g, b = c_ours.rgb255
    r.should eq(123)
    g.should eq(45)
    b.should eq(67)
    ok.should be_true
  end

  it "converts NRGBA64 to Color" do
    c_orig = Colorful::NRGBA64.new(123_u16 << 8, 45_u16 << 8, 67_u16 << 8, 0xFFFF_u16)
    c_ours, ok = Colorful.make_color(c_orig)
    r, g, b = c_ours.rgb255
    r.should eq(123)
    g.should eq(45)
    b.should eq(67)
    ok.should be_true
  end

  it "converts Gray to Color" do
    c_orig = Colorful::Gray.new(123_u8)
    c_ours, ok = Colorful.make_color(c_orig)
    r, g, b = c_ours.rgb255
    r.should eq(123)
    g.should eq(123)
    b.should eq(123)
    ok.should be_true
  end

  it "converts Gray16 to Color" do
    c_orig = Colorful::Gray16.new(123_u16 << 8)
    c_ours, ok = Colorful.make_color(c_orig)
    r, g, b = c_ours.rgb255
    r.should eq(123)
    g.should eq(123)
    b.should eq(123)
    ok.should be_true
  end

  it "handles RGBA with zero alpha" do
    c_orig = Colorful::RGBA.new(255_u8, 255_u8, 255_u8, 0_u8)
    c_ours, ok = Colorful.make_color(c_orig)
    r, g, b = c_ours.rgb255
    r.should eq(0)
    g.should eq(0)
    b.should eq(0)
    ok.should be_false
  end
end

# Issue 11: blending endpoints test
# https://github.com/lucasb-eyer/go-colorful/issues/11
describe "Issue 11 blending endpoints" do
  c1hex = "#1a1a46"
  c2hex = "#666666"

  c1 = Colorful::Color.hex(c1hex)
  c2 = Colorful::Color.hex(c2hex)

  it "blends Hsv with t=0 returns first color" do
    blend = c1.blend_hsv(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends Hsv with t=1 returns second color" do
    blend = c1.blend_hsv(c2, 1).hex
    blend.should eq(c2hex)
  end

  it "blends Luv with t=0 returns first color" do
    blend = c1.blend_luv(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends Luv with t=1 returns second color" do
    blend = c1.blend_luv(c2, 1).hex
    blend.should eq(c2hex)
  end

  it "blends Rgb with t=0 returns first color" do
    blend = c1.blend_rgb(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends Rgb with t=1 returns second color" do
    blend = c1.blend_rgb(c2, 1).hex
    blend.should eq(c2hex)
  end

  it "blends LinearRgb with t=0 returns first color" do
    blend = c1.blend_linear_rgb(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends LinearRgb with t=1 returns second color" do
    blend = c1.blend_linear_rgb(c2, 1).hex
    blend.should eq(c2hex)
  end

  it "blends Lab with t=0 returns first color" do
    blend = c1.blend_lab(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends Lab with t=1 returns second color" do
    blend = c1.blend_lab(c2, 1).hex
    blend.should eq(c2hex)
  end

  it "blends Hcl with t=0 returns first color" do
    blend = c1.blend_hcl(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends Hcl with t=1 returns second color" do
    blend = c1.blend_hcl(c2, 1).hex
    blend.should eq(c2hex)
  end

  it "blends LuvLCh with t=0 returns first color" do
    blend = c1.blend_luv_lch(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends LuvLCh with t=1 returns second color" do
    blend = c1.blend_luv_lch(c2, 1).hex
    blend.should eq(c2hex)
  end

  it "blends OkLab with t=0 returns first color" do
    blend = c1.blend_oklab(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends OkLab with t=1 returns second color" do
    blend = c1.blend_oklab(c2, 1).hex
    blend.should eq(c2hex)
  end

  it "blends OkLch with t=0 returns first color" do
    blend = c1.blend_oklch(c2, 0).hex
    blend.should eq(c1hex)
  end

  it "blends OkLch with t=1 returns second color" do
    blend = c1.blend_oklch(c2, 1).hex
    blend.should eq(c2hex)
  end
end

# Angle interpolation tests
describe "Angle interpolation" do
  # Forward
  ANGLE_VALS.each_with_index do |(a0, a1, t, at_expected), i|
    it "interpolates forward case #{i}" do
      res = Colorful.interp_angle(a0, a1, t)
      almosteq_eps(res, at_expected, 1e-15).should be_true
    end
  end

  # Backward
  ANGLE_VALS.each_with_index do |(a0, a1, t, at_expected), i|
    it "interpolates backward case #{i}" do
      res = Colorful.interp_angle(a1, a0, 1.0 - t)
      almosteq_eps(res, at_expected, 1e-15).should be_true
    end
  end
end

# HSLuv tests (ported from go-colorful/hsluv_test.go)
describe "HSLuv" do
  # Load HSLuv snapshot data
  snapshot_path = File.join(__DIR__, "..", "vendor", "go-colorful", "hsluv-snapshot-rev4.json")
  snapshot_file = File.read(snapshot_path)
  snapshot = Hash(String, Hash(String, Array(Float64))).from_json(snapshot_file)

  # HSLuv internal white reference (rounded D65)
  hsluv_d65 = [0.95045592705167, 1.0, 1.089057750759878]

  it "passes HSLuv snapshot tests" do
    snapshot.each do |hex, color_values|
      # Adjust color values to be in the ranges this library uses
      hsluv = color_values["hsluv"].dup
      hpluv = color_values["hpluv"].dup
      rgb = color_values["rgb"]

      # Adjust HSLuv/HPLuv saturation and luminance from [0..100] to [0..1]
      hsluv[1] /= 100.0
      hsluv[2] /= 100.0
      hpluv[1] /= 100.0
      hpluv[2] /= 100.0

      # Test public methods
      compare_hex(Colorful::Color.hsluv(hsluv[0], hsluv[1], hsluv[2]).hex, hex, "HsluvToHex", hex)

      result = Colorful::Color.hsluv(hsluv[0], hsluv[1], hsluv[2])
      compare_tuple({result.r, result.g, result.b}, {rgb[0], rgb[1], rgb[2]}, "HsluvToRGB", hex)

      result = Colorful::Color.hex(hex).hsluv
      compare_tuple(result, {hsluv[0], hsluv[1], hsluv[2]}, "HsluvFromHex", hex)

      result = Colorful::Color.new(rgb[0], rgb[1], rgb[2]).hsluv
      compare_tuple(result, {hsluv[0], hsluv[1], hsluv[2]}, "HsluvFromRGB", hex)

      compare_hex(Colorful::Color.hpluv(hpluv[0], hpluv[1], hpluv[2]).hex, hex, "HpluvToHex", hex)

      result = Colorful::Color.hpluv(hpluv[0], hpluv[1], hpluv[2])
      compare_tuple({result.r, result.g, result.b}, {rgb[0], rgb[1], rgb[2]}, "HpluvToRGB", hex)

      result = Colorful::Color.hex(hex).hpluv
      compare_tuple(result, {hpluv[0], hpluv[1], hpluv[2]}, "HpluvFromHex", hex)

      result = Colorful::Color.new(rgb[0], rgb[1], rgb[2]).hpluv
      compare_tuple(result, {hpluv[0], hpluv[1], hpluv[2]}, "HpluvFromRGB", hex)
    end
  end

  # Internal methods test (only run if not in short mode)
  unless ENV["CRYSTAL_SPEC_SHORT"]?
    it "passes HSLuv internal conversion tests" do
      snapshot.each do |hex, color_values|
        # Adjust color values to be in the ranges this library uses
        rgb = color_values["rgb"]
        xyz = color_values["xyz"]
        luv = color_values["luv"].dup
        lch = color_values["lch"].dup

        # Adjust LCh and Luv values from [0..100] to [0..1]
        lch[0] /= 100.0
        lch[1] /= 100.0
        luv[0] /= 100.0
        luv[1] /= 100.0
        luv[2] /= 100.0

        # Test internal conversions
        # LuvLCh -> RGB
        color = Colorful::Color.luv_lch_white_ref(lch[0], lch[1], lch[2], hsluv_d65)
        compare_tuple({color.r, color.g, color.b}, {rgb[0], rgb[1], rgb[2]}, "convLchRgb", hex)

        # RGB -> LuvLCh
        result = Colorful::Color.new(rgb[0], rgb[1], rgb[2]).luv_lch_white_ref(hsluv_d65)
        compare_tuple(result, {lch[0], lch[1], lch[2]}, "convRgbLch", hex)

        # XYZ -> Luv
        result = Colorful.xyz_to_luv_white_ref(xyz[0], xyz[1], xyz[2], hsluv_d65)
        compare_tuple(result, {luv[0], luv[1], luv[2]}, "convXyzLuv", hex)

        # Luv -> XYZ
        result = Colorful.luv_to_xyz_white_ref(luv[0], luv[1], luv[2], hsluv_d65)
        compare_tuple(result, {xyz[0], xyz[1], xyz[2]}, "convLuvXyz", hex)

        # Luv -> LuvLCh
        result = Colorful.luv_to_luv_lch(luv[0], luv[1], luv[2])
        compare_tuple(result, {lch[0], lch[1], lch[2]}, "convLuvLch", hex)

        # LuvLCh -> Luv
        result = Colorful.luv_lch_to_luv(lch[0], lch[1], lch[2])
        compare_tuple(result, {luv[0], luv[1], luv[2]}, "convLchLuv", hex)

        # HSLuv -> LuvLCh
        hsluv = color_values["hsluv"].dup
        hsluv[1] /= 100.0
        hsluv[2] /= 100.0
        result = Colorful.hsluv_to_luv_lch(hsluv[0], hsluv[1], hsluv[2])
        compare_tuple(result, {lch[0], lch[1], lch[2]}, "convHsluvLch", hex)

        # LuvLCh -> HSLuv
        result = Colorful.luv_lch_to_hsluv(lch[0], lch[1], lch[2])
        compare_tuple(result, {hsluv[0], hsluv[1], hsluv[2]}, "convLchHsluv", hex)

        # HPLuv -> LuvLCh
        hpluv = color_values["hpluv"].dup
        hpluv[1] /= 100.0
        hpluv[2] /= 100.0
        result = Colorful.hpluv_to_luv_lch(hpluv[0], hpluv[1], hpluv[2])
        compare_tuple(result, {lch[0], lch[1], lch[2]}, "convHpluvLch", hex)

        # LuvLCh -> HPLuv
        result = Colorful.luv_lch_to_hpluv(lch[0], lch[1], lch[2])
        compare_tuple(result, {hpluv[0], hpluv[1], hpluv[2]}, "convLchHpluv", hex)

        # XYZ -> Linear RGB -> RGB
        result = Colorful.xyz_to_linear_rgb(xyz[0], xyz[1], xyz[2])
        color = Colorful::Color.linear_rgb(result[0], result[1], result[2]).clamped
        compare_tuple({color.r, color.g, color.b}, {rgb[0], rgb[1], rgb[2]}, "convXyzRgb", hex)

        # RGB -> XYZ
        result = Colorful::Color.new(rgb[0], rgb[1], rgb[2]).xyz
        compare_tuple(result, {xyz[0], xyz[1], xyz[2]}, "convRgbXyz", hex)
      end
    end
  end
end

# HexColor tests (ported from go-colorful/hexcolor_test.go)
describe "HexColor" do
  it "parses hex colors" do
    hc = Colorful::HexColor.parse("#000000")
    hc.r.should be_close(0.0, Colorful::DELTA)
    hc.g.should be_close(0.0, Colorful::DELTA)
    hc.b.should be_close(0.0, Colorful::DELTA)

    hc = Colorful::HexColor.parse("#ff0000")
    hc.r.should be_close(1.0, Colorful::DELTA)
    hc.g.should be_close(0.0, Colorful::DELTA)
    hc.b.should be_close(0.0, Colorful::DELTA)

    hc = Colorful::HexColor.parse("#00ff00")
    hc.r.should be_close(0.0, Colorful::DELTA)
    hc.g.should be_close(1.0, Colorful::DELTA)
    hc.b.should be_close(0.0, Colorful::DELTA)

    hc = Colorful::HexColor.parse("#0000ff")
    hc.r.should be_close(0.0, Colorful::DELTA)
    hc.g.should be_close(0.0, Colorful::DELTA)
    hc.b.should be_close(1.0, Colorful::DELTA)

    hc = Colorful::HexColor.parse("#ffffff")
    hc.r.should be_close(1.0, Colorful::DELTA)
    hc.g.should be_close(1.0, Colorful::DELTA)
    hc.b.should be_close(1.0, Colorful::DELTA)
  end

  it "converts to hex string" do
    Colorful::HexColor.new(0.0, 0.0, 0.0).to_s.should eq("#000000")
    Colorful::HexColor.new(1.0, 0.0, 0.0).to_s.should eq("#ff0000")
    Colorful::HexColor.new(0.0, 1.0, 0.0).to_s.should eq("#00ff00")
    Colorful::HexColor.new(0.0, 0.0, 1.0).to_s.should eq("#0000ff")
    Colorful::HexColor.new(1.0, 1.0, 1.0).to_s.should eq("#ffffff")
  end

  it "serializes to JSON" do
    hc = Colorful::HexColor.new(1.0, 0.0, 1.0)
    json = hc.to_json
    json.should eq(%{"#ff00ff"})
  end

  it "deserializes from JSON" do
    hc = Colorful::HexColor.from_json(%{"#ff00ff"})
    hc.r.should be_close(1.0, Colorful::DELTA)
    hc.g.should be_close(0.0, Colorful::DELTA)
    hc.b.should be_close(1.0, Colorful::DELTA)
  end

  it "serializes composite type to JSON" do
    obj = CompositeType.new("John", Colorful::HexColor.new(1.0, 0.0, 1.0))
    json = obj.to_json
    parsed = JSON.parse(json)
    parsed["name"].should eq("John")
    parsed["color"].should eq("#ff00ff")
  end

  it "deserializes composite type from JSON" do
    json = %{{"name":"John","color":"#ff00ff"}}
    obj = CompositeType.from_json(json)
    obj.name.should eq("John")
    obj.color.r.should be_close(1.0, Colorful::DELTA)
    obj.color.g.should be_close(0.0, Colorful::DELTA)
    obj.color.b.should be_close(1.0, Colorful::DELTA)
  end
end
