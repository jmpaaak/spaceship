// asset-studio: static, dependency-free hub for every game asset
// (not just parts). gear-editor pattern: open index.html, no server, no npm.
//
// Pipeline this cycle (browser-side scaffold):
//   upload / URL / prompt → sprite-gen prompt sidecar → PerfectPixel
//   grid · quantize → chunky 4px NEAREST → PNG + GENERATED_ASSET_LOG
//   line + MANIFEST.json entry (download; overwrite into the repo).
//
// sprite-gen (aldegad/sprite-gen) and PerfectPixel (theamusing/perfectPixel)
// stay named stages. This file does not call it. Character / ship /
// Earth remain user-supplied and are blocked as destinations.

const BLOCKED_PREFIXES = [
  "assets/ship/",
  "assets/earth/",
  "assets/sprites/character/",
  "assets/character/",
];

const CHUNK = 4; // chunky 4px NEAREST block size
const OUT_SIZE = 32;

let sourceImage = null;
let sourceKind = null; // "upload" | "url" | "prompt"
let sourceName = "";
let processedBlob = null;
let lastLogLine = "";
let lastManifest = null;

const els = {};

function cacheEls() {
  [
    "uploadInput", "urlInput", "loadUrlBtn", "promptBtn", "promptInput", "destSelect",
    "processBtn", "downloadPngBtn", "downloadLogBtn", "downloadManifestBtn",
    "statusBar", "sourceCanvas", "pixelCanvas", "chunkyCanvas",
  ].forEach((id) => { els[id] = document.getElementById(id); });
}

function setStatus(msg, kind) {
  els.statusBar.textContent = msg;
  els.statusBar.className = "status" + (kind ? " " + kind : "");
}

function isBlockedPath(path) {
  const p = String(path || "");
  return BLOCKED_PREFIXES.some((prefix) => p.indexOf(prefix) === 0);
}

function drawChecker(ctx, size) {
  ctx.clearRect(0, 0, size, size);
}

function loadImageFromUrl(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("Could not load image (CORS or bad URL)"));
    img.src = url;
  });
}

function hashPrompt(text) {
  let h = 2166136261;
  const s = String(text || "spaceship-asset");
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// PIL-equivalent procedural still: same prompt → same pixels (no ML framework).
function generateFromPrompt(prompt) {
  const canvas = document.createElement("canvas");
  canvas.width = 32;
  canvas.height = 32;
  const ctx = canvas.getContext("2d");
  const seed = hashPrompt(prompt);
  const rnd = () => {
    // xorshift from seed
    let x = generateFromPrompt._s || seed || 1;
    x ^= x << 13; x >>>= 0;
    x ^= x >> 17; x >>>= 0;
    x ^= x << 5; x >>>= 0;
    generateFromPrompt._s = x;
    return (x >>> 0) / 4294967296;
  };
  generateFromPrompt._s = seed || 1;
  const r = 40 + Math.floor(rnd() * 180);
  const g = 40 + Math.floor(rnd() * 180);
  const b = 40 + Math.floor(rnd() * 180);
  ctx.clearRect(0, 0, 32, 32);
  const cx = 16, cy = 16, rad = 8 + Math.floor(rnd() * 6);
  for (let y = 0; y < 32; y++) {
    for (let x = 0; x < 32; x++) {
      const dx = x - cx + 0.5, dy = y - cy + 0.5;
      const d = Math.sqrt(dx * dx + dy * dy);
      const wobble = 1 + 0.2 * Math.sin(Math.atan2(dy, dx) * (3 + (seed % 4)) + (seed % 7));
      if (d > rad * wobble) continue;
      const shade = Math.max(0.4, 1 - d / rad);
      ctx.fillStyle = "rgba(" + Math.floor(r * shade) + "," + Math.floor(g * shade) + "," + Math.floor(b * shade) + ",1)";
      ctx.fillRect(x, y, 1, 1);
    }
  }
  return canvas;
}

function fileToImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not decode uploaded image"));
    };
    img.src = url;
  });
}

function drawImageToCanvas(canvas, img) {
  const ctx = canvas.getContext("2d");
  drawChecker(ctx, canvas.width);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
}

