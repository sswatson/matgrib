// matgrib: draw matgrib figure specs (SPEC.md, version 2) with Gribouille.
//
// Specs come from MATLAB (matgrib.gg or the figure translator) with stats,
// positions and downsampling already resolved; this file maps primitives
// onto Gribouille geoms and supplies the document-derived look: palette,
// fonts, sizes, gridlines.
//
// Customise per document with
//   #matgrib-set(palette: (...), theme: grib.theme-bw(), aspect: 0.5)
// before the first figure.

#import "@preview/gribouille:0.6.0" as grib

#let matgrib-palette = (
  rgb("#0072B2"), rgb("#D55E00"), rgb("#009E73"), rgb("#E69F00"),
  rgb("#56B4E9"), rgb("#CC79A7"), rgb("#7F7F7F"), rgb("#F0E442"),
)

#let _config = state("matgrib-config", (:))

/// Override defaults for every following matgrib figure.
/// - palette: colours for automatic series colours, in order
/// - theme: a Gribouille theme, or `auto` for one derived from the text style
/// - aspect: facet/panel height ÷ width, or `auto` for the figure's own
/// - legend: `auto` (as the spec says) or a side such as "bottom"
/// - text-scale: plot text size relative to body text
/// - ink, paper: foreground and background colours
#let matgrib-set(..args) = _config.update(c => c + args.named())

#let _defaults = (
  palette: matgrib-palette,
  theme: auto,
  aspect: auto,
  max-aspect: 0.65,
  legend: auto,
  text-scale: 0.8,
  ink: rgb("#273036"),
  paper: white,
  gutter: 1.2em,
)

#let _arr(v) = if v == none { () } else if type(v) == array { v } else { (v,) }
#let _nonempty(s) = s != none and s != ""
// MATLAB's jsonencode writes an empty value as [] rather than null.
#let _get(d, k) = { let v = d.at(k, default: none); if v == () { none } else { v } }

#let _colour(c, cfg) = {
  if type(c) == dictionary {
    let p = cfg.palette
    p.at(calc.rem(int(c.auto) - 1, p.len()))
  } else if c == "ink" { cfg.ink } else if c == "paper" { cfg.paper } else if c == "none" { none } else { rgb(c) }
}

// ------------------------------------------------------------------ dates

// Date axes arrive as Unix epoch milliseconds; Gribouille's scale-date
// counts days since 2000-01-01.
#let _days(ms) = (ms - 946684800000) / 86400000
#let _epoch = datetime(year: 2000, month: 1, day: 1)
#let _days-of(dt) = (dt - _epoch).days()

// Calendar-aligned ticks: month or year starts rather than evenly spaced days.
#let _date-breaks(lo, hi, max-ticks) = {
  let span = hi - lo
  if span < 75 {
    let step = if span < 15 { 2 } else if span < 40 { 7 } else { 14 }
    let ds = range(int(calc.ceil(lo)), int(calc.floor(hi)) + 1, step: step)
    return (ds, ds.map(d => (_epoch + duration(days: d)).display("[month repr:short] [day]")))
  }
  let months = span / 30.44
  let steps = (1, 2, 3, 6, 12, 24, 60, 120, 240)
  let ticks(step) = {
    let d0 = _epoch + duration(days: int(calc.floor(lo)))
    let idx = d0.year() * 12 + d0.month() - 1
    idx = int(calc.ceil(idx / step) * step)
    let out = ()
    while true {
      let dt = datetime(year: calc.div-euclid(idx, 12), month: calc.rem-euclid(idx, 12) + 1, day: 1)
      let d = _days-of(dt)
      if d > hi { break }
      if d >= lo { out.push((d, dt)) }
      idx += step
    }
    out
  }
  // Smallest step within the tick budget; step down once if month alignment
  // leaves fewer than two ticks inside the range.
  let i = steps.position(s => months / s <= max-ticks)
  if i == none { i = steps.len() - 1 }
  let out = ticks(steps.at(i))
  if out.len() < 2 and i > 0 { i -= 1; out = ticks(steps.at(i)) }
  let step = steps.at(i)
  let fmt = if step >= 12 { "[year]" } else { "[month repr:short] [year]" }
  (out.map(p => p.at(0)), out.map(p => p.at(1).display(fmt)))
}

