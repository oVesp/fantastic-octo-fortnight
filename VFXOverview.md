Move Visual Effects (VFX) System Overview
Effects&SFX Module Architecture

The Effects&SFX system provides a reusable, pooled approach to visual and sound effects. At its core is an EffectPoolManager that preloads templates from ReplicatedStorage/Assets into categorized pools (e.g. folders named EmitterEffects, AuraEffects, SFX, Trail, Lights, Misc)
GitHub
. Each category holds objects (parts, particle emitters, sounds, etc.) serving as templates. The pool manager caches these and creates clones on demand, avoiding expensive instantiation during gameplay. For example, when an effect is requested by name and category via EffectPool:GetInstance(name, category), the system either reuses an available inactive instance or clones a new one from the stored template
GitHub
GitHub
. After a short duration, effects are returned to the pool (their parent set to nil) for reuse
GitHub
GitHub
.

Effect Functions: The Effects&SFX module (often referenced as _G.EFFECTS) defines high-level helper functions that spawn these pooled effects in the world
GitHub
. Key functions include:

EmitterEffect: Spawns a transient particle effect or part. It fetches an instance from the EmitterEffects pool by name and places it in the world (e.g. into workspace.Debris). If the template is a BasePart, it sets the part’s CFrame to the given position (with optional offset) and toggles any ParticleEmitter children to emit for a short duration
GitHub
GitHub
. If the template is a Folder of particle emitters (for effects applied to multiple parts), it will clone those emitters onto a provided list of target parts
GitHub
. After the specified Duration, the effect (and any temporary welds or emitted particles) are cleaned up or returned to the pool
GitHub
.

TrailEffect: Attaches a trail object (from the Trail pool) to a moving part (e.g. a projectile). It welds the trail to follow the given part and automatically returns it after a duration
GitHub
GitHub
.

AuraEffect: Clones particle emitters from an AuraEffects template onto multiple target parts (e.g. all body parts of a character) to create a sustained aura. Each emitter can be tagged with an AuraName attribute for later removal
GitHub
GitHub
.

LightEffect: Creates or reuses a light (PointLight) from the Lights pool, parented to a given object, and tweens its brightness/range for a brief flash effect
GitHub
GitHub
.

PlaySound: Plays audio using pooled Sound objects from SFX. It either fetches a Sound by name from the pool or creates one on the fly (if given a numeric asset ID)
GitHub
GitHub
. The sound is parented to a location (or temporary part if a 3D position is provided) and played with optional volume, random pitch, and fade-out settings. Once the sound finishes or its duration lapses, it is returned to the pool for reuse
GitHub
GitHub
.

All these functions are exposed via the global _G.EFFECTS for easy use across the codebase. This architecture ensures that visual effects (VFX) and sound effects (SFX) are efficiently reused and can be triggered with simple function calls rather than manually creating/destroying objects each time.

MoveVFX and Effect Integration

To integrate with the combat system’s moves, the project uses a MoveVFX framework. The module Shared/MoveVFX.luau maintains a mapping of move identifiers to their VFX configurations. It automatically loads all sub-modules in the MoveVFXModules/ folder on startup
GitHub
. Each such sub-module corresponds to a specific move and defines that move’s unique visual/sound effects. For example, the module VoidRayVFX.luau has moveId = "VoidRay" and returns a table of effect names for the cast, travel, impact, and end of the move
GitHub
. When MoveVFX.Resolve(moveId) is called, it checks if a custom VFX module exists for that move. If yes, it loads that module’s configuration (“pack”) and returns it (along with the module itself)
GitHub
. If no custom module is found, the system falls back to a naming convention: it constructs a default pack of effect names by prefixing the move’s name with Cast, Travel, Impact, etc.
GitHub
. For instance, a move with id "Fireball" would by default use effect assets named Cast_Fireball, Travel_Fireball, Impact_Fireball, and an end sound End_Fireball.

Each move’s VFX “pack” contains entries for different stages of the move’s lifecycle:

cast: Effects when the move is initiated (e.g. charge-up particles on the caster) and an optional sfxStart sound.

travel: Effects while the move is in motion (e.g. a trail attached to a projectile, with an optional looping sfxLoop sound).

impact: Effects on hit (e.g. an explosion at the target, with a sfxHit sound).

endcast: Any cleanup or end sound (sfxEnd) after the move completes (e.g. a spell end whoosh).

These names correspond to actual objects under ReplicatedStorage/Assets. The developer is expected to create those asset instances (particle effects, parts, sounds, etc.) and name them accordingly (more on this in the guide below).

