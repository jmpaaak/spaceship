import json

def inspect(file):
    with open(file) as f:
        data = json.load(f)
    print(file)
    for part in data.get('parts', []):
        r = part.get('rarity', 'common')
        eff = part.get('effects', [])
        print(f"  {part['id']}: {r}, {len(eff)} effects")
        
inspect("game/data/hull_parts.json")
inspect("game/data/engine_parts.json")
