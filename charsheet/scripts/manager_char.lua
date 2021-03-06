-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function import()
	local sFile = Interface.dialogFileOpen();
	if sFile then
		DB.import(sFile, "charsheet", "character");
		ChatManager.SystemMessage("Imported character(s) from: " .. sFile);
	end
end

function export(nodeChar)
	local sFile = Interface.dialogFileSave();
	if sFile then
		if nodeChar then
			DB.export(sFile, nodeChar, "character");
			ChatManager.SystemMessage("Exported character: " .. DB.getValue(nodeChar, "name", ""));
		else
			DB.export(sFile, "charsheet", "character", true);
			ChatManager.SystemMessage("Exported all characters");
		end
	end
end

function hasFeat(nodeChar, sFeat)
	if not sFeat then
		return false;
	end
	local sLowerFeat = string.lower(sFeat);
	
	for _,vNode in pairs(DB.getChildren(nodeChar, "featlist")) do
		if string.lower(DB.getValue(vNode, "value", "")) == sLowerFeat then
			return true;
		end
	end
	return false;
end

function addItemDB(nodeChar, nodeSource, sNodeClass)
	-- Validate parameters
	if not nodeChar or not nodeSource then
		return nil;
	end

	-- Get the inventory list
	local nodeInventory = nodeChar.createChild("inventorylist");
	if not nodeInventory then
		return;
	end
	
	-- Remember identified state of item
	local nID = DB.getValue(nodeSource, "isidentified", nil);

	-- Create and copy the new inventory entry
	local nodeItem = nodeInventory.createChild();
	if not nodeItem then
		return;
	end
	DB.copyNode(nodeSource, nodeItem);
	
	-- Handle backward compatibility with d20_JPG module
	local nodeCost = nodeItem.getChild("cost");
	if nodeCost and nodeCost.getType() ~= "string" then
		nodeCost.delete();
	end
	
	-- Set the carried field
	local sType = DB.getValue(nodeItem, "type", "");
	local sSubType = DB.getValue(nodeItem, "subtype", "");
	if sType == "Goods and Services" and StringManager.contains({"Mounts and Related Gear", "Transport", "Spellcasting and Services"}, sSubType) then
		DB.setValue(nodeItem, "carried", "number", 0);
	else
		DB.setValue(nodeItem, "carried", "number", 1);
	end
	
	-- Set the identified field
	if sNodeClass == "item" then
		if not nID then
			DB.setValue(nodeItem, "isidentified", "number", 0);
		end
	else
		DB.setValue(nodeItem, "isidentified", "number", 1);
	end
	
	-- Create the new weapon entry, if appropriate
	if sType == "Weapon" then
		local aWeaponIDs = addWeaponDB(nodeChar, nodeItem, "item");
		
		DB.setValue(nodeItem, "weaponlinks", "string", table.concat(aWeaponIDs, "|"));
	end
	
	return nodeItem;
end

function removeItemFromWeaponDB(nodeItem)
	if not nodeItem then
		return false;
	end
	
	-- Check to see if any of the weapon nodes linked to this item node should be deleted
	local sItemNode = nodeItem.getNodeName();
	local bMeleeFound = false;
	local bRangedFound = false;
	for _,v in pairs(DB.getChildren(nodeItem, "...weaponlist")) do
		local sClass, sRecord = DB.getValue(v, "shortcut", "", "");
		if sRecord == sItemNode then
			local sType = DB.getValue(v, "type", 0);
			if sType == 1 and not bMeleeFound then
				bMeleeFound = true;
				v.delete();
			elseif sType == 0 and not bRangedFound then
				bRangedFound = true;
				v.delete();
			end
		end
	end

	-- We didn't find any linked weapons
	return (bMeleeFound or bRangedFound);
end

