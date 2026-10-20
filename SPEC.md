# matgrib figure spec, version 2

The JSON contract between the MATLAB front ends (`matgrib.gg` and the
figure-handle translator `matgrib.figureSpec`) and the renderers
(`matgrib.typ` for Gribouille/Typst, `matgrib.js` for Observable
Plot/HTML).

All statistics, positions (dodge/stack), coordinate flips and downsampling
are resolved in MATLAB. Renderers only draw **primitives** with mapped or
fixed aesthetics, so the PDF and HTML outputs show the same geometry.

MATLAB's `jsonencode` writes one-element arrays as scalars, so renderers
treat any scalar where an array is expected as a one-element array.

## Figure

```jsonc
{
  "matgrib": 2,
  "title": "", "subtitle": "", "caption": "",
  "ncol": 1,                 // panels per row
  "aspect": null,            // facet-cell height / width; null = renderer default
  "panels": [Panel],
  "notes": ["..."]           // e.g. downsampling messages, logged by the engine
}
```

## Panel

```jsonc
{
  "title": "", "subtitle": "", "caption": "",
  "x": Axis, "y": Axis,
  "colour": ColourScale | null,
  "fill": ColourScale | null,
  "legend": "right" | "left" | "top" | "bottom" | "none"
          | "top-right" | "top-left" | "bottom-right" | "bottom-left"
          | "top-center" | "bottom-center" | "right-center" | "left-center",
  "facet": null
         | {"type": "wrap", "ncol": 3, "levels": ["a", "b"], "scales": "fixed"}
         | {"type": "grid", "rows": ["r1"], "cols": ["c1", "c2"], "scales": "fixed"},
  "layers": [Layer]
}
```

`scales` is one of `fixed`, `free`, `free_x`, `free_y`. HTML always draws
fixed scales.

## Axis

```jsonc
{
  "label": "",
  "type": "continuous" | "date" | "discrete",
  "trans": "identity" | "log10" | "reverse",
  "limits": [lo, hi] | [],
  "breaks": [...] | [],
  "labels": ["..."] | [],     // parallel to breaks
  "format": "" | "percent" | "percent:1" | "comma" | "dollar" | "scientific" | "fixed:2"
}
```

* `date`: values are Unix epoch milliseconds (UTC).
* `discrete`: values are positions 1..k; `breaks` are the positions and
  `labels` are the level names.

## Colour scale

```jsonc
{"type": "discrete", "title": "", "levels": ["A", "B"], "values": [Colour, Colour]}
{"type": "continuous", "title": "", "colours": ["#440154", ...], "limits": [] | [lo, hi]}
```

A `Colour` is `"#rrggbb"`, `{"auto": i}` (the i-th colour of the
document palette, 1-based), `"ink"` (the foreground colour) or `"paper"`
(the background colour).

## Layer

```jsonc
{
  "geom": "point" | "path" | "rect" | "ribbon" | "polygon" | "segment"
        | "errorbar" | "text" | "hline" | "vline",
  "data": {"x": [...], "y": [...], ...},   // columnar
  "aes": ["colour"],         // which of colour/fill/group/label columns are mapped
  "legend": true,            // whether mapped colour/fill appears in the legend
  "params": {...}            // fixed aesthetics
}
```

Required columns by geom:

| geom       | columns                                   | notes |
|------------|-------------------------------------------|-------|
| `point`    | `x y`                                     | |
| `path`     | `x y` (+`group`)                          | drawn in data order, never sorted |
| `rect`     | `xmin xmax ymin ymax`                     | |
| `ribbon`   | `x ymin ymax` (+`group`)                  | |
| `polygon`  | `x y` (+`group`)                          | closed implicitly |
| `segment`  | `x y xend yend`                           | |
| `errorbar` | `x ymin ymax`, or `y xmin xmax` if `params.horizontal` | caps drawn by renderer |
| `text`     | `x y label`                               | |
| `hline`    | `y`                                       | one line per row |
| `vline`    | `x`                                       | one line per row |

Optional mapped columns: `colour`, `fill` (level strings for discrete
scales, numbers for continuous ones) and `group`. Facet columns are `facet`
(wrap) or `facet_row` / `facet_col` (grid). A layer without facet columns
is drawn in every facet.

Fixed `params` (all optional): `colour`, `fill` (Colour), `alpha` (0–1),
`size` (point diameter, pt), `linewidth` (pt), `linetype` (`solid`,
`dashed`, `dotted`, `dash-dotted`), `shape` (`circle`, `square`,
`triangle`, `diamond`, `cross`, `x`), `filled` (bool), `fontsize`
(relative to the plot's base text size), `halign` (`left`, `center`,
`right`), `horizontal` (errorbar), `caps` (errorbar, bool).
