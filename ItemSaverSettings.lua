
ItemSaverSettings = ZO_Object:Subclass()

local LAM = LibStub("LibAddonMenu-1.0")
local settings = nil


local MARKER_TEXTURES = {
	["Star"] = {
		texturePath = [[/esoui/art/campaign/overview_indexicon_bonus_disabled.dds]],
		textureSize = 32
	},
	["Padlock"] =  {
		texturePath = [[/esoui/art/campaign/campaignbrowser_fullpop.dds]],
		textureSize = 32
	},
	["Flag"] = {
		texturePath = [[/esoui/art/ava/tabicon_bg_score_disabled.dds]],
		textureSize = 32
	},
	["BoxStar"] = {
		texturePath = [[/esoui/art/guild/guild_rankicon_leader_large.dds]],
		textureSize = 32
	},
	["Medic"] = {
		texturePath = [[/esoui/art/miscellaneous/announce_icon_levelup.dds]],
		textureSize = 32
	},
	["Timer"] = {
		texturePath = [[/esoui/art/mounts/timer_icon.dds]],
		textureSize = 32
	},
}

local TEXTURE_OPTIONS = { "Star", "Padlock", "Flag", "BoxStar", "Medic", "Timer" }

-----------------------------
--UTIL FUNCTIONS
-----------------------------

local function RGBAToHex( r, g, b, a )
	r = r <= 1 and r >= 0 and r or 0
	g = g <= 1 and g >= 0 and g or 0
	b = b <= 1 and b >= 0 and b or 0
	return string.format("%02x%02x%02x%02x", r * 255, g * 255, b * 255, a * 255)
end

local function HexToRGBA( hex )
    local rhex, ghex, bhex, ahex = string.sub(hex, 1, 2), string.sub(hex, 3, 4), string.sub(hex, 5, 6), string.sub(hex, 7, 8)
    return tonumber(rhex, 16)/255, tonumber(ghex, 16)/255, tonumber(bhex, 16)/255
end

------------------------------
--OBJECT FUNCTIONS
------------------------------

function ItemSaverSettings:New()
	local obj = ZO_Object.New(self)
	obj:Initialize()
	return obj
end

function ItemSaverSettings:Initialize()
	local defaults = {
		textureName = "Star",
		textureColor = RGBAToHex(1, 1, 0, 1),

		isFilterOn = false,
		filterShop = true,
		filterDeconstruction = true,
		filterResearch = true,

		--non-settings vars
		markedItems = {}
	}

	settings = ZO_SavedVars:NewAccountWide("ItemSaver_Settings", 1, nil, defaults)

    self:CreateOptionsMenu()
end

function ItemSaverSettings:ToggleFilter()
	settings.isFilterOn = not settings.isFilterOn
end

function ItemSaverSettings:IsFilterOn()
	return settings.isFilterOn
end

function ItemSaverSettings:IsFilterShop()
	return settings.filterShop
end

function ItemSaverSettings:IsFilterDeconstruction()
	return settings.filterDeconstruction
end

function ItemSaverSettings:IsFilterResearch()
	return settings.filterResearch
end

function ItemSaverSettings:GetTexturePath()
	return MARKER_TEXTURES[settings.textureName].texturePath
end

function ItemSaverSettings:GetTextureSize()
	return MARKER_TEXTURES[settings.textureName].textureSize
end

function ItemSaverSettings:GetTextureColor()
	return HexToRGBA(settings.textureColor)
end

function ItemSaverSettings:GetMarkedItems()
	return settings.markedItems
end

function ItemSaverSettings:CreateOptionsMenu()
	local str = ItemSaver_Strings[self:GetLanguage()]

	local panel = LAM:CreateControlPanel("ItemSaverSettingsPanel", "Item Saver")
	LAM:AddHeader(panel, "ItemSaver_Header", "General Options")

	local icon = WINDOW_MANAGER:CreateControl("ItemSaver_Icon", ZO_OptionsWindowSettingsScrollChild, CT_TEXTURE)
	icon:SetColor(HexToRGBA(settings.textureColor))
	icon:SetHandler("OnShow", function()
			self:SetTexture(MARKER_TEXTURES[settings.textureName].texturePath)
			icon:SetDimensions(MARKER_TEXTURES[settings.textureName].textureSize, MARKER_TEXTURES[settings.textureName].textureSize)
		end)
	local dropdown = LAM:AddDropdown(panel, "ItemSaver_Icon_Dropdown", str.ICON_LABEL, str.ICON_TOOLTIP, 
					TEXTURE_OPTIONS,
					function() return settings.textureName end,	--getFunc
					function(value)							--setFunc
						settings.textureName = value
						icon:SetTexture(MARKER_TEXTURES[value].texturePath)
						icon:SetDimensions(MARKER_TEXTURES[settings.textureName].textureSize, MARKER_TEXTURES[settings.textureName].textureSize)
					end)
	icon:SetParent(dropdown)
	icon:SetTexture(MARKER_TEXTURES[settings.textureName].texturePath)
	icon:SetDimensions(MARKER_TEXTURES[settings.textureName].textureSize, MARKER_TEXTURES[settings.textureName].textureSize)
	icon:SetAnchor(RIGHT, dropdown:GetNamedChild("Dropdown"), LEFT, -12, 0)

	LAM:AddColorPicker(panel, "ItemSaver_Icon_Color_Picker", str.TEXTURE_COLOR_LABEL, str.TEXTURE_COLOR_TOOLTIP,
					function()
						local r, g, b, a = HexToRGBA(settings.textureColor)
						return r, g, b
					end,
					function(r, g, b)
						settings.textureColor = RGBAToHex(r, g, b, 1)
						icon:SetColor(r, g, b, 1)
					end)

	LAM:AddHeader(panel, "ItemSaver_Filters_Header", "Filter options")
	LAM:AddCheckbox(panel, "ItemSaver_Filters_Toggle", str.FILTERS_TOGGLE_LABEL, str.FILTERS_TOGGLE_TOOLTIP,
					function() return settings.isFilterOn end,
					function(value)
						settings.isFilterOn = value
						ItemSaver_ToggleFilters(value, true)
					end)

	LAM:AddCheckbox(panel, "ItemSaver_Filter_Shop", str.FILTERS_SHOP_LABEL, str.FILTERS_SHOP_TOOLTIP,
					function() return settings.filterShop end,
					function(value)
						settings.filterShop = value
						ItemSaver_ToggleShopFilter(value)
					end)
	LAM:AddCheckbox(panel, "ItemSaver_Filter_Deconstruction", str.FILTERS_DECONSCRUCTION_LABEL, str.FILTERS_DECONSCRUCTION_TOOLTIP,
					function() return settings.filterDeconstruction end,
					function(value)
						settings.filterDeconstruction = value
						ItemSaver_ToggleDeconstructionFilter(value)
					end)
	LAM:AddCheckbox(panel, "ItemSaver_Filter_Research", str.FILTERS_RESEARCH_LABEL, str.FILTERS_RESEARCH_TOOLTIP,
					function() return settings.filterResearch end,
					function(value)
						settings.filterResearch = value
					end)
end

function ItemSaverSettings:GetLanguage()
	local lang = GetCVar("language.2")

	--check for supported languages
	if(lang == "en") then return lang end

	--return english if not supported
	return "en"
end