function addWeaponDB(nodeChar, nodeItem, sNodeClass)
	-- Parameter validation
	if not nodeChar or not nodeItem then
		return nil;
	end
	
	-- Get the weapon list we are going to add to
	local nodeWeapons = nodeChar.createChild("weaponlist");
	if not nodeWeapons then
		return nil;
	end
	
	-- Grab some information from the source node to populate the new weapon entries
	local sName = DB.getValue(nodeItem, "name", "");
	local nRange = DB.getValue(nodeItem, "range", 0);
	local nBonus = DB.getValue(nodeItem, "bonus", 0);
	local nAtkBonus = nBonus;

	local sType = string.lower(DB.getValue(nodeItem, "subtype", ""));
	local bMelee = true;
	local bRanged = false;
	if string.find(sType, "melee") then
		bMelee = true;
		if nRange > 0 then
			bRanged = true;
		end
	elseif string.find(sType, "ranged") then
		bMelee = false;
		bRanged = true;
	end
	
	local bDouble = false;
	local sProps = DB.getValue(nodeItem, "properties", "");
	local sPropsLower = sProps:lower();
	if sPropsLower:match("double") then
		bDouble = true;
	end
	if nAtkBonus == 0 and (sPropsLower:match("masterwork") or sPropsLower:match("adamantine")) then
		nAtkBonus = 1;
	end
	local bTwoWeaponFight = false;
	if hasFeat(nodeChar, "Two-Weapon Fighting") then
		bTwoWeaponFight = true;
	end
	
	local aDamage = {};
	local sDamage = DB.getValue(nodeItem, "damage", "");
	local aDamageSplit = StringManager.split(sDamage, "/");
	for kDamage, vDamage in ipairs(aDamageSplit) do
		local diceDamage, nDamage = StringManager.convertStringToDice(vDamage);
		table.insert(aDamage, { dice = diceDamage, mod = nDamage });
	end
	
	local sDamageType = string.lower(DB.getValue(nodeItem, "damagetype", ""));
	sDamageType = string.gsub(sDamageType, " or ", ",");
	local aDamageTypes = ActionDamage.getDamageTypesFromString(sDamageType);
	
	local aCritThreshold = { 20 };
	local aCritMult = { 2 };
	local sCritical = DB.getValue(nodeItem, "critical", "");
	local aCrit = StringManager.split(sCritical, "/");
	local nThresholdIndex = 1;
	local nMultIndex = 1;
	for kCrit, sCrit in ipairs(aCrit) do
		local sCritThreshold = string.match(sCrit, "(%d+)[%-�]20");
		if sCritThreshold then
			aCritThreshold[nThresholdIndex] = tonumber(sCritThreshold) or 20;
			nThresholdIndex = nThresholdIndex + 1;
		end
		
		local sCritMult = string.match(sCrit, "x(%d)");
		if sCritMult then
			aCritMult[nMultIndex] = tonumber(sCritMult) or 2;
			nMultIndex = nMultIndex + 1;
		end
	end
	
	-- Get some character data to pre-fill weapon info
	local nBAB = DB.getValue(nodeChar, "attackbonus.base", 0);
	local nAttacks = math.floor((nBAB - 1) / 5) + 1;
	if nAttacks < 1 then
		nAttacks = 1;
	end
	local sAttackStat = "";
	if bRanged then
		sAttackStat = DB.getValue(nodeChar, "attackbonus.ranged.ability", "");
	elseif bMelee then
		sAttackStat = DB.getValue(nodeChar, "attackbonus.melee.ability", "");
	end

	local aWeaponIDs = {};
	if bMelee then
		local nodeWeapon = nodeWeapons.createChild();
		if nodeWeapon then
			local nodeRef = nodeWeapon.createChild("shortcut", "windowreference");
			if nodeRef then
				nodeRef.setValue(sNodeClass, nodeItem.getNodeName());
			end
			
			if bDouble then
				DB.setValue(nodeWeapon, "name", "string", sName .. " (2H)");
			else
				DB.setValue(nodeWeapon, "name", "string", sName);
			end
			DB.setValue(nodeWeapon, "type", "number", 0);
			DB.setValue(nodeWeapon, "attacks", "number", nAttacks);

			DB.setValue(nodeWeapon, "bonus", "number", nAtkBonus);
			DB.setValue(nodeWeapon, "attackstat", "string", sAttackStat);
			DB.setValue(nodeWeapon, "critatkrange", "number", aCritThreshold[1]);

			if aDamage[1] then
				DB.setValue(nodeWeapon, "damagedice", "dice", aDamage[1].dice);
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus + aDamage[1].mod);
			else
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus);
			end
			DB.setValue(nodeWeapon, "critdmgmult", "number", aCritMult[1]);
			
			if bDouble then
				if aDamageTypes[1] then
					DB.setValue(nodeWeapon, "damagetype", "string", aDamageTypes[1]);
				end
			else
				DB.setValue(nodeWeapon, "damagetype", "string", table.concat(aDamageTypes, ", "));
			end

			if string.find(sType, "two%-handed") then
				DB.setValue(nodeWeapon, "damagemeleestatadj", "string", "2h");
			end
			
			DB.setValue(nodeWeapon, "properties", "string", sProps);

			table.insert(aWeaponIDs, nodeWeapon.getName());
		end
	end

	-- Double head 1
	if bMelee and bDouble then
		local nodeWeapon = nodeWeapons.createChild();
		if nodeWeapon then
			local nodeRef = nodeWeapon.createChild("shortcut", "windowreference");
			if nodeRef then
				nodeRef.setValue(sNodeClass, nodeItem.getNodeName());
			end
			
			DB.setValue(nodeWeapon, "name", "string", sName .. " (D1)");
			DB.setValue(nodeWeapon, "type", "number", 0);
			DB.setValue(nodeWeapon, "attacks", "number", nAttacks);

			if bTwoWeaponFight then
				DB.setValue(nodeWeapon, "bonus", "number", nAtkBonus - 2);
			else
				DB.setValue(nodeWeapon, "bonus", "number", nAtkBonus - 4);
			end
			
			DB.setValue(nodeWeapon, "attackstat", "string", sAttackStat);
			DB.setValue(nodeWeapon, "critatkrange", "number", aCritThreshold[1]);

			if aDamage[1] then
				DB.setValue(nodeWeapon, "damagedice", "dice", aDamage[1].dice);
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus + aDamage[1].mod);
			else
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus);
			end
			DB.setValue(nodeWeapon, "critdmgmult", "number", aCritMult[1]);

			if aDamageTypes[1] then
				DB.setValue(nodeWeapon, "damagetype", "string", aDamageTypes[1]);
			end
			
			DB.setValue(nodeWeapon, "properties", "string", sProps);

			table.insert(aWeaponIDs, nodeWeapon.getName());
		end
	end

	-- Double head 2
	if bMelee and bDouble then
		local nodeWeapon = nodeWeapons.createChild();
		if nodeWeapon then
			local nodeRef = nodeWeapon.createChild("shortcut", "windowreference");
			if nodeRef then
				nodeRef.setValue(sNodeClass, nodeItem.getNodeName());
			end
			
			DB.setValue(nodeWeapon, "name", "string", sName .. " (D2)");
			DB.setValue(nodeWeapon, "type", "number", 0);
			DB.setValue(nodeWeapon, "attacks", "number", 1);

			if bTwoWeaponFight then
				DB.setValue(nodeWeapon, "bonus", "number", nAtkBonus - 2);
			else
				DB.setValue(nodeWeapon, "bonus", "number", nAtkBonus - 8);
			end
			
			DB.setValue(nodeWeapon, "attackstat", "string", sAttackStat);
			if aCritThreshold[2] then
				DB.setValue(nodeWeapon, "critatkrange", "number", aCritThreshold[2]);
			else
				DB.setValue(nodeWeapon, "critatkrange", "number", aCritThreshold[1]);
			end

			if aDamage[2] then
				DB.setValue(nodeWeapon, "damagedice", "dice", aDamage[2].dice);
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus + aDamage[2].mod);
			elseif aDamage[1] then
				DB.setValue(nodeWeapon, "damagedice", "dice", aDamage[1].dice);
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus + aDamage[1].mod);
			else
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus);
			end
			if aCritMult[2] then
				DB.setValue(nodeWeapon, "critdmgmult", "number", aCritMult[2]);
			else
				DB.setValue(nodeWeapon, "critdmgmult", "number", aCritMult[1]);
			end
			
			if aDamageTypes[1] then
				if aDamageTypes[2] then
					DB.setValue(nodeWeapon, "damagetype", "string", aDamageTypes[2]);
				else
					DB.setValue(nodeWeapon, "damagetype", "string", aDamageTypes[1]);
				end
			end

			DB.setValue(nodeWeapon, "damagemeleestatadj", "string", "oh");

			DB.setValue(nodeWeapon, "properties", "string", sProps);

			table.insert(aWeaponIDs, nodeWeapon.getName());
		end
	end

	if bRanged then
		local nodeWeapon = nodeWeapons.createChild();
		if nodeWeapon then
			local nodeRef = nodeWeapon.createChild("shortcut", "windowreference");
			if nodeRef then
				nodeRef.setValue(sNodeClass, nodeItem.getNodeName());
			end
			
			DB.setValue(nodeWeapon, "name", "string", sName);
			DB.setValue(nodeWeapon, "type", "number", 1);
			DB.setValue(nodeWeapon, "attacks", "number", nAttacks);
			DB.setValue(nodeWeapon, "rangeincrement", "number", nRange);

			DB.setValue(nodeWeapon, "bonus", "number", nAtkBonus);
			DB.setValue(nodeWeapon, "attackstat", "string", sAttackStat);
			DB.setValue(nodeWeapon, "critatkrange", "number", aCritThreshold[1]);

			if aDamage[1] then
				DB.setValue(nodeWeapon, "damagedice", "dice", aDamage[1].dice);
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus + aDamage[1].mod);
			else
				DB.setValue(nodeWeapon, "damagebonus", "number", nBonus);
			end
			DB.setValue(nodeWeapon, "critdmgmult", "number", aCritMult[1]);

			DB.setValue(nodeWeapon, "damagetype", "string", table.concat(aDamageTypes, ", "));
			
			if sName == "Sling" then
				DB.setValue(nodeWeapon, "damagerangedstatadj", "string", "sling");
			elseif sName == "Shortbow" or sName == "Longbow" or sName == "Shortbow, composite" or sName == "Longbow, composite" then
				DB.setValue(nodeWeapon, "damagerangedstatadj", "string", "bow");
			elseif string.find(string.lower(sName), "crossbow") or sName == "Net" then
				DB.setValue(nodeWeapon, "damagerangedstatadj", "string", "");
			else
				DB.setValue(nodeWeapon, "damagerangedstatadj", "string", "thrown");
			end

			DB.setValue(nodeWeapon, "properties", "string", sProps);

			table.insert(aWeaponIDs, nodeWeapon.getName());
		end
	end
	
	return aWeaponIDs;
