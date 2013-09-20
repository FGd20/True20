-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	deliverLaunchMessage()
end

function deliverLaunchMessage()
--    local msg = {sender = "", font = "emotefont", icon="portrait_ruleset_token"};
    local msg = {sender = "", font = "emotefont", icon="true20_ruleset_token"};
    msg.text = "True20 v0.1 ruleset for Fantasy Grounds II.\rBased on Smiteworks USA LLC's 3.5E v2.9.3 ruleset.\rThe Blood-dimmed Tide Edition"
    Comm.addChatMessage(msg);
    
    local launchmsg = ChatManager.retrieveLaunchMessages();
    for keyMessage, rMessage in ipairs(launchmsg) do
    	Comm.addChatMessage(rMessage);
    end
end

function onDiceLanded(draginfo)
 	return ActionsManager.onDiceLanded(draginfo);
end

function onDrop(x, y, draginfo)
	local sDragType = draginfo.getType();
	if StringManager.contains(DataCommon.actions, sDragType) then
		ActionsManager.handleActionDrop(draginfo, nil);
	end
end
