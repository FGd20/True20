-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	local nodeChar = getDatabaseNode();
	if nodeChar then
		local nodeClass = nodeChar.getChild("classes");
		if nodeClass then
			nodeClass.onChildUpdate = onLevelChanged;
		end
	end
	
	onLevelChanged();

	OptionsManager.registerCallback("SYSTEM", onSystemChanged);
	onSystemChanged();
end

function onClose()
	OptionsManager.unregisterCallback("SYSTEM", onSystemChanged);
end

function onLevelChanged()
	CharManager.calcLevel(getDatabaseNode());
end

function onSystemChanged()
	local bPFMode = OptionsManager.isOption("SYSTEM", "pf");
	
	--cmd.setVisible(bPFMode);
	--label_cmd.setVisible(bPFMode);
	
	if label_grapple then
		if bPFMode then
			label_grapple.setValue("CMB");
		elseif minisheet then
			label_grapple.setValue("Grp");
		else
			label_grapple.setValue("Grapple");
		end
	end
	
	notice.setVisible(not bPFMode);
	label_notice.setVisible(not bPFMode);
	search.setVisible(not bPFMode);
	label_search.setVisible(not bPFMode);

end

function onWoundsChanged()
	local sColor = ActorManager.getWoundColor("pc", getDatabaseNode());
	wounds.setColor(sColor);
	nonlethal.setColor(sColor);
end