end

function rest(nodeChar)
	-- RESET SPELLS
	SpellsManager.resetSpells(nodeChar);
	
	-- RESET HEALTH
	resetHealth(nodeChar);
end

function resetHealth(nodeChar)
	-- CLEAR TEMPORARY HIT POINTS
	DB.setValue(nodeChar, "hp.temporary", "number", 0);
	
	-- HEAL HIT POINTS EQUAL TO CHARACTER LEVEL
	local nHP = DB.getValue(nodeChar, "hp.total", 0);
	local nLevel = DB.getValue(nodeChar, "level", 0);
	
	local nWounds = DB.getValue(nodeChar, "hp.wounds", 0);
	nWounds = nWounds - nLevel;
	if nWounds + nLevel > nHP then
		local nodeCT = CTManager.getCTFromNode(nodeChar);
		if nodeCT then
			EffectsManager.removeEffect(nodeCT, "Stable");
		end
	end
	if nWounds < 0 then
		nWounds = 0;
	end
	DB.setValue(nodeChar, "hp.wounds", "number", nWounds);
	
	local nNonlethal = DB.getValue(nodeChar, "hp.nonlethal", 0);
	nNonlethal = nNonlethal - (nLevel * 8);
	if nNonlethal < 0 then
		nNonlethal = 0;
	end
	DB.setValue(nodeChar, "hp.nonlethal", "number", nNonlethal);
	
	-- HEAL ABILITY DAMAGE
	local nAbilityDamage;
	for kAbility, vAbility in pairs(DataCommon.abilities) do
		nAbilityDamage = DB.getValue(nodeChar, "abilities." .. vAbility .. ".damage", 0);
		if nAbilityDamage > 0 then
			DB.setValue(nodeChar, "abilities." .. vAbility .. ".damage", "number", nAbilityDamage - 1);
		end
	end
