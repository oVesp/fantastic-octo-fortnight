return function()
        local StatusEffects = require(script.Parent.StatusEffects)

        describe("StatusEffects.Apply", function()
                beforeEach(function()
                        StatusEffects._resetForTests()
                end)

                it("applies shield strength from the payload", function()
                        local target = {}

                        StatusEffects.Apply(target, {name = "Shield", dur = 6, power = 50})

                        local remaining, absorbed = StatusEffects.AbsorbWithShield(target, 40)
                        expect(absorbed).to.equal(40)
                        expect(remaining).to.equal(0)

                        remaining, absorbed = StatusEffects.AbsorbWithShield(target, 40)
                        expect(absorbed).to.equal(10)
                        expect(remaining).to.equal(30)
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
        end)
end