#let _AXIS-COLS = (x: ("x", "xmin", "xmax", "xend"), y: ("y", "ymin", "ymax", "yend"))

// ------------------------------------------------------------------ scales

#let _format(f) = {
  if not _nonempty(f) { return auto }
  let (name, digits) = if f.contains(":") { let p = f.split(":"); (p.at(0), int(p.at(1))) } else { (f, none) }
  if name == "percent" { grib.format-percent(digits: if digits == none { 0 } else { digits }) }
  else if name == "comma" { grib.format-comma(digits: if digits == none { auto } else { digits }) }
  else if name == "dollar" { grib.format-currency(digits: if digits == none { 0 } else { digits }) }
  else if name == "scientific" { grib.format-scientific(digits: if digits == none { 2 } else { digits }) }
  else if name == "fixed" { grib.format-number(big-mark: "", digits: digits) }
  else { auto }
}

#let _range(layers, keys) = {
  let vs = ()
  for L in layers { for k in keys { vs += _arr(L.data.at(k, default: ())).filter(v => v != none) } }
  if vs.len() == 0 { none } else { (calc.min(..vs), calc.max(..vs)) }
}

#let _axis-scale(a, layers, axis, max-ticks) = {
  let args = (:)
  if _nonempty(a.label) { args.name = a.label }
  let lim = _arr(a.limits)
  let breaks = _arr(a.breaks)
  let labels = _arr(a.labels)
  if a.type == "date" {
    if lim.len() == 2 { args.limits = lim.map(_days) }
    if breaks.len() > 0 { args.breaks = breaks.map(_days) } else {
      let r = if lim.len() == 2 { lim } else { _range(layers, _AXIS-COLS.at(axis)) }
      if r != none {
        let (b, l) = _date-breaks(..r.map(_days), max-ticks)
        if b.len() >= 2 { args.breaks = b; args.labels = l }
      }
    }
    return grib.scale-date(..args)
  }
  if lim.len() == 2 { args.limits = lim }
  if breaks.len() > 0 { args.breaks = breaks }
  if labels.len() > 0 and labels.len() == breaks.len() { args.labels = labels } else {
    let f = _format(a.at("format", default: ""))
    if f != auto { args.labels = f }
  }
  if a.type == "discrete" { args.expand = false }
  if a.trans == "log10" { grib.scale-log10(..args) }
  else if a.trans == "reverse" { grib.scale-continuous(transform: "reverse", ..args) }
  else { grib.scale-continuous(..args) }
}

#let _colour-scale(s, cfg) = {
  if s == none { return none }
  if s.type == "discrete" {
    grib.scale-discrete(limits: _arr(s.levels), palette: _arr(s.values).map(c => _colour(c, cfg)))
  } else {
    let args = (colours: _arr(s.colours).map(rgb))
    let lim = _arr(s.at("limits", default: ()))
    if lim.len() == 2 and lim.at(0) != lim.at(1) { args.limits = lim }
    grib.scale-gradientn(..args)
  }
}

// ------------------------------------------------------------------ layers

#let _rows(data, date-axes) = {
  let keys = data.keys()
  let cols = keys.map(k => _arr(data.at(k)))
  let n = calc.max(0, ..cols.map(c => c.len()))
  let conv = keys.map(k => date-axes.any(ax => k in _AXIS-COLS.at(ax)))
  range(n).map(i => {
    let r = (:)
    for (j, k) in keys.enumerate() {
      let c = cols.at(j)
      let v = if c.len() == 1 { c.at(0) } else { c.at(i) }
      r.insert(k, if conv.at(j) and v != none { _days(v) } else { v })
    }
    r
  })
}