end

function getWeaponAttackRollStructures(nodeWeapon, nAttack)
	if not nodeWeapon then
		return;
	end
	
	local nodeChar = nodeWeapon.getChild("...");
	local rActor = ActorManager.getActor("pc", nodeChar);

	local rAttack = {};
	rAttack.type = "attack";
	rAttack.label = DB.getValue(nodeWeapon, "name", "");
	local nType = DB.getValue(nodeWeapon, "type", 0);
	if nType == 2 then
		rAttack.range = "M";
		rAttack.cm = true;
	elseif nType == 1 then
		rAttack.range = "R";
	else
		rAttack.range = "M";
	end
	rAttack.crit = DB.getValue(nodeWeapon, "critatkrange", 20);
	rAttack.stat = DB.getValue(nodeWeapon, "attackstat", "");
	if rAttack.stat == "" then
		if rAttack.range == "M" then
			rAttack.stat = "strength";
		else
			rAttack.stat = "dexterity";
		end
	end
	
	local sProp = DB.getValue(nodeWeapon, "properties", ""):lower();
	if sProp:match("touch") then
		rAttack.touch = true;
	end
	
	return rActor, rAttack;
end

function getWeaponDamageStats(nodeWeapon)
	local sDamageStat1, sDamageStat2;
	local nMult = 1;
	local nMaxStat = nil;

	local bRanged = (DB.getValue(nodeWeapon, "type", 0) == 1);

	sDamageStat1 = DB.getValue(nodeWeapon, "damagestat1", "");
	if sDamageStat1 == "" then
		sDamageStat1 = "strength";
	end
	if bRanged then
		local sRangedStatAdj = DB.getValue(nodeWeapon, "damagerangedstatadj", "");
		if sRangedStatAdj == "bow" then
			nMult = 1;
			nMaxStat = DB.getValue(nodeWeapon, "damagemaxstat", 0);
		elseif sRangedStatAdj == "sling" or sRangedStatAdj == "thrown" then
			nMult = 1;
		elseif sRangedStatAdj == "thrownoh" then
			nMult = 0.5;
		else
			nMult = 0;
		end
	else
		local sMeleeStatAdj = DB.getValue(nodeWeapon, "damagemeleestatadj", "");
		if sMeleeStatAdj == "2h" then
			nMult = 1.5;
		elseif sMeleeStatAdj == "oh" then
			nMult = 0.5;
		end
	end
	
	sDamageStat2 = DB.getValue(nodeWeapon, "damagestat2", "");

	return sDamageStat1, nMaxStat, nMult, sDamageStat2;
