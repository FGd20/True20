-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local nStaticMod;

function onSourceUpdate()
	-- True 20:  TODO; This should not be an attack roll
	local nodeWin = window.getDatabaseNode();
	local nType = DB.getValue(nodeWin, "type", 0);
	local nValue = calculateSources();
	
	local nRanks = DB.getValue(nodeWin, "powercheckbase","");
	local nMisc = DB.getValue(nodeWin, "powercheckbonus","");
	local sPowercheckstat = DB.getValue(nodeWin, "powercheckstat","");
	local nStatModifier = DB.getValue(nodeWin, "...abilities." .. sPowercheckstat .. ".bonus", 0);

	setValue(nRanks + nStatModifier + nMisc);
end

function action(draginfo)
	local rActor, rAttack = CharManager.getWeaponAttackRollStructures(window.getDatabaseNode());
	rAttack.modifier = getValue();
	rAttack.order = tonumber(string.sub(getName(), 7)) or 1;
	
	-- ActionAttack.performRoll(draginfo, rActor, rAttack); -- Doom: This shouldn't really be an attack roll.
	ActionSkill.performRoll(draginfo, rActor, "Power check", getValue(), nill, nTargetDC, false, true);
	return true;
end

function onDragStart(button, x, y, draginfo)
	return action(draginfo);
end

function onDoubleClick(x,y)
	return action();
end			
