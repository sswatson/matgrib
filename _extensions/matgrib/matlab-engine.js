// Quarto execution engine for MATLAB whose figures render natively:
// Gribouille in Typst, Observable Plot in HTML, images everywhere else.
//
// Pipeline: break the .qmd into cells -> run every {matlab} cell in one
// MATLAB job (matgrib.runJob) -> build a Jupyter-shaped notebook from the
// results -> let Quarto's own notebook-to-markdown pass handle echo, captions,
// cross-references, layout and freeze.
//
// Document options (all optional):
//   matlab:
//     session: agent-docs      # run in this Matlock session (persistent, fast)
//     url: http://127.0.0.1:N  # or a Matlock URL directly
//     max-points: 2000         # per-line decimation budget
//     max-scatter: 3000        # larger scatters fall back to an image
//     strict: true             # image fallback if any object is untranslatable
//     palette: ["#1b9e77", ...] # series colors for both PDF and HTML
//     aspect: 0.55             # panel height / width for both
// Cell options: the usual Quarto ones, plus
//   %| matgrib: image          # force an image for this cell's figures

let quarto;

const kEngine = "matlab";
const extensionDir = new URL(".", import.meta.url).pathname;
const matlabDir = extensionDir + "matlab";

const read = (p) => Deno.readTextFileSync(p);
const exists = (p) => { try { Deno.statSync(p); return true; } catch { return false; } };

function outputKind(format) {
  const to = format.pandoc.to || "";
  if (to.startsWith("typst")) return "typst";
  if (quarto.format.isHtmlCompatible(format)) return "html";
  if (quarto.format.isLatexOutput(format.pandoc)) return "pdf";
  return "png";
}

