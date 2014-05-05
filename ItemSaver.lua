------------------------------------------------------------------
--ItemSaver.lua
--Author: ingeniousclown, 
--v0.3.0
--[[
Allows you to mark an item so you can know that you meant to save
it for some reason.
]]
------------------------------------------------------------------

libFilters = LibStub("libFilters")

local BACKPACK = ZO_PlayerInventoryBackpack
local BANK = ZO_PlayerBankBackpack
local GUILD_BANK = ZO_GuildBankBackpack
local DECONSTRUCTION = ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack
local LIST_DIALOG = ZO_ListDialog1List

local MARKER_TEXTURE = [[/esoui/art/campaign/overview_indexicon_bonus_disabled.dds]]

local settings = {}
local markedItems = nil

local SIGNED_INT_MAX = 2^32 / 2 - 1
local INT_MAX = 2^32

local function RefreshAll()
	ZO_ScrollList_RefreshVisible(BACKPACK)
	ZO_ScrollList_RefreshVisible(BANK)
	ZO_ScrollList_RefreshVisible(GUILD_BANK)
	ZO_ScrollList_RefreshVisible(DECONSTRUCTION)
	ZO_ScrollList_RefreshVisible(LIST_DIALOG)
end

local function GetItemSaverControl(parent)
	return parent:GetNamedChild("ItemSaver")
end

--converts unsigned itemId to signed
local function SignItemId(itemId)
	if(itemId and itemId > SIGNED_INT_MAX) then
		itemId = itemId - INT_MAX
	end
	return itemId
end

local function MyGetItemInstanceId(rowControl)
	--gotta do this in case deconstruction...
	local dataEntry = rowControl.dataEntry
	local bagId, slotIndex 

	--case to handle equiped items
	if(not dataEntry) then
		bagId = rowControl.bagId
		slotIndex = rowControl.itemIndex
	else
		bagId = dataEntry.data.bagId
		slotIndex = dataEntry.data.slotIndex
	end

	--case to handle list dialog, list dialog uses index instead of slotIndex and bag instead of badId...?
	if(dataEntry and not bagId and not slotIndex) then 
		bagId = rowControl.dataEntry.data.bag
		slotIndex = rowControl.dataEntry.data.index 
	end

	local itemId = GetItemInstanceId(bagId, slotIndex)
	return SignItemId(itemId)
end

local function FilterSavedItems(self, bagId, slotIndex, ...)
	if(markedItems[SignItemId(GetItemInstanceId(bagId, slotIndex))]) then
		return true
	end
end

local function FilterSavedItemsForShop(slot)
	if(markedItems[MyGetItemInstanceId(slot)]) then
		return false
	end
	return true
end

local function CreateMarkerControl(parent)
	local control = parent:GetNamedChild("ItemSaver")

	if(not control) then
		control = WINDOW_MANAGER:CreateControl(parent:GetName() .. "ItemSaver", parent, CT_TEXTURE)
		control:SetDimensions(32, 32)
		control:SetTexture(MARKER_TEXTURE)
	end

	control:SetColor(1, 0, 0, 1)
	if(markedItems[MyGetItemInstanceId(parent)]) then
		control:SetHidden(false)
	else
		control:SetHidden(true)
	end

	if(parent:GetWidth() - parent:GetHeight() < 5) then
		if(parent:GetNamedChild("SellPrice")) then
			parent:GetNamedChild("SellPrice"):SetHidden(true)
		end
		control:SetDrawTier(DT_HIGH)
		control:ClearAnchors()
		control:SetAnchor(CENTER, parent, BOTTOMLEFT, 12, -12)
	else
		control:ClearAnchors()
		control:SetAnchor(LEFT, parent, LEFT)
	end

	return control
end

local function CreateMarkerControlForEquipment(parent)
	local control = CreateMarkerControl(parent)
	control:ClearAnchors()
	control:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT)
	control:SetDimensions(20, 20)
	control:SetDrawTier(1)
end

local function MarkMe(rowControl)
	markedItems[MyGetItemInstanceId(rowControl)] = true
	RefreshAll()
	GetItemSaverControl(rowControl):SetHidden(false)
end

local function UnmarkMe(rowControl)
	local itemId = MyGetItemInstanceId(rowControl)
	if(markedItems[itemId]) then
		markedItems[itemId] = nil
	end
	RefreshAll()
	GetItemSaverControl(rowControl):SetHidden(true)
end