Bridge – Executing Move VFX: The CombatManager.Bridge module connects the combat logic with the Effects system. When a move is performed in combat, the server calls bridge functions like PlayCast, PlayTravel, PlayImpact, and PlayEnd at appropriate times
GitHub
GitHub
. The Bridge uses MoveVFX.Resolve to get the VFX pack (and module) for the move, then calls a generic helper playStage(stage, moveId, where, opts) internally
GitHub
. This function first checks if the move’s VFX module defines a custom handler for that stage (e.g. a function VoidRayVFX.impact). If so, it calls the custom function; this allows move-specific logic to run (and if the custom function handles the effect, the default handling is skipped)
GitHub
. For example, VoidRay provides a custom impact function that directly triggers an emitter effect for its impact visuals
GitHub
. Similarly, Fortify overrides the cast stage to apply an aura effect to the caster and nearby allies, using a custom particle configuration called "FortifyAura"
GitHub
. These overrides use the global _G.EFFECTS functions to spawn effects (e.g. _G.EFFECTS.EmitterEffect or _G.EFFECTS.AuraEffect) with move-specific asset names and parameters.

If no custom handler exists for a given stage, the Bridge falls back to default behavior using the pack data
GitHub
. It retrieves the effect names from the pack and invokes the appropriate _G.EFFECTS function:

For a cast or impact stage with an info.effect defined, it calls EmitterEffect. The effect asset (e.g. "Cast_VoidRay" or "Impact_Fireball") will be fetched from the pool and spawned at the specified location. Typically, cast effects spawn at the caster’s position, and impact effects at the target’s position. The Bridge automatically provides the where argument as the caster’s root part or target’s root part, and it can weld the effect to that part if needed (so it follows the character)
GitHub
GitHub
. Duration and offset can be passed via the opts table.

For a travel stage with a trail defined, it calls TrailEffect, attaching the named trail object to a moving reference. The where argument in this case might be a projectile part or the caster (if using a simpler travel effect)
GitHub
.

For any sound entries (sfxStart, sfxLoop, sfxHit, sfxEnd), the Bridge calls PlaySound on each. It uses the names provided to fetch sounds from the SFX pool or play asset IDs, applying volume or pitch modifiers from the options if specified
GitHub
GitHub
.

Because the Effects system is networked (the objects are placed in Workspace or sounds in 3D space), these VFX and SFX are visible/hearable to all players as appropriate. Some effects that are purely client-sided (like camera FOV changes or UI notifications) are handled separately (e.g. _G.EFFECTS.FovEffect is likely called on the client only). However, for move VFX, the server-driven approach ensures that when a move is executed, all clients see the corresponding effects in sync.

Implementing Existing vs. Custom Move Effects

Using Existing (Default) Effects: For many moves, you might not need to write any code to get VFX working – simply follow the naming conventions for assets. If a move does not have a custom VFX module, MoveVFX will use the move’s id or a mapped name to look for asset names like Cast_<MoveName>, Travel_<MoveName>, Impact_<MoveName>, etc.
GitHub
. As long as you have placed the appropriate effect objects in the correct folders under ReplicatedStorage/Assets, the system will automatically handle playing them at runtime. For example, suppose you have a move "RockFist" which is a simple melee attack. If you add an effect part or particle named Impact_RockFist under Assets/EmitterEffects and perhaps a sound Impact_RockFist under Assets/SFX, then when the move hits, the Bridge will trigger an emitter effect at the target using that object and play the sound – no custom script required. The default cast and endcast sounds can also fall back to generic assets if you name them accordingly (e.g. many moves might reuse a common "Cast_Default" sound for the start of cast if a specific one isn’t provided).

Creating Custom Effects: In cases where a move’s visuals are complex or need special timing/logic, developers can create a custom MoveVFX module. This is a ModuleScript in Shared/MoveVFXModules/ named after the move (typically <MoveName>VFX.luau). In it, you define a table with at least a moveId field and a getPack function. The moveId should exactly match the move’s identifier as used in the Moves definitions (this is how the system links them up)
GitHub
. The getPack(moveId) function should return the same structure as the default pack: a table with cast, travel, impact, endcast subtables describing the asset names to use
GitHub
. Often, you can simply return a table of names that follow the convention. For instance, the VoidRayVFX.getPack in the code returns "Cast_VoidRay", "Travel_VoidRay", etc., which is identical to the default naming – but the module exists to allow additional customization
GitHub
. What truly makes custom modules powerful is the ability to define stage handler functions (optional). If you include a function named cast, travel, impact, or endcast in your module, the Bridge will call that instead of or in addition to the default effect. In these functions, you can script any sequence of effect calls. For example, Fortify’s module overrides cast to call AuraEffect on multiple body parts, creating a shield aura around the caster for a duration
GitHub
. You could similarly override impact to maybe create multiple explosions, spawn terrain decals, or other complex behaviors that the simple one-asset default wouldn’t cover.

