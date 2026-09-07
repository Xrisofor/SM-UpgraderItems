# Upgrader Items / EN

![Mod Preview](https://github.com/Xrisofor/SM-UpgraderItems/blob/main/preview.jpg?raw=true)

**Upgrade Items** swaps one item for another - if you're lucky. The mod considers the odds itself, based on the real value of things.

# How it works

There are two slots in the bot: in one you put the object that you give away, in the other - the object that you want to receive in return. The mod will compare their value and calculate the chance. Press the button and an arrow will run along the wheel: if it stops in the orange zone, the given item will turn into the desired one. If not, the item will be lost.
 
The value is not specified manually. Each item is evaluated according to its real crafting recipes (Craftbot, Portable Craftbot, Mechanic Station, Refinery, Farmer Hideout, and others) - the mod expands the recipe chain to raw materials and adds up the cost of ingredients. For raw materials and over-the-counter items (ore, scrap metal, kitty component, and others), the value is calculated based on their physical characteristics - volume, material, and game ratings of strength, buoyancy, friction, and density.
 
The chance of success = 0.9 × (the value of your item is the value of the goal), but not less than 0.1% and not more than 90%.

# Modification Features

- **Pricing based on real recipes** - If an item has a crafting recipe, its price is calculated recursively from the ingredients, down to the raw materials.
- **Fair calculation for raw materials** - Over-the-counter items are evaluated by volume, material, and ratings.
- **Flexible bet** - x2/x4/x8 multipliers raise the price of the target and, accordingly, lower the chance.
- **Server authorization of the result** - the calculation of the chance and the outcome of the spin are checked on the server; the client only animates the wheel and the bot.