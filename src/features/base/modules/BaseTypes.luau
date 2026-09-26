export type SlotResult = {
	definitionKey: string,
	isNew: boolean
}

export type RollResult = {
	slots: {[number]: SlotResult },
	cutsceneSlotIndex: number?
}

export type CollectedEgg = {
	standIndex: number,
	collectTime: number,
	earnings: number,
}

export type DronePhase = "Idle" | "Moving" | "Collecting"

export type DroneState = {
	phase: DronePhase,
	fromStand: number,  
	toStand: number,
	phaseStart: number,
	phaseEnd: number
}


return nil