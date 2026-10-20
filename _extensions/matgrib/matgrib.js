// matgrib: draw matgrib figure specs (SPEC.md, version 2) with Observable
// Plot. Figures inherit the page's font and colours (currentColor, so dark
// mode works), resize with the page and show tooltips.
//
// Customise from CSS:  .matgrib { --matgrib-palette: #1b9e77, #d95f02, ...; }
// or from JS before load: window.matgribConfig = { palette: [...], aspect: 0.5 }
(function () {
  "use strict";

  const DEFAULT_PALETTE = ["#0072B2", "#D55E00", "#009E73", "#E69F00",
    "#56B4E9", "#CC79A7", "#7F7F7F", "#F0E442"];
  const DASH = { solid: null, dashed: "6,4", dotted: "1.5,3", "dash-dotted": "6,3,1.5,3" };
  const SYMBOL = { circle: "circle", square: "square", diamond: "diamond",
    triangle: "triangle", x: "times", cross: "plus" };
  const AXIS_COLS = { x: ["x", "xmin", "xmax", "xend"], y: ["y", "ymin", "ymax", "yend"] };

  // MATLAB's jsonencode writes scalars for 1-element arrays and [] for empty.
  const arr = (v) => (v == null ? [] : Array.isArray(v) ? v : [v]);
  const get = (o, k) => { const v = o == null ? null : o[k]; return Array.isArray(v) && v.length === 0 ? null : v; };
  const nonempty = (s) => s != null && s !== "" && !(Array.isArray(s) && s.length === 0);

  function config(el) {
    const cfg = Object.assign({ aspect: null, maxAspect: 0.65, gutter: 24, fontSize: 12 }, window.matgribConfig || {});
    const css = getComputedStyle(el).getPropertyValue("--matgrib-palette").trim();
    cfg.palette = cfg.palette || (css ? css.split(",").map((s) => s.trim()) : DEFAULT_PALETTE);
    return cfg;
  }

  function colour(c, cfg) {
    if (c && typeof c === "object") return cfg.palette[(c.auto - 1) % cfg.palette.length];
    if (c === "ink") return "currentColor";
    if (c === "paper") return "var(--matgrib-bg, white)";
    return c;
  }

  function format(f) {
    if (!nonempty(f)) return undefined;
    const [name, d] = f.split(":");
    const digits = d === undefined ? undefined : +d;
    switch (name) {
      case "percent": return d3.format(`.${digits ?? 0}%`);
      case "comma": return d3.format(digits === undefined ? "," : `,.${digits}f`);
      case "dollar": return d3.format(`$,.${digits ?? 0}f`);
      case "scientific": return d3.format(`.${digits ?? 2}e`);
      case "fixed": return d3.format(`.${digits ?? 2}f`);
      default: return undefined;
    }
  }

  function axis(a) {
    const o = { label: nonempty(a.label) ? a.label : null, grid: a.type !== "discrete" };
    const lim = arr(a.limits), breaks = arr(a.breaks), labels = arr(a.labels);
    if (a.type === "date") {
      o.type = "utc";
      if (lim.length === 2) o.domain = lim.map((v) => new Date(v));
      if (breaks.length) o.ticks = breaks.map((v) => new Date(v));
      return o;
    }
    if (a.trans === "log10") o.type = "log";
    if (a.trans === "reverse") o.reverse = true;
    if (lim.length === 2) o.domain = lim;
    if (breaks.length) o.ticks = breaks;
    if (labels.length && labels.length === breaks.length) {
      o.tickFormat = (v) => { const i = breaks.indexOf(v); return i < 0 ? "" : labels[i]; };
    } else if (format(a.format)) {
      o.tickFormat = format(a.format);
    }
    return o;
  }

  // Columnar layer data -> row objects, with dates as Date objects and
  // discrete colour levels resolved to concrete colours (the legend is drawn
  // separately, so Plot's single colour scale is only used for continuous data).
  function rows(L, ctx) {
    const keys = Object.keys(L.data || {});
    const cols = keys.map((k) => arr(L.data[k]));
    const n = Math.max(0, ...cols.map((c) => c.length));
    const dateKeys = new Set(ctx.dateAxes.flatMap((a) => AXIS_COLS[a]));
    const out = [];
    for (let i = 0; i < n; i++) {
      const r = {};
      keys.forEach((k, j) => {
        const c = cols[j];
        let v = c.length === 1 ? c[0] : c[i];
        if (dateKeys.has(k) && v != null) v = new Date(v);
        r[k] = v;
      });
      for (const k of ["colour", "fill"]) {
        if (r[k] == null) continue;
        const s = ctx.scales[k];
        if (s && s.type === "discrete") { r[k + "Level"] = r[k]; r[k] = s.lookup.get(String(r[k])); }
      }
      if (ctx.facet && ctx.facet.type === "wrap" && r.facet != null) {
        const i = ctx.facet.index.get(String(r.facet));
        r.fx = i % ctx.facet.ncol; r.fy = Math.floor(i / ctx.facet.ncol);
      } else if (ctx.facet && ctx.facet.type === "grid") {
        if (r.facet_col != null) r.fx = r.facet_col;
        if (r.facet_row != null) r.fy = r.facet_row;
      }
      out.push(r);
    }
    return out;
  }

  function marks(L, ctx, cfg) {
    const P = L.params || {};
    const aes = new Set(arr(L.aes));
    const data = rows(L, ctx);
    const faceted = data.length && (data[0].fx !== undefined || data[0].fy !== undefined);
    const fac = faceted ? { fx: "fx", fy: "fy" } : {};
    const fixedColour = P.colour != null ? colour(P.colour, cfg) : undefined;
    const fixedFill = P.fill != null ? colour(P.fill, cfg) : undefined;
    const stroke = aes.has("colour") ? (ctx.scales.colour?.type === "continuous" ? "colour" : (d) => d.colour) : fixedColour;
    const fill = aes.has("fill") ? (ctx.scales.fill?.type === "continuous" ? "fill" : (d) => d.fill) : fixedFill;
    const lw = P.linewidth ?? 1;
    const common = { ...fac, strokeDasharray: DASH[P.linetype] || null };
    const opacity = P.alpha ?? 1;
    const titleOf = (d) => [d.colourLevel, d.fillLevel, d.label].filter((v) => v != null).join(" · ") || undefined;
    switch (L.geom) {
      case "point": {
        const filled = P.filled ?? true;
        const f = aes.has("fill") ? fill : filled ? stroke : "none";
        return [Plot.dot(data, { ...fac, x: "x", y: "y", r: (P.size ?? 4.5) / 2 * 1.2,
          symbol: SYMBOL[P.shape] || "circle", stroke, fill: f, fillOpacity: opacity, strokeOpacity: opacity,
          tip: L.legend !== false, title: titleOf })];
      }
      case "path":
        return [Plot.line(data, { ...common, x: "x", y: "y", z: aes.has("group") ? "group" : undefined,
          stroke, strokeWidth: lw * 1.4, strokeOpacity: opacity, tip: L.legend !== false, title: titleOf })];
      case "rect":
        return [Plot.rect(data, { ...fac, x1: "xmin", x2: "xmax", y1: "ymin", y2: "ymax", fill: fill ?? "currentColor",
          fillOpacity: opacity, stroke: lw > 0 ? stroke : null, strokeWidth: lw * 1.2, tip: L.legend !== false, title: titleOf })];
      case "ribbon":
        return [Plot.areaY(data, { ...fac, x: "x", y1: "ymin", y2: "ymax", z: aes.has("group") ? "group" : undefined,
          fill: fill ?? "currentColor", fillOpacity: opacity })];
      case "polygon":
        return [Plot.line(data, { ...fac, x: "x", y: "y", z: aes.has("group") ? "group" : undefined,
          fill: fill ?? "currentColor", fillOpacity: opacity, stroke: "none", curve: "linear-closed" })];
      case "segment":
        return [Plot.link(data, { ...common, x1: "x", y1: "y", x2: "xend", y2: "yend", stroke, strokeWidth: lw * 1.4 })];
      case "errorbar": {
        const sw = lw * 1.4;
        const caps = P.caps ?? true;
        const capSymbol = (vertical) => ({ draw(c, size) { const w = Math.sqrt(size); if (vertical) { c.moveTo(0, -w); c.lineTo(0, w); } else { c.moveTo(-w, 0); c.lineTo(w, 0); } } });
        if (P.horizontal) {
          const m = [Plot.ruleY(data, { ...fac, y: "y", x1: "xmin", x2: "xmax", stroke, strokeWidth: sw })];
          if (caps) for (const k of ["xmin", "xmax"]) m.push(Plot.dot(data, { ...fac, x: k, y: "y", r: 4, symbol: capSymbol(true), stroke, strokeWidth: sw }));
          return m;
        }
        const m = [Plot.ruleX(data, { ...fac, x: "x", y1: "ymin", y2: "ymax", stroke, strokeWidth: sw })];
        if (caps) for (const k of ["ymin", "ymax"]) m.push(Plot.dot(data, { ...fac, x: "x", y: k, r: 4, symbol: capSymbol(false), stroke, strokeWidth: sw }));
        return m;
      }
      case "text":
        return [Plot.text(data, { ...fac, x: "x", y: "y", text: "label", fill: stroke ?? "currentColor",
          fontSize: cfg.fontSize * (P.fontsize ?? 1),
          textAnchor: { left: "start", right: "end", center: "middle" }[P.halign] || "middle" })];
      case "hline":
        return [Plot.ruleY(data.map((d) => d.y), { stroke: fixedColour ?? "currentColor", strokeWidth: lw * 1.2, strokeDasharray: DASH[P.linetype] || null })];
      case "vline":
        return [Plot.ruleX(data.map((d) => d.x), { stroke: fixedColour ?? "currentColor", strokeWidth: lw * 1.2, strokeDasharray: DASH[P.linetype] || null })];
      default:
        return [];
    }
  }

  function prepareScale(s, cfg) {
    if (!s) return null;
    if (s.type === "discrete") {
      const levels = arr(s.levels).map(String);
      const values = arr(s.values).map((c) => colour(c, cfg));
      return { ...s, levels, values, lookup: new Map(levels.map((l, i) => [l, values[i]])) };
    }
    return { ...s, colours: arr(s.colours), limits: arr(s.limits) };
  }

  function legends(p, ctx, layers) {
    if (p.legend === "none") return [];
    const out = [];
    for (const k of ["colour", "fill"]) {
      const s = ctx.scales[k];
      if (!s || !layers.some((L) => L.legend && arr(L.aes).includes(k))) continue;
      if (s.type === "discrete") {
        // A colour and a fill legend listing the same levels would repeat each other.
        if (k === "fill" && out.some((o) => o.key === s.levels.join("\u0000"))) continue;
        const el = Plot.legend({ color: { type: "categorical", domain: s.levels, range: s.values },
          label: nonempty(s.title) ? s.title : null, swatchSize: 11, className: "matgrib-legend" });
        el.key = s.levels.join("\u0000");
        out.push(el);
      } else {
        const side = ["right", "left"].includes(p.legend);
        out.push(Plot.legend({ color: { type: "linear", domain: s.limits.length === 2 ? s.limits : undefined, range: s.colours },
          label: nonempty(s.title) ? s.title : null, width: side ? 100 : 200, ticks: side ? 3 : undefined, className: "matgrib-legend" }));
      }
    }
    return out;
  }

  function panel(p, cfg, width, asp) {
    const layers = arr(p.layers);
    const ctx = {
      dateAxes: ["x", "y"].filter((a) => p[a].type === "date"),
      scales: { colour: prepareScale(get(p, "colour"), cfg), fill: prepareScale(get(p, "fill"), cfg) },
      facet: null,
    };
    const f = get(p, "facet");
    let frows = 1, fcols = 1;
    if (f && f.type === "wrap") {
      const levels = arr(f.levels).map(String);
      ctx.facet = { type: "wrap", ncol: Math.min(f.ncol, levels.length) || 1, index: new Map(levels.map((l, i) => [l, i])), levels };
      fcols = ctx.facet.ncol; frows = Math.ceil(levels.length / fcols);
    } else if (f && f.type === "grid") {
      ctx.facet = { type: "grid" };
      fcols = Math.max(1, arr(f.cols).length); frows = Math.max(1, arr(f.rows).length);
    }
    const marksAll = layers.flatMap((L) => marks(L, ctx, cfg));
    const continuous = ctx.scales.colour?.type === "continuous" ? ctx.scales.colour
      : ctx.scales.fill?.type === "continuous" ? ctx.scales.fill : null;
    // Room for the longest y tick label (discrete axes have word labels).
    const ylabels = arr(p.y.labels).map(String);
    const marginLeft = Math.max(50, 14 + 6.5 * Math.max(0, ...ylabels.map((l) => l.length)));
    const opts = {
      width, height: Math.round(width / fcols * asp * frows + (f ? 24 * frows : 0)),
      marginLeft, marginBottom: 40, marginTop: f ? 28 : 20, marginRight: 16,
      x: axis(p.x), y: axis(p.y),
      title: nonempty(p.title) ? p.title : undefined,
      subtitle: nonempty(p.subtitle) ? p.subtitle : undefined,
      caption: nonempty(p.caption) ? p.caption : undefined,
      style: { fontFamily: "inherit", fontSize: `${cfg.fontSize}px`, background: "transparent", overflow: "visible" },
      marks: marksAll,
    };
    if (continuous) {
      opts.color = { type: "linear", range: continuous.colours, interpolate: "rgb" };
      if (continuous.limits.length === 2) opts.color.domain = continuous.limits;
    }
    if (ctx.facet && ctx.facet.type === "wrap") {
      const fl = ctx.facet;
      opts.fx = { axis: null }; opts.fy = { axis: null };
      opts.marks.push(Plot.text(fl.levels, { fx: (_, i) => i % fl.ncol, fy: (_, i) => Math.floor(i / fl.ncol),
        text: (d) => d, frameAnchor: "top", dy: -16, fontWeight: "bold" }));
    } else if (ctx.facet) {
      opts.fx = { label: null }; opts.fy = { label: null };
    }
    const plot = Plot.plot(opts);
    const lg = legends(p, ctx, layers);
    if (!lg.length) return plot;
    const keys = document.createElement("div");
    keys.className = "matgrib-keys";
    lg.forEach((l) => keys.appendChild(l));
    const side = ["right", "left"].includes(p.legend) ? p.legend : p.legend.startsWith("bottom") ? "bottom" : "top";
    if (side === "top" || side === "bottom") {
      // Plot wraps titled charts in <figure><h2/><h3/><svg/></figure>; keep
      // the legend between the titles and the chart (or under it).
      const svg = plot.tagName === "svg" ? plot : plot.querySelector(":scope > svg");
      if (plot.tagName !== "svg" && svg) {
        if (side === "top") svg.before(keys); else svg.after(keys);
        return plot;
      }
      const box = document.createElement("div");
      box.className = `matgrib-panel matgrib-legend-${side}`;
      if (side === "top") box.append(keys, plot); else box.append(plot, keys);
      return box;
    }
    const box = document.createElement("div");
    box.className = `matgrib-panel matgrib-legend-${side}`;
    if (side === "left") box.append(keys, plot); else box.append(plot, keys);
    return box;
  }

  function render(el) {
    const spec = JSON.parse(el.querySelector('script[type="application/json"]').textContent);
    const cfg = config(el);
    const panels = arr(spec.panels);
    const cols = Math.max(1, Math.min(spec.ncol || 1, panels.length));
    const rowsN = Math.ceil(panels.length / cols);
    const own = get(spec, "aspect");
    const figAspect = parseFloat(el.dataset.aspect || "NaN");
    const asp = own != null ? arr(own)[0] : cfg.aspect
      || (isFinite(figAspect) ? Math.min(cfg.maxAspect, figAspect * cols / rowsN) : 0.62);
    const host = document.createElement("div");
    host.className = "matgrib-body";
    el.appendChild(host);
    let lastWidth = 0;
    const draw = () => {
      const width = el.clientWidth;
      if (!width || Math.abs(width - lastWidth) < 2) return;
      lastWidth = width;
      const w = Math.floor((width - cfg.gutter * (cols - 1)) / cols);
      host.replaceChildren();
      for (const [k, cls] of [["title", "matgrib-title"], ["subtitle", "matgrib-subtitle"]]) {
        if (!nonempty(spec[k])) continue;
        const h = document.createElement("div");
        h.className = cls; h.textContent = spec[k];
        host.appendChild(h);
      }
      const grid = document.createElement("div");
      grid.className = "matgrib-grid";
      grid.style.gridTemplateColumns = `repeat(${cols}, minmax(0, 1fr))`;
      grid.style.gap = `${cfg.gutter}px`;
      panels.forEach((p) => {
        const right = ["right", "left"].includes(p.legend) && (get(p, "colour") || get(p, "fill"));
        grid.appendChild(panel(p, cfg, right ? w - 110 : w, asp));
      });
      host.appendChild(grid);
      if (nonempty(spec.caption)) {
        const c = document.createElement("div");
        c.className = "matgrib-caption"; c.textContent = spec.caption;
        host.appendChild(c);
      }
    };
    draw();
    new ResizeObserver(draw).observe(el);
  }

  function init() {
    document.querySelectorAll(".matgrib:not([data-rendered])").forEach((el) => {
      el.dataset.rendered = "1";
      try { render(el); } catch (e) {
        el.textContent = "matgrib: could not render figure (" + e.message + ")";
        console.error(e);
      }
    });
  }
  window.matgrib = { render: init };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
