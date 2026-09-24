-- ColorCraft: color each recipe name in the professions window by its
-- skill-up chance, like the classic trade skill window did.
--   orange  = always a skill-up        (Optimal)
--   yellow  = usually a skill-up        (Medium)
--   green   = sometimes a skill-up      (Easy)
--   gray    = no skill-up anymore      (Trivial)
-- Blizzard's recipe row sets its name color in Init (when the row is built)
-- and OnLeave (after the mouse-over highlight). ColorCraft repaints the name
-- right after both, through secure hooks, so nothing of Blizzard's is replaced.
-- The row's selected and hover highlights (gold in Blizzard's art) are tinted
-- the same color, so the whole row reads orange / yellow / green / gray.
-- No settings, no saved variables.

local COLORS = {
	[0] = DIFFICULT_DIFFICULTY_COLOR,  -- Optimal
	[1] = FAIR_DIFFICULTY_COLOR,       -- Medium
	[2] = EASY_DIFFICULTY_COLOR,       -- Easy
	[3] = TRIVIAL_DIFFICULTY_COLOR or GRAY_FONT_COLOR,  -- Trivial
}
if Enum and Enum.TradeskillRelativeDifficulty then
	local E = Enum.TradeskillRelativeDifficulty
	COLORS = {
		[E.Optimal] = DIFFICULT_DIFFICULTY_COLOR,
		[E.Medium] = FAIR_DIFFICULTY_COLOR,
		[E.Easy] = EASY_DIFFICULTY_COLOR,
		[E.Trivial] = TRIVIAL_DIFFICULTY_COLOR or GRAY_FONT_COLOR,
	}
end

-- Guild, NPC and runeforging lists have no skill-ups: Blizzard shows no
-- arrows there, and ColorCraft leaves their names alone too.
local function listHasSkillUps()
	local T = C_TradeSkillUI
	if not T then return false end
	if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return false end
	if T.IsNPCCrafting and T.IsNPCCrafting() then return false end
	if T.IsRuneforging and T.IsRuneforging() then return false end
	return true
end

-- The highlights: Blizzard's gold art turned gray, then colored, so the tint is
-- clean instead of gold-times-color. Rows are reused, so a row without a color
-- gets Blizzard's gold back.
local function tintHighlights(row, r, g, b)
	for _, key in ipairs({ "SelectedOverlay", "HighlightOverlay" }) do
		local tex = row[key]
		if tex then
			if r then
				tex:SetDesaturated(true)
				tex:SetVertexColor(r, g, b)
			else
				tex:SetDesaturated(false)
				tex:SetVertexColor(1, 1, 1)
			end
		end
	end
end

local function paint(row, node)
	if not (row and row.Label) then return end
	node = node or (row.GetElementData and row:GetElementData())
	local data = node and (node.GetData and node:GetData() or node.data)
	local info = data and data.recipeInfo
	if info and Professions and Professions.GetHighestLearnedRecipe then
		info = Professions.GetHighestLearnedRecipe(info) or info
	end
	if not info or not info.learned or info.disabled or not listHasSkillUps() then
		tintHighlights(row)   -- no color for this row: Blizzard's gold
		return
	end
	-- a learned recipe that can no longer raise the skill is gray, as in classic
	local color = info.canSkillUp and COLORS[info.relativeDifficulty] or COLORS[3]
	if not color then tintHighlights(row) return end
	local r, g, b = color:GetRGB()
	tintHighlights(row, r, g, b)
	if row.IsMouseOver and row:IsMouseOver() then return end   -- keep Blizzard's white hover text
	row.Label:SetVertexColor(r, g, b)
	if row.Count then row.Count:SetVertexColor(r, g, b) end
end

local hooked
local function hook()
	if hooked then return end
	local mixin = ProfessionsRecipeListRecipeMixin
	if not mixin then return end
	hooked = true
	-- Rows built from now on carry the hooked methods (a mixin is copied into
	-- each frame when the frame is created).
	hooksecurefunc(mixin, "Init", function(row, node) paint(row, node) end)
	hooksecurefunc(mixin, "OnLeave", function(row) paint(row) end)
end

-- Rows that already existed before the hook (another addon opened the window
-- first) are hooked one by one, and repainted, the first time they are seen.
local seen = setmetatable({}, { __mode = "k" })
local function catchUp()
	local list = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList
	local box = list and list.ScrollBox
	if not (box and box.ForEachFrame) then return end
	box:ForEachFrame(function(row)
		if row.Label and not seen[row] and row.Init ~= ProfessionsRecipeListRecipeMixin.Init then
			seen[row] = true
			hooksecurefunc(row, "Init", function(r, node) paint(r, node) end)
			hooksecurefunc(row, "OnLeave", function(r) paint(r) end)
		end
		paint(row)
	end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == "Blizzard_ProfessionsTemplates" or ProfessionsRecipeListRecipeMixin then hook() end
	else
		hook()
		C_Timer.After(0, catchUp)
	end
end)
hook()   -- already loaded (another addon forced it)