end

function getWeaponDamageRollStructures(nodeWeapon)
	if not nodeWeapon then
		return;
	end
	
	local nodeChar = nodeWeapon.getChild("...");
	local rActor = ActorManager.getActor("pc", nodeChar);

	local bRanged = (DB.getValue(nodeWeapon, "type", 0) == 1);

	local rDamage = {};
	rDamage.type = "damage";
	rDamage.label = DB.getValue(nodeWeapon, "name", "");
	if bRanged then
		rDamage.range = "R";
	else
		rDamage.range = "M";
	end
	
	rDamage.stat, rDamage.statmax, rDamage.statmult, rDamage.stat2 = getWeaponDamageStats(nodeWeapon);
	
	if rDamage.statmult ~= 0 then
		if rDamage.statmax then
			local nStat = ActorManager.getAbilityBonus(rActor, rDamage.stat);
			if nStat >= rDamage.statmax then
				rDamage.stat = "";
				rDamage.statmax = 0;
			elseif nStat >= 0 then
				rDamage.statmax = rDamage.statmax - nStat;
			end
		end
	end
	
	rDamage.clauses = {};

	local rWeaponClause = {};

	rWeaponClause.dice = DB.getValue(nodeWeapon, "damagedice", {});
	rWeaponClause.modifier = DB.getValue(nodeWeapon, "damagetotalbonus", 0);
	rWeaponClause.mult = DB.getValue(nodeWeapon, "critdmgmult", 2);
	
	local aDamageTypes = ActionDamage.getDamageTypesFromString(DB.getValue(nodeWeapon, "damagetype", ""));
	rWeaponClause.dmgtype = table.concat(aDamageTypes, ",");
	
	table.insert(rDamage.clauses, rWeaponClause);
	
	return rActor, rDamage;
