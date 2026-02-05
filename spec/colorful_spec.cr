require "spec"
require "../src/colorful"

describe Colorful::Color do
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
end
