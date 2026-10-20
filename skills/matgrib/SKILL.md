---
name: matgrib
description: Write Quarto (.qmd) documents whose MATLAB figures render natively — Gribouille in Typst/PDF output, Observable Plot in HTML — using the matgrib engine extension and its matgrib.gg grammar-of-graphics DSL. Use when a report, memo or notebook-style document mixes MATLAB analysis with prose and should compile to PDF via Typst and/or HTML, or when asked to plot MATLAB data "ggplot-style".
---

# matgrib: native MATLAB figures in Quarto

The matgrib extension adds a Quarto engine (`engine: matlab`) that runs
`{matlab}` cells and draws their figures natively:

| Output        | Figures become                                                 |
|---------------|----------------------------------------------------------------|
| `typst` (PDF) | Gribouille plots: document font, text width, vector            |
| `html`        | Observable Plot SVG: page font, responsive, tooltips, no CDN    |
| other formats | MATLAB image export                                            |

Do **not** export figures with `exportgraphics`/`saveas`, and do not hand-write
Gribouille or Plot code. Write MATLAB.

## Setup

```bash
quarto add sswatson/matgrib        # in the project directory
```

Requires Quarto ≥ 1.9 and MATLAB on `PATH` (or `QUARTO_MATLAB`). No
toolboxes and no Jupyter are needed. Front matter:

```yaml
engine: matlab
matlab:
  session: agent-docs     # optional: a Matlock session for fast re-renders
format:
  typst: default
  html: default
```

Without `session`, every render pays about 10 s of `matlab -batch` startup.
For iterative work, start a dedicated Matlock session (see the `matlock`
skill: `matlock-serve --session agent-docs &`) and stop it when done. Never
use the user's interactive session: cells run in its base workspace.

## Prefer the DSL for new figures

```matlab
matgrib.gg(T, x="date", y="nav", colour="strategy") ...
    .line() ...
    .smooth(method="loess", span=0.3) ...
    .hline(100) ...
    .scaleY(format="comma") ...
    .labs(title="Strategy NAV", y="Index level", x="", colour="") ...
    .theme(legend="bottom")
```

* Leave the final expression **without a semicolon**: that displays it as a
  figure. Assigning (`p = ...;`) and later `p` or `p.show()` also works.
  Display at most one plot per captioned cell.
* Aesthetics: `x y colour fill group label ymin ymax xmin xmax xend yend`.
  A string names a table column; vectors are used directly
  (`matgrib.gg(x=t, y=sin(t))`). For `colour`/`fill`, a string that isn't a
  column is a fixed colour.
* Layers: `point line path step area ribbon col bar histogram density smooth
  boxplot errorbar pointrange text tile segment hline vline abline annotate`.
* Settings: `scaleX/scaleY` (`limits breaks labels trans format levels`),
  `logX/logY`, `scaleColour/scaleFill` (`values levels palette limits
  midpoint`), `labs`, `facet(var, ncol=)`, `facetGrid(rows=, cols=)`,
  `coordFlip()`, `theme(legend=, aspect=, maxPoints=, maxPath=)`.
* `matgrib.arrange(p1, p2, ncol=2)` combines plots into one figure.
* Formats: `"percent"`, `"percent:1"`, `"comma"`, `"dollar"`,
  `"scientific"`, `"fixed:2"`.
* Discrete axes come from string/categorical columns; order them with
  `scaleX(levels=...)` or categorical categories. Dates come from `datetime`
  columns.
* Everything is computed in MATLAB with base functions (loess, lm with CI,
  KDE, quantiles), so no toolbox is needed. Don't pre-aggregate what a layer
  already computes (`histogram`, `bar`, `boxplot`, `smooth`, `density`).
* Big data is safe: point layers are sampled to `maxPoints` (2500) and lines
  decimated to `maxPath` (1500 per series). Stats use every row. Don't
  downsample by hand unless you want a different budget.

Each method's help (`help matgrib.Plot/smooth`) lists its options.

## Plain MATLAB plots also work

Existing `plot`/`bar`/`histogram`/`scatter`/`errorbar`/`area`/`stairs`/
`xline`/`yline`/`text`/`fill` code inside `tiledlayout`/`subplot` is
translated natively. Leave colours on auto so the document palette applies,
and use `DisplayName` plus `legend` for legends. These fall back to an image:
`surf`, `mesh`, `contour`, `image(sc)`, `quiver`, `pcolor`, polar or geographic
axes, `yyaxis`, 3-D views, `heatmap` and other chart objects, and scatters over
`max-scatter` points. Force a fallback with `%| matgrib: image`.

## Cell and document options

Cell options use `%|` (`#|` is accepted). Use `label: fig-...` with
`fig-cap` for cross-references (`@fig-...`), plus the usual `echo`, `eval`,
`code-fold` and so on.

```yaml
matlab:
  palette: ["#0072B2", "#D55E00"]  # series colours for PDF and HTML
  aspect: 0.55                     # panel height / width
execute:
  cache: true                      # keyed on cell code only
```

`execute: cache` keys on cell code only. Delete `.matgrib-cache/` when the
data files a cell reads change.

## Verify every render

```bash
quarto render doc.qmd --to typst 2>&1 | grep -E "matlab engine|WARN|ERROR"
pdftoppm -png -r 80 doc.pdf /tmp/doc-pages/p        # look at every page
quarto render doc.qmd --to html
google-chrome --headless=new --no-sandbox --virtual-time-budget=8000 \
  --window-size=1100,4000 --screenshot=/tmp/doc.png "file://$PWD/doc.html"
```

Check that:

* every figure is present;
* legends list the right series;
* date and percent axes read well;
* the log has no unexpected `image fallback` or `MATLAB error` lines;
* the HTML contains no `matgrib: could not render figure`.

The log reports sampling (`point layer sampled to ...`); that is expected
for large data.

## Troubleshooting

* **`Unable to resolve crossref`**: the `%|` lines must be the first lines of
  the cell, and the label needs the `fig-` prefix.
* **A figure is missing**: the plot expression ended with `;`, or was
  assigned and never displayed.
* **`No column named "x"`**: the string doesn't match a table variable
  (names are case-sensitive).
* **Inspecting a spec**: `addpath('<project>/_extensions/matgrib/matlab')`,
  then `p.json(PrettyPrint=true)` or `p.preview()`.
