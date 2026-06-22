local jecs = require("@Packages/jecs")

export type DamageInterface = {
	damage: number,
	source: jecs.Entity<any>,
}

export type DamageSourceInterface = {
	damage: number,
	delay: number,
	instance: BasePart,
}

return nil
