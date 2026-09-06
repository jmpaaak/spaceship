// slot-editor: static, dependency-free editor for game/data/slot_config.json

const KNOWN_PROFILES = ["solar", "fringe", "void"];

let currentConfig = {
  schemaVersion: 2,
  spinCost: 10,
  symbols: [
    {id: "MONEY", name: "Money", weight: 6},
    {id: "PART", name: "Part", weight: 3},
    {id: "SPEED", name: "Speed", weight: 4},
    {id: "DURABILITY", name: "Durability", weight: 3},
    {id: "HARVEST", name: "Harvest", weight: 4}
  ],
  payouts: {miss: 0, pair: 3, triple: 10},
  profiles: {
    "solar": {weights: {MONEY: 6, PART: 3, SPEED: 4, DURABILITY: 3, HARVEST: 4}, multipliers: {tripleMultiplier: 1.0}},
    "fringe": {weights: {MONEY: 5, PART: 3, SPEED: 4, DURABILITY: 3, HARVEST: 5}, multipliers: {tripleMultiplier: 1.5}},
    "void": {weights: {MONEY: 4, PART: 4, SPEED: 4, DURABILITY: 4, HARVEST: 4}, multipliers: {tripleMultiplier: 2.0}}
  }
};

let activeFileHandle = null;

const dom = {
  spinCost: document.getElementById("fieldSpinCost"),
  payoutMiss: document.getElementById("fieldPayoutMiss"),
  payoutPair: document.getElementById("fieldPayoutPair"),
  payoutTriple: document.getElementById("fieldPayoutTriple"),
  payoutJackpot: document.getElementById("fieldPayoutJackpot"),
  symbolsList: document.getElementById("symbolsList"),
  addSymbolBtn: document.getElementById("addSymbolBtn"),
  form: document.getElementById("configForm"),
  error: document.getElementById("formError"),
  status: document.getElementById("statusBar"),
  downloadBtn: document.getElementById("downloadBtn"),
  saveFsaBtn: document.getElementById("saveFsaBtn"),
  openFsaBtn: document.getElementById("openFsaBtn"),
  openConfigInput: document.getElementById("openConfigInput"),
  
  solarJackpot: document.getElementById("fieldSolarJackpot"),
  fringeJackpot: document.getElementById("fieldFringeJackpot"),
  voidJackpot: document.getElementById("fieldVoidJackpot"),
};

function renderForm() {
  dom.spinCost.value = currentConfig.spinCost;
  dom.payoutMiss.value = currentConfig.payouts.miss;
  dom.payoutPair.value = currentConfig.payouts.pair;
  dom.payoutTriple.value = currentConfig.payouts.triple;
  dom.payoutJackpot.value = currentConfig.payouts.jackpot;
  
  dom.solarJackpot.value = currentConfig.profiles.solar.multipliers.tripleMultiplier;
  dom.fringeJackpot.value = currentConfig.profiles.fringe.multipliers.tripleMultiplier;
  dom.voidJackpot.value = currentConfig.profiles.void.multipliers.tripleMultiplier;

  dom.symbolsList.innerHTML = "";
  currentConfig.symbols.forEach((sym, i) => {
    const div = document.createElement("div");
    div.style.display = "flex";
    div.style.gap = "8px";
    div.style.marginBottom = "8px";
    
    div.innerHTML = `
      <input type="text" placeholder="ID (e.g. STAR)" value="${sym.id}" data-idx="${i}" class="sym-id" required>
      <input type="text" placeholder="Name" value="${sym.name}" data-idx="${i}" class="sym-name" required>
      <input type="number" placeholder="Weight" value="${sym.weight}" data-idx="${i}" class="sym-wt" required min="1">
      <button type="button" class="del-sym" data-idx="${i}">X</button>
    `;
    dom.symbolsList.appendChild(div);
  });
  
  document.querySelectorAll(".del-sym").forEach(btn => {
    btn.addEventListener("click", e => {
      const idx = parseInt(e.target.dataset.idx);
      currentConfig.symbols.splice(idx, 1);
      renderForm();
    });
  });
}

dom.addSymbolBtn.addEventListener("click", () => {
  currentConfig.symbols.push({id: "NEW", name: "New Symbol", weight: 1});
  renderForm();
});

dom.form.addEventListener("submit", e => {
  e.preventDefault();
  try {
    currentConfig.spinCost = parseInt(dom.spinCost.value);
    currentConfig.payouts.miss = parseInt(dom.payoutMiss.value);
    currentConfig.payouts.pair = parseInt(dom.payoutPair.value);
    currentConfig.payouts.triple = parseInt(dom.payoutTriple.value);
    currentConfig.payouts.jackpot = parseInt(dom.payoutJackpot.value);
    
    currentConfig.profiles.solar.multipliers.tripleMultiplier = parseFloat(dom.solarJackpot.value);
    currentConfig.profiles.fringe.multipliers.tripleMultiplier = parseFloat(dom.fringeJackpot.value);
    currentConfig.profiles.void.multipliers.tripleMultiplier = parseFloat(dom.voidJackpot.value);
    
    const syms = [];
    document.querySelectorAll("#symbolsList > div").forEach(div => {
      const id = div.querySelector(".sym-id").value;
      const name = div.querySelector(".sym-name").value;
      const weight = parseInt(div.querySelector(".sym-wt").value);
      syms.push({id, name, weight});
    });
    currentConfig.symbols = syms;
    
    dom.error.textContent = "";
    dom.status.textContent = "Changes applied to memory.";
    dom.downloadBtn.disabled = false;
    if (activeFileHandle) dom.saveFsaBtn.disabled = false;
    
  } catch(err) {
    dom.error.textContent = "Error: " + err.message;
  }
});

function loadJson(text) {
  try {
    const doc = JSON.parse(text);
    if(doc.spinCost !== undefined) currentConfig = doc;
    renderForm();
    dom.status.textContent = "Loaded config.";
  } catch(e) {
    alert("Invalid JSON");
  }
}

dom.openConfigInput.addEventListener("change", e => {
  const file = e.target.files[0];
  if(!file) return;
  const reader = new FileReader();
  reader.onload = ev => loadJson(ev.target.result);
  reader.readAsText(file);
});

dom.downloadBtn.addEventListener("click", () => {
  const data = JSON.stringify(currentConfig, null, 2);
  const blob = new Blob([data], {type: "application/json"});
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "slot_config.json";
  a.click();
  URL.revokeObjectURL(url);
});

if (window.showOpenFilePicker) {
  dom.openFsaBtn.addEventListener("click", async () => {
    try {
      const [handle] = await window.showOpenFilePicker({
        types: [{description: 'JSON', accept: {'application/json': ['.json']}}]
      });
      activeFileHandle = handle;
      const file = await handle.getFile();
      loadJson(await file.text());
      dom.saveFsaBtn.disabled = false;
      dom.status.textContent = "Direct access enabled.";
    } catch(e) {}
  });

  dom.saveFsaBtn.addEventListener("click", async () => {
    if(!activeFileHandle) return;
    try {
      const writable = await activeFileHandle.createWritable();
      await writable.write(JSON.stringify(currentConfig, null, 2));
      await writable.close();
      dom.status.textContent = "Saved directly to file.";
    } catch(e) {
      alert("Save failed");
    }
  });
} else {
  dom.openFsaBtn.style.display = "none";
}

renderForm();