When writing a custom stage function, you’ll typically use the _G.EFFECTS APIs to spawn effects. The Bridge passes in moveId, a where object (usually the part or model representing the location of the effect), and an opts table for any additional parameters. You can ignore opts if not needed, or use it for things like effect duration. Always ensure to check for the existence of the needed _G.EFFECTS function before calling it (the examples do this with if _G.EFFECTS and _G.EFFECTS.FunctionName then ... end). Once your module is in place, it will be auto-loaded on game start, and its definitions will override or augment the default behavior for that move.

Step-by-Step: Adding Custom Move VFX

Developing a new move’s visual effects involves creating the asset resources and hooking them into the system. Below is a step-by-step guide:

Design and Create Effect Assets: Determine what visual elements and sounds your move needs (e.g. a casting animation effect, a projectile or trail, an impact blast, and sounds for each). Using Roblox Studio, create these assets under ReplicatedStorage → Assets in the appropriate category folders:

EmitterEffects: for particle effects or part-based effects that play once (e.g. muzzle flash, explosion). This could be a ParticleEmitter inside a part, a model/folder of multiple particles, or any BasePart with special properties. For example, a part with a ParticleEmitter could serve as Impact_Fireball.

Trail: for any Trail objects that should attach to moving parts (e.g. a fiery trail following a projectile, named Travel_Fireball).

AuraEffects: for effects that need to be replicated across multiple parts (usually a folder containing one or more ParticleEmitters). E.g., an aura FortifyAura (used by Fortify) is likely a folder with emitters, placed under AuraEffects
GitHub
.

Lights: for light flash effects (PointLight/SpotLight templates). For instance, a PointLight asset named Flash could be reused for any bright flash.

SFX: for sound effects. Insert Sound objects and name them according to move stages (e.g. Cast_MyMove, Impact_MyMove). Set their SoundId or other properties as needed. These will be cloned and played via PlaySound.

Make sure the names of these assets exactly follow the pattern “Prefix_MoveName” (Cast_, Travel_, Impact_, End_, etc.) to match what the MoveVFX system expects. You can reuse existing generic effects if appropriate (for example, many moves might use the same Impact_Default explosion asset if they are similar). The EffectPool will automatically detect and register any new assets you add to these folders
GitHub
.

Hook Up the Move in MoveVFX: If you are adding a brand new move, ensure its identifier is defined in your move data (MovesModules and registered in Moves.luau). By default, MoveVFX will look for assets named after this id.

Using conventions only: If your move’s effects are straightforward and you’ve created assets with the proper names, you might not need a custom module. The system will resolve the effect names on the fly
GitHub
. For example, if move id is "LightningStrike", the system will expect assets like Cast_LightningStrike, Impact_LightningStrike, etc. Simply ensure those exist. You can still define the move’s sounds in its data (e.g. a field sfxStart if present, but in this setup the MoveVFX system is handling sounds through naming convention, so usually not needed to define in move data).

Custom module (optional): If your move requires special handling or you want to fine-tune the effects, create a module in Shared/MoveVFXModules. Name it clearly (e.g. LightningStrikeVFX.luau). In this script, set up the structure as follows:

-- Example Move VFX module for "MyNewMove"
local MyNewMoveVFX = { moveId = "MyNewMove" }

function MyNewMoveVFX.getPack(moveId)
    return {
        cast = { effect = "Cast_MyNewMove", sfxStart = "Cast_MyNewMove" },
        travel = { trail = "Travel_MyNewMove", sfxLoop = "Travel_MyNewMove" },
        impact = { effect = "Impact_MyNewMove", sfxHit = "Impact_MyNewMove" },
        endcast = { sfxEnd = "End_MyNewMove" }
    }
end

-- Optional: custom behavior for cast/travel/impact/end stages
function MyNewMoveVFX.impact(moveId, where, opts)
    -- e.g., combine an impact particle and a light flash at the target
    if _G.EFFECTS then
        _G.EFFECTS.EmitterEffect({ Name = "Impact_MyNewMove", Position = where.CFrame })
        _G.EFFECTS.LightEffect({ Name = "Flash", Where = where, Duration = 0.5, Range = 10 })
    end
end

return MyNewMoveVFX


This template shows a typical structure: we return a table with moveId and a getPack. The pack here uses the standard naming (you could customize the names if your assets don’t follow the default pattern or if you want to mix in some existing effect). We also override the impact stage as an example – perhaps our new move should create a flash of light in addition to a particle burst on impact. Inside the custom handler, we call the relevant effect functions. We could add similar overrides for cast or others if needed. Any stage not overridden will use the default behavior with the assets from the pack. Once this module is created, the main MoveVFX loader will automatically pick it up (mapping "MyNewMove" to this module) on game start
GitHub
.

Ensure Consistent Naming and Registration: Double-check that the move’s identifier in the Moves data matches the naming of your VFX assets and any custom module:

