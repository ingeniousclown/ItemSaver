
ItemSaverSettings = ZO_Object:Subclass()

local LAM = LibStub("LibAddonMenu-2.0")
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
	
	local icon = WINDOW_MANAGER:CreateControl("ItemSaver_Icon", ZO_OptionsWindowSettingsScrollChild, CT_TEXTURE)
	icon:SetColor(HexToRGBA(settings.textureColor))
	icon:SetHandler("OnShow", function()
			self:SetTexture(MARKER_TEXTURES[settings.textureName].texturePath)
			icon:SetDimensions(MARKER_TEXTURES[settings.textureName].textureSize, MARKER_TEXTURES[settings.textureName].textureSize)
		end)

	local panel = {
		type = "panel",
		name = "Item Saver",
		author = "ingeniousclown",
		version = "1.0.2",
		slashCommand = "/itemsaversettings",
		registerForRefresh = true
	}

	local optionsData = {
		[1] = {
			type = "header",
			name = "General Options"
		},

		[2] = {
			type = "dropdown",
			name = str.ICON_LABEL,
			tooltip = str.ICON_TOOLTIP,
			choices = TEXTURE_OPTIONS,
			getFunc = function() return settings.textureName end,
			setFunc = function(value)
						settings.textureName = value
						icon:SetTexture(MARKER_TEXTURES[value].texturePath)
						icon:SetDimensions(MARKER_TEXTURES[settings.textureName].textureSize, MARKER_TEXTURES[settings.textureName].textureSize)
					end,
			reference = "ItemSaver_Icon_Dropdown"
		},

		[3] = {
			type = "colorpicker",
			name = str.TEXTURE_COLOR_LABEL,
			tooltip = str.TEXTURE_COLOR_TOOLTIP,
			getFunc = function()
						local r, g, b, a = HexToRGBA(settings.textureColor)
						return r, g, b
					end,
			setFunc = function(r, g, b)
						settings.textureColor = RGBAToHex(r, g, b, 1)
						icon:SetColor(r, g, b, 1)
					end
		},

		[4] = {
			type = "header",
			name = "Filter options"
		},

		[5] = {
			type = "checkbox",
			name = str.FILTERS_TOGGLE_LABEL,
			tooltip = str.FILTERS_TOGGLE_TOOLTIP,
			getFunc = function() return settings.isFilterOn end,
			setFunc = function(value)
						settings.isFilterOn = value
						ItemSaver_ToggleFilters(value, true)
					end
		},

		[6] = {
			type = "checkbox",
			name = str.FILTERS_SHOP_LABEL,
			tooltip = str.FILTERS_SHOP_TOOLTIP,
			getFunc = function() return settings.filterShop end,
			setFunc = function(value)
						settings.filterShop = value
						ItemSaver_ToggleShopFilter(value)
					end,
			disabled = function() return not settings.isFilterOn end
		},

		[7] = {
			type = "checkbox",
			name = str.FILTERS_DECONSCRUCTION_LABEL,
			tooltip = str.FILTERS_DECONSCRUCTION_TOOLTIP,
			getFunc = function() return settings.filterDeconstruction end,
			setFunc = function(value)
						settings.filterDeconstruction = value
						ItemSaver_ToggleDeconstructionFilter(value)
					end,
			disabled = function() return not settings.isFilterOn end
		},

		[8] = {
			type = "checkbox",
			name = str.FILTERS_RESEARCH_LABEL,
			tooltip = str.FILTERS_RESEARCH_TOOLTIP,
			getFunc = function() return settings.filterResearch end,
			setFunc = function(value)
						settings.filterResearch = value
					end,
			disabled = function() return not settings.isFilterOn end
		},
	}

	LAM:RegisterAddonPanel("ItemSaverSettingsPanel", panel)
	LAM:RegisterOptionControls("ItemSaverSettingsPanel", optionsData)

	CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated",
		function()
			icon:SetParent(ItemSaver_Icon_Dropdown)
			icon:SetTexture(MARKER_TEXTURES[settings.textureName].texturePath)
			icon:SetDimensions(MARKER_TEXTURES[settings.textureName].textureSize, MARKER_TEXTURES[settings.textureName].textureSize)
			icon:SetAnchor(CENTER, ItemSaver_Icon_Dropdown, CENTER, 36, 0)
		end)

end

function ItemSaverSettings:GetLanguage()
	local lang = GetCVar("language.2")

	--check for supported languages
	if(lang == "en") then return lang end

	--return english if not supported
	return "en"
end