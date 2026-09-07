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
  "A: additive": ["speed", "sampleSellValue", "money", "hullDurability"],
  "B: multiplicative": ["sellMultiplier", "streakMultiplier"],
  "C: trigger/probability": ["luck", "chainTrigger", "rerollBonus"],
  "D: survival/risk": ["insurance", "collisionRadius", "hullRegen"],
  "E: scouting/info": ["detectionRadius", "autoCollect"],
  "F: economy": ["shopDiscount"],
  "G: propulsion (engine parts)": ["fuelEfficiency", "boostCharge"],
};
const KNOWN_EFFECT_TYPES = Object.values(EFFECT_TYPE_GROUPS).flat();
const KNOWN_RARITIES = ["common", "uncommon", "rare", "legendary"];
const KNOWN_SUITS = ["solar", "nebula", "void", "pulsar"];
const LOCALE_STORAGE_KEY = "gear-editor-locale";
let editorLocale = "ko";
// Mirrors game/i18n.lua rarity_*/suit_*/effect_* / synergy_* (no symbol prefixes).
const I18N = {
  en: {
    synergyTitle: "SYNERGIES",
    galaxyExclusive: "galaxy exclusive",
    slotExclusive: "slot exclusive",
    rarity: { common: "COMMON", uncommon: "UNCOMMON", rare: "RARE", legendary: "LEGENDARY" },
    suit: { solar: "SOLAR", nebula: "NEBULA", void: "VOID", pulsar: "PULSAR" },
    effect: {
      speed: "SPEED +%d",
      hullDurability: "HULL %+d",
      sampleSellValue: "HARVEST +%d",
      money: "MONEY +%d",
      sellMultiplier: "HARVEST +%d%%",
      shopDiscount: "SHOP -%d%%",
      collisionRadius: "HITBOX %+d",
      detectionRadius: "DETECT %+d",
      luck: "LUCK +%d",
      rerollBonus: "REROLL +%d",
      boostCharge: "BOOST +%d",
      autoCollect: "AUTO COLLECT",
      chainTrigger: "CHAIN",
      insurance: "INSURANCE",
      streakMultiplier: "STREAK +%d%%",
      hullRegen: "REGEN +%.1f/s",
      fuelEfficiency: "FUEL +%d",
    },
  },
  ko: {
    synergyTitle: "시너지",
    galaxyExclusive: "은하 전용",
    slotExclusive: "슬롯 전용",
    rarity: { common: "커먼", uncommon: "언커먼", rare: "레어", legendary: "전설" },
    suit: { solar: "솔라", nebula: "네뷸라", void: "보이드", pulsar: "펄서" },
    effect: {
      speed: "속도 +%d",
      hullDurability: "내구 %+d",
      sampleSellValue: "수확 +%d",
      money: "수확 +%d",
      sellMultiplier: "수확 +%d%%",
      shopDiscount: "상점 -%d%%",
      collisionRadius: "충돌 %+d",
      detectionRadius: "탐지 %+d",
      luck: "행운 +%d",
      rerollBonus: "리롤 +%d",
      boostCharge: "부스트 +%d",
      autoCollect: "자동 채집",
      chainTrigger: "연쇄",
      insurance: "보험",
      streakMultiplier: "연속 +%d%%",
      hullRegen: "회복 +%.1f/초",
      fuelEfficiency: "연료 +%d",
    },
  },
};
const STELLAR_SYNERGIES = [
  { key: "solarSystem",  suit: "solar",  name: { ko: "태양계 시너지", en: "SOLAR SYSTEM" }, desc: { ko: "솔라 3+: 착지 시 최대내구 +1", en: "3+ SOLAR: +1 max HP on land" } },
  { key: "nebulaField",  suit: "nebula", name: { ko: "성운 지대", en: "NEBULA FIELD" }, desc: { ko: "네뷸라 3+: 수확 x1.5", en: "3+ NEBULA: harvest x1.5" } },
  { key: "eventHorizon", suit: "void",   name: { ko: "사건의 지평선", en: "EVENT HORIZON" }, desc: { ko: "보이드 3+: 채집 +30%", en: "3+ VOID: collect +30%" } },
  { key: "pulsarBurst",  suit: "pulsar", name: { ko: "펄서 폭발", en: "PULSAR BURST" }, desc: { ko: "펄서 2+: 연속 x2", en: "2+ PULSAR: streak x2" } },
  { key: "binaryStar",   suit: null,     name: { ko: "쌍성", en: "BINARY STAR" }, desc: { ko: "솔라2+네뷸라2: 착지 +$30", en: "2S+2N: +30$ on land" } },
  { key: "supernova",    suit: null,     name: { ko: "초신성", en: "SUPERNOVA" }, desc: { ko: "4수트: 전설 x1.5", en: "ALL 4: legendary x1.5" } },
  { key: "darkMatter",   suit: null,     name: { ko: "암흑물질", en: "DARK MATTER" }, desc: { ko: "보이드2+펄서2: 연속 +50%", en: "2V+2P: streak +50%" } },
];
const SUIT_COLOR = { solar: "#ffb347", nebula: "#c084fc", void: "#5b8def", pulsar: "#5ce1e6" };
// Item 12: known edition ids a card's `editions` array may reference (must
// stay identical to game/gear.lua's M.knownEditions whitelist).
const KNOWN_EDITIONS = ["irradiated", "crystallized", "quantum_flawed", "refined"];
const EDITION_EFFECTS = {
  "irradiated": { scope: "all", multiplier: 1.0, synergyBonusAdd: 0.05 },
  "crystallized": { scope: "sampleSellValue", multiplier: 2.0, sellMultiplier: 2 },
  "quantum_flawed": { scope: "all", multiplier: 2.0, drawback: { type: "hullDurability", value: -1 } },
  "refined": { scope: "all", multiplier: 0.5, noSlotCost: true },
};
const EFFECT_VALUE_MIN = -100;
const EFFECT_VALUE_MAX = 100;