end

function getBaseAttackRollStructures(sAttack, nodeChar)
	-- CREATURE
	local rCreature = ActorManager.getActor("pc", nodeChar);

	-- ABILITY
	local rAttack = {};
	rAttack.type = "attack";
	rAttack.label = sAttack;

	if string.match(string.lower(sAttack), "melee") then
		rAttack.range = "M";
		rAttack.modifier = DB.getValue(nodeChar, "attackbonus.melee.total", 0);
		rAttack.stat = DB.getValue(nodeChar, "attackbonus.melee.ability", "");
		if rAttack.stat == "" then
			rAttack.stat = "strength";
		end
	else
		rAttack.range = "R";
		rAttack.modifier = DB.getValue(nodeChar, "attackbonus.ranged.total", 0);
		rAttack.stat = DB.getValue(nodeChar, "attackbonus.ranged.ability", "");
		if rAttack.stat == "" then
			rAttack.stat = "dexterity";
		end
	end
	
	-- RESULTS
	return rCreature, rAttack;
end

function getGrappleRollStructures(rActor, sAttack)
	-- ABILITY
	local rAttack = {};
	rAttack.type = "attack";
	rAttack.label = sAttack;
	rAttack.range = "M";
	if rActor then
		rAttack.modifier = DB.getValue(rActor.nodeCreature, "attackbonus.grapple.total", 0);
		rAttack.stat = DB.getValue(rActor.nodeCreature, "attackbonus.grapple.ability", "");
	end
	if rAttack.stat == "" then
		rAttack.stat = "strength";
	end

	-- RESULTS
	return rAttack;
end

-- Doom
function getMentalRollStructures(rActor, sAttack)
	-- ABILITY
	local rAttack = {};
	rAttack.type = "attack";
	rAttack.label = sAttack;
	rAttack.range = "Psychic";
	if rActor then
		rAttack.modifier = DB.getValue(rActor.nodeCreature, "attackbonus.mental.total", 0);
		rAttack.stat = DB.getValue(rActor.nodeCreature, "saves.will.ability", "");
	end
	if rAttack.stat == "" then
		rAttack.stat = "wisdom";
	end

	-- RESULTS
	return rAttack;
