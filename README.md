# colorful

A Crystal library for working with colors in various color spaces. This is a port of the Go library [go-colorful](https://github.com/lucasb-eyer/go-colorful) by Lucas Beyer.

**Note: This is a work-in-progress port.** Not all features from the original Go library are implemented yet.

## Features

* **RGB**: Red, Green and Blue in [0..1]
* **Hex RGB**: The web color format (e.g., `#FF00FF`, `#abc`)
* **HSL**, **HSV**: Legacy color spaces
* **CIE-XYZ**, **CIE-xyY**: Standard color spaces
* **CIE-L\*a\*b\***: Another perceptually uniform color space
* **CIE-L\*u\*v\***: A perceptually uniform color space where distances are meaningful
* **CIE-L\*C\*h° (HCL)**: Polar representation of Lab (better HSV)
* **CIE-L\*u\*v\*LCh (LuvLCh)**: Polar representation of Luv
* **HSLuv**, **HPLuv**: Human-friendly alternatives to HSL
* **Oklab**, **Oklch**: Modern perceptual color spaces
* **Color distance calculations**: CIE76, CIE94, CIEDE2000, RGB, Linear RGB, Riemersma, Luv, Lab, HSLuv, HPLuv
* **Blending**: Smooth interpolation in RGB, Linear RGB, HSV, Lab, Luv, HCL, LuvLCh, OkLab, OkLch spaces
* **SRGB to Linear RGB conversion**: For gamma-correct rendering (with fast approximation)
* **Random color generation**: Warm/happy colors with perceptual uniformity constraints
* **Color palette generation**: Soft palette generation using k-means clustering in Lab space
* **Color sorting**: Perceptually meaningful ordering
* **HexColor struct**: JSON/YAML serialization, database/sql compatibility
* **MakeColor**: Conversion from Go standard color types (RGBA, NRGBA, Gray, etc.)

**Porting Status**: This Crystal port is nearly complete, implementing all major features from the original go-colorful library.

**Missing features** (planned for future releases):

* **Happy/Warm palette generators**: `HappyPalette`, `WarmPalette` and their fast variants
* **Additional convenience aliases**: Some Go-specific aliases (e.g., `DistanceCIE76`)

## Why use colorful?

When you need to work with colors in a way that matches human perception rather than screen representation. RGB distance doesn't correspond to visual distance - two colors with the same RGB distance can look very different. Colorful provides color spaces (like CIE-L\*u\*v\* and CIE-L\*a\*b\*) where distances are perceptually meaningful.

## Installation

1.  Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     colorful:
       github: dsisnero/colorful
   ```

2.  Run `shards install`

## Usage

```crystal
require "colorful"

# Create colors from hex
color1 = Colorful.hex("#FF0000")
color2 = Colorful.hex("#00FF00")

# Blend colors in perceptually uniform Luv space
midpoint = color1.blend_luv(color2, 0.5)
puts midpoint.hex  # => "#8a9e5a" (perceptually midway between red and green)

# Create colors directly
color = Colorful::Color.new(0.5, 0.3, 0.8)

# Convert between color spaces
hsl = color.hsl                    # => {hue, saturation, lightness}
lab = color.lab                    # => {L*, a*, b*} (perceptually uniform)
hcl = color.hcl                    # => {hue, chroma, lightness} (polar Lab)
oklab = color.oklab                # => {L, a, b} (modern perceptual space)

# Create colors from other spaces
from_hsl = Colorful::Color.hsl(120.0, 1.0, 0.5)   # Bright green
from_lab = Colorful::Color.lab(0.8, -0.2, 0.1)
from_hcl = Colorful::Color.hcl(90.0, 0.5, 0.7)

# Calculate perceptual distance
distance = color1.distance_lab(color2)   # CIE76 distance
distance_cie94 = color1.distance_cie94(color2)
distance_ciede2000 = color1.distance_ciede2000(color2)

# Generate random colors
warm = Colorful.warm_color                # Random warm color
happy = Colorful.happy_color              # Random bright, happy color

# Generate a soft palette of 5 distinct colors
palette = Colorful.soft_palette(5)

# Serialize colors as JSON
require "json"
hex_color = Colorful::HexColor.new(1.0, 0.0, 0.0)
json = hex_color.to_json                  # => "#ff0000"
```

## Development

This is a Crystal port of the Go library [`go-colorful`](https://github.com/lucasb-eyer/go-colorful). The goal is to implement the full API while following Crystal idioms and best practices.

### Development Setup

```bash
make install      # Install dependencies (requires BEADS_DIR set)
make format       # Check code formatting
make lint         # Run linter (ameba)
make test         # Run tests
```

See [AGENTS.md](AGENTS.md) for detailed development guidelines and workflow.

### Porting Status

Currently implemented:

*   **Core**: Color struct with RGB values, validity checking, clamping
*   **Hex**: Parsing and formatting (short and long forms)
*   **HSL/HSV**: Conversion and creation
*   **CIE-XYZ/xyY**: Conversion and creation (D65 and custom white references)
*   **CIE-Lab/Luv**: Perceptually uniform color spaces (D65 and custom white references)
*   **HCL/LuvLCh**: Polar representations of Lab and Luv
*   **HSLuv/HPLuv**: Human-friendly perceptual color spaces
*   **OkLab/OkLch**: Modern perceptual color spaces
*   **Blending**: RGB, Linear RGB, HSV, Lab, Luv, HCL, LuvLCh, OkLab, OkLch
*   **Distance calculations**: CIE76, CIE94, CIEDE2000, RGB, Linear RGB, Riemersma, Luv, Lab, HSLuv, HPLuv
*   **Random color generation**: Warm/happy colors with perceptual constraints
*   **Color palette generation**: Soft palette generation using k-means clustering
*   **Color sorting**: Perceptually meaningful ordering
*   **Serialization**: HexColor struct with JSON/YAML support, database/sql compatibility
*   **Interoperability**: MakeColor conversion from Go standard color types

The port is nearly complete, with most features from the original go-colorful library implemented.

## Contributing

1.  Fork it (<https://github.com/dsisnero/colorful/fork>)
2.  Create your feature branch (`git checkout -b my-new-feature`)
3.  Commit your changes (`git commit -am 'Add some feature'`)
4.  Push to the branch (`git push origin my-new-feature`)
5.  Create a new Pull Request

When contributing, please:

*   Follow Crystal coding conventions (snake_case, CamelCase)
*   Add specs for new functionality
*   Port tests from the original Go library when possible
*   See [AGENTS.md](AGENTS.md) for detailed contribution guidelines

## Credits

*   Original Go library: [go-colorful](https://github.com/lucasb-eyer/go-colorful) by Lucas Beyer
*   Port maintainer: [dsisnero](https://github.com/dsisnero)

## License

MIT - see [LICENSE](LICENSE) for details.
