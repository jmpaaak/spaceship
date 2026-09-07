import json
import random

def process_file(filepath):
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    random.seed(42 + len(filepath))
    
    # Gather valid effect types for this specific file to avoid cross-pollination
    valid_types = set()
    for part in data.get("parts", []):
        for eff in part.get("effects", []):
            valid_types.add(eff["type"])
    valid_types = list(valid_types)
    
    for part in data.get("parts", []):
        rarity = part.get("rarity", "common")
        effects = part.get("effects", [])
        
        if not effects:
            effects = [{"type": random.choice(valid_types), "value": 1}]
            
        primary_type = effects[0]["type"]
        
        if rarity == "common":
            # 1 flat effect, value 5-12
            val = effects[0].get("value", 1)
            if isinstance(val, (int, float)) and val < 5:
                val = random.randint(5, 12)
            elif not isinstance(val, (int, float)):
                val = 8
            
            part["effects"] = [{
                "type": primary_type,
                "value": int(val)
            }]
            
        elif rarity == "uncommon":
            # 2 flat effects
            val1 = effects[0].get("value", 1)
            if isinstance(val1, (int, float)) and val1 < 5:
                val1 = random.randint(5, 10)
            elif not isinstance(val1, (int, float)):
                val1 = 8
                
            effect1 = {"type": primary_type, "value": int(val1)}
            
            if len(effects) > 1:
                sec_type = effects[1]["type"]
                sec_val = effects[1].get("value", 5)
            else:
                available = [t for t in valid_types if t != primary_type]
                sec_type = random.choice(available) if available else primary_type
                sec_val = random.randint(3, 8)
                
            if isinstance(sec_val, (int, float)) and sec_val < 3:
                sec_val = random.randint(3, 8)
                
            effect2 = {"type": sec_type, "value": int(sec_val)}
            
            part["effects"] = [effect1, effect2]
            
        elif rarity == "rare":
            # 1 multiply effect (e.g. 1.2 to 2.0)
            mult_val = round(random.uniform(1.2, 1.8), 1)
            part["effects"] = [{
                "type": primary_type,
                "mode": "multiply",
                "value": mult_val
            }]
            
        elif rarity == "legendary":
            # 1 flat + 1 multiply
            flat_val = random.randint(10, 20)
            
            if len(effects) > 1:
                sec_type = effects[1]["type"]
            else:
                available = [t for t in valid_types if t != primary_type]
                sec_type = random.choice(available) if available else primary_type
                
            mult_val = round(random.uniform(1.5, 3.0), 1)
            
            part["effects"] = [
                {"type": primary_type, "value": flat_val},
                {"type": sec_type, "mode": "multiply", "value": mult_val}
            ]

    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

process_file("game/data/hull_parts.json")
process_file("game/data/engine_parts.json")
