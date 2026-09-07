import json
import random

def process_file(filepath):
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    random.seed(42 + len(filepath))
    
    valid_types = set()
    for part in data.get("parts", []):
        for eff in part.get("effects", []):
            valid_types.add(eff["type"])
    valid_types = list(valid_types)
    
    rare_types = {"collisionRadius", "chainTrigger", "rerollBonus", "detectionRadius", "autoCollect", "streakMultiplier", "luck", "boostCharge"}
    
    for part in data.get("parts", []):
        if part["id"] == "engine_emergency_boost_pod":
            part["rarity"] = "uncommon"
            part["effects"] = [{"type": "boostCharge", "value": 2}, {"type": "speed", "value": 5}]
            continue
            
        rarity = part.get("rarity", "common")
        effects = part.get("effects", [])
        
        if not effects:
            continue
            
        if rarity == "common":
            chosen_eff = effects[0]
            for eff in effects:
                if eff["type"] in rare_types:
                    chosen_eff = eff
                    break
            
            val = chosen_eff.get("value", 1)
            if isinstance(val, (int, float)) and val < 5:
                val = random.randint(5, 12)
            elif not isinstance(val, (int, float)):
                val = 8
            
            part["effects"] = [{
                "type": chosen_eff["type"],
                "value": int(val)
            }]
            
        elif rarity == "uncommon":
            val1 = effects[0].get("value", 1)
            if isinstance(val1, (int, float)) and val1 < 5:
                val1 = random.randint(5, 10)
            elif not isinstance(val1, (int, float)):
                val1 = 8
            effects[0]["value"] = int(val1)
            
            if len(effects) > 1:
                val2 = effects[1].get("value", 3)
                if isinstance(val2, (int, float)) and val2 < 3:
                    val2 = random.randint(3, 8)
                effects[1]["value"] = int(val2)
                part["effects"] = [effects[0], effects[1]]
            else:
                available = [t for t in valid_types if t != effects[0]["type"]]
                sec_type = random.choice(available) if available else effects[0]["type"]
                part["effects"] = [effects[0], {"type": sec_type, "value": random.randint(3, 8)}]
                
        elif rarity == "rare":
            for eff in effects:
                eff["mode"] = "multiply"
                eff["value"] = round(random.uniform(1.2, 1.8), 1)
            
        elif rarity == "legendary":
            effects[0]["value"] = random.randint(10, 20)
            if "mode" in effects[0]:
                del effects[0]["mode"]
                
            if len(effects) > 1:
                effects[1]["mode"] = "multiply"
                effects[1]["value"] = round(random.uniform(1.5, 3.0), 1)
                part["effects"] = [effects[0], effects[1]]
            else:
                available = [t for t in valid_types if t != effects[0]["type"]]
                sec_type = random.choice(available) if available else effects[0]["type"]
                part["effects"] = [effects[0], {"type": sec_type, "mode": "multiply", "value": round(random.uniform(1.5, 3.0), 1)}]

    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

process_file("game/data/hull_parts.json")
process_file("game/data/engine_parts.json")
