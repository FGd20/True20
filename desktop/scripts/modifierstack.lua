-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

control = nil;
freeadjustment = 0;
slots = {};
modifierkeys = {};

local bLocked = false;
local aModifierUsed = {};

function getModifierKey(sButton)
	local bState = modifierkeys[sButton];
	
	if bLocked then
		aModifierUsed[sButton] = true;
	else
		if bState then
			setModifierKey(sButton, false, true);
		end
	end
	
	return bState;
end

function setModifierKey(sButton, bState, bUpdateWnd)
	modifierkeys[sButton] = bState;
	
	if bUpdateWnd then
		local wndMod = Interface.findWindow("modifiers", "modifiers");
		if wndMod and wndMod[sButton] then
			if bState then
				wndMod[sButton].activate();
			else
				wndMod[sButton].deactivate();
			end
		end
	end
end

function registerControl(ctrl)
	control = ctrl;
end

function updateControl()
	if control then
		if adjustmentedit then
			control.label.setValue("Adjusting");
		else
			control.label.setValue("Modifier");
			
			if freeadjustment > 0 then
				control.label.setValue("(+" .. freeadjustment .. ")");
			elseif freeadjustment < 0 then
				control.label.setValue("(" .. freeadjustment .. ")");
			end
			
			control.modifier.setValue(getSum());
			
			control.base.resetCounters();
			
			for i = 1, #slots do
				control.base.addCounter();
			end
			
			if hoverslot and hoverslot ~= 0 and slots[hoverslot] then
				control.label.setValue(slots[hoverslot].description);
			end
		end
		
		if math.abs(control.modifier.getValue()) > 999 then
			control.modifier.setFont("modcollectorlabel");
		else
			control.modifier.setFont("modcollector");
		end
	end
end

function isEmpty()
	if freeadjustment == 0 and #slots == 0 then
		return true;
	end

	return false;
end

function getSum()
	local total = freeadjustment;
	
	for i = 1, #slots do
		total = total + slots[i].number;
	end
	
	return total;
end

function getDescription(forcebonus)
	local s = "";
	
	if not forcebonus and #slots == 1 and freeadjustment == 0 then
		s = slots[1].description;
	else
		local aMods = {};
		
		for i = 1, #slots do
			table.insert(aMods, string.format("%s %+d", slots[i].description, slots[i].number));
		end
		
		if freeadjustment ~= 0 then
			table.insert(aMods, string.format("%+d", freeadjustment));
		end
		
		s = table.concat(aMods, ", ");
	end
	
	return s;
end

function addSlot(description, number)
	if #slots < 6 then
		table.insert(slots, { ['description'] = description, ['number'] = number });
	end
	
	updateControl();
end

function removeSlot(number)
	table.remove(slots, number);
	updateControl();
end

function adjustFreeAdjustment(amount)
	freeadjustment = freeadjustment + amount;
	
	updateControl();
end

function setFreeAdjustment(amount)
	freeadjustment = amount;
	
	updateControl();
end

function setAdjustmentEdit(state)
	if state then
		control.modifier.setValue(freeadjustment);
	else
		setFreeAdjustment(control.modifier.getValue());
	end

	adjustmentedit = state;
	updateControl();
end

function reset()
	if control and control.modifier.hasFocus() then
		control.modifier.setFocus(false);
	end

	freeadjustment = 0;
	slots = {};
	updateControl();
end

function hoverDisplay(n)
	hoverslot = n;
	updateControl();
end

function getStack(forcebonus)
	local sDesc = "";
	local nMod = 0;
	
	if not isEmpty() then
		sDesc = getDescription(forcebonus);
		nMod = getSum();
	end

	if not bLocked then
		reset();
	end
	
	return sDesc, nMod;
end

-- Lock handling
-- Used to keep the modifier stack from being cleared when making multiple rolls (i.e. full attack)
function lock()
	bLocked = true;
end

function unlock(bReset)
	bLocked = false;

	if bReset then
		reset();

		for k, v in pairs(aModifierUsed) do
			setModifierKey(k, false, true);
		end
		aModifierUsed = {};
	end
end

-- Hot key handling
function checkHotkey(draginfo)
	local sDragType = draginfo.getType();
	if sDragType == "number" or sDragType == "modifierstack" then
		addSlot(draginfo.getDescription(), draginfo.getNumberData());
		return true;
	end
end

function onInit()
	Interface.onHotkeyActivated = checkHotkey;
end
