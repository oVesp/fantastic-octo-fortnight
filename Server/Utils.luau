-- ModuleScript: ServerScriptService>Main>Utils
local module = {}

local nameComponents = {
	prefixes = {"Ae","Be","Ca","De","El","Fa","Ga","He","Il","Ja","Ka","Le","Me","Ne","Oe","Pe","Qu","Re","Se","Te","U","Ve","We","Xe","Ye","Ze","Tho","Gra","Bri","Dra","Fro","Gro","Kro","Pro","Stro","Zy","Xy","Ny","Ly","Ry"},
	middles = {"ra","la","ma","na","tha","sha","ka","va","za","xa","ri","li","mi","ni","thi","shi","ki","vi","zi","xi","ro","lo","mo","no","tho","sho","ko","vo","zo","xo","ru","lu","mu","nu","thu","shu","ku","vu","zu","xu","ar","al","am","an","ath","ash","ak","av","az","ax"},
	suffixes = {"dor","nor","thor","mor","kor","vor","zor","xor","dus","nus","thus","mus","kus","vus","zus","xus","dan","nan","than","man","kan","van","zan","xan","del","nel","thel","mel","kel","vel","zel","xel","rak","nak","thak","mak","kak","vak","zak","xak","ion","eon","thion","mion","kion","vion","zion","xion"},
	titles = {"the Brave","the Wise","the Strong","the Swift","the Ancient","the Young","the Bold","the Silent","the Fierce","the Gentle","the Hunter","the Protector","the Destroyer","the Creator","of the Mountain","of the Sea","of the Forest","of the Desert","of the Stars","of the Void","of the Flame","of the Frost"}
}

local racePatterns = {
	Dino = {pattern = "prefix-middle-suffix", chanceForTitle = 0.3},
	Golem = {pattern = "prefix-suffix", chanceForTitle = 0.4},
	Devil = {pattern = "prefix-middle-suffix", chanceForTitle = 0.2},
	Angel = {pattern = "prefix-suffix", chanceForTitle = 0.5},
	Progenitor = {pattern = "prefix-middle-suffix", chanceForTitle = 0.6},
	Beast = {pattern = "prefix-suffix", chanceForTitle = 0.1}
}

local function capitalize(str)
	return str:sub(1,1):upper() .. str:sub(2):lower()
end

local function randomElement(tbl)
	return tbl[math.random(1, #tbl)]
end

function module.nameGenerator(race)
	local components = nameComponents
	local pattern = "prefix-middle-suffix"

	if race and racePatterns[race] then
		pattern = racePatterns[race].pattern
	end

	local nameParts = {}
	for part in pattern:gmatch("[^-]+") do
		if part == "prefix" then
			table.insert(nameParts, randomElement(components.prefixes))
		elseif part == "middle" then
			table.insert(nameParts, randomElement(components.middles))
		elseif part == "suffix" then
			table.insert(nameParts, randomElement(components.suffixes))
		end
	end

	local baseName = table.concat(nameParts)
	baseName = capitalize(baseName)

	local titleChance = 0.3
	if race and racePatterns[race] then
		titleChance = racePatterns[race].chanceForTitle
	end

	if math.random() <= titleChance then
		return baseName .. " " .. randomElement(components.titles)
	end

	return baseName
end

function module.generateNames(count, race)
	local names = {}
	for i = 1, (count or 1) do
		table.insert(names, module.nameGenerator(race))
	end
	return names
end

function module.getNameComponents()
	return {
		prefixes = nameComponents.prefixes,
		middles = nameComponents.middles,
		suffixes = nameComponents.suffixes,
		titles = nameComponents.titles
	}
end

return module