#let _layer(L, cfg, date-axes) = {
  let P = L.params
  let aes = _arr(L.aes)
  let rows = _rows(L.data, date-axes)
  let mapped(k) = k in aes
  let fixed = (:)
  let colour = if "colour" in P { _colour(P.colour, cfg) } else { auto }
  let fill = if "fill" in P { _colour(P.fill, cfg) } else { auto }
  if colour != auto and not mapped("colour") { fixed.colour = colour }
  if "alpha" in P { fixed.alpha = P.alpha }
  let m = (:)
  for k in ("colour", "fill", "group", "label") { if mapped(k) { m.insert(k, k) } }
  let lw = P.at("linewidth", default: 1) * 1pt
  let lt = P.at("linetype", default: "solid")
  let g = L.geom

  if g == "point" {
    let filled = P.at("filled", default: true)
    if filled and not mapped("fill") {
      if mapped("colour") { m.fill = "colour" } else if colour != auto { fixed.fill = colour }
    }
    if not filled { fixed.fill = none }
    grib.geom-point(
      data: rows, mapping: grib.aes(x: "x", y: "y", ..m),
      size: P.at("size", default: 4.5) / 2 * 1pt,
      shape: P.at("shape", default: "circle"),
      inherit-aes: false, ..fixed,
    )
  } else if g == "path" {
    grib.geom-path(
      data: rows, mapping: grib.aes(x: "x", y: "y", ..m),
      stroke: lw, linetype: lt, inherit-aes: false, ..fixed,
    )
  } else if g == "rect" or g == "ribbon" or g == "polygon" {
    if fill != auto and not mapped("fill") { fixed.fill = fill }
    let outline = if lw > 0pt and (colour != auto or mapped("colour")) {
      if mapped("colour") { lw } else { lw + colour }
    } else { none }
    let geom = (rect: grib.geom-rect, ribbon: grib.geom-ribbon, polygon: grib.geom-polygon).at(g)
    let pos = (
      rect: (xmin: "xmin", xmax: "xmax", ymin: "ymin", ymax: "ymax"),
      ribbon: (x: "x", ymin: "ymin", ymax: "ymax"),
      polygon: (x: "x", y: "y"),
    ).at(g)
    if g == "rect" { m.remove("group", default: none) }
    geom(data: rows, mapping: grib.aes(..pos, ..m), stroke: outline, inherit-aes: false, ..fixed)
  } else if g == "segment" {
    grib.geom-segment(
      data: rows, mapping: grib.aes(x: "x", y: "y", xend: "xend", yend: "yend", ..m),
      stroke: lw, linetype: lt, inherit-aes: false, ..fixed,
    )
  } else if g == "errorbar" {
    let caps = P.at("caps", default: true)
    let st = if mapped("colour") or colour == auto { lw } else { lw + colour }
    if P.at("horizontal", default: false) {
      grib.geom-errorbarh(
        data: rows, mapping: grib.aes(y: "y", xmin: "xmin", xmax: "xmax", ..m),
        height: if caps { 0.15 } else { 0 }, stroke: st, inherit-aes: false, ..fixed,
      )
    } else {
      grib.geom-errorbar(
        data: rows, mapping: grib.aes(x: "x", ymin: "ymin", ymax: "ymax", ..m),
        width: if caps { 0.15 } else { 0 }, stroke: st, inherit-aes: false, ..fixed,
      )
    }
  } else if g == "text" {
    let anchor = (left: "west", right: "east", center: "center").at(P.at("halign", default: "center"), default: "center")
    grib.geom-text(
      data: rows, mapping: grib.aes(x: "x", y: "y", label: "label", ..m),
      size: text.size * cfg.text-scale * P.at("fontsize", default: 1),
      anchor: anchor, inherit-aes: false, ..fixed,
    )
  } else if g == "hline" or g == "vline" {
    let vals = rows.map(r => r.at(if g == "hline" { "y" } else { "x" }))
    let args = (colour: if colour == auto { cfg.ink } else { colour }, linetype: lt, stroke: lw)
    if g == "hline" { grib.geom-hline(yintercept: vals, ..args) } else { grib.geom-vline(xintercept: vals, ..args) }
  } else { none }
}

