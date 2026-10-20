# matgrib

MATLAB figures for [Quarto](https://quarto.org) documents, drawn natively:
by [Gribouille](https://typst.app/universe/package/gribouille/) in Typst/PDF
output and by [Observable Plot](https://observablehq.com/plot/) in HTML.
They are not pasted-in PNGs.

Figures pick up the document's font, size, palette and column width. The PDF
version is vector and typeset with the text. The HTML version resizes with the
page, follows dark mode and has tooltips.

matgrib is a Quarto **engine extension** (`engine: matlab`). It runs your
`{matlab}` cells, without Jupyter, and turns their figures into native ones.
There are two ways to make a figure:

* **`matgrib.gg`**, a grammar-of-graphics DSL for MATLAB, in the style of ggplot2:

  ```matlab
  matgrib.gg(T, x="date", y="nav", colour="strategy") ...
      .line() ...
      .smooth(method="loess") ...
      .facet("region") ...
      .labs(title="Strategy NAV", y="Index level")
  ```

* **Plain MATLAB plotting code** (`plot`, `bar`, `histogram`, `scatter`,
  `tiledlayout`, ...). It is translated from the figure handles. Anything the
  translator doesn't know (`surf`, `imagesc`, `contour`, ...) falls back to a
  vector image, so figures never silently disappear.

See [`example.qmd`](example.qmd) for a tour.

## Install

```bash
quarto add sswatson/matgrib
```

This copies the extension into the project's `_extensions/` folder. It
requires:

* Quarto ≥ 1.9 (for engine extensions)
* MATLAB on `PATH`, or `QUARTO_MATLAB=/path/to/matlab`. Base MATLAB is
  enough; no toolboxes are needed.

Everything else ships with the extension: the MATLAB package, the Typst
renderer, and the HTML renderer with d3 and Observable Plot vendored, so
there is no CDN at render or view time. Typst downloads
`@preview/gribouille` from Typst Universe on the first PDF render and caches
it.

## Use

```yaml
---
title: My report
engine: matlab
format:
  typst: default
  html: default
---
```

````markdown
```{matlab}
%| label: fig-nav
%| fig-cap: "Strategy NAVs."
matgrib.gg(T, x="date", y="nav", colour="strategy").line()
```

As @fig-nav shows, ...
````

* Cell options are written `%|` (MATLAB comments). `#|` also works. All the
  usual Quarto options apply: `label`, `fig-cap`, `echo`, `eval`,
  `code-fold`, `layout-ncol` and cross-references.
* Cells share one MATLAB workspace, in order, like a notebook.
* A `matgrib.gg` plot is displayed by leaving the expression unterminated (no
  semicolon) or by calling `p.show()`. At the MATLAB prompt the same code opens
  a preview figure (`p.preview()`).
* Any MATLAB figure a cell leaves open is translated as well.

### Faster renders with Matlock

By default each render runs `matlab -batch`, which spends about 10 s
starting MATLAB. If you run a Matlock session (a persistent MATLAB Engine
served over HTTP), point the document at it for near-instant re-renders:

```yaml
matlab:
  session: docs        # a session name from `matlock-serve --list`
  # or url: http://127.0.0.1:PORT
```

Cells run in that session's base workspace, so use a dedicated session.

## The DSL

```matlab
p = matgrib.gg(T, x="col", y="col", colour="col", ...)   % or vectors: gg(x=t, y=sin(t))
```

Aesthetics are `x y colour fill group label ymin ymax xmin xmax xend yend`. A
string names a column; any other value is used as data. For `colour`/`fill`, a
string that isn't a column is a fixed colour (`colour="red"`, `"#336699"`,
`"ink"`).

| Layer | Draws | Options |
|---|---|---|
| `point` | scatter | `size`, `shape`, `filled`, `alpha` |
| `line` / `path` / `step` | lines in x / data / staircase order | `linewidth`, `linetype`, `direction` (step) |
| `area` | stacked areas | `position="stack"\|"identity"` |
| `ribbon` | band from `ymin` to `ymax` | `alpha` |
| `col` | bars of height `y` | `position="stack"\|"dodge"\|"identity"`, `width` |
| `bar` | bars counting rows per `x` | as `col` |
| `histogram` | binned counts | `bins`, `binwidth`, `normalize="density"`, `position` |
| `density` | Gaussian KDE (bw.nrd0) | `adjust`, `n`; pass a `fill` for areas |
| `smooth` | loess or linear fit with CI band | `method="loess"\|"lm"`, `span`, `degree`, `se`, `level` |
| `boxplot` | Tukey boxplots | `width`, `coef`, `outliers` |
| `errorbar` / `pointrange` | intervals `ymin`–`ymax` | |
| `text` | labels | `fontsize` (relative), `halign` |
| `tile` | heatmap cells | `width`, `height` |
| `segment` | `(x, y)` → `(xend, yend)` | |
| `hline(y)` / `vline(x)` / `abline(a, b)` | reference lines | `linetype`, `colour` |
| `annotate(geom, ...)` | a layer of literal values | |

Every layer also takes `data=T2` (use other data), `inherit=false` (ignore
the plot-level aesthetics) and `legend=false`.

| Setting | Options |
|---|---|
| `scaleX`, `scaleY` | `name`, `limits`, `breaks`, `labels`, `trans="log10"\|"reverse"`, `format="percent"\|"percent:1"\|"comma"\|"dollar"\|"scientific"\|"fixed:2"`, `levels` (discrete order) |
| `logX`, `logY` | shorthand for `trans="log10"` |
| `scaleColour`, `scaleFill` | `values` (per level, or a `dictionary`), `levels`, `palette` (continuous: `viridis`, `magma`, `cividis`, `blues`, `reds`, `greens`, `greys`, `rdbu`, `brbg`, `rdylbu`, or any colormap name), `limits`, `midpoint` |
| `labs` | `title`, `subtitle`, `caption`, `x`, `y`, `colour`, `fill` |
| `facet(var)` / `facetGrid(rows=, cols=)` | `ncol`, `scales="fixed"\|"free"\|"free_x"\|"free_y"` (PDF only) |
| `coordFlip()` | swap axes (horizontal bars and boxplots) |
| `theme` | `legend="right"\|"bottom"\|"top"\|"left"\|"none"\|"top-right"\|...`, `aspect`, `maxPoints`, `maxPath` |

`matgrib.arrange(p1, p2, ncol=2, title=...)` puts several plots in one figure.

**Large data.** All statistics run in MATLAB, so the renderers only draw
primitives. Point layers above `maxPoints` (2500) are sampled reproducibly,
and lines above `maxPath` (1500 per series) are min/max-decimated, which keeps
the visible highs and lows. Stats such as `smooth` and `histogram` always use
all of the data. The render log notes any sampling.

## Document options

```yaml
matlab:
  session: docs              # Matlock session (or url:)
  palette: ["#0072B2", "#D55E00", "#009E73"]   # series colours, PDF and HTML
  aspect: 0.55               # panel height / width
  max-points: 2000           # translator: per-line budget
  max-scatter: 3000          # translator: larger scatters -> image
  strict: true               # translator: image fallback if anything is untranslatable
execute:
  cache: true                # reuse MATLAB results while cell code is unchanged
```

Per cell, `%| matgrib: image` forces a MATLAB image export.

For Typst-only tweaks, add a raw block after the front matter:

````markdown
```{=typst}
#matgrib-set(theme: grib.theme-bw(), text-scale: 0.85, legend: "bottom")
```
````

For HTML-only tweaks, set `.matgrib { --matgrib-palette: ... }` in CSS or
`window.matgribConfig` before the page loads.

## How it works

```
{matlab} cells ──► matgrib.runJob (MATLAB) ──► figure specs (JSON, SPEC.md)
                      │  matgrib.gg: stats, positions, sampling
                      │  figure handles: matgrib.figureSpec
                      ▼
          Quarto notebook → markdown (captions, cross-refs, echo, ...)
                      ▼
   typst: #matgrib-figure(...) → Gribouille     html: <div class="matgrib"> → Observable Plot
```

[`SPEC.md`](SPEC.md) documents the contract between the parts. Because
statistics and positions are resolved in MATLAB, the PDF and HTML show the
same geometry, and adding another renderer only means mapping about ten
primitives.

## Development

```text
_extensions/matgrib/
  matlab-engine.js         Quarto engine
  matgrib.typ              Typst renderer (Gribouille 0.6.0)
  matgrib.js, matgrib.css  HTML renderer
  vendor/                  d3 7.9.0, Observable Plot 0.6.17 (ISC licences included)
  matlab/+matgrib/         gg, Plot, arrange, figureSpec, runJob, preview, emit
tests/
  TestMatgrib.m            unit tests:      runtests("tests/TestMatgrib.m")
  smoke_dsl.m              writes tests/out/gallery.json for the visual galleries
  gallery.typ              typst compile --root . tests/gallery.typ tests/out/gallery.pdf
  gallery.html             serve the repo root and open /tests/gallery.html
  smoke_preview.m          renders the gallery through matgrib.preview
```

## Known limitations

* **Gribouille is pinned to 0.6.0**, the newest that runs on the Typst 0.14
  bundled with Quarto 1.9. `QUARTO_TYPST=$(which typst)` lets Quarto use a
  newer Typst.
* **Gribouille draws each marker separately**, which is why point layers are
  sampled. Raise `maxPoints` if you accept slower compiles.
* **Horizontal legends** (`legend="bottom"`) in Gribouille can space
  proportional-font labels tightly.
* **HTML facets always share scales.** `scales="free"` only affects the PDF.
* **The translator covers common 2-D charts.** Everything else becomes an
  image; see the skill file for the full list.

## Licence

MIT. Vendored d3 and Observable Plot are ISC-licensed; their licences are in
`_extensions/matgrib/vendor/`.