end



function calcLevel(nodeChar)
	local nLevel = 0;
	
	for kClass, nodeChild in pairs(DB.getChildren(nodeChar, "classes")) do
		nLevel = nLevel + DB.getValue(nodeChild, "level", 0);
	end
	
	DB.setValue(nodeChar, "level", "number", nLevel);
end

function sortClasses(a,b)
	return a.getName() < b.getName();
end

function getClassLevelSummary(nodeChar)
	if not nodeChar then
		return "";
	end
	
	local aClasses = {};

	local aSorted = {};
	for _,nodeChild in pairs(DB.getChildren(nodeChar, "classes")) do
		table.insert(aSorted, nodeChild);
	end
	table.sort(aSorted, sortClasses);
			
	for _,nodeChild in pairs(aSorted) do
		local sClass = DB.getValue(nodeChild, "name", "");
		local nLevel = DB.getValue(nodeChild, "level", 0);
		if nLevel > 0 then
			table.insert(aClasses, string.sub(sClass, 1, 3) .. " " .. nLevel);
		end
	end

	local sSummary = table.concat(aClasses, " / ");
	return sSummary;
end

function updateSkillPoints(nodeChar)
	local nSpentTotal = 0;

	local bPFMode = OptionsManager.isOption("SYSTEM", "pf");
	
	local nSpent;
	for _,vNode in pairs(DB.getChildren(nodeChar, "skilllist")) do
		nSpent = DB.getValue(vNode, "ranks", 0);
		if nSpent > 0 then
			if not bPFMode and DB.getValue(vNode, "state", 0) == 0 then
				nSpent = nSpent * 2;
			end
			
			nSpentTotal = nSpentTotal + nSpent;
		end
	end

	DB.setValue(nodeChar, "skillpoints.spent", "number", nSpentTotal);
end

function updateEncumbrance(nodeChar)
	local nEncTotal = 0;

	local nCount, nWeight;
	for _,vNode in pairs(DB.getChildren(nodeChar, "inventorylist")) do
		if DB.getValue(vNode, "carried", 0) == 1 then
			nCount = DB.getValue(vNode, "count", 0);
			if nCount < 1 then
				nCount = 1;
			end
			nWeight = DB.getValue(vNode, "weight", 0);
			
			nEncTotal = nEncTotal + (nCount * nWeight);
		end
	end

	DB.setValue(nodeChar, "encumbrance.load", "number", nEncTotal);
end

function onActionDrop(draginfo, nodeChar)
	if draginfo.isType("spellmove") then
		ChatManager.Message("Unable to determine class for moved spell, please drop within a class.");
		return true;
	elseif draginfo.isType("spelldescwithlevel") then
		ChatManager.Message("Unable to determine class for new spell, please drop within a class.");
		return true;
	elseif draginfo.isType("shortcut") then
		local sClass = draginfo.getShortcutData();
		
		if sClass == "spelldesc" or sClass == "spelldesc2" then
			ChatManager.Message("Unable to determine class or level for new spell, please drop within a class level.");
			return true;
		elseif sClass == "referenceweapon" then
			CharManager.addItemDB(nodeChar, draginfo.getDatabaseNode(), sClass);
			return true;
		elseif sClass == "item" then
			local nodeItem = draginfo.getDatabaseNode();
			local sType = DB.getValue(nodeItem, "type", "");
			if sType == "Weapon" then
				CharManager.addItemDB(nodeChar, nodeItem, sClass);
				return true;
			end
		end
	end
end