// ------------------------------------------------------------------ panels

#let _theme(cfg) = {
  if cfg.theme != auto { return cfg.theme }
  let s = text.size * cfg.text-scale
  let muted = cfg.ink.lighten(35%)
  grib.theme-minimal(
    ink: cfg.ink,
    text: grib.element-text(size: s, colour: cfg.ink),
    axis-title: grib.element-text(size: s, colour: cfg.ink),
    axis-text: grib.element-text(size: s * 0.92, colour: muted),
    plot-title: grib.element-text(size: s * 1.15, weight: "bold", colour: cfg.ink),
    plot-subtitle: grib.element-text(size: s, colour: muted),
    plot-caption: grib.element-text(size: s * 0.85, colour: muted),
    legend-text: grib.element-text(size: s * 0.92, colour: cfg.ink, margin: grib.margin(right: 1em)),
    legend-title: grib.element-text(size: s * 0.92, weight: "bold", colour: cfg.ink),
    strip-text: grib.element-text(size: s * 0.95, weight: "bold", colour: cfg.ink),
    panel-grid: grib.element-line(colour: cfg.ink.lighten(85%), stroke: 0.4pt),
    panel-grid-minor: grib.element-blank(),
  )
}

#let _legend-position(p, cfg) = {
  if cfg.legend != auto { return cfg.legend }
  let inside = (
    "top-right": top + right, "top-left": top + left,
    "bottom-right": bottom + right, "bottom-left": bottom + left,
    "top-center": top + center, "bottom-center": bottom + center,
    "right-center": horizon + right, "left-center": horizon + left,
  )
  inside.at(p, default: p)
}

#let _facet-shape(f) = {
  if f == none { (1, 1) }
  else if f.type == "wrap" {
    let n = _arr(f.levels).len()
    let c = calc.min(int(f.ncol), calc.max(1, n))
    (calc.ceil(n / c), c)
  } else { (calc.max(1, _arr(f.rows).len()), calc.max(1, _arr(f.cols).len())) }
}