// Item 9(c)/12 economy axis: game/gear.lua's M.raritySellValue /
// M.editionSellBonus / M.buyPriceMultiplier / M.sellValue / M.buyPrice.
// Until this constant set existed, the web editor had zero visibility into
// a card's actual sell/buy economics -- an author designing a new legendary
// card had no way to see (without reading Lua) that it refunds 40 (or 86
// crystallized) and costs 120 (or 258 crystallized) at Earth shop, even
// though those numbers are entirely rarity+edition-derived and therefore
// exactly the kind of thing item 14's "웹 에디터 폼 동기화" mandate covers.
// Must stay byte-for-byte in sync with gear.lua (mirrors the existing
// EDITION_EFFECTS/KNOWN_EDITIONS/KNOWN_RARITIES/EFFECT_VALUE_MIN/MAX sync
// pattern already enforced by game/self_test.lua).
const RARITY_SELL_VALUE = { common: 4, uncommon: 9, rare: 18, legendary: 40 };
const EDITION_SELL_BONUS = 6;
const BUY_PRICE_MULTIPLIER = 3;

// Mirrors gear.lua's M.sellValue(part): unknown/missing rarity falls back
// to common (defensive money calc, not schema validation -- validatePool
// above already guarantees a known rarity for any card that would save).
function computeSellValue(rarity, editionId) {
  let base = RARITY_SELL_VALUE[rarity] !== undefined ? RARITY_SELL_VALUE[rarity] : RARITY_SELL_VALUE.common;
  const def = editionId && EDITION_EFFECTS[editionId];
  if (def && def.sellMultiplier) base = base * def.sellMultiplier;
  if (editionId) base = base + EDITION_SELL_BONUS;
  return base;
}

// Mirrors gear.lua's M.buyPrice(part) = M.sellValue(part) * M.buyPriceMultiplier.
function computeBuyPrice(rarity, editionId) {
  return computeSellValue(rarity, editionId) * BUY_PRICE_MULTIPLIER;
}

/** @type {{schemaVersion: number, parts: Array<object>}|null} */
let hullPool = null;
let enginePool = null;
let activeKind = "hull"; // "hull" | "engine"
let pool = null; // currently displayed pool (hullPool or enginePool)
let fileHandle = null; // File System Access API handle, when available
let editingId = null; // id of the card currently open in the form, or null for "new"

