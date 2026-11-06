<div align="center">
    <img src="./LMProdPhoto.png" width="350" height="350" />
</div>

# Lean Machine

Lean Machine is a Garry's Mod addon meant for the DarkRP gamemode. It implements a simple lean making, drinking, and selling mechanic. Players are able to brew cups of lean by mixing various components in a barrel.

## Features

- Lean Barrel: players use a Lean Barrel to mix together candy, sprite, ice, and codeine into a cup
- Lean Cup: a cup of lean can either by drank by interacting with it, which results in intoxication, or players can store it while crouching and interacting
- Lean Buyer: a standalone entity that players can interact with to sell stored cups of lean
- Haggling: with the Lean Buyer, you are able to haggle for a better sale value. However, if he rejects your haggle, you may be punished
- Configuration: the core configuration of Lean Machine is easily changable through the Q menu

## How to Install

### Steam (Recommended)
Simply subscribe to <a href="">Lean Machine on the Steam Workshop</a> and add it to your
server's collection.

### Manual
1. Clone this repo into your `garrysmod/addons` folder
2. Edit any config in `/lua/leanmachine/sh_config.lua`
3. Restart your server


## How to Use

### Server Admins
To setup Lean Machine for your Garry's Mod server, you just need to add a Lean Barrel entity
to the F4 spawn menu and Lean Buyer entities around your map. Configuration can be done in-game via the Utilities tab.

Lean Barrels can be added manually to the F4 menu or you can edit `sh.config.lua`

```lua
C.DarkRP = {
    Register = true,     
    ...
}
```

Lean Buyers can be spawned via the Entities tab.

### Players
1. Buy a Lean Barrel
2. Interact with the barrel to open the menu
3. Mix in all the necessary ingredients
4. Pour out a cup to either drink or sell