local jecs = require("@Packages/jecs")

export type TimerInterface = {
	start: number,
	wait: number,
	repeats: boolean?,
	callback: (jecs.Entity<any>) -> (),
}

return nil
