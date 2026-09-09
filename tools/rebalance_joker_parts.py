#!/usr/bin/env python3
"""INBOX 61(44): reassign part effects to Balatro-joker identities.

Does not add new effect types. Preserves id/name/nameKo/icon/rarity/suit/
tags/editions/galaxyExclusive/slotExclusive. Engine cards drop hull-only
types. Discrete gates (insurance/autoCollect/boostCharge/chainTrigger) stay
flat so floor(totalEffect) consumers actually fire.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HULL_PATH = ROOT / "game/data/hull_parts.json"
ENGINE_PATH = ROOT / "game/data/engine_parts.json"

HULL_ONLY = {
    "hullDurability",
    "insurance",
    "shopDiscount",
    "sellMultiplier",
    "sampleSellValue",
    "money",
    "hullRegen",
}


def fx(type_, value, mode=None):
    out = {"type": type_, "value": value}
    if mode == "multiply":
        out["mode"] = "multiply"
    return out


# id -> effects. Unlisted cards keep existing effects (minus illegal types).
HULL = {
    # Commons — one identity (Abstract / Greedy / Banner / ...).
    "hull_scrap_plate": [fx("hullDurability", 8)],
    "hull_ion_fin": [fx("speed", 8)],
    "hull_cargo_pod": [fx("sampleSellValue", 10)],
    "hull_solar_collector": [fx("sampleSellValue", 9)],
    "hull_nebula_vent": [fx("luck", 8)],
    "hull_gyro_stabilizer": [fx("collisionRadius", 10)],
    "hull_micro_thruster_array": [fx("rerollBonus", 8)],
    "hull_ablative_coat": [fx("hullDurability", 7)],
    "hull_ballast_weight": [fx("hullDurability", 10)],
    "hull_navigation_beacon": [fx("money", 8)],
    "hull_void_capacitor": [fx("streakMultiplier", 8)],
    "hull_scanner_array": [fx("sampleSellValue", 8)],
    "hull_nano_mesh": [fx("hullRegen", 5)],
    # Uncommons — two flats (Business Card, Delayed Gratification, ...).
    "hull_reserve_tank": [fx("money", 10), fx("sampleSellValue", 6)],
    "hull_climb_booster": [fx("speed", 6), fx("luck", 5)],
    "hull_void_lens": [fx("sampleSellValue", 10), fx("rerollBonus", 8)],
    "hull_solar_sail": [fx("sellMultiplier", 8), fx("money", 5)],
    "hull_nebula_core": [fx("speed", 5), fx("luck", 8)],
    "hull_star_compass": [fx("speed", 5), fx("hullRegen", 5)],
    "hull_nebula_plating": [fx("hullDurability", 6), fx("shopDiscount", 8)],
    "hull_emergency_beacon": [fx("insurance", 5), fx("collisionRadius", 5)],
    "hull_trade_license": [fx("shopDiscount", 20), fx("luck", 7)],
    "hull_market_broker": [fx("sellMultiplier", 20), fx("rerollBonus", 7)],
    "hull_negotiator_chip": [fx("rerollBonus", 5), fx("streakMultiplier", 7)],
    "hull_slipstream_hull": [fx("collisionRadius", 15), fx("rerollBonus", 5)],
    "hull_repair_drone": [fx("hullRegen", 10), fx("shopDiscount", 8)],
    "hull_slot_lucky_plating": [fx("hullDurability", 9), fx("luck", 5)],
    # Rares — × (Baron / Photograph / The Idol).
    "hull_reactive_hull": [
        fx("hullDurability", 1.8, "multiply"),
        fx("sampleSellValue", 1.5, "multiply"),
    ],
    "hull_titan_frame": [
        fx("speed", 1.5, "multiply"),
        fx("hullDurability", 1.3, "multiply"),
    ],
    "hull_prism_hull": [
        fx("hullDurability", 1.3, "multiply"),
        fx("sampleSellValue", 1.4, "multiply"),
    ],
    "hull_void_shard": [
        fx("hullDurability", 1.7, "multiply"),
        fx("sampleSellValue", 1.2, "multiply"),
    ],
    "hull_solar_prism": [
        fx("speed", 1.8, "multiply"),
        fx("sampleSellValue", 1.7, "multiply"),
    ],
    "hull_combo_matrix": [fx("streakMultiplier", 1.7, "multiply")],
    "hull_lucky_charm": [fx("luck", 1.7, "multiply")],
    "hull_echo_relay": [fx("sellMultiplier", 1.5, "multiply")],
    "hull_collector_drone": [
        fx("sampleSellValue", 1.6, "multiply"),
        fx("money", 1.5, "multiply"),
    ],
    "hull_slot_jackpot_shield": [
        fx("hullDurability", 1.5, "multiply"),
        fx("sampleSellValue", 1.6, "multiply"),
    ],
    "hull_auto_welder": [fx("hullRegen", 1.5, "multiply")],
    # Legendary — + AND × (Blueprint-class payoff).
    "hull_quantum_alloy": [
        fx("speed", 18),
        fx("hullDurability", 1.5, "multiply"),
    ],
    "hull_nebula_forge": [
        fx("speed", 16),
        fx("hullDurability", 2.9, "multiply"),
    ],
    "hull_starforge_relic": [
        fx("sampleSellValue", 14),
        fx("luck", 2.8, "multiply"),
    ],
}

ENGINE = {
    # Commons.
    "engine_basic_thruster": [fx("speed", 8)],
    "engine_vector_nozzle": [fx("speed", 12)],
    "engine_gyro_stabilizer": [fx("luck", 8)],
    "engine_solar_sail_flap": [fx("detectionRadius", 15)],
    "engine_slim_nacelle": [fx("collisionRadius", 12)],
    # Uncommons.
    "engine_afterburner": [fx("speed", 6), fx("boostCharge", 3)],
    "engine_ion_drive": [fx("speed", 7), fx("detectionRadius", 10)],
    "engine_solar_coolant_jet": [fx("speed", 5), fx("collisionRadius", 8)],
    "engine_nebula_burst_valve": [fx("boostCharge", 4), fx("speed", 8)],
    "engine_burst_capacitor": [fx("speed", 6), fx("boostCharge", 7)],
    "engine_emergency_boost_pod": [fx("boostCharge", 2), fx("speed", 5)],
    "engine_cryo_fuel_cell": [fx("speed", 6), fx("luck", 6)],
    "engine_haggler_valve": [fx("speed", 5), fx("rerollBonus", 5)],
    "engine_deep_scan_pod": [fx("detectionRadius", 20), fx("luck", 8)],
    "engine_freelancer_manifold": [fx("speed", 9), fx("detectionRadius", 25)],
    "engine_market_thruster": [fx("autoCollect", 5), fx("speed", 6)],
    "engine_safety_bypass": [fx("luck", 8), fx("collisionRadius", 6)],
    "engine_trade_vent": [fx("rerollBonus", 8), fx("speed", 6)],
    "engine_profit_turbine": [fx("streakMultiplier", 12), fx("speed", 6)],
    "engine_slot_turbo_spin": [fx("speed", 6), fx("boostCharge", 3)],
    # Rares — × on scalable stats; discrete gates stay flat.
    "engine_fusion_core": [
        fx("speed", 1.3, "multiply"),
        fx("boostCharge", 2),
        fx("detectionRadius", 1.6, "multiply"),
    ],
    "engine_void_phase_thruster": [fx("speed", 1.5, "multiply")],
    "engine_probability_core": [
        fx("luck", 1.8, "multiply"),
        fx("speed", 1.2, "multiply"),
    ],
    "engine_echo_thruster": [fx("chainTrigger", 2), fx("speed", 1.4, "multiply")],
    "engine_magnet_intake": [
        fx("autoCollect", 1),
        fx("speed", 1.3, "multiply"),
    ],
    "engine_escape_pod_thruster": [
        fx("boostCharge", 2),
        fx("speed", 1.8, "multiply"),
    ],
    "engine_momentum_stabilizer": [
        fx("streakMultiplier", 1.4, "multiply"),
        fx("speed", 1.3, "multiply"),
    ],
    "engine_slot_fortune_drive": [
        fx("luck", 1.3, "multiply"),
        fx("speed", 1.2, "multiply"),
    ],
    # Legendary.
    "engine_singularity_drive": [
        fx("speed", 18),
        fx("speed", 2.7, "multiply"),
    ],
    "engine_void_forge_drive": [
        fx("speed", 19),
        fx("rerollBonus", 1.9, "multiply"),
    ],
    "engine_stellar_matrix_core": [
        fx("speed", 19),
        fx("boostCharge", 3),
        fx("speed", 2.1, "multiply"),
    ],
}


def apply(path: Path, mapping: dict, strip_hull_only: bool) -> None:
    data = json.loads(path.read_text())
    missing = []
    for part in data["parts"]:
        pid = part["id"]
        if pid in mapping:
            part["effects"] = mapping[pid]
        elif strip_hull_only:
            kept = [e for e in part["effects"] if e["type"] not in HULL_ONLY]
            if not kept:
                missing.append(pid)
            part["effects"] = kept
        if pid not in mapping:
            missing.append("unmapped:" + pid)
    leftover = [p["id"] for p in data["parts"] if p["id"] not in mapping]
    if leftover:
        raise SystemExit(f"{path.name} unmapped: {leftover}")
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {path.name} n={len(data['parts'])}")


def main() -> None:
    apply(HULL_PATH, HULL, False)
    apply(ENGINE_PATH, ENGINE, True)


if __name__ == "__main__":
    main()