const els = {};
function cacheEls() {
  [
    "openHullInput", "openEngineInput", "openFsaBtn", "saveFsaBtn",
    "tabHull", "tabEngine",
    "downloadBtn", "newCardBtn", "statusBar", "grid", "formPanel",
    "formTitle", "cardForm", "fieldId", "fieldName", "fieldNameKo",
    "fieldIcon", "fieldRarity", "rarityPreview", "fieldSuit", "fieldTags",
    "fieldEditions", "fieldGalaxyExclusive", "fieldSlotExclusive", "effectsList", "addEffectBtn", "saveCardBtn",
    "deleteCardBtn", "cancelBtn", "formError", "editionPreviewContainer", "economyPreviewContainer",
    "synergyPanel", "localeKoBtn", "localeEnBtn"
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
    if (part.suit != null && part.suit !== "" && !KNOWN_SUITS.includes(part.suit)) {
      errors.push(`${prefix}: unknown suit '${part.suit}'`);
    }
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

function poolKindFromName(name) {
  const n = String(name || "").toLowerCase();
  if (n.indexOf("engine") >= 0) return "engine";
  if (n.indexOf("hull") >= 0) return "hull";
  return activeKind;
}

function storePool(kind, doc) {
  if (kind === "engine") enginePool = doc;
  else hullPool = doc;
}

function syncActivePool() {
  pool = activeKind === "engine" ? enginePool : hullPool;
  const ready = !!pool;
  els.downloadBtn.disabled = !ready;
  els.newCardBtn.disabled = !ready;
}

function loadDocument(doc, name) {
  const errors = validatePool(doc);
  if (errors.length > 0) {
    setStatus(`Loaded '${name}' but it failed validation:\n` + errors.join("\n"), "error");
  } else {
    setStatus(`Loaded '${name}' — ${doc.parts.length} card(s), all valid.`, "ok");
  }
  const kind = poolKindFromName(name);
  storePool(kind, doc);
  if (kind === activeKind) {
    syncActivePool();
    renderGrid();
  }
}

function readFileAsJson(file) {
  return file.text().then((text) => JSON.parse(text));
}

function wireOpenInput(inputEl, kindHint) {
  inputEl.addEventListener("change", () => {
    const file = inputEl.files[0];
    if (!file) return;
    readFileAsJson(file)
      .then((doc) => {
        fileHandle = null;
        els.saveFsaBtn.disabled = true;
        const name = kindHint === "engine"
          ? (file.name.indexOf("engine") >= 0 ? file.name : "engine_parts.json")
          : (kindHint === "hull"
            ? (file.name.indexOf("hull") >= 0 ? file.name : "hull_parts.json")
            : file.name);
        loadDocument(doc, name);
      })
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
    a.download = activeKind === "engine" ? "engine_parts.json" : "hull_parts.json";
    a.click();
    URL.revokeObjectURL(url);
    setStatus(`Downloaded ${a.download} — move it into game/data/ to replace the original.`, "ok");
  });
}

const RARITY_COLOR = {
  common: "#b0b6c1",
  uncommon: "#52d17a",
  rare: "#4a90ff",
  legendary: "#ffb347",
};

function loadLocale() {
  try {
    const stored = localStorage.getItem(LOCALE_STORAGE_KEY);
    if (stored === "en" || stored === "ko") editorLocale = stored;
  } catch (_) { /* file:// or disabled storage */ }
}

function setLocale(locale) {
  editorLocale = locale === "en" ? "en" : "ko";
  try { localStorage.setItem(LOCALE_STORAGE_KEY, editorLocale); } catch (_) { /* ignore */ }
  if (els.localeKoBtn) els.localeKoBtn.classList.toggle("active", editorLocale === "ko");
  if (els.localeEnBtn) els.localeEnBtn.classList.toggle("active", editorLocale === "en");
  document.documentElement.lang = editorLocale;
  renderGrid();
  renderSynergyPanel();
}

function packI18n(template, value) {
  if (template.indexOf("%+d") >= 0) {
    const sign = value >= 0 ? "+" : "";
    return template.replace("%+d", sign + String(value));
  }
  if (template.indexOf("%d") >= 0) return template.replace("%d", String(value));
  if (template.indexOf("%.1f") >= 0) return template.replace("%.1f", Number(value).toFixed(1));
  return template;
}

function formatEffectLine(effect) {
  const pack = I18N[editorLocale] || I18N.ko;
  const template = (pack.effect && pack.effect[effect.type]) || (effect.type + " %d");
  if (effect.mode === "multiply") {
    const label = template.replace(/[+\-]?%[+.]?\d*[df]?%%?/g, "").replace(/[+\-]?%.1f\/(s|초)/g, "").trim();
    return (label || effect.type) + " ×" + effect.value;
  }
  return packI18n(template, effect.value);
}

function partDisplayName(part) {
  if (editorLocale === "ko") return part.nameKo || part.name || part.id;
  return part.name || part.id;
}

function rarityLabel(rarity) {
  const pack = I18N[editorLocale] || I18N.ko;
  return (pack.rarity && pack.rarity[rarity]) || rarity || "?";
}

function suitLabel(suit) {
  const pack = I18N[editorLocale] || I18N.ko;
  return (pack.suit && pack.suit[suit]) || suit;
}

function renderGrid() {
  if (!els.grid) return;
  els.grid.innerHTML = "";
  if (!pool) return;
  const pack = I18N[editorLocale] || I18N.ko;
  pool.parts.forEach((part) => {
    const card = document.createElement("div");
    card.className = `card rarity-${part.rarity || "common"}`;
    card.tabIndex = 0;
    const suit = part.suit || "";
    const suitChip = suit
      ? `<div class="suit-chip suit-${escapeHtml(suit)}">${escapeHtml(suitLabel(suit))}</div>`
      : "";
    const extra = [];
    if (part.galaxyExclusive) extra.push(pack.galaxyExclusive);
    if (part.slotExclusive) extra.push(pack.slotExclusive);
    const extraStr = extra.length ? " · " + extra.join(" · ") : "";
    card.innerHTML = `
      <div class="icon">${escapeHtml(part.icon || "?")}</div>
      <div class="name">${escapeHtml(partDisplayName(part))}</div>
      <div class="rarity-label">${escapeHtml(rarityLabel(part.rarity))}${escapeHtml(extraStr)}</div>
      ${suitChip}
      <div class="effects">${(part.effects || []).map((e) => `<div>${escapeHtml(formatEffectLine(e))}</div>`).join("")}</div>
    `;
    card.addEventListener("click", () => openForm(part.id));
    els.grid.appendChild(card);
  });
}

function renderSynergyPanel() {
  if (!els.synergyPanel) return;
  const pack = I18N[editorLocale] || I18N.ko;
  const loc = editorLocale === "en" ? "en" : "ko";
  els.synergyPanel.innerHTML = `<h2>${escapeHtml(pack.synergyTitle)}</h2>` + STELLAR_SYNERGIES.map((s) => {
    const color = s.suit ? (SUIT_COLOR[s.suit] || "#8b93a7") : "#e6e9ef";
    const name = (s.name && s.name[loc]) || s.name || s.key;
    const desc = (s.desc && s.desc[loc]) || s.desc || "";
    return `<div class="synergy-item" style="border-left-color:${color}">
      <div class="synergy-name">${escapeHtml(name)}</div>
      <div class="synergy-desc">${escapeHtml(desc)}</div>
    </div>`;
  }).join("");
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

function addEffectRow(type, value, mode) {
  const row = document.createElement("div");
  row.className = "effect-row";
  const select = document.createElement("select");
  Object.entries(EFFECT_TYPE_GROUPS).forEach(([groupLabel, types]) => {
    const group = document.createElement("optgroup");
    group.label = groupLabel;
    types.forEach((t) => {
      const option = document.createElement("option");
      option.value = t;
      option.textContent = t;
      group.appendChild(option);
    });
    select.appendChild(group);
  });
  select.value = type || KNOWN_EFFECT_TYPES[0];
  select.addEventListener("change", () => { updateEditionPreview(); });

  const modeSelect = document.createElement("select");
  modeSelect.className = "effect-mode-select";
  ["flat", "multiply"].forEach(m => {
    const opt = document.createElement("option");
    opt.value = m;
    opt.textContent = m;
    modeSelect.appendChild(opt);
  });
  modeSelect.value = mode || "flat";
  modeSelect.addEventListener("change", () => { updateEditionPreview(); });

  const input = document.createElement("input");
  input.type = "number";
  input.value = value;
  input.min = EFFECT_VALUE_MIN;
  input.max = EFFECT_VALUE_MAX;
  input.addEventListener("input", () => { updateEditionPreview(); });

  const removeBtn = document.createElement("button");
  removeBtn.type = "button";
  removeBtn.textContent = "X";
  removeBtn.className = "danger";
  removeBtn.addEventListener("click", () => { row.remove(); updateEditionPreview(); });

  row.appendChild(select);
  row.appendChild(modeSelect);
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
    els.fieldSuit.value = "solar";
    els.fieldTags.value = "";
    els.fieldEditions.value = "";
    els.fieldGalaxyExclusive.checked = false;
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
    els.fieldSuit.value = KNOWN_SUITS.includes(part.suit) ? part.suit : "solar";
    els.fieldTags.value = (part.tags || []).join(", ");
    els.fieldEditions.value = (part.editions || []).join(", ");
    els.fieldGalaxyExclusive.checked = part.galaxyExclusive === true;
    els.fieldSlotExclusive.checked = part.slotExclusive === true;
    (part.effects || []).forEach((e) => addEffectRow(e.type, e.value, e.mode));
    els.deleteCardBtn.style.display = "";
  }
  updateRarityPreview();
  updateEditionPreview();
  updateEconomyPreview();
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
    
    const outEffects = candidate.effects.map(e => ({ type: e.type, value: e.value, mode: e.mode }));
    outEffects.forEach(effect => {
      if (def.scope === "all" || def.scope === effect.type) {
        effect.value = effect.value * def.multiplier;
      }
    });
    if (def.drawback) {
      outEffects.push({ type: def.drawback.type, value: def.drawback.value, mode: "flat" });
    }

    const item = document.createElement("div");
    item.className = "edition-preview-item";
    
    let html = `<strong>${escapeHtml(editionId)}</strong>: `;
    const effectStrs = outEffects.map(e => `${escapeHtml(e.type)} ${e.mode === "multiply" ? "×" : e.value >= 0 ? "+" : ""}${e.value}`);
    if (def.synergyBonusAdd) {
      effectStrs.push(`(synergy +${def.synergyBonusAdd})`);
    }
    if (def.noSlotCost) {
      effectStrs.push(`(no slot cost)`);
    }
    if (def.sellMultiplier) {
      effectStrs.push(`(sell x${def.sellMultiplier})`);
    }
    html += effectStrs.join(", ");
    
    item.innerHTML = html;
    els.editionPreviewContainer.appendChild(item);
  });
}

