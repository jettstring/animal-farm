local PurchaseProfileTemplate = {
	StoredPurchases = {},
	GiftedPurchases = {},	
	TotalGifted = 0,
	GiftPopup = {},
	RobuxSpent = 0,
}



export type PurchaseProfile = typeof(PurchaseProfileTemplate) 
return PurchaseProfileTemplate
