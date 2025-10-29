return function()
        local StatusEffects = require(script.Parent.StatusEffects)

        describe("StatusEffects.Apply", function()
                beforeEach(function()
                        StatusEffects._resetForTests()
                end)

                afterEach(function()
                        StatusEffects._setNowForTests(nil)
                end)

                it("applies default shield strength when not provided", function()
                        local target = {}

                        StatusEffects.Apply(target, {name = "Shield"})

                        local remaining, absorbed = StatusEffects.AbsorbWithShield(target, 15)
                        expect(absorbed).to.equal(15)
                        expect(remaining).to.equal(0)

                        remaining, absorbed = StatusEffects.AbsorbWithShield(target, 10)
                        expect(absorbed).to.equal(5)
                        expect(remaining).to.equal(5)
                end)

                it("applies custom damage over time values", function()
                        local target = {}
                        local source = {}
                        StatusEffects.Apply(target, {name = "Poison", dur = 6, stacks = 2, dps = 5}, source)

                        local total = 0
                        StatusEffects.Tick(1, function(_, amount, origin, effectName)
                                total += amount
                                expect(origin).to.equal(source)
                                expect(effectName).to.equal("Poison")
                        end)

                        expect(total).to.equal(10)
                end)

                it("falls back to default damage over time when not overridden", function()
                        local target = {}
                        StatusEffects.Apply(target, {name = "Poison", dur = 6})

                        local total = 0
                        StatusEffects.Tick(1, function(_, amount)
                                total += amount
                        end)

                        expect(total).to.equal(3)
                end)

                it("uses default durations when none are provided", function()
                        local target = {}
                        local current = 0

                        StatusEffects._setNowForTests(function()
                                return current
                        end)

                        StatusEffects.Apply(target, {name = "Poison"})
                        expect(StatusEffects.Has(target, "Poison")).to.equal(true)

                        current += 3
                        StatusEffects.Tick(3, function() end)
                        expect(StatusEffects.Has(target, "Poison")).to.equal(true)

                        current += 4
                        StatusEffects.Tick(4, function() end)
                        expect(StatusEffects.Has(target, "Poison")).to.equal(false)
                end)
        end)
end