function updateRarityPreview() {
  els.rarityPreview.style.background = RARITY_COLOR[els.fieldRarity.value] || "#000";
}

// Item 9(c)/12/14: renders the sell/buy economics preview so an author can
// see -- live, as they change rarity or editions -- exactly what a card
// will refund on sale and cost to (re)purchase, without cross-referencing
// game/gear.lua by hand. Mirrors updateEditionPreview's "only show once
// there's something meaningful to show" posture.
function updateEconomyPreview() {
  if (!els.economyPreviewContainer) return;
  els.economyPreviewContainer.innerHTML = "";
  const rarity = els.fieldRarity.value;
  const editionsRaw = els.fieldEditions.value.split(",").map((s) => s.trim()).filter(Boolean);
  const validEditions = editionsRaw.filter((e) => KNOWN_EDITIONS.includes(e));

  const h3 = document.createElement("h3");
  h3.textContent = "Economy Preview";
  els.economyPreviewContainer.appendChild(h3);

  const baseline = document.createElement("div");
  baseline.className = "economy-preview-item";
  baseline.innerHTML = `<strong>no edition</strong>: sell $${computeSellValue(rarity, null)} · buy $${computeBuyPrice(rarity, null)}`;
  els.economyPreviewContainer.appendChild(baseline);

  validEditions.forEach((editionId) => {
    const item = document.createElement("div");
    item.className = "economy-preview-item";
    item.innerHTML = `<strong>${escapeHtml(editionId)}</strong>: sell $${computeSellValue(rarity, editionId)} · buy $${computeBuyPrice(rarity, editionId)}`;
    els.economyPreviewContainer.appendChild(item);
  });
}