The moveId string in your VFX module must match the move’s id exactly (including case) for MoveVFX to register it
GitHub
. For example, if your move is "ShadowLeap" in the move list, use moveId = "ShadowLeap" in the VFX module and name assets like Cast_ShadowLeap (not “shadowLeap” or other variations).

If the move’s id is not a convenient string for asset naming (say, some moves are indexed or have internal codes), you can add an entry in the NAME table inside MoveVFX.luau to map an id to a base name
GitHub
. (By default, that table maps a few internal IDs to user-friendly names. For instance, if a move id was "BasicAttack" or a numeric code, you might map it to "BasicAttack" or another key used in asset names. In most cases you can just use identical strings and not worry about this.)

Ensure your new MoveVFX module script is placed in the MoveVFXModules folder in ReplicatedStorage so that it’s replicated to clients and available to the server. The safe require in the initialization will print a success message if loaded properly
GitHub
.

Test the Effects In-Game: Run the game and use the move in a test combat scenario. Verify each stage:

Casting: When the monster/character begins using the move, check that the cast effect plays at the caster (e.g. particles appear, cast sound plays). If you welded the effect, it should follow the character if they move.

Travel (if applicable): For projectile moves, ensure the trail appears attached to the projectile or the moving model. The trail should persist for the intended duration and then clean up.

Impact: Upon hit, confirm the impact particles and sounds occur at the target location. If you had custom logic (like additional light or camera shake), verify those trigger correctly (camera effects might only be visible on the client who owns the character, depending on implementation).

End: If there is any endcast sound or effect (for example, a lingering sound or a cleanup effect), ensure it fires. In many cases endcast is just a sound (e.g. a cooldown or finish sound).

Use the Roblox Developer Console to watch for any warnings or errors. The Effects system will warn if an asset is not found in the pool (e.g. a typo in name or missing object)
GitHub
. It will also warn if a custom VFX function errors out. These messages can help pinpoint integration issues.

Tune parameters if needed: you might adjust the Duration or Offset passed via the opts table when calling effects. For instance, if an impact blast is too short, increase its particle Duration or lifetime. You can pass such options either via the Bridge call (not usually manual) or bake them into your custom function logic.

Iterate and Reuse: Leverage the pooling system by reusing effects when appropriate. If your new move’s visuals resemble an existing move, consider using the same assets to save time (for example, many moves might use a common “Impact_Default” explosion). Conversely, if your move is unique, encapsulate those differences in its VFX module so that other moves remain unaffected. Document your new move’s effects for the team, and consider adding any general-purpose effects to a common library for future use.

Checklist for Creating & Registering New Effects

 Assets created: All necessary particle, mesh, or sound assets for the move are created in ReplicatedStorage/Assets under the correct category folders (EmitterEffects, Trail, AuraEffects, SFX, etc.). They are named with the proper Prefix_MoveName convention (e.g. Cast_MoveName, Impact_MoveName).

 MoveVFX module (if needed): A ModuleScript for the move exists in Shared/MoveVFXModules/ (named MoveNameVFX.luau). It exports a table with moveId and getPack, and includes any custom stage functions for non-standard effect behavior.

 Naming consistency: The moveId in the VFX module matches the move’s id in MovesModules/Moves.luau. All asset names correspond to that moveId or its alias (check spelling, punctuation, and case exactly).

 Integration in code: The Effects system and MoveVFX loader will auto-register the new effects on game start. (No manual registration code is needed beyond placing the assets and module in the correct locations
GitHub
.) Verify that no errors appear during the module loading phase (look for “[Main] Module 'X' loaded successfully” in the server output for your Effects&SFX and MoveVFX modules
GitHub
).

 Testing: Run a test battle or scenario with the move. Confirm that each VFX/SFX triggers at the right moment (cast, travel, impact, end). Use debug prints or Roblox’s output to ensure _G.EFFECTS calls are executing without error
GitHub
. Adjust asset properties (particle emitter counts, durations, sound volumes) as needed to achieve the desired visual effect.

 Optimization check: Ensure that effects are cleaned up properly (the pooling system should handle most of this). Avoid extremely long-lived particles or sounds unless necessary, to prevent clutter. The pooling system’s debris and return calls (already built-in) will help, but be mindful of performance (complex effects might be better handled on the client only, or with rate limits).

 Documentation: Update any relevant documentation or comments (e.g. add your move to lists in the code comments or guides) so other developers know that this move has custom VFX. Following the existing naming conventions and module structure will make it easier for the team to maintain the effects library.

By following this structured approach, you ensure that the new move’s visual effects are well-integrated into the game’s architecture, reuse resources efficiently, and are easy to maintain or tweak going forward. With the Effects&SFX and MoveVFX systems handling most of the heavy lifting (pool management, replication, timing), developers can focus on designing creative effects and simply plugging them in with minimal code changes
GitHub
. The result is a clean separation of combat logic and visual effects, making the codebase more modular and scalable.
