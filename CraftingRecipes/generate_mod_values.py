import os
import re
import json
from pathlib import Path

MATERIAL_MULTIPLIERS = {
    "Metal": 5.0,
    "Mechanical": 8.0,
    "Electronics": 15.0,
    "Glass": 3.0,
    "Rock": 4.0,
    "Wood": 2.0,
    "Plastic": 1.5,
    "Fence": 2.0,
    "Cardboard": 0.5,
    "Rubber": 3.0,
    "Default": 1.0,
}

DEFAULT_MATERIAL_MULTIPLIER = 2.0
COMPONENT_KIT_UUID = "7f0b0c54-4cb6-4ad6-aaa0-0d0e321b8253"
DEFAULT_KIT_VALUE = 40.0
UPGRADE_COSTS = {1: 1, 2: 2, 3: 4, 4: 8}

def strip_comments(text: str) -> str:
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    text = re.sub(r'//.*', '', text)
    return text

def load_json_file(filepath: Path):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        clean_content = strip_comments(content)
        clean_content = re.sub(r',\s*([\]}])', r'\1', clean_content)
        return json.loads(clean_content)
    except Exception:
        return None

def calculate_volume(item: dict) -> float:
    if "tiling" in item:
        return 1.0
    if "box" in item and isinstance(item["box"], dict):
        box = item["box"]
        return float(box.get("x", 1) * box.get("y", 1) * box.get("z", 1))
    if "cylinder" in item and isinstance(item["cylinder"], dict):
        cyl = item["cylinder"]
        diameter = cyl.get("diameter", 1)
        depth = cyl.get("depth", 1)
        return float(diameter * diameter * depth)
    if "hull" in item and isinstance(item["hull"], dict):
        hull = item["hull"]
        return float(hull.get("x", 1) * hull.get("y", 1) * hull.get("z", 1))
    return 1.0

def calculate_ratings_modifier(item: dict) -> float:
    ratings = item.get("ratings")
    if not ratings or not isinstance(ratings, dict):
        return 1.0
    values = [float(v) for v in ratings.values() if isinstance(v, (int, float))]
    if not values:
        return 1.0
    avg_rating = sum(values) / len(values)
    return 1.0 + (avg_rating / 5.0)

