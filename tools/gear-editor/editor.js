// gear-editor: static, dependency-free editor for game/data/hull_parts.json
// and game/data/engine_parts.json (docs/feedback/INBOX.md item 13).
//
// Validation rules here intentionally mirror game/gear.lua's loader
// exactly (same known effect types, known rarities, and effect value
// range) so a card that validates in this editor is guaranteed to load
// cleanly in the actual game.

// Item 14: "부품 효과 종류(effect schema) 확장 — 가산형 5종 + 배율/트리거/조작형
// 추가". Grouped by schema category (A~F) so this list — and the effect
// type <select> built from it — stays organized as the schema grows; the
// flat KNOWN_EFFECT_TYPES array below is what actually drives validation
// and must be kept byte-for-byte in sync with game/gear.lua's
// M.knownEffectTypes whitelist (game/self_test.lua's
// testGearEffectSchemaExpansion asserts this).
const EFFECT_TYPE_GROUPS = {
  "A: additive": ["speed", "sampleSellValue", "money", "climbSpeed", "hullDurability"],
  "B: multiplicative": ["sellMultiplier", "streakMultiplier"],
  "C: trigger/probability": ["luck", "chainTrigger", "rerollBonus"],
  "D: survival/risk": ["insurance", "collisionRadius"],
  "E: scouting/info": ["detectionRadius", "autoCollect"],
  "F: economy": ["shopDiscount"],
  "G: propulsion (engine parts)": ["fuelEfficiency", "steeringResponsiveness", "boostCharge"],
};
const KNOWN_EFFECT_TYPES = Object.values(EFFECT_TYPE_GROUPS).flat();
const KNOWN_RARITIES = ["common", "uncommon", "rare", "legendary"];
// Item 12: known edition ids a card's `editions` array may reference (must
// stay identical to game/gear.lua's M.knownEditions whitelist).
const KNOWN_EDITIONS = ["irradiated", "crystallized", "quantum_flawed", "refined"];
const EDITION_EFFECTS = {
  "irradiated": { scope: "all", multiplier: 1.0, synergyBonusAdd: 0.05 },
  "crystallized": { scope: "sampleSellValue", multiplier: 2.0 },
  "quantum_flawed": { scope: "all", multiplier: 2.0, drawback: { type: "hullDurability", value: -1 } },
  "refined": { scope: "all", multiplier: 0.5, noSlotCost: true },
};
const EFFECT_VALUE_MIN = -100;
const EFFECT_VALUE_MAX = 100;

/** @type {{schemaVersion: number, parts: Array<object>}|null} */
let pool = null;
let fileHandle = null; // File System Access API handle, when available
let editingId = null; // id of the card currently open in the form, or null for "new"

const els = {};
function cacheEls() {
  [
    "openHullInput", "openEngineInput", "openFsaBtn", "saveFsaBtn",
    "downloadBtn", "newCardBtn", "statusBar", "grid", "formPanel",
    "formTitle", "cardForm", "fieldId", "fieldName", "fieldNameKo",
    "fieldIcon", "fieldRarity", "rarityPreview", "fieldTags",
    "fieldEditions", "effectsList", "addEffectBtn", "saveCardBtn",
    "deleteCardBtn", "cancelBtn", "formError", "editionPreviewContainer"
  ].forEach((id) => { els[id] = document.getElementById(id); });
}

function setStatus(message, kind) {
  els.statusBar.textContent = message;
  els.statusBar.className = "status" + (kind ? " " + kind : "");
}

function isNonEmptyString(v) {
  return typeof v === "string" && v.length > 0;
}

