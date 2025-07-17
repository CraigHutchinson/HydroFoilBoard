# Hydrofoil Board Wing Generator

A sophisticated OpenSCAD-based wing generator designed for creating 3D printable hydrofoil board wings with integrated carbon fiber reinforcement and optimized internal structures.

## Table of Contents

- [About](#about)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Technical Specifications](#technical-specifications)
- [Applications](#applications)
- [Contributing](#contributing)
- [License](#license)

## About

This project is a comprehensive wing generation tool adapted from RC wing generators, specifically designed for hydrofoil board applications. The system combines aerodynamic principles with 3D printing technology to create functional wings with carbon fiber spar integration and weight-optimized internal structures.

**Key Highlights:**
- Based on PNG 1150 hydrofoil specifications (1150mm span, 7.72 aspect ratio)
- Supports both vase-mode and traditional 3D printing
- Integrated carbon fiber spar system with 5 configurable positions
- Uses E818 airfoil optimized for low-speed efficiency
- Advanced customizer interface with slider controls

## Features

### Wing Geometry Options
- **Trapezoidal Wings** - Traditional straight-tapered design
- **Elliptical Wings** - Aerodynamically efficient curved planform with configurable ellipse power
- **Configurable Dimensions** - Customizable span, chord, and tip dimensions
- **Anhedral Support** - Downward wing angle for stability (0-10°)
- **Washout Control** - Progressive twist along wingspan for stall characteristics

### Airfoil System
- **E818 Airfoil** - Low-speed efficiency airfoil as default
- **Multi-Section Support** - Different airfoils for root, mid-section, and tip
- **Airfoil Blending** - Smooth transitions between different airfoil sections
- **Customizable Transition Points** - Configurable change points along wingspan

### 3D Printing Optimization
- **Vase Mode Support** - Single-wall printing for lightweight structures
- **Internal Grid Structures** - Two configurable modes:
  - Diamond grid pattern with adjustable density
  - Spar and cross-rib system with configurable spacing
- **Slice Management** - Controlled gap widths (0.02mm default) for slicer compatibility
- **Automatic Sectioning** - Splits large wings into printable 250mm sections

### Carbon Fiber Integration
- **5 Configurable Spar Holes** - Positions at 15%, 30%, 45%, 60%, and 75% chord
- **Variable Diameters** - 3-5mm holes for different spar thicknesses
- **Precise Positioning** - Percentage-based placement from leading edge
- **Void Clearances** - Proper fit tolerances for spar installation
- **Length Optimization** - Different spar lengths (350-450mm) based on position

### Advanced Features
- **Rib Voids** - Optional weight reduction holes in internal ribs
- **Quality Control** - Separate preview (20 sections) and final render (75 sections) modes
- **Scaling System** - Proportional sizing from 0.1x to 3.0x
- **Customizer Interface** - Organized slider controls for all parameters



## Architecture

The project consists of several specialized modules working together:

### Core Components
- **HydroFoilBoard.scad** - Main configuration file with customizable parameters
- **Wing-Creator.scad** - Core wing generation logic with elliptical and trapezoidal modes
- **Grid-Structure.scad** - Internal support structures (diamond grid and spar systems)
- **Spar-Hole.scad** - Carbon fiber spar integration and void management
- **Helpers.scad** - Mathematical utility functions for wing calculations
- **Rib-Void-Creator.scad** - Weight reduction features
- **Grid-Void-Creator.scad** - Advanced void creation for complex structures
- **Aileron-Creator.scad** - Control surface generation capabilities

### Mathematical Foundations
- **Elliptical Function** - `ChordLengthAtEllipsePosition()` creates smooth chord distribution
- **Quadratic Curve** - `f(i, numPoints, height)` controls wing thickness distribution
- **Washout Calculation** - Progressive twist from root to tip
- **Airfoil Scaling** - Proportional sizing based on local chord length
- **Grid Spacing** - Calculated based on chord length and density factors

### Airfoil Database
- **E818 Airfoil** - Primary airfoil with 916 coordinate points
- **Extensible System** - Support for additional airfoils from m-selig database
- **Path Vectors** - Precise coordinate data for accurate airfoil reproduction


## Installation

### Requirements
- **OpenSCAD** - Main requirement for wing generation
- **BOSL2 Library** - Required for advanced geometric operations
- **Python** (optional) - For airfoil database scraping
- **BeautifulSoup & AeroSandbox** (optional) - For Python scraper functionality

### OpenSCAD Setup
1. Install OpenSCAD from https://openscad.org/downloads.html
2. Install BOSL2 library (included with recent OpenSCAD versions)

### Performance Optimization
**Important:** This is a complex render that takes significant time with standard OpenSCAD. For much faster rendering:

1. Install the newest **Development Snapshot** of OpenSCAD from:
   https://openscad.org/downloads.html#snapshots

2. Enable the Manifold geometry engine:
   - Go to Edit → Preferences
   - Click on Features tab
   - Select "manifold" checkbox
   - **Result:** ~100x faster rendering performance

### Optional Components
For airfoil database scraping:
```bash
pip install beautifulsoup4 aerosandbox
```

For Perl script usage (airfoil conversion):
Refer to https://github.com/guillaumef/openscad-airfoil for instructions.

## Usage

### Quick Start
1. **Open** `HydroFoilBoard.scad` in OpenSCAD
2. **Configure** parameters using the customizer panel (Window → Customizer)
3. **Preview** with F5 (fast, low-resolution preview)
4. **Render** with F6 (high-resolution final output)
5. **Export** STL files for 3D printing

### Configuration Workflow

#### 1. Build Configuration
- **Build_Scale** - Overall size scaling (0.1x to 3.0x)
- **Build_Preview** - Toggle between preview and render modes
- **Design_For_VaseMode** - Enable vase-mode printing optimizations

#### 2. Wing Geometry Settings
- **Wing Mode** - Choose between Trapezoidal (1) or Elliptical (2)
- **Main_Wing_Eliptic_Pow** - Control ellipse shape (1.0-3.0, 2.0 = perfect ellipse)
- **wing_sections** - Resolution quality (20 for preview, 75 for final)
- **MainWing_Center_Line_Perc** - Wing mounting position (0-100%)

#### 3. Airfoil Settings
- **center_airfoil_change_perc** - Where to transition to center airfoil
- **tip_airfoil_change_perc** - Where to transition to tip airfoil
- **slice_transisions** - Number of blending slices between airfoils

#### 4. Wing Washout Settings
- **washout_deg** - Twist amount (0-10°)
- **washout_start** - Distance from root to start washout
- **washout_pivot_perc** - Pivot point for twist (0-100% from LE)

#### 5. Internal Structure Settings
- **add_inner_grid** - Enable internal support structures
- **grid_mode** - Choose Diamond (1) or Spar+Rib (2) pattern
- **grid_size_factor** - Density of internal structures

### Advanced Customization

#### Adding New Airfoils
1. Add airfoil `.scad` file to `lib/openscad-airfoil/` directory
2. Update airfoil includes in main file:
```scad
include <lib/openscad-airfoil/[folder]/[airfoil].scad>
```
3. Modify airfoil polygon modules:
```scad
module RootAirfoilPolygon() {
    [your_airfoil]();
}
```

#### Carbon Fiber Spar Configuration
Modify the `spar_holes` array to customize spar positions:
```scad
spar_holes = [
    new_spar(15, 3.0, 350, 0.25),  // 15% chord, 3mm dia, 350mm length
    new_spar(30, 4.0, 400, 0.75),  // 30% chord, 4mm dia, 400mm length
    // ... add more as needed
];
```

### 3D Printing Guidelines

#### Vase Mode Printing
- Enable `Design_For_VaseMode = true`
- Use single-wall vase mode in slicer
- Recommended for lightweight applications
- Requires carbon fiber spars for structural integrity

#### Traditional Printing
- Enable `add_inner_grid = true`
- Choose appropriate `grid_mode` (Diamond or Spar+Rib)
- Adjust `grid_size_factor` for strength vs. weight balance
- Enable `create_rib_voids = true` for weight reduction

#### Multi-Section Printing
- Large wings automatically split into 250mm sections
- Print each section separately
- Assemble with alignment features
- Insert carbon fiber spars through all sections


## Technical Specifications

### Default Configuration
- **Wing Span:** 1150mm (PNG 1150 specification)
- **Aspect Ratio:** 7.72
- **Root Chord:** ~149mm (calculated from span/aspect ratio)
- **Tip Chord:** 50mm (configurable)
- **Airfoil:** E818 (optimized for low-speed efficiency)
- **Anhedral:** 1° (starting at 50% span)
- **Washout:** 1.5° (starting at 60mm from root)

### Structural Elements
- **Carbon Fiber Spars:** 5 positions (15%, 30%, 45%, 60%, 75% chord)
- **Spar Diameters:** 3-5mm (configurable per position)
- **Spar Lengths:** 350-450mm (optimized per position)
- **Diamond Grid:** Configurable density factor (1-10)
- **Rib Spacing:** Configurable for spar+rib mode
- **Print Tolerance:** 0.02mm default gap width

### Performance Parameters
- **Wing Sections:** 20 (preview) / 75 (final render)
- **Airfoil Points:** 916 coordinate points (E818)
- **Render Quality:** Adjustable facet angle (1-10°) and size (0.1-1.0mm)
- **Scale Range:** 0.1x to 3.0x proportional sizing
- **Print Sections:** Automatic 250mm section splitting

### Material Specifications
- **3D Printing:** PLA/PETG recommended for prototypes, CF-reinforced for production
- **Carbon Fiber:** 3-5mm diameter rods/tubes
- **Void Clearance:** Configurable for spar-to-grid interface
- **Wall Thickness:** Single-wall (vase mode) or configurable (traditional)

## Applications

### Primary Use Cases
- **Hydrofoil Boards** - Main intended application
- **Hydrofoil Kites** - Adapted for kite hydrofoils
- **RC Seaplanes** - Water-based radio control aircraft
- **Wind Tunnel Models** - Research and educational testing

### Secondary Applications
- **Educational Projects** - Aerodynamics demonstrations
- **Prototyping** - Rapid iteration of hydrofoil designs
- **Custom Hydrofoils** - Specialized applications with modified parameters
- **Scale Models** - Reduced-size testing and display models

### Performance Characteristics
- **Low-Speed Efficiency** - Optimized for hydrofoil applications (5-30 knots)
- **Structural Integrity** - Carbon fiber reinforcement for operational loads
- **Lightweight Design** - Optimized internal structures for weight reduction
- **Scalable Manufacturing** - 3D printable in sections for any size requirement

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a new branch for your feature or bugfix
3. Make your changes
4. Test thoroughly
5. Submit a pull request describing your changes

## Contributing

We welcome contributions to improve the Hydrofoil Board Wing Generator! Here's how you can help:

### Ways to Contribute
- **Bug Reports** - Submit issues with detailed reproduction steps
- **Feature Requests** - Suggest new functionality or improvements
- **Code Contributions** - Submit pull requests with enhancements
- **Documentation** - Improve documentation and examples
- **Airfoil Database** - Add new airfoil profiles to the library
- **Testing** - Test with different 3D printers and materials

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with detailed description

### Code Style
- Follow OpenSCAD best practices
- Use descriptive variable names
- Include comments for complex calculations
- Maintain consistent indentation
- Update documentation for new features

### Airfoil Contributions
- Use the included Python scraper for m-selig database
- Convert using the Perl script from https://github.com/guillaumef/openscad-airfoil
- Test airfoil integration before submission
- Include performance characteristics in documentation

## License

Please see the "LICENSE" file for license information.

## Acknowledgments

This project builds upon excellent prior work:
- **Wing Construction Technique** - Adapted from Propeller Generator by BouncyMonkey: https://www.thingiverse.com/thing:3506692
- **Airfoil Database** - m-selig coordinate database: http://m-selig.ae.illinois.edu/ads/coord_database.html
- **OpenSCAD Airfoil Library** - Perl script integration: https://github.com/guillaumef/openscad-airfoil
- **AeroSandbox** - Python aerodynamic tools: https://github.com/peterdsharpe/AeroSandbox
- **BOSL2** - OpenSCAD utility library for advanced geometric operations