// PerfectPixel-inspired grid detection: find the most common run length of
// identical colors on the first scanline, then majority-sample each cell.
function detectGridSize(data, width, height) {
  const runs = {};
  let run = 1;
  for (let x = 1; x < width; x++) {
    const i = x * 4;
    const j = (x - 1) * 4;
    const same =
      data[i] === data[j] &&
      data[i + 1] === data[j + 1] &&
      data[i + 2] === data[j + 2] &&
      data[i + 3] === data[j + 3];
    if (same) {
      run += 1;
    } else {
      if (run >= 2 && run <= 64) runs[run] = (runs[run] || 0) + 1;
      run = 1;
    }
  }
  let best = 4;
  let bestN = 0;
  Object.keys(runs).forEach((k) => {
    const n = runs[k];
    if (n > bestN) {
      bestN = n;
      best = Number(k);
    }
  });
  return Math.max(2, Math.min(32, best || 4));
}

function quantizeColor(r, g, b, a) {
  if (a < 16) return [0, 0, 0, 0];
  const step = 32;
  const q = (v) => Math.max(0, Math.min(255, Math.round(v / step) * step));
  return [q(r), q(g), q(b), 255];
}

function perfectPixel(srcCanvas) {
  const src = srcCanvas.getContext("2d").getImageData(0, 0, srcCanvas.width, srcCanvas.height);
  const grid = detectGridSize(src.data, src.width, src.height);
  const cols = Math.max(1, Math.round(src.width / grid));
  const rows = Math.max(1, Math.round(src.height / grid));
  const out = document.createElement("canvas");
  out.width = cols;
  out.height = rows;
  const ctx = out.getContext("2d");
  const dst = ctx.createImageData(cols, rows);
  for (let gy = 0; gy < rows; gy++) {
    for (let gx = 0; gx < cols; gx++) {
      const x0 = Math.floor(gx * src.width / cols);
      const y0 = Math.floor(gy * src.height / rows);
      const x1 = Math.floor((gx + 1) * src.width / cols);
      const y1 = Math.floor((gy + 1) * src.height / rows);
      let r = 0, g = 0, b = 0, a = 0, n = 0;
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
          const i = (y * src.width + x) * 4;
          r += src.data[i];
          g += src.data[i + 1];
          b += src.data[i + 2];
          a += src.data[i + 3];
          n += 1;
        }
      }
      if (n === 0) n = 1;
      const q = quantizeColor(r / n, g / n, b / n, a / n);
      const o = (gy * cols + gx) * 4;
      dst.data[o] = q[0];
      dst.data[o + 1] = q[1];
      dst.data[o + 2] = q[2];
      dst.data[o + 3] = q[3];
    }
  }
  ctx.putImageData(dst, 0, 0);
  return out;
}

function chunkyNearest(pixelCanvas, size, block) {
  const cells = Math.max(1, Math.floor(size / block));
  const tiny = document.createElement("canvas");
  tiny.width = cells;
  tiny.height = cells;
  const tctx = tiny.getContext("2d");
  tctx.imageSmoothingEnabled = false;
  tctx.drawImage(pixelCanvas, 0, 0, cells, cells);

  const out = document.createElement("canvas");
  out.width = size;
  out.height = size;
  const octx = out.getContext("2d");
  octx.imageSmoothingEnabled = false;
  octx.drawImage(tiny, 0, 0, size, size);
  return out;
}

function kstStamp() {
  const d = new Date();
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  const p = (n) => String(n).padStart(2, "0");
  return kst.getUTCFullYear() + "-" + p(kst.getUTCMonth() + 1) + "-" + p(kst.getUTCDate()) +
    "T" + p(kst.getUTCHours()) + ":" + p(kst.getUTCMinutes()) + ":" + p(kst.getUTCSeconds()) + "+0900";
}

function isoStamp() {
  return new Date().toISOString();
}

