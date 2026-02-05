# colorful

A Crystal library for working with colors in various color spaces. This is a port of the Go library [go-colorful](https://github.com/lucasb-eyer/go-colorful) by Lucas Beyer.

**Note: This is a work-in-progress port.** Not all features from the original Go library are implemented yet.

## Features

- **RGB**: Red, Green and Blue in [0..1]
- **Hex RGB**: The web color format (e.g., `#FF00FF`)
- **CIE-L\*u\*v\***: A perceptually uniform color space where distances are meaningful
- **Blending in Luv space**: Smooth color interpolation using perceptual color space
- **SRGB to Linear RGB conversion**: For gamma-correct rendering

Planned features (from the original go-colorful):
- **HSL**, **HSV**: Legacy color spaces
- **CIE-XYZ**, **CIE-xyY**: Standard color spaces
- **CIE-L\*a\*b\***: Another perceptually uniform color space
- **CIE-L\*C\*h° (HCL)**: Polar representation of Lab (better HSV)
- **HSLuv**, **HPLuv**: Human-friendly alternatives to HSL
- **Oklab**, **Oklch**: Modern perceptual color spaces
- Color distance calculations (CIE76, CIE94, CIEDE2000)
- Random color generation with constraints
- Color palette generation

## Why use colorful?

When you need to work with colors in a way that matches human perception rather than screen representation. RGB distance doesn't correspond to visual distance - two colors with the same RGB distance can look very different. Colorful provides color spaces (like CIE-L\*u\*v\* and CIE-L\*a\*b\*) where distances are perceptually meaningful.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     colorful:
       github: dsisnero/colorful
   ```

2. Run `shards install`

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
- Basic Color struct with RGB values
- Hex color parsing and formatting
- CIE-L\*u\*v\* color space conversion
- Luv space blending
- SRGB/Linear RGB conversion

Coming soon: Other color spaces, distance calculations, palette generation, etc.

## Contributing

1. Fork it (<https://github.com/dsisnero/colorful/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

When contributing, please:
- Follow Crystal coding conventions (snake_case, CamelCase)
- Add specs for new functionality
- Port tests from the original Go library when possible
- See [AGENTS.md](AGENTS.md) for detailed contribution guidelines

## Credits

- Original Go library: [go-colorful](https://github.com/lucasb-eyer/go-colorful) by Lucas Beyer
- Port maintainer: [dsisnero](https://github.com/dsisnero)

## License

MIT - see [LICENSE](LICENSE) for details.
