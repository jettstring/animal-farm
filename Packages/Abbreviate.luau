local Abbreviate = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dec" }

function Abbreviate.AbbreviateNumber(Number: number?, Decimals)
	if Number == nil then
		return "0"
	end
	
	if Number < 1 then
		return tostring(Number)
	end

	local decimalPlaces = Decimals or 3

	local logValue = math.log10(Number)
	local suffixIndex = math.floor(logValue / 3)

	local suffix = SUFFIXES[suffixIndex] or ""

	local divisor = 10 ^ (logValue - logValue % 3)
	local abbreviatedValue = math.floor(Number / divisor * 10 ^ decimalPlaces) / 10 ^ decimalPlaces

	return tostring(abbreviatedValue) .. suffix
end

function Abbreviate.AddCommas(Number: number)
	local NumberString = tostring(Number)

	local IntegerPart, DecimalPart = NumberString:match("^([^%.]+)%.?(.*)$")
	if not IntegerPart then
		IntegerPart = NumberString
		DecimalPart = ""
	end

	local CommaIndex = #IntegerPart - 3
	while CommaIndex > 0 do
		IntegerPart = IntegerPart:sub(1, CommaIndex) .. "," .. IntegerPart:sub(CommaIndex + 1)
		CommaIndex = CommaIndex - 3
	end

	if DecimalPart ~= "" then
		return IntegerPart .. "." .. DecimalPart
	else
		return IntegerPart
	end
end

return Abbreviate
