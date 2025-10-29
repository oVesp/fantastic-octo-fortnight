# Agents.md - Monster Combat Game Development Guide

## Overview
This document provides guidance for Roblox developers working on this monster collection and combat game. The project features a turn-based combat system with monster evolution, status effects, and a variety of moves inspired by creature collection games.

## Project Structure

### Client Scripts (`Client/`)
Client-side LocalScripts that handle UI, animations, and visual effects:
- **CombatUI.local.luau** - Combat interface and player interactions
- **EvolutionClient.local.luau** - Handles evolution animations and UI
- **EvolutionVFX.local.luau** - Visual effects for monster evolution
- **MatchmakingUI.local.luau** - Queue and matchmaking interface
- **AnimationHandler.local.luau** - Client-side animation management
- **Interface.local.luau** - General UI controller
- **MusicController.local.luau** - Background music and sound management

### Server Scripts (`Server/`)
Server-side Scripts that manage game logic, data, and combat:
- **CombatManager/** - Core combat system and turn resolution
  - `init.luau` - Main combat loop and state machine
  - `Bridge.luau` - Communication layer between combat components
  - `CombatMath.luau` - Damage calculation, accuracy, and combat formulas
  - `StatusEffects.luau` - Status effect application and tick processing
  - `EnhancedMovement.luau` - Advanced move execution logic
- **MonsterGenerator.luau** - Monster creation and stat generation
- **EvolutionManager.luau** - Handles monster evolution logic and requirements
- **QueueManager.luau** / **QueueService.luau** - Matchmaking and battle queues
- **MonsterSpawner.luau** - NPC and wild monster spawning
- **Data/** - Player data management and persistence

### Shared Modules (`Shared/`)
Replicated modules accessible by both client and server:
- **Moves.luau** - Move definitions, power calculations, and base stats
- **MovesModules/** - Individual move implementations
  - `BasicAttack.luau`, `RockFist.luau`, `VoidRay.luau`, etc.
- **StatusEffectDefs.luau** - Status effect definitions (buffs, debuffs, DoTs, CC)
- **Races.luau** - Monster races, stages, and evolution trees
- **Personalities.luau** - Monster personality traits and stat modifiers
- **EvolutionDefs.luau** - Evolution requirements and bonus stats
- **MoveUnlocks.luau** - Move unlock conditions and level requirements
- **AnimationManager.luau** - Animation data and mappings
- **MoveVFX.luau** / **MoveVFXModules/** - Visual effects for moves

## Key Systems

### 1. Combat System
The combat system uses a turn-based state machine with the following states:
- **deciding** - AI/Player chooses next action
- **positioning** - Monster moves to attack position
- **executing** - Move is performed and damage is calculated
- **repositioning** - Monster returns to rest position
- **resting** - Brief pause before next turn

**Combat Flow:**
```lua
-- Combat loop runs continuously for active battles
-- Each monster has a speed stat that determines turn order
-- Moves are executed via EnhancedMovement module
-- Damage is calculated in CombatMath based on stats, types, and modifiers
```

**Key Features:**
- Accuracy and critical hit calculations
- Type effectiveness (elemental advantages)
- Status effects that persist across turns
- Shield/barrier mechanics that absorb damage
- DoT (Damage over Time) effects with tick intervals

### 2. Monster System
Monsters have multiple attributes and progression mechanics:

**Monster Stages:**
- **Proto** (Level 1-5) - Basic form
- **Fledgeling** (Level 6-15) - First evolution
- **Rookie** (Level 16-25) - Intermediate form
- **Champion** (Level 26-35) - Advanced form
- **Elder** (Level 36-45) - Penultimate form
- **Unique** (Level 46-50) - Final evolution

**Core Stats:**
- **HP** - Hit Points (health)
- **MP** - Mana Points (for using moves)
- **STR** - Strength (physical damage)
- **INT** - Intelligence (magical damage)
- **DEF** - Defense (physical resistance)
- **RES** - Resistance (magical resistance)
- **SPD** - Speed (turn order)

**Derived Stats:**
- **Accuracy** - Chance to hit with moves
- **Evasion** - Chance to dodge attacks
- **CritRate** - Critical hit chance
- **CritDamage** - Critical hit multiplier

### 3. Move System
Moves are the actions monsters can perform in combat.

**Move Properties:**
- **id** - Unique identifier
- **name** - Display name
- **description** - What the move does
- **power** - Base damage (0 for utility moves)
- **mpCost** - MP required to use
- **accuracy** - Hit chance (0.0 to 1.0)
- **critRate** - Critical hit chance
- **cooldown** - Turns before move can be used again
- **tags** - Array of tags (e.g., "Melee", "Magic", "AoE", "Defensive")
- **element** - Elemental type for type effectiveness
- **rarity** - Amateur, Advanced, Specialist, Ascended, Primordial
- **effects** - Status effects applied on hit

**Move Tags:**
- **Melee** - Close-range physical attack
- **Ranged** - Long-range physical attack
- **Magic** - Magical/special attack
- **AoE** - Area of Effect (hits multiple targets)
- **Mobility** - Movement-based attack
- **Defensive** - Protective or counter move
- **Support** - Buffs/heals allies
- **Debuff** - Weakens enemies
- **DoT** - Damage over Time effect

**Creating New Moves:**
1. Create a module in `Shared/MovesModules/`
2. Define the move data following the template:
```lua
return {
    id = "MyMove",
    name = "My Move Name",
    description = "What this move does",
    power = 50,
    mpCost = 15,
    accuracy = 0.90,
    cooldown = 0,
    tags = {"Melee", "Debuff"},
    element = "Physical",
    rarity = "Advanced",
    effects = {
        {statusId = "Weaken", chance = 0.3, duration = 3}
    }
}
```
3. Register the move in `Shared/Moves.luau` move list

### 4. Status Effects System
Status effects modify monster stats, apply DoT, or control actions. See `Shared/StatusEffects.md` for comprehensive documentation.

**Status Effect Categories:**
- **Buffs** - Beneficial effects (Haste, Guard Up, Berserk)
- **Debuffs** - Harmful stat reductions (Weaken, Slow, Blind)
- **DoTs** - Damage over Time (Poison, Burn, Bleed)
- **CC** - Crowd Control (Stun, Freeze, Sleep, Silence)
- **Unique** - Special effects (Taunt, Fear, Curse)

**Status Effect Structure:**
```lua
{
    statusId = "StatusName",
    duration = 5,  -- seconds
    chance = 1.0,  -- 100% chance to apply
    stacks = 1,    -- number of stacks to apply
    power = 10     -- effect strength (for DoTs, damage per tick)
}
```

**Common Status Effects:**
- **Poison** - DoT that stacks up to 3 times
- **Burn** - Fire DoT with potential attack reduction
- **Stun** - Prevents all actions
- **Slow** - Reduces speed stat
- **Shield** - Absorbs damage
- **Haste** - Increases speed stat

### 5. Evolution System
Monsters evolve when they meet level requirements and specific conditions.

**Evolution Process:**
1. Player reaches required level for current stage
2. Player requests evolution via `EvolutionRequest` RemoteEvent
3. Server validates requirements in `EvolutionManager`
4. Monster receives stat boosts and learns new moves
5. Visual effects play via `EvolutionEffect` RemoteEvent
6. Monster model is rebuilt with new stage appearance
7. Client receives completion via `EvolutionComplete`

**Evolution Requirements:**
- Minimum level for target stage
- May require specific conditions (items, location, stats)
- Defined in `Shared/EvolutionDefs.luau` and `Shared/Races.luau`

**Evolution Bonuses:**
- Stat increases (HP, MP, STR, INT, DEF, RES, SPD)
- New move unlocks
- Potential personality changes
- Model/appearance update

### 6. Data Management
Player and monster data is managed through `_G.DATA` system:
- Persistent storage across sessions
- Proxy pattern for safe data access
- Automatic saving to DataStore
- Monster inventory management
- Player progression tracking

**Accessing Data:**
```lua
local playerData = _G.DATA:Get(player)
local monsters = playerData.Monsters
local activeMonster = playerData.ActiveMonster
```

## Development Guidelines

### Adding New Features

**New Move:**
1. Create module in `Shared/MovesModules/YourMove.luau`
2. Define move properties and effects
3. Register in `Shared/Moves.luau`
4. Add VFX module in `Shared/MoveVFXModules/` if needed
5. Test in combat scenarios

**New Status Effect:**
1. Define in `Shared/StatusEffectDefs.luau`
2. Add logic in `Server/CombatManager/StatusEffects.luau` if special behavior needed
3. Create icon and visual feedback
4. Test interactions with existing effects

**New Monster Race:**
1. Add race definition in `Shared/Races.luau`
2. Define evolution tree and stages
3. Create models in `ReplicatedStorage.Assets.Templates`
4. Add starter moves and stats
5. Test evolution progression

**New Evolution:**
1. Define requirements in `Shared/EvolutionDefs.luau`
2. Add evolution path in `Shared/Races.luau`
3. Create evolved form model
4. Define stat bonuses and move unlocks
5. Test evolution trigger and result

### Best Practices

**Code Organization:**
- Keep client scripts in `Client/` with `.local.luau` extension
- Server logic goes in `Server/`
- Shared code in `Shared/` for both client and server access
- Use ModuleScripts for reusable code

**Performance:**
- Minimize RemoteEvent traffic
- Cache frequently accessed modules
- Use object pooling for VFX and projectiles
- Optimize combat loop to handle multiple battles

**Security:**
- Always validate inputs on server side
- Never trust client data for critical game logic
- Use RemoteFunctions for data requests
- Implement proper anti-cheat measures

**Testing:**
- Test moves with various stat combinations
- Verify status effect interactions
- Check evolution requirements thoroughly
- Test combat with different monster types
- Validate data persistence

### Common Tasks

**Balancing a Move:**
1. Adjust power, mpCost, accuracy, or cooldown in move definition
2. Test in combat scenarios
3. Compare to similar rarity moves
4. Check combo potential with status effects

**Fixing Combat Bugs:**
1. Check `Server/CombatManager/init.luau` for state machine issues
2. Verify damage calculation in `CombatMath.luau`
3. Review status effect logic in `StatusEffects.luau`
4. Check RemoteEvent communication between client/server

**Adding Visual Effects:**
1. Create particle emitters or beam effects
2. Add to `Shared/Effects&SFX/`
3. Reference in `Shared/MoveVFX.luau` or `MoveVFXModules/`
4. Trigger from `Client/` or via RemoteEvent

**Debugging Combat:**
1. Enable debug prints in CombatManager
2. Check `_G.EFFECTS` for visual feedback
3. Monitor RemoteEvent traffic
4. Use Roblox Developer Console for errors
5. Verify stat calculations step by step

## Architecture Patterns

### Client-Server Communication
- **RemoteEvents** - Fire-and-forget messages (UI updates, VFX triggers)
- **RemoteFunctions** - Request-response (data queries, validation)
- **ReplicatedStorage** - Shared modules and assets
- **ServerStorage** - Server-only secure data

### Module Pattern
```lua
local Module = {}
Module.__index = Module

function Module.new(...)
    local self = setmetatable({}, Module)
    -- initialization
    return self
end

function Module:Method()
    -- instance method
end

return Module
```

### State Machine (Combat)
```lua
local states = {
    deciding = function(combat, dt) 
        -- Choose next action
    end,
    positioning = function(combat, dt)
        -- Move to position
    end,
    executing = function(combat, dt)
        -- Perform move
    end
}

-- State transition
combat.state = "deciding"
states[combat.state](combat, deltaTime)
```

## Troubleshooting

### Common Issues

**Monster Not Evolving:**
- Check level requirements in `Races.luau`
- Verify evolution path exists
- Ensure EvolutionManager is loaded
- Check for script errors in output

**Move Not Dealing Damage:**
- Verify power > 0 in move definition
- Check accuracy calculation
- Ensure target has Humanoid
- Review CombatMath formulas

**Status Effect Not Applying:**
- Check effect chance (0.0 to 1.0)
- Verify statusId matches StatusEffectDefs
- Ensure StatusEffects module is loaded
- Check for immunities or resistances

**UI Not Updating:**
- Verify RemoteEvent connections
- Check client script enabled
- Review script execution order
- Test RemoteEvent firing on server

**Data Not Saving:**
- Check DataStore limits and quotas
- Verify player data structure
- Test `_G.DATA` system
- Review autosave intervals

## Resources

### Roblox Documentation
- [RemoteEvents and RemoteFunctions](https://create.roblox.com/docs/scripting/events/remote)
- [DataStore Service](https://create.roblox.com/docs/cloud-services/data-stores)
- [Humanoid Class](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- [TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService)

### Project Documentation
- `Shared/StatusEffects.md` - Comprehensive status effect guide
- Technical Reports (in root) - Evolution and combat system refactoring

### Game Design References
- Turn-based RPG combat systems
- Pokémon-style creature collection mechanics
- Digimon evolution progression
- Status effect design from ARPGs

## Contributing

When working on this project:
1. Follow existing code style and naming conventions
2. Document new systems and features
3. Test changes thoroughly before committing
4. Update this guide when adding major features
5. Communicate with team about breaking changes
6. Keep client and server code properly separated
7. Use meaningful variable and function names
8. Comment complex logic and formulas

## Quick Reference

### Important Global Variables
- `_G.DATA` - Player data management system
- `_G.MONSTERGENERATOR` - Monster creation utilities
- `_G.EFFECTS` - Visual effects helper (damage numbers, etc.)

### Key Services
- `ReplicatedStorage` - Shared modules and assets
- `ServerScriptService` - Server scripts location
- `StarterPlayer.StarterPlayerScripts` - Client scripts location

### Remote Events
- `EvolutionRequest` - Client requests evolution
- `EvolutionEffect` - Server triggers evolution VFX
- `EvolutionComplete` - Server confirms evolution done
- `CombatUpdate` - Combat state synchronization

### Directory Shortcuts
- `RS.Modules` - ReplicatedStorage shared modules
- `RS.Assets.Templates` - Monster models
- `RS.Remotes` - RemoteEvents and RemoteFunctions

---

*This document is maintained for Roblox developers working on the monster combat game. Update as systems evolve.*