#let _panel(p, cfg, width, asp) = {
  let layers = _arr(p.layers)
  let date-axes = ("x", "y").filter(a => p.at(a).type == "date")
  // "Mar 2024" needs about 2.4cm; keep date labels from colliding.
  let (frows0, fcols0) = _facet-shape(_get(p, "facet"))
  let max-ticks = calc.max(2, calc.min(6, int(width / fcols0 / 2.4cm)))
  let scales = (
    x: _axis-scale(p.x, layers, "x", max-ticks),
    y: _axis-scale(p.y, layers, "y", 6),
  )
  for k in ("colour", "fill") {
    let s = _colour-scale(_get(p, k), cfg)
    if s != none { scales.insert(k, s) }
  }
  // Filled points map fill to their colour column; share the colour scale.
  if "fill" not in scales and "colour" in scales { scales.fill = scales.colour }

  // A legend appears for colour / fill when a legend-visible layer maps it.
  let shows(k) = _get(p, k) != none and layers.any(L => L.legend and k in _arr(L.aes))
  let pos = _legend-position(p.legend, cfg)
  let guide(k) = if pos == "none" or not shows(k) { none } else if p.at(k).type == "continuous" { auto } else {
    grib.guide-legend(position: pos)
  }
  let guides = grib.guides(colour: guide("colour"), fill: guide("fill"))

  let lab = (:)
  for k in ("title", "subtitle", "caption") { if _nonempty(p.at(k)) { lab.insert(k, p.at(k)) } }
  lab.x = if _nonempty(p.x.label) { p.x.label } else { none }
  lab.y = if _nonempty(p.y.label) { p.y.label } else { none }
  for k in ("colour", "fill") {
    let s = _get(p, k)
    if s != none { lab.insert(k, if _nonempty(s.title) { s.title } else { none }) }
  }

  let f = _get(p, "facet")
  let facet = if f == none { none } else if f.type == "wrap" {
    grib.facet-wrap("facet", ncolumn: int(f.ncol), scales: f.scales)
  } else {
    grib.facet-grid(
      rows: if _arr(f.rows).len() > 0 { "facet_row" } else { none },
      columns: if _arr(f.cols).len() > 0 { "facet_col" } else { none },
      scales: f.scales,
    )
  }
  let (frows, fcols) = _facet-shape(f)
  let height = width / fcols * asp * frows + if f != none { 1.4em * frows } else { 0pt }

  // Plot-level data only lists facet levels (in spec order); layers carry
  // their own data.
  let base = if f == none { ((x: 0),) } else if f.type == "wrap" {
    _arr(f.levels).map(l => (facet: l))
  } else {
    let rs = _arr(f.rows); let cs = _arr(f.cols)
    if rs.len() == 0 { rs = (none,) }
    if cs.len() == 0 { cs = (none,) }
    rs.map(r => cs.map(c => (facet_row: r, facet_col: c))).flatten()
  }
  grib.plot(
    data: base,
    layers: layers.map(L => _layer(L, cfg, date-axes)).filter(l => l != none),
    scales: grib.scales(..scales),
    labels: grib.labels(..lab),
    guides: guides,
    facet: facet,
    theme: _theme(cfg),
    width: width,
    height: height.to-absolute(),
  )
}

/// Render a matgrib figure spec.
/// - aspect: panel height ÷ width override for this figure
/// - fig-aspect: the source MATLAB figure's aspect, used when nothing else is set
#let matgrib-figure(spec, aspect: auto, fig-aspect: auto) = context {
  let cfg = _defaults + _config.get()
  let panels = _arr(spec.panels)
  let cols = calc.max(1, calc.min(int(spec.at("ncol", default: 1)), panels.len()))
  let rows = calc.ceil(panels.len() / cols)
  let own = _get(spec, "aspect")
  let asp = if aspect != auto { aspect }
    else if own != none and _arr(own).len() > 0 { _arr(own).at(0) }
    else if cfg.aspect != auto { cfg.aspect }
    else if fig-aspect != auto and fig-aspect != none { calc.min(cfg.max-aspect, fig-aspect * cols / rows) }
    else { 0.62 }
  layout(size => {
    let w = (size.width - cfg.gutter.to-absolute() * (cols - 1)) / cols
    let body = grid(
      columns: (1fr,) * cols,
      column-gutter: cfg.gutter,
      row-gutter: cfg.gutter,
      ..panels.map(p => _panel(p, cfg, w, asp)),
    )
    let s = text.size * cfg.text-scale
    let head = ()
    if _nonempty(spec.title) { head.push(align(center, text(size: s * 1.2, weight: "bold", fill: cfg.ink, spec.title))) }
    if _nonempty(spec.at("subtitle", default: "")) { head.push(align(center, text(size: s, fill: cfg.ink.lighten(35%), spec.subtitle))) }
    if _nonempty(spec.at("caption", default: "")) { head.push(none) }
    if head.len() > 0 or _nonempty(spec.at("caption", default: "")) {
      stack(spacing: 0.6em, ..head.filter(h => h != none), body,
        ..if _nonempty(spec.at("caption", default: "")) { (align(right, text(size: s * 0.85, fill: cfg.ink.lighten(35%), spec.caption)),) } else { () })
    } else { body }
  })
}
