export type SlotResult = {
	definitionKey: string,
	isNew: boolean
}

export type RollResult = {
	slots: {[number]: SlotResult },
	cutsceneSlotIndex: number?
}


return nil