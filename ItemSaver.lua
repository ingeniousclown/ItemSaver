------------------------------------------------------------------
--ItemSaver.lua
--Author: ingeniousclown, 
--v1.0.0
--[[
Allows you to mark an item so you can know that you meant to save
it for some reason.
]]
------------------------------------------------------------------

local libFilters = LibStub("libFilters")

local BACKPACK = ZO_PlayerInventoryBackpack
local BANK = ZO_PlayerBankBackpack
local GUILD_BANK = ZO_GuildBankBackpack
local DECONSTRUCTION = ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack
local LIST_DIALOG = ZO_ListDialog1List

local MARKER_TEXTURE = [[/esoui/art/campaign/overview_indexicon_bonus_disabled.dds]]
local MARKER_TEXTURE_ALT = [[/esoui/art/campaign/campaignbrowser_fullpop.dds]]

local ISSettings = nil
local markedItems = nil

local SIGNED_INT_MAX = 2^32 / 2 - 1
local INT_MAX = 2^32


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

local function FilterSavedItems(bagId, slotIndex, ...)
	if(markedItems[SignItemId(GetItemInstanceId(bagId, slotIndex))]) then
		return false
	end
	return true
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
	end

	control:SetTexture(ISSettings:GetTexturePath())
	control:SetColor(ISSettings:GetTextureColor())
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

local function RefreshEquipmentControls()
	for i=1, ZO_Character:GetNumChildren() do
		if(string.find(ZO_Character:GetChild(i):GetName(), "ZO_CharacterEquipmentSlots")) then
			CreateMarkerControlForEquipment(ZO_Character:GetChild(i))
		end
	end
end

local function RefreshAll()
	ZO_ScrollList_RefreshVisible(BACKPACK)
	ZO_ScrollList_RefreshVisible(BANK)
	ZO_ScrollList_RefreshVisible(GUILD_BANK)
	ZO_ScrollList_RefreshVisible(DECONSTRUCTION)
	ZO_ScrollList_RefreshVisible(LIST_DIALOG)
	RefreshEquipmentControls()
end

local function MarkMe(rowControl)
	itemId = MyGetItemInstanceId(rowControl)

	if(not itemId) then return end

	markedItems[MyGetItemInstanceId(rowControl)] = true
	RefreshAll()
	if(GetItemSaverControl(rowControl)) then
		GetItemSaverControl(rowControl):SetHidden(false)
	end
end

local function UnmarkMe(rowControl)
	local itemId = MyGetItemInstanceId(rowControl)

	if(not itemId) then return end

	if(markedItems[itemId]) then
		markedItems[itemId] = nil
	end
	RefreshAll()
	if(GetItemSaverControl(rowControl)) then
		GetItemSaverControl(rowControl):SetHidden(true)
	end
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
	if(BACKPACK:IsHidden() and BANK:IsHidden() and GUILD_BANK:IsHidden() and DECONSTRUCTION:IsHidden()) then return end

	if(rowControl:GetParent() ~= ZO_Character) then
		zo_callLater(function() AddMark(rowControl:GetParent()) end, 50)
	else
		zo_callLater(function() AddMark(rowControl) end, 50)
	end
end

local function ToggleMark(rowControl)
	if(not markedItems[MyGetItemInstanceId(rowControl)]) then 
		MarkMe(rowControl)
	else
		UnmarkMe(rowControl)
	end
end

function ItemSaver_ToggleSave()
	local mouseOverControl = WINDOW_MANAGER:GetMouseOverControl()
	--if is a backpack row or child of one
	if(mouseOverControl:GetName():find("^ZO_%a+Backpack%dRow%d%d*")) then
		--check if the control IS the row
		if(mouseOverControl:GetName():find("^ZO_%a+Backpack%dRow%d%d*$")) then
			ToggleMark(mouseOverControl)
		else
			mouseOverControl = mouseOverControl:GetParent()
			--this SHOULD be the row control - if it isn't then idk how to handle it without going iterating through parents
			--that shouldn't happen unless someone is doing something weird
			if(mouseOverControl:GetName():find("^ZO_%a+Backpack%dRow%d%d*$")) then
				ToggleMark(mouseOverControl)
			end
		end
	elseif(mouseOverControl:GetName():find("^ZO_CharacterEquipmentSlots.+$")) then
		ToggleMark(mouseOverControl)
	end
end

function ItemSaver_ToggleShopFilter( toggle )
	if(toggle) then
		if(ISSettings:IsFilterShop() and not libFilters:IsFilterRegistered("ItemSaver_ShopFilter")) then
			libFilters:RegisterFilter("ItemSaver_ShopFilter", LAF_STORE, FilterSavedItemsForShop)
		end
	else
		libFilters:UnregisterFilter("ItemSaver_ShopFilter")
	end
end

function ItemSaver_ToggleDeconstructionFilter( toggle )
	if(toggle) then
		if(ISSettings:IsFilterDeconstruction() and not libFilters:IsFilterRegistered("ItemSaver_DeconstructionFilter")) then
			libFilters:RegisterFilter("ItemSaver_DeconstructionFilter", LAF_DECONSTRUCTION, FilterSavedItems)
		end
	else
		libFilters:UnregisterFilter("ItemSaver_DeconstructionFilter")
	end
end

function ItemSaver_ToggleFilters( toggle, quiet )
	if(not quiet) then
		if(not toggle) then
			d("ItemSaver filters turned OFF")
		else
			d("ItemSaver filters turned ON")
		end
	end
	ItemSaver_ToggleShopFilter(toggle)
	ItemSaver_ToggleDeconstructionFilter(toggle)
	ZO_ScrollList_RefreshVisible(LIST_DIALOG)
end

local function ItemSaver_Loaded(eventCode, addOnName)
	if(addOnName ~= "ItemSaver") then
        return
    end

    local defaults = {
    	markedItems = {},
    	isFilterOn = false,
    	isAlternate = false
	}

	ISSettings = ItemSaverSettings:New()
	markedItems = ISSettings:GetMarkedItems()

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

	libFilters:InitializeLibFilters()

	ZO_PreHook("ZO_InventorySlot_ShowContextMenu", AddMarkSoon)
	ZO_PreHook("PlayOnEquippedAnimation", CreateMarkerControlForEquipment)

	RefreshEquipmentControls()

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
			if(ISSettings:IsFilterOn() and ISSettings:IsFilterResearch() and not isSoulGem and markedItems[MyGetItemInstanceId(rowControl)]) then
				rowControl:SetMouseEnabled(false)
				rowControl:GetNamedChild("Name"):SetColor(.75, 0, 0, 1)
			else
				rowControl:SetMouseEnabled(true)
			end
		end

	ZO_ScrollList_RefreshVisible(BACKPACK)
	ZO_ScrollList_RefreshVisible(BANK)
	ZO_ScrollList_RefreshVisible(GUILD_BANK)
	ItemSaver_ToggleFilters(ISSettings:IsFilterOn())

	ZO_CreateStringId("SI_BINDING_NAME_ITEM_SAVER_TOGGLE", "Toggle Item Saved")

	SLASH_COMMANDS["/itemsaver"] = function(arg)
			if(arg == "filters") then
				ISSettings:ToggleFilter()
				ItemSaver_ToggleFilters(ISSettings:IsFilterOn())
			end
		end
end

local function ItemSaver_Initialized()
	EVENT_MANAGER:RegisterForEvent("ItemSaverLoaded", EVENT_ADD_ON_LOADED, ItemSaver_Loaded)
end

ItemSaver_Initialized()