// Validates a whole pool document. Returns [] on success, or an array of
// human-readable error strings (mirrors game/gear.lua's validatePart /
// parsePool checks, including duplicate-id detection).
function validatePool(doc) {
  const errors = [];
  if (!doc || typeof doc !== "object" || !Array.isArray(doc.parts)) {
    return ["document must be an object with a 'parts' array"];
  }
  const seenIds = new Set();
  doc.parts.forEach((part, index) => {
    const prefix = `part #${index + 1} (${part && part.id ? part.id : "?"})`;
    if (!part || typeof part !== "object") {
      errors.push(`${prefix}: is not an object`);
      return;
    }
    if (!isNonEmptyString(part.id)) errors.push(`${prefix}: missing non-empty id`);
    if (!isNonEmptyString(part.name)) errors.push(`${prefix}: missing non-empty name`);
    if (!isNonEmptyString(part.icon)) errors.push(`${prefix}: missing non-empty icon`);
    if (!KNOWN_RARITIES.includes(part.rarity)) errors.push(`${prefix}: unknown rarity '${part.rarity}'`);
    if (Array.isArray(part.editions)) {
      part.editions.forEach((edition) => {
        if (isNonEmptyString(edition) && !KNOWN_EDITIONS.includes(edition)) {
          errors.push(`${prefix}: unknown edition '${edition}'`);
        }
      });
    }
    if (!Array.isArray(part.effects) || part.effects.length === 0) {
      errors.push(`${prefix}: must have at least one effect`);
    } else {
      part.effects.forEach((effect, effectIndex) => {
        if (!effect || !KNOWN_EFFECT_TYPES.includes(effect.type)) {
          errors.push(`${prefix} effect #${effectIndex + 1}: unknown type '${effect && effect.type}'`);
        }
        if (!effect || typeof effect.value !== "number" || Number.isNaN(effect.value)) {
          errors.push(`${prefix} effect #${effectIndex + 1}: non-numeric value`);
        } else if (effect.value < EFFECT_VALUE_MIN || effect.value > EFFECT_VALUE_MAX) {
          errors.push(`${prefix} effect #${effectIndex + 1}: value ${effect.value} out of range [${EFFECT_VALUE_MIN}, ${EFFECT_VALUE_MAX}]`);
        }
      });
    }
    if (isNonEmptyString(part.id)) {
      if (seenIds.has(part.id)) errors.push(`duplicate part id '${part.id}'`);
      seenIds.add(part.id);
    }
  });
  return errors;
}

function loadDocument(doc, name) {
  const errors = validatePool(doc);
  if (errors.length > 0) {
    setStatus(`Loaded '${name}' but it failed validation:\n` + errors.join("\n"), "error");
  } else {
    setStatus(`Loaded '${name}' — ${doc.parts.length} card(s), all valid.`, "ok");
  }
  pool = doc;
  els.downloadBtn.disabled = false;
  els.newCardBtn.disabled = false;
  renderGrid();
}

function readFileAsJson(file) {
  return file.text().then((text) => JSON.parse(text));
}

function wireOpenInput(inputEl) {
  inputEl.addEventListener("change", () => {
    const file = inputEl.files[0];
    if (!file) return;
    readFileAsJson(file)
      .then((doc) => { fileHandle = null; els.saveFsaBtn.disabled = true; loadDocument(doc, file.name); })
      .catch((err) => setStatus(`Failed to parse '${file.name}': ${err.message}`, "error"));
  });
}

function wireOpenFsa() {
  els.openFsaBtn.addEventListener("click", async () => {
    if (!window.showOpenFilePicker) {
      setStatus("File System Access API not supported in this browser — use the Open buttons instead.", "error");
      return;
    }
    try {
      const [handle] = await window.showOpenFilePicker({
        types: [{ description: "Gear JSON", accept: { "application/json": [".json"] } }],
      });
      const file = await handle.getFile();
      const doc = await readFileAsJson(file);
      fileHandle = handle;
      els.saveFsaBtn.disabled = false;
      loadDocument(doc, file.name);
    } catch (err) {
      if (err.name !== "AbortError") setStatus(`Failed to open file: ${err.message}`, "error");
    }
  });
}

function serializePool() {
  return JSON.stringify(pool, null, 2) + "\n";
}

function wireSaveFsa() {
  els.saveFsaBtn.addEventListener("click", async () => {
    if (!fileHandle || !pool) return;
    const errors = validatePool(pool);
    if (errors.length > 0) {
      setStatus("Cannot save: pool has validation errors:\n" + errors.join("\n"), "error");
      return;
    }
    try {
      const writable = await fileHandle.createWritable();
      await writable.write(serializePool());
      await writable.close();
      setStatus("Saved to disk.", "ok");
    } catch (err) {
      setStatus(`Failed to save: ${err.message}`, "error");
    }
  });
}

