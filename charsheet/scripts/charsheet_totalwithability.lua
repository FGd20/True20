-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local sCharPath;

local aAbility = {};
local aDefault = {};

function onInit()
	sCharPath = "";
	if charpath then
		sCharPath = charpath[1];
	end
	
	if ability then
		for k, v in ipairs(ability) do
			if v.source then
				local sDefault = "";
				if v.default then
					sDefault = v.default[1];
				end
				addAbilitySource(v.source[1], sDefault);
			end
		end
	end
	
	local nodeChar = window.getDatabaseNode();
	local nodeAbilities = nodeChar.createChild(sCharPath .. "abilities");
	if nodeAbilities then
		nodeAbilities.onChildUpdate = sourceupdate;
	end
	local nodeLevel = nodeChar.createChild("level", "number");
	if nodeLevel then
		nodeLevel.onUpdate = sourceupdate;
	end
	local nodeBAB = nodeChar.createChild("attackbonus.base", "number");
	if nodeBAB then
		nodeBAB.onUpdate = sourceupdate;
	end
	
	super.onInit();
end

function sourceupdate()
	if self.onSourceUpdate() then
		self.onSourceUpdate();
	end
end

function onSourceUpdate()
	local nAbility = getAbilityBonus();

	setValue(calculateSources() + nAbility);
end

function getAbilityBonus(nMaxMod)
	local nBonus = 0;
	
	local rActor = ActorManager.getActor("pc", window.getDatabaseNode().getChild(sCharPath));
	
	for k, v in ipairs(aAbility) do
		local nAbilityBonus = ActorManager.getAbilityBonus(rActor, getAbility(k));
		if k == 1 and nMaxMod and nMaxMod >= 0 then
			if nAbilityBonus > nMaxMod then
				nAbilityBonus = nMaxMod;
			end
		end
		nBonus = nBonus + nAbilityBonus;
	end
	
	return nBonus;
end

function getAbility(kAbility)
	local sAbility = "";
	if aAbility[kAbility] then
		sAbility = DB.getValue(window.getDatabaseNode(), sCharPath .. aAbility[kAbility], "");
	end
	if sAbility == "" and aDefault[kAbility] then
		sAbility = aDefault[kAbility];
	end
	
	return sAbility;
end

function addAbilitySource(sSource, sDefault)
	table.insert(aAbility, sSource);
	table.insert(aDefault, sDefault);
	
	addSource(sSource, "string");
end