function collectFormPart() {
  const effects = Array.from(els.effectsList.querySelectorAll(".effect-row")).map((row) => {
    const type = row.querySelector("select").value;
    const mode = row.querySelector(".effect-mode-select").value;
    const rawValue = row.querySelector("input").value;
    const value = Number(rawValue);
    const effect = { type, value };
    if (mode === "multiply") effect.mode = "multiply";
    return effect;
  });
  const tags = els.fieldTags.value.split(",").map((s) => s.trim()).filter(Boolean);
  const editions = els.fieldEditions.value.split(",").map((s) => s.trim()).filter(Boolean);
  return {
    id: els.fieldId.value.trim(),
    name: els.fieldName.value.trim(),
    nameKo: els.fieldNameKo.value.trim() || els.fieldName.value.trim(),
    icon: els.fieldIcon.value.trim(),
    rarity: els.fieldRarity.value,
    suit: els.fieldSuit.value,
    tags,
    editions,
    galaxyExclusive: els.fieldGalaxyExclusive.checked,
    slotExclusive: els.fieldSlotExclusive.checked,
    effects,
  };
}

function wireForm() {
  els.fieldRarity.addEventListener("change", () => { updateRarityPreview(); updateEconomyPreview(); });
  els.fieldEditions.addEventListener("input", () => { updateEditionPreview(); updateEconomyPreview(); });
  els.addEffectBtn.addEventListener("click", () => addEffectRow(KNOWN_EFFECT_TYPES[0], 0));
  els.cancelBtn.addEventListener("click", closeForm);
  els.newCardBtn.addEventListener("click", () => openForm(null));

  els.deleteCardBtn.addEventListener("click", () => {
    if (!editingId || !pool) return;
    pool.parts = pool.parts.filter((p) => p.id !== editingId);
    storePool(activeKind, pool);
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
    storePool(activeKind, pool);
    setStatus(`Saved '${candidate.id}' in memory. Use "Save to disk" or "Download JSON" to persist.`, "ok");
    renderGrid();
    closeForm();
  });
}