function wireDownload() {
  els.downloadBtn.addEventListener("click", () => {
    if (!pool) return;
    const errors = validatePool(pool);
    if (errors.length > 0) {
      setStatus("Cannot download: pool has validation errors:\n" + errors.join("\n"), "error");
      return;
    }
    const blob = new Blob([serializePool()], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "gear_parts.json";
    a.click();
    URL.revokeObjectURL(url);
    setStatus("Downloaded gear_parts.json — move it into game/data/ to replace the original.", "ok");
  });
}

const RARITY_COLOR = {
  common: "#b0b6c1",
  uncommon: "#52d17a",
  rare: "#4a90ff",
  legendary: "#ffb347",
};

function renderGrid() {
  els.grid.innerHTML = "";
  if (!pool) return;
  pool.parts.forEach((part) => {
    const card = document.createElement("div");
    card.className = `card rarity-${part.rarity || "common"}`;
    card.tabIndex = 0;
    card.innerHTML = `
      <div class="icon">${escapeHtml(part.icon || "?")}</div>
      <div class="name">${escapeHtml(part.name || part.id)}</div>
      <div class="rarity-label">${escapeHtml(part.rarity || "?")}</div>
      <div class="effects">${(part.effects || []).map((e) => `<div>${escapeHtml(e.type)} ${e.value >= 0 ? "+" : ""}${e.value}</div>`).join("")}</div>
    `;
    card.addEventListener("click", () => openForm(part.id));
    els.grid.appendChild(card);
  });
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

function addEffectRow(type, value) {
  const row = document.createElement("div");
  row.className = "effect-row";
  const select = document.createElement("select");
  // Item 14: group the dropdown by schema category (A~F) so the ~15
  // effect types stay navigable as the schema grows, instead of one long
  // flat list.
  Object.entries(EFFECT_TYPE_GROUPS).forEach(([groupLabel, types]) => {
    const group = document.createElement("optgroup");
    group.label = groupLabel;
    types.forEach((t) => {
      const opt = document.createElement("option");
      opt.value = t;
      opt.textContent = t;
      if (t === type) opt.selected = true;
      group.appendChild(opt);
    });
    select.appendChild(group);
  });
  const input = document.createElement("input");
  input.type = "text";
  input.placeholder = "value";
  input.value = value !== undefined ? String(value) : "";
  
  input.addEventListener("input", updateEditionPreview);
  select.addEventListener("change", updateEditionPreview);
  const removeBtn = document.createElement("button");
  removeBtn.type = "button";
  removeBtn.textContent = "✕";
  removeBtn.addEventListener("click", () => { row.remove(); updateEditionPreview(); });

  row.appendChild(select);
  row.appendChild(input);
  row.appendChild(removeBtn);
  els.effectsList.appendChild(row);
}

function openForm(id) {
  editingId = id;
  els.formPanel.classList.remove("hidden");
  els.formError.textContent = "";
  els.effectsList.innerHTML = "";

  if (id === null) {
    els.formTitle.textContent = "New Card";
    els.fieldId.value = "";
    els.fieldId.disabled = false;
    els.fieldName.value = "";
    els.fieldNameKo.value = "";
    els.fieldIcon.value = "";
    els.fieldRarity.value = "common";
    els.fieldTags.value = "";
    els.fieldEditions.value = "";
    addEffectRow(KNOWN_EFFECT_TYPES[0], 1);
    els.deleteCardBtn.style.display = "none";
  } else {
    const part = pool.parts.find((p) => p.id === id);
    els.formTitle.textContent = `Edit: ${part.name}`;
    els.fieldId.value = part.id;
    els.fieldId.disabled = true; // id is the stable key; rename by delete+recreate
    els.fieldName.value = part.name || "";
    els.fieldNameKo.value = part.nameKo || "";
    els.fieldIcon.value = part.icon || "";
    els.fieldRarity.value = part.rarity || "common";
    els.fieldTags.value = (part.tags || []).join(", ");
    els.fieldEditions.value = (part.editions || []).join(", ");
    (part.effects || []).forEach((e) => addEffectRow(e.type, e.value));
    els.deleteCardBtn.style.display = "";
  }
  updateRarityPreview();
  updateEditionPreview();
}

function closeForm() {
  els.formPanel.classList.add("hidden");
  editingId = null;
}


function updateEditionPreview() {
  els.editionPreviewContainer.innerHTML = "";
  const candidate = collectFormPart();
  const validEditions = candidate.editions.filter(e => KNOWN_EDITIONS.includes(e));
  if (validEditions.length === 0 || candidate.effects.length === 0) return;

  const h3 = document.createElement("h3");
  h3.textContent = "Edition Previews";
  els.editionPreviewContainer.appendChild(h3);

  validEditions.forEach(editionId => {
    const def = EDITION_EFFECTS[editionId];
    if (!def) return;
    
    const outEffects = candidate.effects.map(e => ({ type: e.type, value: e.value }));
    outEffects.forEach(effect => {
      if (def.scope === "all" || def.scope === effect.type) {
        effect.value = effect.value * def.multiplier;
      }
    });
    if (def.drawback) {
      outEffects.push({ type: def.drawback.type, value: def.drawback.value });
    }

    const item = document.createElement("div");
    item.className = "edition-preview-item";
    
    let html = `<strong>${escapeHtml(editionId)}</strong>: `;
    const effectStrs = outEffects.map(e => `${escapeHtml(e.type)} ${e.value >= 0 ? "+" : ""}${e.value}`);
    if (def.synergyBonusAdd) {
      effectStrs.push(`(synergy +${def.synergyBonusAdd})`);
    }
    if (def.noSlotCost) {
      effectStrs.push(`(no slot cost)`);
    }
    html += effectStrs.join(", ");
    
    item.innerHTML = html;
    els.editionPreviewContainer.appendChild(item);
  });
}

function updateRarityPreview() {
  els.rarityPreview.style.background = RARITY_COLOR[els.fieldRarity.value] || "#000";
}

function collectFormPart() {
  const effects = Array.from(els.effectsList.querySelectorAll(".effect-row")).map((row) => {
    const type = row.querySelector("select").value;
    const rawValue = row.querySelector("input").value;
    const value = Number(rawValue);
    return { type, value };
  });
  const tags = els.fieldTags.value.split(",").map((s) => s.trim()).filter(Boolean);
  const editions = els.fieldEditions.value.split(",").map((s) => s.trim()).filter(Boolean);
  return {
    id: els.fieldId.value.trim(),
    name: els.fieldName.value.trim(),
    nameKo: els.fieldNameKo.value.trim() || els.fieldName.value.trim(),
    icon: els.fieldIcon.value.trim(),
    rarity: els.fieldRarity.value,
    tags,
    editions,
    effects,
  };
}

function wireForm() {
  els.fieldRarity.addEventListener("change", updateRarityPreview);
  els.fieldEditions.addEventListener("input", updateEditionPreview);
  els.addEffectBtn.addEventListener("click", () => addEffectRow(KNOWN_EFFECT_TYPES[0], 0));
  els.cancelBtn.addEventListener("click", closeForm);
  els.newCardBtn.addEventListener("click", () => openForm(null));

  els.deleteCardBtn.addEventListener("click", () => {
    if (!editingId || !pool) return;
    pool.parts = pool.parts.filter((p) => p.id !== editingId);
    setStatus(`Deleted '${editingId}'. Remember to save/download.`, "ok");
    renderGrid();
    closeForm();
  });

  els.cardForm.addEventListener("submit", (event) => {
    event.preventDefault();
    if (!pool) return;
    const candidate = collectFormPart();

    // Build a hypothetical pool with this card applied, then run it
    // through the same validator used for save/download so the form
    // can never produce a card that would fail to load in the game.
    const others = pool.parts.filter((p) => p.id !== editingId);
    const hypothetical = { schemaVersion: pool.schemaVersion, parts: [...others, candidate] };
    const errors = validatePool(hypothetical);
    if (errors.length > 0) {
      els.formError.textContent = errors.join("\n");
      return;
    }

    pool.parts = hypothetical.parts;
    setStatus(`Saved '${candidate.id}' in memory. Use "Save to disk" or "Download JSON" to persist.`, "ok");
    renderGrid();
    closeForm();
  });
}

function init() {
  cacheEls();
  wireOpenInput(els.openHullInput);
  wireOpenInput(els.openEngineInput);
  wireOpenFsa();
  wireSaveFsa();
  wireDownload();
  wireForm();
  setStatus("Open a hull_parts.json or engine_parts.json file to begin.");
}

document.addEventListener("DOMContentLoaded", init);
