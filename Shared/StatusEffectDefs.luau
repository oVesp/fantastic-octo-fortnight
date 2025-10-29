local defs = {
        Haste = {
                type = "Buff",
                maxStacks = 1,
                pri = 20,
                mods = { Speed = { mult = 1.20 } },
                defaultDuration = 5,
        },
        Berserk = {
                type = "Buff",
                maxStacks = 1,
                pri = 10,
                mods = {
                        Strength = { mult = 1.25 },
                        Defense = { mult = 0.9 },
                },
                defaultDuration = 6,
        },
        GuardUp = {
                type = "Buff",
                maxStacks = 1,
                pri = 18,
                mods = { Defense = { mult = 1.25 } },
                defaultDuration = 6,
        },
        Focus = {
                type = "Buff",
                maxStacks = 3,
                pri = 12,
                mods = { Skill = { add = 5 } },
                defaultDuration = 6,
        },
        ArcaneMind = {
                type = "Buff",
                maxStacks = 1,
                pri = 12,
                mods = { Intelligence = { mult = 1.20 } },
                defaultDuration = 6,
        },

        Slow = {
                type = "Debuff",
                maxStacks = 2,
                pri = 15,
                mods = { Speed = { mult = 0.8 } },
                defaultDuration = 6,
        },
        Weaken = {
                type = "Debuff",
                maxStacks = 2,
                pri = 14,
                mods = { Strength = { mult = 0.85 } },
                defaultDuration = 6,
        },
        Silence = {
                type = "Debuff",
                maxStacks = 1,
                pri = 30,
                flags = { NoCast = true },
                defaultDuration = 6,
        },
        Burn = {
                type = "Debuff",
                maxStacks = 3,
                pri = 10,
                dot = { dps = 4 },
                defaultDuration = 6,
        },
        Poison = {
                type = "Debuff",
                maxStacks = 3,
                pri = 10,
                dot = { dps = 3 },
                defaultDuration = 6,
        },
        Stun = {
                type = "CC",
                maxStacks = 1,
                pri = 100,
                flags = { Stunned = true, NoMove = true, NoCast = true },
                defaultDuration = 1,
        },
        Root = {
                type = "CC",
                maxStacks = 1,
                pri = 80,
                flags = { NoMove = true },
                defaultDuration = 6,
        },

        Shield = {
                type = "Shield",
                maxStacks = 1,
                pri = 50,
                shield = true,
                defaultPower = 20,
                defaultDuration = 6,
        },
        Invulnerability = {
                type = "State",
                maxStacks = 1,
                pri = 200,
                flags = { Invuln = true },
                defaultDuration = 1,
        },
}

return defs