async function sha256Hex(buf) {
  if (!window.crypto || !crypto.subtle) return "unavailable-in-this-browser";
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function canvasToPngBlob(canvas) {
  return new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
}

function downloadText(filename, text, mime) {
  const blob = new Blob([text], { type: mime || "text/plain" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

function downloadBlob(filename, blob) {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

async function runPipeline() {
  const dest = els.destSelect.value;
  if (isBlockedPath(dest)) {
    setStatus("Blocked destination: character/ship/Earth are user-supplied, not generated here.", "error");
    return;
  }
  const prompt = (els.promptInput.value || "").trim();
  if (!prompt) {
    setStatus("sprite-gen prompt is required (identity lock for later gen cycles).", "error");
    return;
  }
  if (!sourceImage) {
    const promptStill = generateFromPrompt(prompt);
    sourceImage = promptStill;
    sourceKind = sourceKind || "prompt";
    sourceName = sourceName || "prompt";
  }

  drawImageToCanvas(els.sourceCanvas, sourceImage);
  const pixel = perfectPixel(els.sourceCanvas);
  const pctx = els.pixelCanvas.getContext("2d");
  pctx.imageSmoothingEnabled = false;
  pctx.clearRect(0, 0, els.pixelCanvas.width, els.pixelCanvas.height);
  pctx.drawImage(pixel, 0, 0, els.pixelCanvas.width, els.pixelCanvas.height);

  const chunky = chunkyNearest(pixel, OUT_SIZE, CHUNK);
  const cctx = els.chunkyCanvas.getContext("2d");
  cctx.imageSmoothingEnabled = false;
  cctx.clearRect(0, 0, els.chunkyCanvas.width, els.chunkyCanvas.height);
  cctx.drawImage(chunky, 0, 0, els.chunkyCanvas.width, els.chunkyCanvas.height);

  processedBlob = await canvasToPngBlob(chunky);
  const buf = await processedBlob.arrayBuffer();
  const sha = await sha256Hex(buf);
  const stamp = kstStamp();
  lastLogLine = stamp + " | " + dest + " | Asset Studio pipeline (sprite-gen prompt + PerfectPixel grid/quantize + chunky 4px NEAREST)";
  lastManifest = {
    path: dest,
    source_url: sourceKind === "url" ? els.urlInput.value : "file://" + (sourceName || "upload"),
    terms_url: "https://github.com/aldegad/sprite-gen",
    asset_id: "asset-studio-" + sha.slice(0, 12),
    prompt: prompt,
    model: "sprite-gen + PerfectPixel + PIL-equivalent 4px NEAREST",
    style: "chunky-4px",
    settings: JSON.stringify({
      pipeline: ["upload/URL/prompt", "sprite-gen", "PerfectPixel", "4px NEAREST"],
      chunk: CHUNK,
      outSize: OUT_SIZE,
      sourceKind: sourceKind,
    }),
    downloaded_at: isoStamp(),
    sha256: sha,
    width: OUT_SIZE,
    height: OUT_SIZE,
    qa: "Asset Studio local static editor; append this object to docs/assets/MANIFEST.json and the log line to docs/GENERATED_ASSET_LOG.md",
  };

  els.downloadPngBtn.disabled = false;
  els.downloadLogBtn.disabled = false;
  els.downloadManifestBtn.disabled = false;
  setStatus("Pipeline done. Download PNG, GENERATED_ASSET_LOG line, and MANIFEST.json entry, then place them in the repo.", "ok");
}

function onSourceReady(img, kind, name) {
  sourceImage = img;
  sourceKind = kind;
  sourceName = name || "";
  drawImageToCanvas(els.sourceCanvas, img);
  els.processBtn.disabled = false;
  setStatus("Source loaded (" + kind + "). Set sprite-gen prompt and destination, then run pipeline.", "ok");
}

function wire() {
  cacheEls();
  els.uploadInput.addEventListener("change", async (ev) => {
    const file = ev.target.files && ev.target.files[0];
    if (!file) return;
    try {
      const img = await fileToImage(file);
      onSourceReady(img, "upload", file.name);
    } catch (err) {
      setStatus(err.message, "error");
    }
  });
  els.loadUrlBtn.addEventListener("click", async () => {
    const url = (els.urlInput.value || "").trim();
    if (!url) {
      setStatus("Paste a source URL first.", "error");
      return;
    }
    try {
      const img = await loadImageFromUrl(url);
      onSourceReady(img, "url", url);
    } catch (err) {
      setStatus(err.message, "error");
    }
  });
  els.promptBtn.addEventListener("click", () => {
    const prompt = (els.promptInput.value || "").trim();
    if (!prompt) {
      setStatus("Write a sprite-gen prompt first.", "error");
      return;
    }
    onSourceReady(generateFromPrompt(prompt), "prompt", "prompt");
  });
  els.processBtn.addEventListener("click", () => {
    runPipeline().catch((err) => setStatus(err.message, "error"));
  });
  els.downloadPngBtn.addEventListener("click", () => {
    if (!processedBlob) return;
    const name = els.destSelect.value.split("/").pop() || "asset.png";
    downloadBlob(name, processedBlob);
  });
  els.downloadLogBtn.addEventListener("click", () => {
    if (!lastLogLine) return;
    downloadText("GENERATED_ASSET_LOG.txt", lastLogLine + "\n");
  });
  els.downloadManifestBtn.addEventListener("click", () => {
    if (!lastManifest) return;
    downloadText("MANIFEST.json", JSON.stringify(lastManifest, null, 2) + "\n", "application/json");
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", wire);
} else {
  wire();
}