local function AddMark(rowControl)
	if(not markedItems[MyGetItemInstanceId(rowControl)]) then 
		AddMenuItem("Save item", function() MarkMe(rowControl) end, MENU_ADD_OPTION_LABEL)
	else
		AddMenuItem("Unsave item", function() UnmarkMe(rowControl) end, MENU_ADD_OPTION_LABEL)
	end
	ShowMenu(self)
end

local function AddMarkSoon(rowControl)
	if(rowControl:GetOwningWindow() == ZO_TradingHouse) then return end

	if(rowControl:GetParent() ~= ZO_Character) then
		zo_callLater(function() AddMark(rowControl:GetParent()) end, 50)
	else
		zo_callLater(function() AddMark(rowControl) end, 50)
	end
end

local function ToggleFilter( toggle )
	if(toggle) then
		d("ItemSaver filters turned OFF")
		libFilters:UnregisterFilter("ItemSaver_ShopFilter")
		libFilters:UnregisterFilter("ItemSaver_DeconstructionFilter")
	else
		d("ItemSaver filters turned ON")
		libFilters:RegisterFilter("ItemSaver_ShopFilter", LAF_STORE, FilterSavedItemsForShop)
		libFilters:RegisterFilter("ItemSaver_DeconstructionFilter", LAF_DECONSTRUCTION, FilterSavedItems)
	end
end

local function ItemSaver_Loaded(eventCode, addOnName)
	if(addOnName ~= "ItemSaver") then
        return
    end

    local defaults = {
    	markedItems = {},
    	isFilterOn = false
	}

	settings = ZO_SavedVars:NewAccountWide("ItemSaver_Settings", 1, nil, defaults)
	markedItems = settings.markedItems

    --Wobin, if you're reading this: <3
    for _,v in pairs(PLAYER_INVENTORY.inventories) do
		local listView = v.listView
		if listView and listView.dataTypes and listView.dataTypes[1] then
			local hookedFunctions = listView.dataTypes[1].setupCallback				
			
			listView.dataTypes[1].setupCallback = 
				function(rowControl, slot)						
					hookedFunctions(rowControl, slot)
					CreateMarkerControl(rowControl)
				end				
		end
	end

	ZO_PreHook("ZO_InventorySlot_ShowContextMenu", AddMarkSoon)
	ZO_PreHook("PlayOnEquippedAnimation", CreateMarkerControlForEquipment)

	for i=1, ZO_Character:GetNumChildren() do
		if(string.find(ZO_Character:GetChild(i):GetName(), "ZO_CharacterEquipmentSlots")) then
			CreateMarkerControlForEquipment(ZO_Character:GetChild(i))
		end
	end


	--deconstruction hook
	local hookedFunctions = DECONSTRUCTION.dataTypes[1].setupCallback
	DECONSTRUCTION.dataTypes[1].setupCallback = function(rowControl, slot)
			hookedFunctions(rowControl, slot)
			CreateMarkerControl(rowControl)
		end

	--research list hook
	local hookedFunctions = LIST_DIALOG.dataTypes[1].setupCallback
	LIST_DIALOG.dataTypes[1].setupCallback = function(rowControl, slot)
			hookedFunctions(rowControl, slot)
			CreateMarkerControl(rowControl)

			local data = rowControl.dataEntry.data
			local isSoulGem = false
			if(data and GetSoulGemItemInfo(data.bag, data.index) > 0) then
				isSoulGem = true
			end
			if(settings.isFilterOn and not isSoulGem and markedItems[MyGetItemInstanceId(rowControl)]) then
				rowControl:SetMouseEnabled(false)
				rowControl:GetNamedChild("Name"):SetColor(.75, 0, 0, 1)
			else
				rowControl:SetMouseEnabled(true)
			end
		end

	ZO_ScrollList_RefreshVisible(BACKPACK)
	ZO_ScrollList_RefreshVisible(BANK)
	ZO_ScrollList_RefreshVisible(GUILD_BANK)
	ToggleFilter(settings.isFilterOn)

	SLASH_COMMANDS["/itemsaver"] = function(arg)
			if(arg == "filters") then
				settings.isFilterOn = not settings.isFilterOn
				ToggleFilter(settings.isFilterOn)
			end
		end
end

local function ItemSaver_Initialized()
	EVENT_MANAGER:RegisterForEvent("ItemSaverLoaded", EVENT_ADD_ON_LOADED, ItemSaver_Loaded)
end

ItemSaver_Initialized()