function getSkillValue(rActor, sSkill, sSubSkill)
	local nValue = 0;
	local bUntrained = false;

	local rSkill = GameSystemManager.getSkill(sSkill);
	local bTrainedOnly = (rSkill and rSkill.trainedonly);
	
	if rActor and rActor.nodeCreature then
		local sSkillLower = sSkill:lower();
		local sSubLower = nil;
		if sSubSkill then
			sSubLower = sSubSkill:lower();
		end
		
		local nodeSkill = nil;
		for _,vNode in pairs(DB.getChildren(rActor.nodeCreature, "skilllist")) do
			local sNameLower = DB.getValue(vNode, "label", ""):lower();

			-- Capture exact matches
			if sNameLower == sSkillLower then
				if sSubLower then
					local sSubName = DB.getValue(vNode, "sublabel", ""):lower();
					if (sSubName == sSubLower) or (sSubLower == "planes" and sSubName == "the planes") then
						nodeSkill = vNode;
						break;
					end
				else
					nodeSkill = vNode;
					break;
				end
			
			-- And partial matches
			elseif sNameLower:sub(1, #sSkillLower) == sSkillLower then
				if sSubLower then
					local sSubName = sNameLower:sub(#sSkillLower + 1):match("%w[%w%s]*%w");
					if sSubName and ((sSubName == sSubLower) or (sSubLower == "planes" and sSubName == "the planes")) then
						nodeSkill = vNode;
						break;
					end
				end
			end
		end
		
		if nodeSkill then
			local nRanks = DB.getValue(nodeSkill, "ranks", 0);
			local nAbility = DB.getValue(nodeSkill, "stat", 0);
			local nMisc = DB.getValue(nodeSkill, "misc", 0);
			
			nValue = math.floor(nRanks) + nAbility + nMisc;

			if OptionsManager.isOption("SYSTEM", "pf") and (nRanks > 0) then
				local nState = DB.getValue(nodeSkill, "state", 0);
				if nState == 1 then
					nValue = nValue + 3;
				end
			end
			
			local nACMult = DB.getValue(nodeSkill, "armorcheckmultiplier", 0);
			if nACMult ~= 0 then
				local bApplyArmorMod = DB.getValue(nodeSkill, "...encumbrance.armormaxstatbonusactive", 0);
				if (bApplyArmorMod ~= 0) then
					local nACPenalty = DB.getValue(nodeSkill, "...encumbrance.armorcheckpenalty", 0);
					nValue = nValue + (nACMult * nACPenalty);
				end
			end

			if bTrainedOnly then
				if nRanks == 0 then
					bUntrained = true;
				end
			end
		else
			if rSkill then
				if rSkill.stat then
					nValue = nValue + ActorManager.getAbilityBonus(rActor, rSkill.stat);
				end
				
				if rSkill.armorcheckmultiplier then
					local bApplyArmorMod = DB.getValue(rActor.nodeCreature, "encumbrance.armormaxstatbonusactive", 0);
					if (bApplyArmorMod ~= 0) then
						local nArmorCheckPenalty = DB.getValue(rActor.nodeCreature, "encumbrance.armorcheckpenalty", 0);
						nValue = nValue + (nArmorCheckPenalty * (tonumber(rSkill.armorcheckmultiplier) or 0));
					end
				end
			end
			bUntrained = bTrainedOnly;
		end
	else
		bUntrained = bTrainedOnly;
	end
	
	return nValue, bUntrained;
end

function setPortrait(nodeChar, sPortraitFile)
	if not nodeChar or not sPortraitFile then
		return;
	end
	
	User.setPortrait(nodeChar, sPortraitFile);
	
	local wnd = Interface.findWindow("charsheet", nodeChar)
	if wnd then
		if User.isLocal() then
			wnd.localportrait.setFile(sPortraitFile);
		else
			wnd.portrait.setIcon("portrait_" .. nodeChar.getName() .. "_charlist", true);
		end
	end
	
	wnd = Interface.findWindow("identityselection", "");
	if wnd then
		for k, v in pairs(wnd.list.getWindows()) do
			if v.localdatabasenode then
				if v.localdatabasenode == nodeChar then
					v.localportrait.setFile(sPortraitFile);
				end
			end
		end
	end
end