function init() {
  cacheEls();
  loadLocale();
  wireOpenInput(els.openHullInput, "hull");
  wireOpenInput(els.openEngineInput, "engine");
  wireOpenFsa();
  wireSaveFsa();
  wireDownload();
  wireForm();
  wirePoolTabs();
  if (els.localeKoBtn) els.localeKoBtn.addEventListener("click", () => setLocale("ko"));
  if (els.localeEnBtn) els.localeEnBtn.addEventListener("click", () => setLocale("en"));
  setLocale(editorLocale);
  // Auto-load hull JSON when served via HTTP. Engine waits for first Engine tab click.
  autoLoadDefaults();
}

function wirePoolTabs() {
  if (els.tabHull) els.tabHull.addEventListener("click", () => selectPool("hull"));
  if (els.tabEngine) els.tabEngine.addEventListener("click", () => selectPool("engine"));
}

function updateTabActive() {
  if (els.tabHull) els.tabHull.classList.toggle("active", activeKind === "hull");
  if (els.tabEngine) els.tabEngine.classList.toggle("active", activeKind === "engine");
}

function selectPool(kind) {
  activeKind = kind === "engine" ? "engine" : "hull";
  updateTabActive();
  closeForm();
  if (activeKind === "engine") {
    ensureEngineLoaded();
    return;
  }
  syncActivePool();
  renderGrid();
}

async function ensureEngineLoaded() {
  if (enginePool) {
    syncActivePool();
    renderGrid();
    return;
  }
  const enginePath = "/gear-editor/data/engine_parts.json";
  try {
    const resp = await fetch(enginePath);
    if (resp.ok) {
      const doc = await resp.json();
      loadDocument(doc, "engine_parts.json");
      setStatus("Auto-loaded engine_parts.json — " + doc.parts.length + " card(s).", "ok");
      return;
    }
  } catch (_) { /* not served via HTTP, ignore */ }
  syncActivePool();
  renderGrid();
  setStatus("Open an engine_parts.json file, or serve the editor over HTTP so Engine can auto-load.");
}

async function autoLoadDefaults() {
  const hullPath = "/gear-editor/data/hull_parts.json";
  try {
    const resp = await fetch(hullPath);
    if (resp.ok) {
      const doc = await resp.json();
      loadDocument(doc, "hull_parts.json");
      setStatus("Auto-loaded hull_parts.json — " + doc.parts.length + " card(s).", "ok");
      return;
    }
  } catch (_) { /* not served via HTTP, ignore */ }
  setStatus("Open a hull_parts.json or engine_parts.json file to begin.");
}

document.addEventListener("DOMContentLoaded", init);