class ModDataGenerator:
    def __init__(self, scan_directory: str):
        self.scan_dir = Path(scan_directory)
        self.execution_dir = Path.cwd()
        self.items = {}
        self.recipes = {}
        self.item_categories = {}
        self.item_names = {}
        self.explicit_upgrades = {}

    def scan_and_parse(self):
        print(f"Scanning directory: {self.scan_dir.resolve()}")
        for root, dirs, files in os.walk(self.scan_dir):
            if "upgrader" in dirs:
                dirs.remove("upgrader")
                
            for file in files:
                filepath = Path(root) / file
                ext = filepath.suffix.lower()
                category_name = filepath.stem.lower()
                
                if ext in [".json", ".shapeset", ".toolset", ".tooldb", ".shapedb"]:
                    data = load_json_file(filepath)
                    if not data:
                        continue
                    
                    if isinstance(data, dict):
                        if "partList" in data:
                            self.parse_items_list(data["partList"], category_name)
                        if "blockList" in data:
                            self.parse_items_list(data["blockList"], category_name)
                        if "toolList" in data:
                            self.parse_items_list(data["toolList"], category_name)
                    
                    if isinstance(data, list) and len(data) > 0 and "itemId" in data[0]:
                        self.parse_recipes_list(data, category_name)

    def parse_items_list(self, items_list: list, category: str):
        for item in items_list:
            uuid = item.get("uuid")
            if not uuid:
                continue
            mat = item.get("physicsMaterial", "Default")
            volume = calculate_volume(item)
            mat_mult = MATERIAL_MULTIPLIERS.get(mat, DEFAULT_MATERIAL_MULTIPLIER)
            rating_mod = calculate_ratings_modifier(item)
            base_value = volume * mat_mult * rating_mod
            
            self.items[uuid] = round(base_value, 2)
            self.item_categories[uuid] = category
            
            name = item.get("name", "")
            self.item_names[uuid] = name
            
            spring = item.get("survivalSpring")
            if spring and isinstance(spring, dict):
                up_uuid = spring.get("upgradeUuid")
                up_cost = spring.get("upgradeCost")
                if up_uuid and up_cost:
                    self.explicit_upgrades[uuid] = (up_uuid, up_cost)

    def parse_recipes_list(self, recipes_list: list, category: str):
        for recipe in recipes_list:
            output_id = recipe.get("itemId")
            if not output_id:
                continue
            qty = recipe.get("quantity", 1)
            ingredients = []
            for ing in recipe.get("ingredientList", []):
                ing_id = ing.get("itemId")
                ing_qty = ing.get("quantity", 1)
                if ing_id:
                    ingredients.append((ing_id, ing_qty))
            
            self.recipes[output_id] = {
                "quantity": qty,
                "ingredients": ingredients
            }
            if output_id not in self.item_categories:
                self.item_categories[output_id] = category

    def build_implicit_upgrades(self):
        groups = {}
        for uuid, name in self.item_names.items():
            match = re.match(r"^(.*)_(\d+)$", name)
            if match:
                base_name, level_str = match.groups()
                level = int(level_str)
                if base_name not in groups:
                    groups[base_name] = []
                groups[base_name].append((level, uuid))
                
        for base_name, members in groups.items():
            members.sort(key=lambda x: x[0])
            for i in range(len(members) - 1):
                parent_lvl, parent_uuid = members[i]
                child_lvl, child_uuid = members[i+1]
                if parent_uuid not in self.explicit_upgrades:
                    cost = UPGRADE_COSTS.get(parent_lvl, 1)
                    self.explicit_upgrades[parent_uuid] = (child_uuid, cost)

    def resolve_recipe_values(self):
        print("Calculating values from crafting recipes...")
        resolved_values = {}
        for uuid, val in self.items.items():
            resolved_values[uuid] = val
            
        for _ in range(10):
            changes_made = False
            for output_uuid, recipe in self.recipes.items():
                total_cost = 0.0
                for ing_uuid, ing_qty in recipe["ingredients"]:
                    if ing_uuid in resolved_values:
                        total_cost += resolved_values[ing_uuid] * ing_qty
                    else:
                        total_cost += 1.0 * ing_qty
                calculated_value = total_cost / recipe["quantity"]
                calculated_value = round(calculated_value, 2)
                
                current_val = resolved_values.get(output_uuid, 0)
                if abs(current_val - calculated_value) > 0.05:
                    resolved_values[output_uuid] = calculated_value
                    changes_made = True
            if not changes_made:
                break
                
        self.build_implicit_upgrades()
        
        kit_value = resolved_values.get(COMPONENT_KIT_UUID, DEFAULT_KIT_VALUE)
        
        for _ in range(10):
            for parent_uuid, (child_uuid, cost) in self.explicit_upgrades.items():
                parent_val = resolved_values.get(parent_uuid)
                if parent_val is not None:
                    calculated_child_val = parent_val + (cost * kit_value)
                    current_child_val = resolved_values.get(child_uuid, 0)
                    if calculated_child_val > current_child_val:
                        resolved_values[child_uuid] = round(calculated_child_val, 2)
                        
        return resolved_values

    def save_output(self, resolved_values: dict):
        output_dir = self.execution_dir / "CraftingRecipes/upgrader/"
        output_dir.mkdir(parents=True, exist_ok=True)
        
        categories_data = {}
        for uuid, val in resolved_values.items():
            cat = self.item_categories.get(uuid, "other")
            if cat not in categories_data:
                categories_data[cat] = []
            categories_data[cat].append({
                "itemId": uuid,
                "value": val
            })
            
        upgrader_index = {}
        for cat, items in categories_data.items():
            cat_filename = f"{cat}.json"
            cat_filepath = output_dir / cat_filename
            with open(cat_filepath, 'w', encoding='utf-8') as f:
                json.dump(items, f, indent=4)
            upgrader_index[cat] = f"$CONTENT_DATA/CraftingRecipes/upgrader/{cat_filename}"
            
        index_filepath = output_dir / "upgrader.json"
        with open(index_filepath, 'w', encoding='utf-8') as f:
            json.dump(upgrader_index, f, indent=4)
            
        print(f"\nData saved to folder: {output_dir.resolve()}")
        print(f"Created category files: {len(categories_data)}")
        print(f"Created index file: {index_filepath.name}")

if __name__ == "__main__":
    target_directory = input("Enter folder path to scan: ").strip()
    if not target_directory:
        target_directory = "."
        
    generator = ModDataGenerator(target_directory)
    generator.scan_and_parse()
    values = generator.resolve_recipe_values()
    generator.save_output(values)