-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	registerMenuItem("Delete Power", "delete", 6);
	registerMenuItem("Confirm Delete", "delete", 6, 3);
	
	toggleDetail();
end

function onMenuSelection(selection, subselection)
	if selection == 6 and subselection == 3 then
		local node = getDatabaseNode();
		if node then
			node.delete();
		else
			close();
		end
	end
end

function onAttackChanged()
	attack1.onSourceUpdate();
end

function onDamageChanged()
	damagetotalbonus.onSourceUpdate();
end

function onTypeChanged()
	toggleDetail();
end

function setSpacerState()
	if activatedetail.getValue() then
		spacer.setVisible(true);
	else
		spacer.setVisible(false);
	end
end

function toggleDetail()
	local bRanged = (type.getIndex() == 1);
	local bAttack = not(type.getIndex() == 2);
	local status = activatedetail.getValue();

	attack1.setVisible(bAttack);
	label_atkdetail.setVisible(status);
	attackbonus.setVisible(status and bAttack); 
	attackbonusranged.setVisible(status and bRanged); -- On top if ranged
	label_atkplus.setVisible(status and bAttack);
	bonus.setVisible(status and bAttack);
	label_critrange.setVisible(status and bAttack);
	critatkrange.setVisible(status and bAttack);

	label_dmgdetail.setVisible(status);
	damagebonusbase.setVisible(status);
	label_dmgplus.setVisible(status);
	damagestat1.setVisible(status);
	label_dmgplus2.setVisible(status);
	damagebonus.setVisible(status);
	label_critmult.setVisible(status and bAttack);
	critdmgmult.setVisible(status and bAttack);
	label_dmgtype.setVisible(status);
	damagetype.setVisible(status);
	
	damageadjanchor.setVisible(status);
	damageadjspacer.setVisible(status);

	label_powercheckdetail.setVisible(status);
	powercheckbase.setVisible(status);
	label_powercheckplus.setVisible(status);
	powercheckstat.setVisible(status);
	label_powercheckplus2.setVisible(status);
	powercheckbonus.setVisible(status);
	
	label_range.setVisible(status and bRanged);
	rangeincrement.setVisible(status and bRanged);
	label_properties.setVisible(status);
	properties.setVisible(status);
	
	setSpacerState();
end