// Quarto only recognises MATLAB cell options written as `%|`; accept `#|` too.
function normaliseOptions(src) {
  const lines = src.split(/(?<=\n)/);
  for (let i = 0; i < lines.length && /^\s*(#|%)\|/.test(lines[i]); i++) {
    lines[i] = lines[i].replace(/^(\s*)#\|/, "$1%|");
  }
  return lines;
}

function stripOptions(lines) {
  let i = 0;
  while (i < lines.length && /^\s*%\|/.test(lines[i])) i++;
  return lines.slice(i).join("");
}

function cellOption(lines, key) {
  const re = new RegExp(`^\\s*%\\|\\s*${key}:\\s*(.*?)\\s*$`);
  for (const l of lines) {
    const m = l.match(re);
    if (m) return m[1].replace(/^["']|["']$/g, "");
  }
  return undefined;
}

async function sha1(text) {
  const buf = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function matlockUrl(cfg) {
  if (cfg.url) return cfg.url.replace(/\/$/, "");
  const session = cfg.session || Deno.env.get("MATGRIB_MATLOCK_SESSION");
  if (!session) return undefined;
  const out = await new Deno.Command("matlock-serve", { args: ["--list"], stdout: "piped", stderr: "piped" }).output();
  const text = new TextDecoder().decode(out.stdout);
  for (const line of text.split("\n")) {
    const cols = line.trim().split(/\s+/);
    if (cols[0] === session && cols[2]) return cols[2];
  }
  throw new Error(`matlab engine: Matlock session '${session}' is not running (see matlock-serve --list)`);
}

async function runMatlab(jobFile, cfg) {
  const command = `addpath('${matlabDir}'); matgrib.runJob('${jobFile}')`;
  const url = await matlockUrl(cfg);
  if (url) {
    quarto.console.info(`Running MATLAB cells in Matlock session at ${url}`);
    const res = await fetch(`${url}/v1/execute`, {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ command }),
    });
    const body = await res.json();
    if (!res.ok || body.ok === false) {
      throw new Error(`matlab engine: Matlock execution failed:\n${body.error_output || body.output || JSON.stringify(body)}`);
    }
    return;
  }
  quarto.console.info("Running MATLAB cells (matlab -batch)...");
  const out = await new Deno.Command(Deno.env.get("QUARTO_MATLAB") || "matlab", {
    args: ["-batch", command], stdout: "piped", stderr: "piped",
  }).output();
  if (!out.success) {
    const dec = new TextDecoder();
    throw new Error(`matlab engine: MATLAB failed:\n${dec.decode(out.stdout)}\n${dec.decode(out.stderr)}`);
  }
}

const typstString = (s) => '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';

function figureMarkdown(fig, kind) {
  const json = JSON.stringify(fig.spec);
  // DSL plots carry no MATLAB figure aspect (jsonencode writes []).
  const aspect = typeof fig.aspect === "number" ? fig.aspect.toFixed(4) : "auto";
  if (kind === "typst") {
    return "```{=typst}\n#matgrib-figure(json(bytes(" + typstString(json) + `)), fig-aspect: ${aspect})\n` + "```\n";
  }
  return "```{=html}\n" + `<div class="matgrib" data-aspect="${aspect}"><script type="application/json">` +
    json.replace(/</g, "\\u003c") + "</script></div>\n```\n";
}

function imageOutput(file) {
  const ext = file.split(".").pop();
  const bytes = Deno.readFileSync(file);
  if (ext === "svg") {
    return { output_type: "display_data", metadata: {}, data: { "image/svg+xml": [new TextDecoder().decode(bytes)] } };
  }
  const mime = ext === "pdf" ? "application/pdf" : "image/png";
  let bin = "";
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return { output_type: "display_data", metadata: {}, data: { [mime]: btoa(bin) } };
}

// The HTML renderer and its vendored d3 / Observable Plot are copied next to
// the document (no CDN), into the supporting directory Quarto already ships
// with the page; `embed-resources: true` inlines them like any local script.
const htmlAssets = ["vendor/d3.min.js", "vendor/plot.umd.min.js", "matgrib.js", "matgrib.css"];

function copyHtmlAssets(assets) {
  const rel = `${assets.supporting_dir}/matgrib`;
  const dir = `${assets.base_dir}/${rel}`;
  Deno.mkdirSync(dir, { recursive: true });
  for (const a of htmlAssets) Deno.copyFileSync(`${extensionDir}${a}`, `${dir}/${a.split("/").pop()}`);
  return rel;
}

// `matlab: {palette: [...], aspect: 0.5}` styles both renderers at once.
function includesFor(kind, tempDir, meta, assets) {
  const file = `${tempDir}/matgrib-header.${kind === "typst" ? "typ" : "html"}`;
  const palette = meta.palette ? [].concat(meta.palette) : undefined;
  if (kind === "typst") {
    const set = [];
    if (palette) set.push(`palette: (${palette.map((c) => `rgb("${c}")`).join(", ")},)`);
    if (meta.aspect) set.push(`aspect: ${Number(meta.aspect)}`);
    Deno.writeTextFileSync(file, read(`${extensionDir}matgrib.typ`) +
      (set.length ? `\n#matgrib-set(${set.join(", ")})\n` : ""));
  } else if (kind === "html") {
    const cfg = {};
    if (palette) cfg.palette = palette;
    if (meta.aspect) cfg.aspect = Number(meta.aspect);
    const rel = copyHtmlAssets(assets);
    Deno.writeTextFileSync(file, [
      `<script>window.matgribConfig = Object.assign(${JSON.stringify(cfg)}, window.matgribConfig || {});</script>`,
      `<link rel="stylesheet" href="${rel}/matgrib.css">`,
      `<script src="${rel}/d3.min.js"></script>`,
      `<script src="${rel}/plot.umd.min.js"></script>`,
      `<script src="${rel}/matgrib.js" defer></script>`,
    ].join("\n"));
  } else {
    return undefined;
  }
  return { "include-in-header": [file] };
}

const engine = {
  init: (q) => { quarto = q; },
  name: kEngine,
  defaultExt: ".qmd",
  defaultYaml: () => [],
  defaultContent: () => ["```{matlab}", "plot(1:10)", "```"],
  validExtensions: () => [],
  claimsFile: () => false,
  claimsLanguage: (language) => language.toLowerCase() === kEngine,
  canFreeze: true,
  generatesFigures: true,
  launch: (_context) => ({
    name: kEngine,
    canFreeze: true,
    partitionedMarkdown: (file) => Promise.resolve(quarto.markdownRegex.partition(read(file))),
    executeTargetSkipped: () => false,
    dependencies: () => Promise.resolve({ includes: {} }),
    postprocess: () => Promise.resolve(),
    canKeepSource: () => true,
    markdownForFile: (file) => Promise.resolve(quarto.mappedString.fromFile(file)),
    target: (file, _quiet, markdown) => {
      markdown = markdown ?? quarto.mappedString.fromFile(file);
      return Promise.resolve({ source: file, input: file, markdown, metadata: quarto.markdownRegex.extractYaml(markdown.value) });
    },

    execute: async (options) => {
      const input = quarto.path.absolute(options.target.input);
      const docDir = input.replace(/\/[^/]*$/, "");
      const meta = options.format.metadata?.matlab ?? options.target.metadata?.matlab ?? {};
      const cfg = { session: meta.session, url: meta.url };
      const kind = outputKind(options.format);
      const imageFormat = { typst: "svg", html: "svg", pdf: "pdf", png: "png" }[kind];
      const evalAll = options.format.execute?.eval !== false;

      const chunks = await quarto.markdownRegex.breakQuartoMd(options.target.markdown, false);
      const nbCells = [];
      const jobCells = [];
      for (const c of chunks.cells) {
        if (typeof c.cell_type === "object" && c.cell_type.language === kEngine) {
          const lines = normaliseOptions(c.sourceWithYaml?.value ?? c.source.value);
          const id = `cell${nbCells.filter((c) => c._id).length + 1}`;
          const cellEval = cellOption(lines, "eval");
          const cell = { cell_type: "code", metadata: {}, source: lines, outputs: [], execution_count: null, _id: id };
          if (evalAll && cellEval !== "false") {
            jobCells.push({ id, code: stripOptions(lines), render: cellOption(lines, "matgrib") === "image" ? "image" : "native" });
          }
          nbCells.push(cell);
        } else if (typeof c.cell_type === "object") {
          // Other languages are shown, not run.
          nbCells.push({ cell_type: "markdown", metadata: {}, source: [c.sourceVerbatim.value] });
        } else {
          nbCells.push({ cell_type: c.cell_type, metadata: {}, source: c.source.value.split(/(?<=\n)/) });
        }
      }

      const assets = quarto.jupyter.assets(input, options.format.pandoc.to);
      const figDir = `${assets.base_dir}/${assets.figures_dir}`;
      Deno.mkdirSync(figDir, { recursive: true });
      const job = {
        cwd: docDir, figdir: figDir, imageFormat,
        maxPoints: meta["max-points"] ?? 2000, maxScatter: meta["max-scatter"] ?? 3000,
        strict: meta.strict ?? true,
        cells: jobCells,
      };

      let result = { cells: [] };
      if (jobCells.length) {
        // execute.cache: reuse the previous run when no cell code changed.
        const cacheDir = `${docDir}/.matgrib-cache`;
        const stem = input.split("/").pop().replace(/\.[^.]*$/, "");
        const key = await sha1(JSON.stringify({ job, v: 1 }));
        const cacheFile = `${cacheDir}/${stem}-${kind}.json`;
        const useCache = options.format.execute?.cache === true;
        if (useCache && exists(cacheFile) && JSON.parse(read(cacheFile)).key === key) {
          result = JSON.parse(read(cacheFile)).result;
          quarto.console.info("matlab engine: using cached results");
        } else {
          const jobFile = `${options.tempDir}/matgrib-job.json`;
          Deno.writeTextFileSync(jobFile, JSON.stringify(job));
          await runMatlab(jobFile, cfg);
          result = JSON.parse(read(`${jobFile}.result.json`));
          if (useCache) {
            Deno.mkdirSync(cacheDir, { recursive: true });
            for (const c of result.cells) for (const f of [].concat(c.figures ?? [])) {
              if (f.image) f.imageData = imageOutput(f.image);
            }
            Deno.writeTextFileSync(cacheFile, JSON.stringify({ key, result }));
          }
        }
      }

      const byId = Object.fromEntries([].concat(result.cells ?? []).map((c) => [c.id, c]));
      let count = 0;
      for (const cell of nbCells) {
        const r = cell._id && byId[cell._id];
        delete cell._id;
        if (!r) continue;
        cell.execution_count = ++count;
        const stdout = (r.stdout || "").replace(/^\n+/, "").replace(/\s+$/, "");
        if (stdout) cell.outputs.push({ output_type: "stream", name: "stdout", text: [stdout + "\n"] });
        if (r.error) {
          (quarto.console.warning ?? quarto.console.info)(`MATLAB error in ${r.id}: ${r.error}`);
          cell.outputs.push({ output_type: "stream", name: "stderr", text: [`Error: ${r.error}\n`] });
        }
        for (const f of [].concat(r.figures ?? [])) {
          for (const n of [].concat(f.spec?.notes ?? [])) quarto.console.info(`matlab engine: ${r.id}: ${n}`);
          const hasSpec = f.spec && !Array.isArray(f.spec);  // jsonencode writes [] for "no spec"
          if (hasSpec && (kind === "typst" || kind === "html")) {
            cell.outputs.push({ output_type: "display_data", metadata: {}, data: { "text/markdown": [figureMarkdown(f, kind)] } });
          } else if (f.image || f.imageData) {
            cell.outputs.push(f.imageData ?? imageOutput(f.image));
            if (f.unsupported?.length) quarto.console.info(`matlab engine: image fallback for ${r.id} (${[].concat(f.unsupported).join(", ")})`);
          }
        }
      }

      const nb = {
        cells: nbCells,
        metadata: { kernelspec: { display_name: "MATLAB", name: "matlab", language: "matlab" } },
        nbformat: 4, nbformat_minor: 5,
      };
      const md = await quarto.jupyter.toMarkdown(nb, {
        executeOptions: options,
        language: kEngine,
        assets,
        execute: options.format.execute,
        keepHidden: false,
        toHtml: quarto.format.isHtmlCompatible(options.format),
        toLatex: quarto.format.isLatexOutput(options.format.pandoc),
        toMarkdown: quarto.format.isMarkdownOutput(options.format),
        toIpynb: quarto.format.isIpynbOutput(options.format.pandoc),
        toPresentation: quarto.format.isPresentationOutput(options.format.pandoc),
        figFormat: options.format.execute?.["fig-format"],
        figDpi: options.format.execute?.["fig-dpi"],
      });

      return {
        engine: kEngine,
        markdown: md.cellOutputs.map((o) => o.markdown).join(""),
        supporting: [`${assets.base_dir}/${assets.supporting_dir}`],
        filters: [],
        includes: includesFor(kind, options.tempDir, meta, assets),
      };
    },
  }),
};

export default engine;
