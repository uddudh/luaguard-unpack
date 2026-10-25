local UserInputService = game:GetService('UserInputService')
local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService('TweenService')
local HttpService = game:GetService('HttpService')
local CoreGui = game:GetService('CoreGui')
local RunService = game:GetService('RunService')
local StatsService = game:GetService('Stats')
local TextService = game:GetService('TextService')
local MarketplaceService = game:GetService('MarketplaceService')
local ContentProvider = game:GetService('ContentProvider')
local Lighting = game:GetService('Lighting')
local TeleportService = game:GetService('TeleportService')

local fallbackEnv = {}
local getgenv = getgenv or function()
    return fallbackEnv
end

local isfolder = isfolder or function() return false end
local makefolder = makefolder or function() end
local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end

local copyclipboard = setclipboard or toclipboard or (syn and syn.write_clipboard)
local httpRequest = (syn and syn.request) or (http and http.request) or request

local genv = getgenv()
genv.UIElements = {}

local IsMobile = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or not UserInputService.MouseEnabled)

local detectedGameName = "Roblox Experience"
local detectedGameIcon = "rbxthumb://type=GameIcon&id=" .. tostring(game.PlaceId) .. "&w=150&h=150"
local gameNameListeners = {}

local function onGameNameResolved(name, icon)
    detectedGameName = name
    if icon then detectedGameIcon = icon end
    for _, fn in ipairs(gameNameListeners) do
        pcall(fn, detectedGameName, detectedGameIcon)
    end
end

task.spawn(function()
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if ok and type(info) == "table" and info.Name and #info.Name > 0 then
        local gIcon = (info.IconImageAssetId and info.IconImageAssetId > 0) and ("rbxassetid://" .. tostring(info.IconImageAssetId)) or detectedGameIcon
        onGameNameResolved(info.Name, gIcon)
        return
    end
    local okAlt, res = pcall(function()
        local url = "https://games.roblox.com/v1/games/multiget-place-details?placeIds=" .. tostring(game.PlaceId)
        local body = (httpRequest and httpRequest({Url = url, Method = "GET"}).Body) or game:HttpGet(url)
        return HttpService:JSONDecode(body)
    end)
    if okAlt and type(res) == "table" and res[1] and res[1].name then
        onGameNameResolved(res[1].name, detectedGameIcon)
        return
    end
    if RunService:IsStudio() then
        onGameNameResolved("Roblox Studio", detectedGameIcon)
        return
    end
    local okName, gName = pcall(function() return game.Name end)
    if okName and type(gName) == "string" and #gName > 0 and gName ~= "Game" then
        onGameNameResolved(gName, detectedGameIcon)
    end
end)

local discordMemberCountStr = ""
local discordOnlineCountStr = ""
local discordStatsListeners = {}
local discordFetched = false

local function extractDiscordCode(link)
    if type(link) ~= "string" or #link == 0 then return nil end
    local clean = link:gsub("https?://", ""):gsub("discord%.gg/", ""):gsub("discord%.com/invite/", ""):gsub("discordapp%.com/invite/", "")
    clean = clean:match("([^/?#]+)")
    return clean
end

local function fetchDiscordStats(link)
    local code = extractDiscordCode(link) or (getgenv and extractDiscordCode(getgenv().discord)) or "moondiety"
    task.spawn(function()
        local ok, res = pcall(function()
            local url = "https://discord.com/api/v10/invites/" .. code .. "?with_counts=true"
            local body = (httpRequest and httpRequest({Url = url, Method = "GET"}).Body) or game:HttpGet(url)
            return HttpService:JSONDecode(body)
        end)
        if ok and type(res) == "table" then
            local mCount = res.approximate_member_count
            local oCount = res.approximate_presence_count
            if mCount and oCount then
                discordMemberCountStr = (mCount >= 1000) and string.format("%.1fk Members", mCount / 1000) or (tostring(mCount) .. " Members")
                discordOnlineCountStr = (oCount >= 1000) and string.format("%.1fk Online", oCount / 1000) or (tostring(oCount) .. " Online")
                discordFetched = true
                for _, fn in ipairs(discordStatsListeners) do
                    pcall(fn, discordMemberCountStr, discordOnlineCountStr)
                end
            end
        end
    end)
end

fetchDiscordStats()

local Library = {
    IsMobile = IsMobile,
    connections = {},
    Flags = {},
    Objects = {},
    Keybinds = {},
    Enabled = true,
    slider_drag = false,
    core = nil,
    dragging = false,
    drag_position = nil,
    start_position = nil,
    hidden = false,
    Theme = "Dark",
    UIScale = 1,
    IslandEnabled = true,
    IslandStyle = "Show on Hover",
    IslandDraggable = true,
    WatermarkEnabled = true,
    KeybindListEnabled = false,
    ToggleBarEnabled = true,
    ToggleBarPlatform = "Both",
    ToggleBarStyle = "Floating Button",
    GameName = "Roblox",
    savedFlags = {},
    activeTaps = {},
}
genv.Moondiety = Library

local CONTAINER_SIZE = UDim2.new(0.44, 0, 0.44, 0)
local CONTAINER_SIZE_TOUCH = UDim2.new(0.92, 0, 0.78, 0)
local SHADOW_SIZE = UDim2.new(0.485, 0, 0.49, 0)
local SHADOW_SIZE_TOUCH = UDim2.new(0.93, 0, 0.82, 0)
local ELEMENT_HEIGHT = 40
local BOX_HEIGHT = 30
local WHITE = Color3.fromRGB(255, 255, 255)
local GRAY = Color3.fromRGB(180, 180, 180)
local MUTED = Color3.fromRGB(130, 130, 138)
local SUCCESS_COLOR = Color3.fromRGB(52, 211, 153)
local WARNING_COLOR = Color3.fromRGB(251, 191, 36)
local ERROR_COLOR = Color3.fromRGB(248, 113, 113)
local INFO_COLOR = Color3.fromRGB(96, 165, 250)

local function new(class, props, parent)
    local obj = Instance.new(class)
    for key, value in pairs(props) do
        obj[key] = value
    end
    if parent then
        obj.Parent = parent
    end
    return obj
end

local function corner(parent, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function pill(parent)
    return new("UICorner", {CornerRadius = UDim.new(1, 0)}, parent)
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or WHITE,
        Thickness = thickness or 1,
        Transparency = transparency or 0.8,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function font(weight)
    return Font.new("rbxasset://fonts/families/Montserrat.json", weight or Enum.FontWeight.SemiBold)
end

local function bind(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(Library.connections, connection)
    return connection
end

local function bindTap(gui, callback)
    if not gui then return end
    local last = 0
    local lastPos
    local function fire(pos)
        local now = tick()
        if now - last < 0.1 then return end
        last = now
        callback(pos or lastPos)
    end
    gui.Activated:Connect(function()
        fire(lastPos)
    end)
    gui.MouseButton1Click:Connect(function()
        fire(lastPos)
    end)
    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            lastPos = input.Position
            Library.activeTaps[input] = {pos = input.Position, fire = fire}
        end
    end)
end

local function hexToColor(hex, fallback)
    if type(hex) == "userdata" then return hex end
    if type(hex) ~= "string" then return fallback end
    hex = hex:gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
    end
    if #hex ~= 6 then return fallback end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not r or not g or not b then return fallback end
    return Color3.fromRGB(r, g, b)
end

local function colorToHex(c)
    local r = math.floor(c.R * 255 + 0.5)
    local g = math.floor(c.G * 255 + 0.5)
    local b = math.floor(c.B * 255 + 0.5)
    return string.format("#%02X%02X%02X", r, g, b)
end

local BaseColors = {
    Dark = Color3.fromRGB(27, 28, 33),
    DarkSecondColor = Color3.fromRGB(22, 23, 27),
    Sapphire = Color3.fromRGB(24, 36, 85),
    SapphireSecondColor = Color3.fromRGB(17, 26, 65),
    Amethyst = Color3.fromRGB(59, 44, 94),
    AmethystSecondColor = Color3.fromRGB(49, 34, 85),
    Emerald = Color3.fromRGB(20, 58, 42),
    EmeraldSecondColor = Color3.fromRGB(14, 42, 30),
    Ruby = Color3.fromRGB(70, 24, 32),
    RubySecondColor = Color3.fromRGB(50, 16, 22),
    Midnight = Color3.fromRGB(18, 22, 38),
    MidnightSecondColor = Color3.fromRGB(13, 16, 28),
}

local function buildTheme(p)
    return {
        main = p.base,
        tabcolor = p.base,
        tabselectedcolor = ColorSequence.new{
            ColorSequenceKeypoint.new(0, p.selA),
            ColorSequenceKeypoint.new(1, p.selB)
        },
        tabtextcolor = WHITE,
        uicontainer = p.container,
        uiline = p.line,
        shadowcolor = p.shadow,
        togglecoloron = p.on,
        togglecoloroff = p.second,
        togglecolor = p.base,
        buttoncolor = p.base,
        originalColor = p.base,
        checkboxcolor = p.base,
        checkboxturnon = ColorSequence.new{
            ColorSequenceKeypoint.new(0, p.chkA),
            ColorSequenceKeypoint.new(1, p.chkB)
        },
        checkboxturnoff = p.second,
        dropdowncolor = p.base,
        dropdownboxscolor = p.second,
        dropdownoptionscolor = p.second,
        multidropdowncolor = p.base,
        multidropdownboxcolor = p.second,
        multidropdownoptioncolor = p.second,
        sidedropdowncolor = p.base,
        sidedropdownboxcolor = p.second,
        sidedropdownoptionscolor = p.second,
        multisidedropdown = p.base,
        multisidedropdownBox = p.second,
        multisidedropdownOptions = p.second,
        slider = p.base,
        trackcolor = p.track,
        sliderfill = p.fill,
        knob = p.knob,
        inputButton = p.base,
        InputBox = p.second,
        Keybind = p.base,
        KeybindBox = Color3.fromRGB(24, 25, 30),
        blockedoverlay = p.overlay,
        blockedtext = p.btext,
        accent = p.accent or p.on,
    }
end

local Themes = {
    Eclipse = buildTheme({
        base = BaseColors.Dark, second = BaseColors.DarkSecondColor,
        container = Color3.fromRGB(20, 21, 26), line = Color3.fromRGB(34, 35, 42),
        shadow = Color3.fromRGB(0, 0, 0),
        selA = Color3.fromRGB(90, 90, 100), selB = Color3.fromRGB(55, 55, 62),
        on = Color3.fromRGB(130, 132, 145),
        chkA = Color3.fromRGB(90, 90, 100), chkB = Color3.fromRGB(140, 140, 150),
        track = Color3.fromRGB(40, 40, 40), fill = Color3.fromRGB(130, 132, 145),
        knob = Color3.fromRGB(160, 160, 170),
        overlay = Color3.fromRGB(0, 0, 0), btext = Color3.fromRGB(210, 210, 210),
        accent = Color3.fromRGB(130, 132, 145),
    }),
    Celestial = buildTheme({
        base = BaseColors.Sapphire, second = BaseColors.SapphireSecondColor,
        container = Color3.fromRGB(12, 20, 55), line = Color3.fromRGB(24, 38, 78),
        shadow = Color3.fromRGB(59, 130, 246),
        selA = Color3.fromRGB(58, 85, 175), selB = Color3.fromRGB(35, 55, 125),
        on = Color3.fromRGB(59, 130, 246),
        chkA = Color3.fromRGB(37, 99, 235), chkB = Color3.fromRGB(59, 130, 246),
        track = BaseColors.SapphireSecondColor, fill = Color3.fromRGB(37, 99, 235),
        knob = Color3.fromRGB(96, 165, 250),
        overlay = Color3.fromRGB(6, 12, 32), btext = Color3.fromRGB(170, 200, 255),
        accent = Color3.fromRGB(59, 130, 246),
    }),
    Crimson = buildTheme({
        base = BaseColors.Ruby, second = BaseColors.RubySecondColor,
        container = Color3.fromRGB(38, 14, 18), line = Color3.fromRGB(68, 24, 32),
        shadow = Color3.fromRGB(239, 68, 68),
        selA = Color3.fromRGB(239, 68, 68), selB = Color3.fromRGB(185, 28, 28),
        on = Color3.fromRGB(239, 68, 68),
        chkA = Color3.fromRGB(239, 68, 68), chkB = Color3.fromRGB(248, 113, 113),
        track = Color3.fromRGB(50, 16, 22), fill = Color3.fromRGB(239, 68, 68),
        knob = Color3.fromRGB(252, 165, 165),
        overlay = Color3.fromRGB(24, 8, 12), btext = Color3.fromRGB(240, 180, 190),
        accent = Color3.fromRGB(239, 68, 68),
    }),
    Aurora = buildTheme({
        base = BaseColors.Emerald, second = BaseColors.EmeraldSecondColor,
        container = Color3.fromRGB(10, 32, 22), line = Color3.fromRGB(20, 60, 42),
        shadow = Color3.fromRGB(16, 185, 129),
        selA = Color3.fromRGB(16, 185, 129), selB = Color3.fromRGB(5, 150, 105),
        on = Color3.fromRGB(16, 185, 129),
        chkA = Color3.fromRGB(16, 185, 129), chkB = Color3.fromRGB(52, 211, 153),
        track = Color3.fromRGB(14, 42, 30), fill = Color3.fromRGB(16, 185, 129),
        knob = Color3.fromRGB(110, 231, 183),
        overlay = Color3.fromRGB(6, 20, 14), btext = Color3.fromRGB(180, 240, 210),
        accent = Color3.fromRGB(16, 185, 129),
    }),
    Nebula = buildTheme({
        base = BaseColors.Amethyst, second = BaseColors.AmethystSecondColor,
        container = Color3.fromRGB(36, 26, 60), line = Color3.fromRGB(60, 44, 98),
        shadow = Color3.fromRGB(147, 51, 234),
        selA = Color3.fromRGB(124, 58, 237), selB = Color3.fromRGB(88, 28, 135),
        on = Color3.fromRGB(147, 51, 234),
        chkA = Color3.fromRGB(124, 58, 237), chkB = Color3.fromRGB(168, 85, 247),
        track = Color3.fromRGB(44, 32, 72), fill = Color3.fromRGB(147, 51, 234),
        knob = Color3.fromRGB(192, 132, 252),
        overlay = Color3.fromRGB(20, 14, 35), btext = Color3.fromRGB(200, 180, 240),
        accent = Color3.fromRGB(147, 51, 234),
    }),
    Solar = buildTheme({
        base = Color3.fromRGB(45, 35, 10), second = Color3.fromRGB(30, 25, 8),
        container = Color3.fromRGB(28, 22, 8), line = Color3.fromRGB(52, 42, 16),
        shadow = Color3.fromRGB(234, 179, 8),
        selA = Color3.fromRGB(234, 179, 8), selB = Color3.fromRGB(161, 98, 7),
        on = Color3.fromRGB(234, 179, 8),
        chkA = Color3.fromRGB(202, 138, 4), chkB = Color3.fromRGB(250, 204, 21),
        track = Color3.fromRGB(36, 28, 10), fill = Color3.fromRGB(234, 179, 8),
        knob = Color3.fromRGB(253, 224, 71),
        overlay = Color3.fromRGB(20, 15, 6), btext = Color3.fromRGB(254, 240, 138),
        accent = Color3.fromRGB(234, 179, 8),
    }),
    Starlight = buildTheme({
        base = Color3.fromRGB(35, 35, 40), second = Color3.fromRGB(22, 22, 26),
        container = Color3.fromRGB(18, 18, 22), line = Color3.fromRGB(40, 40, 48),
        shadow = Color3.fromRGB(148, 163, 184),
        selA = Color3.fromRGB(148, 163, 184), selB = Color3.fromRGB(100, 116, 139),
        on = Color3.fromRGB(203, 213, 225),
        chkA = Color3.fromRGB(148, 163, 184), chkB = Color3.fromRGB(226, 232, 240),
        track = Color3.fromRGB(28, 28, 34), fill = Color3.fromRGB(148, 163, 184),
        knob = Color3.fromRGB(241, 245, 249),
        overlay = Color3.fromRGB(12, 12, 15), btext = Color3.fromRGB(241, 245, 249),
        accent = Color3.fromRGB(203, 213, 225),
    }),
    Cyberpunk = buildTheme({
        base = Color3.fromRGB(18, 30, 36), second = Color3.fromRGB(14, 22, 27),
        container = Color3.fromRGB(10, 22, 28), line = Color3.fromRGB(20, 48, 58),
        shadow = Color3.fromRGB(6, 182, 212),
        selA = Color3.fromRGB(6, 182, 212), selB = Color3.fromRGB(8, 145, 178),
        on = Color3.fromRGB(6, 182, 212),
        chkA = Color3.fromRGB(8, 145, 178), chkB = Color3.fromRGB(34, 211, 238),
        track = Color3.fromRGB(14, 32, 40), fill = Color3.fromRGB(6, 182, 212),
        knob = Color3.fromRGB(103, 232, 249),
        overlay = Color3.fromRGB(6, 16, 22), btext = Color3.fromRGB(207, 250, 254),
        accent = Color3.fromRGB(6, 182, 212),
    }),
    Abyss = buildTheme({
        base = BaseColors.Midnight, second = BaseColors.MidnightSecondColor,
        container = Color3.fromRGB(12, 15, 26), line = Color3.fromRGB(22, 28, 48),
        shadow = Color3.fromRGB(99, 102, 241),
        selA = Color3.fromRGB(99, 102, 241), selB = Color3.fromRGB(67, 56, 202),
        on = Color3.fromRGB(99, 102, 241),
        chkA = Color3.fromRGB(99, 102, 241), chkB = Color3.fromRGB(129, 140, 248),
        track = Color3.fromRGB(20, 24, 40), fill = Color3.fromRGB(99, 102, 241),
        knob = Color3.fromRGB(165, 180, 252),
        overlay = Color3.fromRGB(8, 10, 18), btext = Color3.fromRGB(190, 200, 245),
        accent = Color3.fromRGB(99, 102, 241),
    }),
}
Themes.Dark = Themes.Eclipse
Themes.Sapphire = Themes.Celestial
Themes.Ruby = Themes.Crimson
Themes.Emerald = Themes.Aurora
Themes.Amethyst = Themes.Nebula
Themes.Gold = Themes.Solar
Themes.Silver = Themes.Starlight
Themes.Midnight = Themes.Abyss

local ColorMap = {
    Button = "buttoncolor",
    slider = "slider",
    Box1 = "multidropdownboxcolor",
    Options1 = "multidropdownoptioncolor",
    dropdown1 = "multidropdowncolor",
    multisidedropdown = "multisidedropdown",
    multisidedropdownBox = "multisidedropdownBox",
    multisidedropdownOptions = "multisidedropdownOptions",
    SideDropdown = "sidedropdowncolor",
    SideBox = "sidedropdownboxcolor",
    SideOptions = "sidedropdownoptionscolor",
    Dropdown = "dropdowncolor",
    Box = "dropdownboxscolor",
    Options = "dropdownoptionscolor",
    trackcolor = "trackcolor",
    sliderfill = "sliderfill",
    knob = "knob",
    Input = "inputButton",
    InputBox = "InputBox",
    Keybind = "Keybind",
    KeybindBox = "KeybindBox",
    InlineKeybindBox = "KeybindBox",
    Checkbox = "checkboxturnoff",
    Toggle = "togglecolor",
    Checkbox1 = "checkboxcolor",
    Container = "uicontainer",
    StickyLeft = "uicontainer",
    StickyRight = "uicontainer",
    StickyMerge = "uicontainer",
    OpenButton = "uicontainer",
    Line = "uiline",
    UserCard = "tabcolor",
    Note = "tabcolor",
    Tab = "tabcolor",
    ColorPalette = "dropdownoptionscolor",
    BlockedOverlay = "blockedoverlay",
}

local function ApplyTheme(name, customAccent)
    local theme = Themes[name] or Themes.Eclipse or Themes.Dark
    for key, value in pairs(theme) do
        genv[key] = value
    end
    if customAccent then
        genv.accent = customAccent
        genv.togglecoloron = customAccent
        genv.sliderfill = customAccent
        genv.knob = customAccent:lerp(WHITE, 0.25)
        genv.tabselectedcolor = ColorSequence.new{
            ColorSequenceKeypoint.new(0, customAccent),
            ColorSequenceKeypoint.new(1, customAccent:lerp(Color3.fromRGB(20, 20, 25), 0.4))
        }
        genv.checkboxturnon = ColorSequence.new{
            ColorSequenceKeypoint.new(0, customAccent),
            ColorSequenceKeypoint.new(1, customAccent:lerp(WHITE, 0.3))
        }
    end
    Library.Theme = name
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, obj in pairs(genv.UIElements) do
        if obj and obj.Parent then
            local objName = obj.Name
            if objName == "Switch" then
                local isOn = obj:GetAttribute("State")
                if isOn == nil then isOn = false end
                TweenService:Create(obj, tweenInfo, {
                    BackgroundColor3 = isOn and genv.togglecoloron or genv.togglecoloroff
                }):Play()
            elseif obj:IsA("UIGradient") then
                if objName == "tabselectedcolor" and genv.tabselectedcolor then
                    obj.Color = genv.tabselectedcolor
                elseif objName == "checkboxturnon" and genv.checkboxturnon then
                    obj.Color = genv.checkboxturnon
                end
            elseif obj:IsA("ImageLabel") and objName == "Shadow" and genv.shadowcolor then
                obj.ImageColor3 = genv.shadowcolor
            elseif objName == "BlockedText" and genv.blockedtext then
                obj.TextColor3 = genv.blockedtext
            elseif objName == "LockIcon" and genv.blockedtext then
                obj.ImageColor3 = genv.blockedtext
            else
                local key = ColorMap[objName]
                if key and genv[key] and obj:IsA("GuiObject") then
                    obj.BackgroundColor3 = genv[key]
                end
                if obj:IsA("TextLabel") and obj:GetAttribute("ThemeText") and genv.tabtextcolor then
                    obj.TextColor3 = genv.tabtextcolor
                end
            end
        end
    end
    if Library.OnThemeChanged then
        Library.OnThemeChanged()
    end
    if Library.UpdateHUDThemes then
        Library.UpdateHUDThemes()
    end
end

ApplyTheme("Eclipse")

function Library:SetTheme(name)
    local isCustom = false
    if Library.Objects and Library.Objects.settings_custom_accent and Library.Objects.settings_custom_accent.GetValue then
        isCustom = Library.Objects.settings_custom_accent:GetValue() == true
    end
    local accent = isCustom and Library.CustomAccent or nil
    ApplyTheme(name, accent)
    pcall(writefile, "Moondiety/theme.txt", name)
end

function Library:SetCustomAccent(color)
    Library.CustomAccent = color
    ApplyTheme(Library.Theme, color)
    if color then
        pcall(writefile, "Moondiety/accent.txt", colorToHex(color))
    else
        if isfile("Moondiety/accent.txt") then pcall(delfile, "Moondiety/accent.txt") end
    end
end

function Library:RegisterObject(flag, object)
    if flag then
        self.Objects[flag] = object
    end
end

function Library:RegisterKeybind(flag, name, key, getState, onToggle, callback, isButton)
    self.Keybinds[flag] = {
        name = name or flag,
        key = key or "None",
        getState = getState or function() return nil end,
        toggle = onToggle,
        callback = callback or onToggle,
        isButton = isButton or false,
    }
    if self.UpdateKeybindList then
        self:UpdateKeybindList()
    end
end

function Library:UpdateKeybind(flag, key)
    if self.Keybinds[flag] then
        self.Keybinds[flag].key = key or "None"
        if self.UpdateKeybindList then
            self:UpdateKeybindList()
        end
    end
end

function Library:RefreshConfigs()
    local list = self:ListConfigs()
    if #list == 0 then list = {'None'} end
    local obj = self.Objects.savedconfigs
    if obj and obj.UpdateOptions then
        pcall(function() obj:UpdateOptions(list) end)
    end
    local autoObj = self.Objects.autoloadconfig
    if autoObj and autoObj.UpdateOptions then
        pcall(function() autoObj:UpdateOptions(list) end)
    end
end

function Library:SaveConfig(name)
    name = name or "default"
    local data = {}
    for flag, obj in pairs(Library.Objects) do
        if obj.GetValue then
            local ok, value = pcall(function() return obj:GetValue() end)
            if ok and value ~= nil then data[flag] = value end
        end
    end
    if not isfolder("Moondiety") then makefolder("Moondiety") end
    if not isfolder("Moondiety/Configs") then makefolder("Moondiety/Configs") end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if ok then writefile("Moondiety/Configs/" .. name .. ".json", encoded) end
    self:RefreshConfigs()
    Library:Notify({
        Title = "Config Saved",
        Content = "Saved config: " .. name,
        Duration = 3,
        Type = "Success",
    })
    return ok
end

function Library:LoadConfig(name)
    name = name or "default"
    local path = "Moondiety/Configs/" .. name .. ".json"
    if not isfile(path) then
        Library:Notify({
            Title = "Config Not Found",
            Content = "No config file for: " .. name,
            Duration = 3,
            Type = "Error",
        })
        return false
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false end
    for flag, value in pairs(data) do
        local obj = Library.Objects[flag]
        if obj then
            if obj.SetValue then pcall(function() obj:SetValue(value) end) end
            if obj.callback then pcall(function() obj.callback(value) end) end
        end
    end
    Library:Notify({
        Title = "Config Loaded",
        Content = "Loaded config: " .. name,
        Duration = 3,
        Type = "Success",
    })
    return true
end

function Library:ListConfigs()
    if not isfolder("Moondiety/Configs") then return {} end
    local list = {}
    for _, file in ipairs(listfiles("Moondiety/Configs")) do
        local fileName = file:match("([^/\\]+)%.json$")
        if fileName then table.insert(list, fileName) end
    end
    return list
end

function Library:DeleteConfig(name)
    name = name or "default"
    local path = "Moondiety/Configs/" .. name .. ".json"
    if isfile(path) then delfile(path) end
    self:RefreshConfigs()
    Library:Notify({
        Title = "Config Deleted",
        Content = "Deleted config: " .. name,
        Duration = 3,
        Type = "Info",
    })
end

function Library:SetAutoload(name)
    if not isfolder("Moondiety") then makefolder("Moondiety") end
    pcall(writefile, "Moondiety/autoload.txt", name or "")
end

function Library:GetAutoload()
    if not isfile("Moondiety/autoload.txt") then return "" end
    local ok, name = pcall(readfile, "Moondiety/autoload.txt")
    return ok and name or ""
end

function Library:LoadAutoload()
    local name = self:GetAutoload()
    if name ~= "" and name ~= "None" then
        self:LoadConfig(name)
    end
end

if not isfolder("Moondiety") then makefolder("Moondiety") end
if isfile("Moondiety/theme.txt") then
    local ok, themeName = pcall(readfile, "Moondiety/theme.txt")
    if ok and themeName and Themes[themeName] then
        Library.Theme = themeName
    end
end
if isfile("Moondiety/accent.txt") then
    local ok, hex = pcall(readfile, "Moondiety/accent.txt")
    if ok and hex and #hex >= 6 then
        Library.CustomAccent = hexToColor(hex, nil)
    end
end
ApplyTheme(Library.Theme, Library.CustomAccent)

function Library:disconnect()
    for index, connection in ipairs(Library.connections) do
        pcall(function() connection:Disconnect() end)
        Library.connections[index] = nil
    end
end

function Library:clear()
    Library.Keybinds = {}
    for _, object in ipairs(CoreGui:GetChildren()) do
        if object.Name == "Moondiety" or object.Name == "cac" then
            pcall(function() object:Destroy() end)
        end
    end
end

function Library:exist()
    if not Library.core then return end
    if not Library.core.Parent then return end
    return true
end

local savePending = false
local function doSave()
    if not Library.exist() then return end
    local data = {}
    if Library.savedFlags then
        for key, value in pairs(Library.savedFlags) do
            data[key] = value
        end
    end
    for flag, obj in pairs(Library.Objects) do
        if obj.GetValue then
            local ok, value = pcall(function() return obj:GetValue() end)
            if ok and value ~= nil then data[flag] = value end
        end
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return end
    if not isfolder("Moondiety/Data") then makefolder("Moondiety/Data") end
    writefile("Moondiety/Data/" .. game.GameId .. ".json", encoded)
end

function Library:save_flags()
    if savePending then return end
    savePending = true
    task.delay(0.25, function()
        savePending = false
        doSave()
    end)
end

function Library:load_flags()
    local path = "Moondiety/Data/" .. game.GameId .. ".json"
    if not isfile(path) then
        path = "cac hub/" .. game.GameId .. ".lua"
    end
    if not isfile(path) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return end
    Library.savedFlags = data
end

Library.load_flags()
Library.clear()

function Library:visible()
    if Library.setHidden then
        Library.setHidden(not Library.hidden)
    end
end

function Library:SetScale(scale)
    scale = math.clamp(tonumber(scale) or 1, 0.6, 1.4)
    Library.UIScale = scale
    if Library.ContainerScale and not Library.hidden then
        TweenService:Create(Library.ContainerScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = scale}):Play()
    end
end

function Library:SetIslandVisible(state)
    Library.IslandEnabled = state
    if Library.IslandFrame then
        Library.IslandFrame.Visible = state and Library.hidden
        if state and Library.hidden and Library.IslandStyle == "Always Show" and Library.SetIslandExpanded then
            Library.SetIslandExpanded(true)
        end
    end
end

function Library:SetIslandStyle(style)
    Library.IslandStyle = style
    if Library.IslandFrame and Library.IslandFrame.Visible and Library.SetIslandExpanded then
        if style == "Always Show" then
            Library.SetIslandExpanded(true)
        else
            Library.SetIslandExpanded(false)
        end
    end
end

function Library:SetIslandDraggable(enabled)
    Library.IslandDraggable = (enabled ~= false)
end

function Library:ResetIslandPosition()
    if Library.IslandFrame then
        TweenService:Create(Library.IslandFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 14),
            AnchorPoint = Vector2.new(0.5, 0)
        }):Play()
    end
end

function Library:ResetToggleBarPosition()
    if Library.ToggleBarBtn then
        TweenService:Create(Library.ToggleBarBtn, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 16, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5)
        }):Play()
    end
    if Library.NotchBarBtn then
        TweenService:Create(Library.NotchBarBtn, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 0),
            AnchorPoint = Vector2.new(0.5, 0)
        }):Play()
    end
end

function Library:SetWatermarkVisible(state)
    Library.WatermarkEnabled = state
    if Library.WatermarkFrame then
        Library.WatermarkFrame.Visible = state
    end
end

function Library:SetKeybindListVisible(state)
    Library.KeybindListEnabled = state
    if Library.KeybindListFrame then
        Library.KeybindListFrame.Visible = state
    end
end

function Library:UpdateToggleBarVisibility()
    local isMobileUser = (Library.IsMobile ~= nil) and Library.IsMobile or IsMobile
    local enabled = Library.ToggleBarEnabled and (Library.ToggleBarStyle ~= "Disabled")
    local platformMatches = false
    if Library.ToggleBarPlatform == "Both" then
        platformMatches = true
    elseif Library.ToggleBarPlatform == "Mobile Only" or Library.ToggleBarPlatform == "Mobile" then
        platformMatches = isMobileUser
    elseif Library.ToggleBarPlatform == "PC Only" then
        platformMatches = not isMobileUser
    end
    local active = enabled and platformMatches
    if Library.ToggleBarBtn then
        Library.ToggleBarBtn.Visible = active and (Library.ToggleBarStyle == "Floating Button")
    end
    if Library.NotchBarBtn then
        Library.NotchBarBtn.Visible = active and (Library.ToggleBarStyle == "Top Notch")
    end
end

function Library:SetToggleBarVisible(state)
    Library.ToggleBarEnabled = state
    Library:UpdateToggleBarVisibility()
end

function Library:SetToggleBarStyle(style)
    Library.ToggleBarStyle = style
    Library:UpdateToggleBarVisibility()
end

function Library:SetToggleBarPlatform(platform)
    Library.ToggleBarPlatform = platform
    Library:UpdateToggleBarVisibility()
end

function Library:FinishLoading()
end

function Library.new(selfOrOpts, options)
    Library:clear()
    Library:disconnect()
    local opts = (type(selfOrOpts) == "table" and selfOrOpts ~= Library) and selfOrOpts or (type(options) == "table" and options or {})
    options = opts
    local openInfoModal, closeInfoModal
    local screen = new("ScreenGui", {
        Name = "Moondiety",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    screen.Parent = CoreGui
    Library.core = screen
    genv.CloseUi = screen

    local isMobileUser = (Library.IsMobile ~= nil) and Library.IsMobile or IsMobile
    local fullSize = isMobileUser and CONTAINER_SIZE_TOUCH or CONTAINER_SIZE

    local MainHolder = new("Frame", {
        Name = "MainHolder",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = fullSize,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, screen)
    Library.MainHolder = MainHolder

    local mainScale = new("UIScale", {
        Scale = Library.UIScale or 1,
    }, MainHolder)
    Library.ContainerScale = mainScale

    local Shadow = new("ImageLabel", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, 48, 1, 48),
        ZIndex = 0,
        Image = "rbxassetid://17290899982",
        ImageColor3 = genv.shadowcolor or Color3.fromRGB(0, 0, 0),
    }, MainHolder)
    table.insert(genv.UIElements, Shadow)

    local Container = new("Frame", {
        Name = "Container",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = genv.uicontainer or Color3.fromRGB(19, 20, 24),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 2,
    }, MainHolder)
    table.insert(genv.UIElements, Container)
    corner(Container, 20)
    local containerStroke = stroke(Container, genv.uiline or Color3.fromRGB(34, 35, 42), 1, 0.5)

    local containerGlowLine = new("Frame", {
        Name = "ContainerGlowLine",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(0.7, 0, 0, 1),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, Container)
    new("UIGradient", {
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, genv.accent or Color3.fromRGB(168, 85, 247)),
            ColorSequenceKeypoint.new(0.5, WHITE),
            ColorSequenceKeypoint.new(1, genv.accent or Color3.fromRGB(168, 85, 247)),
        },
        Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        },
    }, containerGlowLine)

    Container.MouseEnter:Connect(function()
        if containerStroke then
            TweenService:Create(containerStroke, TweenInfo.new(0.28, Enum.EasingStyle.Quint), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0.2}):Play()
        end
        TweenService:Create(containerGlowLine, TweenInfo.new(0.28, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.2}):Play()
    end)
    Container.MouseLeave:Connect(function()
        if containerStroke then
            TweenService:Create(containerStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {Color = genv.uiline or Color3.fromRGB(34, 35, 42), Transparency = 0.5}):Play()
        end
        TweenService:Create(containerGlowLine, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.5}):Play()
    end)

    local Top = new("Frame", {
        Name = "Top",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0.08, 0),
        ZIndex = 99,
        Active = true,
    }, Container)

    local positionX = 0.0938254446
    local mainName = genv.hubname or options.Name or "Moondiety"
    local subName = genv.hubsubname or options.SubName

    local HeaderLogo = new("ImageLabel", {
        Name = "HeaderLogo",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0.0338, 0, subName and 0.85 or 0.8, 0),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "rbxassetid://133495621202705",
        Active = true,
        ZIndex = 99,
    }, Top)
    Library.HeaderLogo = HeaderLogo

    local logoWobbling = false
    local function playLogoWobble()
        if logoWobbling then return end
        logoWobbling = true
        task.spawn(function()
            local tw1 = TweenService:Create(HeaderLogo, TweenInfo.new(0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Rotation = -16, Size = UDim2.new(0, 30, 0, 30)})
            tw1:Play()
            tw1.Completed:Wait()
            local tw2 = TweenService:Create(HeaderLogo, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Rotation = 14, Size = UDim2.new(0, 28, 0, 28)})
            tw2:Play()
            tw2.Completed:Wait()
            local tw3 = TweenService:Create(HeaderLogo, TweenInfo.new(0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Rotation = -8, Size = UDim2.new(0, 27, 0, 27)})
            tw3:Play()
            tw3.Completed:Wait()
            local tw4 = TweenService:Create(HeaderLogo, TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Rotation = 5})
            tw4:Play()
            tw4.Completed:Wait()
            local tw5 = TweenService:Create(HeaderLogo, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = 0, Size = UDim2.new(0, 26, 0, 26)})
            tw5:Play()
            tw5.Completed:Wait()
            logoWobbling = false
        end)
    end
    HeaderLogo.MouseEnter:Connect(playLogoWobble)
    HeaderLogo.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            playLogoWobble()
        end
    end)


    local titleLabel = new("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.0338, 34, subName and 0.6 or 0.8, 0),
        Size = UDim2.new(1 - positionX, -34, 0, 16),
        FontFace = font(),
        Text = mainName,
        TextColor3 = WHITE,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 99,
    }, Top)

    if subName then
        new("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0.0338, 34, 1.15, 0),
            Size = UDim2.new(1 - positionX, -34, 0, 14),
            FontFace = font(),
            Text = subName,
            TextColor3 = Color3.fromRGB(170, 170, 170),
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 99,
        }, Top)
    end

    local controls = new("Frame", {
        Name = "Controls",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 60, 0, 22),
        ZIndex = 100,
    }, Top)

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, controls)

    local minimizeBtn = new("TextButton", {
        Name = "Minimize",
        BackgroundColor3 = Color3.fromRGB(28, 30, 38),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 24, 0, 24),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 100,
        LayoutOrder = 1,
    }, controls)
    corner(minimizeBtn, 6)
    local minStroke = stroke(minimizeBtn, Color3.fromRGB(48, 50, 64), 1, 0.5)

    local minBar = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 10, 0, 2),
        BackgroundColor3 = Color3.fromRGB(200, 205, 220),
        BorderSizePixel = 0,
        ZIndex = 101,
    }, minimizeBtn)
    pill(minBar)

    minimizeBtn.MouseEnter:Connect(function()
        TweenService:Create(minimizeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(42, 45, 58), BackgroundTransparency = 0.1}):Play()
        if minStroke then TweenService:Create(minStroke, TweenInfo.new(0.15), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0.2}):Play() end
        TweenService:Create(minBar, TweenInfo.new(0.15), {BackgroundColor3 = WHITE}):Play()
    end)
    minimizeBtn.MouseLeave:Connect(function()
        TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(28, 30, 38), BackgroundTransparency = 0.4}):Play()
        if minStroke then TweenService:Create(minStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(48, 50, 64), Transparency = 0.5}):Play() end
        TweenService:Create(minBar, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 205, 220)}):Play()
    end)

    local closeBtn = new("TextButton", {
        Name = "Close",
        BackgroundColor3 = Color3.fromRGB(28, 30, 38),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 24, 0, 24),
        AutoButtonColor = false,
        Text = "",
        ZIndex = 100,
        LayoutOrder = 2,
    }, controls)
    corner(closeBtn, 6)
    local closeStroke = stroke(closeBtn, Color3.fromRGB(48, 50, 64), 1, 0.5)

    local closeBar1 = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 10, 0, 2),
        Rotation = 45,
        BackgroundColor3 = Color3.fromRGB(200, 205, 220),
        BorderSizePixel = 0,
        ZIndex = 101,
    }, closeBtn)
    pill(closeBar1)

    local closeBar2 = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 10, 0, 2),
        Rotation = -45,
        BackgroundColor3 = Color3.fromRGB(200, 205, 220),
        BorderSizePixel = 0,
        ZIndex = 101,
    }, closeBtn)
    pill(closeBar2)

    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(220, 38, 38), BackgroundTransparency = 0}):Play()
        if closeStroke then TweenService:Create(closeStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(239, 68, 68), Transparency = 0}):Play() end
        TweenService:Create(closeBar1, TweenInfo.new(0.15), {BackgroundColor3 = WHITE}):Play()
        TweenService:Create(closeBar2, TweenInfo.new(0.15), {BackgroundColor3 = WHITE}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(28, 30, 38), BackgroundTransparency = 0.4}):Play()
        if closeStroke then TweenService:Create(closeStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(48, 50, 64), Transparency = 0.5}):Play() end
        TweenService:Create(closeBar1, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 205, 220)}):Play()
        TweenService:Create(closeBar2, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 205, 220)}):Play()
    end)

    local NotifLayout = new("Frame", {
        Name = "NotifLayout",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 20),
        Size = UDim2.new(0, 300, 1, -40),
        BackgroundTransparency = 1,
        ZIndex = 950,
    }, screen)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 10),
    }, NotifLayout)

    local notifyCount = 0
    function Library:Notify(options)
        if genv.hide_notifications then return end
        options = options or {}
        local title = options.Title or "Notification"
        local text = options.Content or options.Text or "This is a notification"
        local duration = tonumber(options.Duration) or 4
        local nType = options.Type or "Info"

        local typeColors = {
            Success = SUCCESS_COLOR,
            Warning = WARNING_COLOR,
            Error = ERROR_COLOR,
            Info = genv.accent or INFO_COLOR,
        }
        local accent = typeColors[nType] or genv.accent or INFO_COLOR

        notifyCount += 1
        local NotifCard = new("Frame", {
            Name = "NotifCard",
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(1, 60, 0, 0),
            BackgroundColor3 = genv.uicontainer or Color3.fromRGB(19, 20, 24),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            LayoutOrder = notifyCount,
            ZIndex = 951,
        }, NotifLayout)
        corner(NotifCard, 16)
        stroke(NotifCard, genv.uiline or Color3.fromRGB(34, 35, 42), 1, 0.5)

        local accentBar = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 6, 0.5, 0),
            Size = UDim2.new(0, 4, 1, -16),
            BackgroundColor3 = accent,
            BorderSizePixel = 0,
            ZIndex = 952,
        }, NotifCard)
        corner(accentBar, 2)

        local NotifLogo = new("ImageLabel", {
            Name = "NotifLogo",
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(0, 16, 0, 14),
            Size = UDim2.new(0, 16, 0, 16),
            BackgroundTransparency = 1,
            Image = "rbxassetid://133495621202705",
            ImageTransparency = 1,
            ZIndex = 952,
        }, NotifCard)

        local TitleLabel = new("TextLabel", {
            Name = "Title",
            Position = UDim2.new(0, 38, 0, 14),
            Size = UDim2.new(1, -68, 0, 16),
            BackgroundTransparency = 1,
            FontFace = font(Enum.FontWeight.SemiBold),
            Text = title,
            TextColor3 = WHITE,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 1,
            ZIndex = 952,
        }, NotifCard)

        local TextLabel = new("TextLabel", {
            Name = "Text",
            Position = UDim2.new(0, 38, 0, 35),
            Size = UDim2.new(1, -54, 0, 0),
            BackgroundTransparency = 1,
            FontFace = font(Enum.FontWeight.Medium),
            Text = text,
            TextColor3 = Color3.fromRGB(170, 170, 170),
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            TextTransparency = 1,
            ZIndex = 952,
        }, NotifCard)

        local CloseButton = new("TextButton", {
            Name = "CloseButton",
            Position = UDim2.new(1, -26, 0, 14),
            Size = UDim2.new(0, 16, 0, 16),
            BackgroundTransparency = 1,
            FontFace = font(Enum.FontWeight.Bold),
            Text = "x",
            TextColor3 = Color3.fromRGB(170, 170, 170),
            TextSize = 13,
            TextTransparency = 1,
            ZIndex = 953,
        }, NotifCard)

        Library.activeNotifications = Library.activeNotifications or {}
        Library.activeNotifications[NotifCard] = {
            card = NotifCard,
            stroke = NotifCard:FindFirstChildOfClass("UIStroke"),
            accentBar = accentBar,
            nType = nType
        }

        local textBounds = TextService:GetTextSize(text, 13, Enum.Font.GothamMedium, Vector2.new(244, 9999))
        TextLabel.Size = UDim2.new(1, -54, 0, textBounds.Y)
        local targetHeight = math.max(62, 35 + textBounds.Y + 14)

        local slideIn = TweenService:Create(NotifCard, TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, targetHeight),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0,
        })
        TweenService:Create(NotifLogo, TweenInfo.new(0.4), {ImageTransparency = 0}):Play()
        TweenService:Create(TitleLabel, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        TweenService:Create(TextLabel, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        TweenService:Create(CloseButton, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        slideIn:Play()

        local dismissed = false
        local function dismiss()
            if dismissed or not NotifCard.Parent then return end
            dismissed = true
            Library.activeNotifications[NotifCard] = nil
            local slideOut = TweenService:Create(NotifCard, TweenInfo.new(0.4, Enum.EasingStyle.Circular, Enum.EasingDirection.In), {
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(1, 60, 0, 0),
                BackgroundTransparency = 1,
            })
            TweenService:Create(NotifLogo, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
            TweenService:Create(TitleLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            TweenService:Create(TextLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            TweenService:Create(CloseButton, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            slideOut:Play()
            slideOut.Completed:Wait()
            if NotifCard.Parent then
                NotifCard:Destroy()
            end
        end

        CloseButton.MouseButton1Click:Connect(dismiss)
        task.delay(duration, dismiss)
    end

    local tooltip = new("Frame", {
        Name = "Tooltip",
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = Color3.fromRGB(16, 17, 21),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 900,
    }, screen)
    corner(tooltip, 6)
    stroke(tooltip, genv.uiline or Color3.fromRGB(45, 45, 55), 1, 0.3)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
    }, tooltip)

    local tipLabel = new("TextLabel", {
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextColor3 = WHITE,
        TextSize = 11,
        TextWrapped = true,
        ZIndex = 901,
    }, tooltip)
    new("UISizeConstraint", {MaxSize = Vector2.new(220, 200)}, tipLabel)

    local function attachTooltip(targetGui, tipText)
        if isMobileUser or not tipText or tipText == "" then return end
        local hover = false
        targetGui.MouseEnter:Connect(function()
            hover = true
            task.delay(0.2, function()
                if not hover or not targetGui.Parent then return end
                tipLabel.Text = tipText
                tooltip.Visible = true
                local mouse = UserInputService:GetMouseLocation()
                local view = screen.AbsoluteSize
                local px = math.clamp(mouse.X + 12, 10, view.X - tooltip.AbsoluteSize.X - 10)
                local py = math.clamp(mouse.Y + 12, 10, view.Y - tooltip.AbsoluteSize.Y - 10)
                tooltip.Position = UDim2.fromOffset(px, py)
            end)
        end)
        targetGui.MouseLeave:Connect(function()
            hover = false
            tooltip.Visible = false
        end)
    end

    local watermark = new("Frame", {
        Name = "Watermark",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 48),
        Size = UDim2.new(0, 0, 0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = genv.uicontainer or Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
        Visible = Library.WatermarkEnabled,
        Active = true,
        ZIndex = 850,
    }, screen)
    pill(watermark)
    local wmStroke = stroke(watermark, genv.uiline or Color3.fromRGB(42, 45, 56), 1, 0.4)
    local wmScale = new("UIScale", {Scale = 1}, watermark)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
    }, watermark)

    local wmLayout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    }, watermark)

    local wmAvatar = new("ImageLabel", {
        Name = "WMAvatar",
        LayoutOrder = 1,
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = Color3.fromRGB(24, 26, 32),
        BorderSizePixel = 0,
        Image = "rbxassetid://133495621202705",
        ZIndex = 851,
    }, watermark)
    pill(wmAvatar)
    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and url then wmAvatar.Image = url end
    end)

    local wmHubLabel = new("TextLabel", {
        Name = "WMHubLabel",
        LayoutOrder = 2,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = WHITE,
        TextSize = 11,
        Text = LocalPlayer.DisplayName,
        ZIndex = 851,
    }, watermark)

    local wmDiv1 = new("Frame", {
        Name = "WMDiv1",
        LayoutOrder = 3,
        Size = UDim2.new(0, 1, 0, 12),
        BackgroundColor3 = genv.uiline or Color3.fromRGB(42, 45, 56),
        BorderSizePixel = 0,
        ZIndex = 851,
    }, watermark)
    if isMobileUser then
        wmHubLabel.Visible = false
        wmDiv1.Visible = false
    end

    local wmPingFrame = new("Frame", {
        Name = "WMPingFrame",
        LayoutOrder = 4,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 851,
    }, watermark)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
    }, wmPingFrame)

    local wmPingIcon = new("ImageLabel", {
        Size = UDim2.new(0, 13, 0, 13),
        BackgroundTransparency = 1,
        Image = "rbxassetid://78424889355261",
        ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        ZIndex = 852,
    }, wmPingFrame)

    local wmPingText = new("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextSize = 11,
        RichText = true,
        Text = "<font color=\"#ffffff\"><b>0</b></font> <font color=\"#8e92a4\">ms</font>",
        ZIndex = 852,
    }, wmPingFrame)

    local wmDiv2 = new("Frame", {
        Name = "WMDiv2",
        LayoutOrder = 5,
        Size = UDim2.new(0, 1, 0, 12),
        BackgroundColor3 = genv.uiline or Color3.fromRGB(42, 45, 56),
        BorderSizePixel = 0,
        ZIndex = 851,
    }, watermark)

    local wmFpsFrame = new("Frame", {
        Name = "WMFpsFrame",
        LayoutOrder = 6,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 851,
    }, watermark)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
    }, wmFpsFrame)

    local wmFpsIcon = new("ImageLabel", {
        Size = UDim2.new(0, 13, 0, 13),
        BackgroundTransparency = 1,
        Image = "rbxassetid://110273524101447",
        ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        ZIndex = 852,
    }, wmFpsFrame)

    local wmFpsText = new("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextSize = 11,
        RichText = true,
        Text = "<font color=\"#ffffff\"><b>60</b></font> <font color=\"#8e92a4\">fps</font>",
        ZIndex = 852,
    }, wmFpsFrame)

    local wmDiv3 = new("Frame", {
        Name = "WMDiv3",
        LayoutOrder = 7,
        Size = UDim2.new(0, 1, 0, 12),
        BackgroundColor3 = genv.uiline or Color3.fromRGB(42, 45, 56),
        BorderSizePixel = 0,
        ZIndex = 851,
    }, watermark)

    local wmPlrBtn = new("TextButton", {
        Name = "WMPlrBtn",
        LayoutOrder = 8,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 851,
    }, watermark)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
    }, wmPlrBtn)

    local wmPlrIcon = new("ImageLabel", {
        Size = UDim2.new(0, 13, 0, 13),
        BackgroundTransparency = 1,
        Image = "rbxassetid://115398113982385",
        ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        ZIndex = 852,
    }, wmPlrBtn)

    local wmPlrText = new("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextSize = 11,
        RichText = true,
        Text = string.format("<font color=\"#ffffff\"><b>%d</b></font> <font color=\"#8e92a4\">players</font>", #Players:GetPlayers()),
        ZIndex = 852,
    }, wmPlrBtn)



    Library.WatermarkFrame = watermark

    local nearbyFrame = new("Frame", {
        Name = "NearbyPlayers",
        Position = UDim2.new(1, -234, 0, 50),
        Size = UDim2.new(0, 224, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = genv.uicontainer or Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = true,
        Active = true,
        ZIndex = 890,
    }, screen)
    corner(nearbyFrame, 12)
    local nearbyStroke = stroke(nearbyFrame, genv.uiline or Color3.fromRGB(42, 45, 56), 1, 0.4)

    local nearbyHeader = new("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        ZIndex = 891,
    }, nearbyFrame)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, nearbyHeader)

    local nearbyHeadIcon = new("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Image = "rbxassetid://81589895647169",
        ImageColor3 = MUTED,
        ZIndex = 892,
    }, nearbyHeader)

    local nearbyHeadTitle = new("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 20, 0.5, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextColor3 = Color3.fromRGB(190, 194, 205),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Nearby players",
        ZIndex = 892,
    }, nearbyHeader)

    local nearbySep = new("Frame", {
        Position = UDim2.new(0, 0, 0, 28),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = genv.uiline or Color3.fromRGB(35, 38, 48),
        BorderSizePixel = 0,
        ZIndex = 891,
    }, nearbyFrame)

    local nearbyScroll = new("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Color3.fromRGB(50, 54, 68),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 891,
    }, nearbyFrame)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 8),
    }, nearbyScroll)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, nearbyScroll)

    local nearbyRows = {}
    local function updateNearbyPlayers()
        if not nearbyFrame.Visible then return end
        local myChar = LocalPlayer.Character
        local myHrp = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar.PrimaryPart)
        local playersList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local dist = 999999
            local pChar = p.Character
            local pHrp = pChar and (pChar:FindFirstChild("HumanoidRootPart") or pChar.PrimaryPart)
            if myHrp and pHrp then
                dist = math.floor((myHrp.Position - pHrp.Position).Magnitude)
            end
            table.insert(playersList, {
                player = p,
                isLocal = (p == LocalPlayer),
                dist = dist
            })
        end
        table.sort(playersList, function(a, b)
            if a.isLocal then return true end
            if b.isLocal then return false end
            return a.dist < b.dist
        end)

        for i = 1, math.max(#playersList, #nearbyRows) do
            local data = playersList[i]
            local item = nearbyRows[i]
            if data then
                if not item then
                    local row = new("Frame", {
                        Name = "Row_" .. i,
                        Size = UDim2.new(1, 0, 0, 24),
                        BackgroundTransparency = 1,
                        ZIndex = 892,
                    }, nearbyScroll)
                    local rowAvatar = new("ImageLabel", {
                        AnchorPoint = Vector2.new(0, 0.5),
                        Position = UDim2.new(0, 0, 0.5, 0),
                        Size = UDim2.new(0, 20, 0, 20),
                        BackgroundColor3 = Color3.fromRGB(24, 26, 34),
                        BorderSizePixel = 0,
                        ZIndex = 893,
                    }, row)
                    pill(rowAvatar)
                    local rowName = new("TextLabel", {
                        AnchorPoint = Vector2.new(0, 0.5),
                        Position = UDim2.new(0, 26, 0.5, 0),
                        Size = UDim2.new(1, -74, 1, 0),
                        BackgroundTransparency = 1,
                        FontFace = font(Enum.FontWeight.Medium),
                        TextColor3 = WHITE,
                        TextSize = 11,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 893,
                    }, row)
                    local rowDist = new("TextLabel", {
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, 0, 0.5, 0),
                        Size = UDim2.new(0, 48, 1, 0),
                        BackgroundTransparency = 1,
                        FontFace = font(Enum.FontWeight.Medium),
                        TextSize = 11,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        ZIndex = 893,
                    }, row)
                    item = {
                        frame = row,
                        avatar = rowAvatar,
                        name = rowName,
                        dist = rowDist,
                        lastUserId = nil,
                    }
                    nearbyRows[i] = item
                end
                item.frame.Visible = true
                item.frame.LayoutOrder = i
                item.name.Text = data.player.DisplayName
                if data.isLocal then
                    item.dist.Text = "you"
                    item.dist.TextColor3 = genv.accent or Color3.fromRGB(168, 85, 247)
                else
                    item.dist.Text = (data.dist < 99990 and (data.dist .. "m") or "?m")
                    item.dist.TextColor3 = MUTED
                end
                if item.lastUserId ~= data.player.UserId then
                    item.lastUserId = data.player.UserId
                    task.spawn(function()
                        local ok, url = pcall(function()
                            return Players:GetUserThumbnailAsync(data.player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                        end)
                        if ok and url and item.avatar then
                            item.avatar.Image = url
                        end
                    end)
                end
            elseif item then
                item.frame.Visible = false
            end
        end
    end

    local function toggleNearbyPopup()
        nearbyFrame.Visible = not nearbyFrame.Visible
        if nearbyFrame.Visible then
            local wx = watermark.AbsolutePosition.X
            local wy = watermark.AbsolutePosition.Y + watermark.AbsoluteSize.Y + 6
            local view = screen.AbsoluteSize
            if wx + 224 > view.X - 10 then
                wx = view.X - 224 - 10
            end
            if wx < 10 then wx = 10 end
            if wy + 200 > view.Y - 10 then
                wy = math.max(10, watermark.AbsolutePosition.Y - 210)
            end
            nearbyFrame.Position = UDim2.fromOffset(wx, wy)
            updateNearbyPlayers()
        end
    end

    wmPlrBtn.MouseEnter:Connect(function()
        wmPlrIcon.ImageColor3 = WHITE
    end)
    wmPlrBtn.MouseLeave:Connect(function()
        wmPlrIcon.ImageColor3 = Color3.fromRGB(150, 155, 170)
    end)
    wmPlrBtn.MouseButton1Click:Connect(toggleNearbyPopup)

    local wmDragging = false
    local wmDragStart, wmStartPos, wmMoved
    watermark.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            wmDragging = true
            wmMoved = false
            wmDragStart = input.Position
            wmStartPos = watermark.Position
            TweenService:Create(wmScale, TweenInfo.new(0.08), {Scale = 0.96}):Play()
        end
    end)
    watermark.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            TweenService:Create(wmScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end
    end)
    watermark.MouseEnter:Connect(function()
        TweenService:Create(watermark, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(26, 28, 36)}):Play()
        if wmStroke then
            TweenService:Create(wmStroke, TweenInfo.new(0.2), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0}):Play()
        end
    end)
    watermark.MouseLeave:Connect(function()
        TweenService:Create(watermark, TweenInfo.new(0.2), {BackgroundColor3 = genv.uicontainer or Color3.fromRGB(18, 19, 24)}):Play()
        if wmStroke then
            TweenService:Create(wmStroke, TweenInfo.new(0.2), {Color = genv.uiline or Color3.fromRGB(42, 45, 56), Transparency = 0.4}):Play()
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if not wmDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - wmDragStart
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
                wmMoved = true
            end
            local view = screen.AbsoluteSize
            local curX = wmStartPos.X.Scale * view.X + wmStartPos.X.Offset + delta.X
            local curY = wmStartPos.Y.Scale * view.Y + wmStartPos.Y.Offset + delta.Y
            local wmW = watermark.AbsoluteSize.X
            curX = math.clamp(curX, wmW + 10, view.X - 10)
            curY = math.clamp(curY, 10, view.Y - watermark.AbsoluteSize.Y - 10)
            watermark.Position = UDim2.fromOffset(curX, curY)
            if nearbyFrame.Visible then
                local nX = math.clamp(curX - 224, 10, view.X - 234)
                local nY = curY + watermark.AbsoluteSize.Y + 6
                if nY + 200 > view.Y - 10 then
                    nY = math.max(10, curY - 210)
                end
                nearbyFrame.Position = UDim2.fromOffset(nX, nY)
            end
        end
    end)
    bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if wmDragging and not wmMoved then
                if openInfoModal then openInfoModal() end
            end
            wmDragging = false
        end
    end)

    local keybindList = new("Frame", {
        Name = "KeybindList",
        Position = UDim2.new(0, 20, 0, 140),
        Size = UDim2.new(0, 204, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = genv.uicontainer or Color3.fromRGB(18, 19, 24),
        BorderSizePixel = 0,
        Visible = Library.KeybindListEnabled,
        Active = true,
        ZIndex = 850,
    }, screen)
    corner(keybindList, 10)
    local kbStroke = stroke(keybindList, genv.uiline or Color3.fromRGB(42, 45, 56), 1, 0.4)
    local kbScale = new("UIScale", {Scale = 1}, keybindList)

    keybindList.MouseEnter:Connect(function()
        TweenService:Create(keybindList, TweenInfo.new(0.22), {BackgroundColor3 = Color3.fromRGB(22, 24, 32)}):Play()
        if kbStroke then
            TweenService:Create(kbStroke, TweenInfo.new(0.22), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0.15}):Play()
        end
    end)
    keybindList.MouseLeave:Connect(function()
        if not kbDragging then
            TweenService:Create(keybindList, TweenInfo.new(0.25), {BackgroundColor3 = genv.uicontainer or Color3.fromRGB(18, 19, 24)}):Play()
            if kbStroke then
                TweenService:Create(kbStroke, TweenInfo.new(0.25), {Color = genv.uiline or Color3.fromRGB(42, 45, 56), Transparency = 0.4}):Play()
            end
        end
    end)

    local kbTop = new("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 851,
    }, keybindList)

    local kbLogo = new("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.new(0, 15, 0, 15),
        BackgroundTransparency = 1,
        Image = "rbxassetid://133495621202705",
        ZIndex = 852,
    }, kbTop)

    local kbTitleLabel = new("TextLabel", {
        Position = UDim2.new(0, 28, 0, 0),
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = WHITE,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Active Keybinds",
        ZIndex = 852,
    }, kbTop)

    local kbCountBadge = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 16),
        BackgroundColor3 = Color3.fromRGB(24, 25, 32),
        BorderSizePixel = 0,
        ZIndex = 852,
    }, kbTop)
    pill(kbCountBadge)
    local kbCountStroke = stroke(kbCountBadge, genv.accent or Color3.fromRGB(50, 52, 64), 1, 0.4)

    local kbCountText = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = genv.accent or WHITE,
        TextSize = 10,
        Text = "0",
        ZIndex = 853,
    }, kbCountBadge)

    local kbLine = new("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = genv.uiline or Color3.fromRGB(32, 34, 42),
        BorderSizePixel = 0,
        ZIndex = 851,
    }, kbTop)

    local kbDragging = false
    local kbDragStart, kbStartPos
    kbTop.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            kbDragging = true
            kbDragStart = input.Position
            kbStartPos = keybindList.Position
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if not kbDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - kbDragStart
            local view = screen.AbsoluteSize
            local curX = kbStartPos.X.Scale * view.X + kbStartPos.X.Offset + delta.X
            local curY = kbStartPos.Y.Scale * view.Y + kbStartPos.Y.Offset + delta.Y
            curX = math.clamp(curX, 10, view.X - 210)
            curY = math.clamp(curY, 10, view.Y - 50)
            keybindList.Position = UDim2.fromOffset(curX, curY)
        end
    end)
    bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            kbDragging = false
        end
    end)

    local kbHolder = new("Frame", {
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 851,
    }, keybindList)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    }, kbHolder)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 8),
    }, kbHolder)

    Library.KeybindListFrame = keybindList

    local function refreshKeybindList()
        for _, child in ipairs(kbHolder:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
        end
        local count = 0
        local seenKeybinds = {}
        for _, kb in pairs(Library.Keybinds) do
            if kb.key and kb.key ~= "None" and not seenKeybinds[kb.name] then
                seenKeybinds[kb.name] = true
                count += 1
                local row = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = Color3.fromRGB(24, 26, 33),
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 852,
                }, kbHolder)
                corner(row, 6)
                local rowStrk = stroke(row, Color3.fromRGB(38, 40, 52), 1, 0.4)
                new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6)}, row)

                local nameLabel = new("TextLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.new(1, -78, 1, 0),
                    BackgroundTransparency = 1,
                    FontFace = font(Enum.FontWeight.Medium),
                    TextColor3 = WHITE,
                    TextSize = 11,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = kb.name,
                    ZIndex = 853,
                }, row)

                local rightHolder = new("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.new(0, 76, 1, 0),
                    BackgroundTransparency = 1,
                    ZIndex = 853,
                }, row)

                new("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 5),
                }, rightHolder)

                if kb.isButton then
                    local actBtn = new("TextButton", {
                        Size = UDim2.new(0, 34, 0, 16),
                        BackgroundColor3 = Color3.fromRGB(36, 38, 48),
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        Text = "",
                        ZIndex = 854,
                    }, rightHolder)
                    corner(actBtn, 4)
                    stroke(actBtn, genv.accent or Color3.fromRGB(60, 64, 80), 1, 0.4)

                    local actText = new("TextLabel", {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        FontFace = font(Enum.FontWeight.Bold),
                        TextColor3 = genv.accent or WHITE,
                        TextSize = 9,
                        Text = "RUN",
                        ZIndex = 855,
                    }, actBtn)

                    local lastRun = 0
                    local function runAct()
                        if tick() - lastRun < 0.15 then return end
                        lastRun = tick()
                        TweenService:Create(actBtn, TweenInfo.new(0.08), {BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247)}):Play()
                        actText.TextColor3 = WHITE
                        if kb.toggle then kb.toggle() elseif kb.callback then kb.callback() end
                        task.delay(0.12, function()
                            if actBtn and actBtn.Parent then
                                TweenService:Create(actBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(36, 38, 48)}):Play()
                                actText.TextColor3 = genv.accent or WHITE
                            end
                        end)
                    end
                    actBtn.MouseButton1Click:Connect(runAct)
                    actBtn.TouchTap:Connect(runAct)
                    row.MouseButton1Click:Connect(runAct)
                    row.TouchTap:Connect(runAct)
                else
                    local state = kb.getState and kb.getState()
                    local switchTrack = new("Frame", {
                        Size = UDim2.new(0, 28, 0, 16),
                        BackgroundColor3 = (state == true) and (genv.togglecoloron or genv.accent or Color3.fromRGB(168, 85, 247)) or (genv.togglecoloroff or Color3.fromRGB(38, 40, 50)),
                        BorderSizePixel = 0,
                        ZIndex = 854,
                    }, rightHolder)
                    pill(switchTrack)
                    local trackStrk = stroke(switchTrack, Color3.fromRGB(50, 53, 66), 1, 0.5)

                    local switchKnob = new("Frame", {
                        AnchorPoint = Vector2.new(0, 0.5),
                        Position = (state == true) and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                        Size = UDim2.new(0, 11, 0, 11),
                        BackgroundColor3 = WHITE,
                        BorderSizePixel = 0,
                        ZIndex = 855,
                    }, switchTrack)
                    pill(switchKnob)

                    local lastTog = 0
                    local function toggleRow()
                        if tick() - lastTog < 0.15 then return end
                        lastTog = tick()
                        if kb.toggle then
                            kb.toggle()
                        elseif kb.callback then
                            kb.callback(not (kb.getState and kb.getState() or false))
                        end
                        task.defer(function()
                            local newState = kb.getState and kb.getState() or false
                            local targetPos = (newState == true) and UDim2.new(1, -13, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
                            local targetCol = (newState == true) and (genv.togglecoloron or genv.accent or Color3.fromRGB(168, 85, 247)) or (genv.togglecoloroff or Color3.fromRGB(38, 40, 50))
                            TweenService:Create(switchKnob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 14, 0, 11)}):Play()
                            TweenService:Create(switchKnob, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = targetPos}):Play()
                            TweenService:Create(switchTrack, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = targetCol}):Play()
                            task.delay(0.09, function()
                                if switchKnob and switchKnob.Parent then
                                    TweenService:Create(switchKnob, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 11, 0, 11)}):Play()
                                end
                            end)
                            if rowStrk then
                                local strkCol = (newState == true) and (genv.accent or Color3.fromRGB(168, 85, 247)) or Color3.fromRGB(38, 40, 52)
                                TweenService:Create(rowStrk, TweenInfo.new(0.2), {Color = strkCol}):Play()
                            end
                        end)
                    end
                    row.MouseButton1Click:Connect(toggleRow)
                    row.TouchTap:Connect(toggleRow)
                end

                local badge = new("Frame", {
                    Size = UDim2.new(0, 0, 0, 17),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = Color3.fromRGB(30, 32, 40),
                    BorderSizePixel = 0,
                    ZIndex = 854,
                }, rightHolder)
                corner(badge, 4)
                stroke(badge, Color3.fromRGB(48, 52, 66), 1, 0.5)
                new("UIPadding", {PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, badge)

                new("TextLabel", {
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    FontFace = font(Enum.FontWeight.Bold),
                    TextColor3 = genv.accent or WHITE,
                    TextSize = 10,
                    Text = tostring(kb.key),
                    ZIndex = 855,
                }, badge)

                row.MouseEnter:Connect(function()
                    TweenService:Create(row, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 33, 44)}):Play()
                end)
                row.MouseLeave:Connect(function()
                    TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(24, 26, 33)}):Play()
                end)
            end
        end
        kbCountText.Text = tostring(count)
        if count == 0 then
            local emptyRow = new("Frame", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                ZIndex = 852,
            }, kbHolder)
            new("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                FontFace = font(Enum.FontWeight.Regular),
                TextColor3 = MUTED,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "No active binds",
                ZIndex = 853,
            }, emptyRow)
        end
    end
    Library.UpdateKeybindList = refreshKeybindList
    refreshKeybindList()

    local execName = "Unknown"
    local okExec, resExec = pcall(function()
        return (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname())
    end)
    if okExec and type(resExec) == "string" and #resExec > 0 then
        execName = resExec
    end

    local bar1, bar2, bar3, bar4, islandMascot

    local island = new("Frame", {
        Name = "DynamicIsland",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.new(0, 204, 0, 32),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Active = true,
        ZIndex = 850,
    }, screen)
    local islandCorner = corner(island, 17)
    local islandStroke = stroke(island, Color3.fromRGB(36, 38, 48), 1, 0.45)

    island.MouseEnter:Connect(function()
        if islandStroke then
            TweenService:Create(islandStroke, TweenInfo.new(0.25), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0.2}):Play()
        end
    end)
    island.MouseLeave:Connect(function()
        if islandStroke then
            TweenService:Create(islandStroke, TweenInfo.new(0.25), {Color = Color3.fromRGB(36, 38, 48), Transparency = 0.45}):Play()
        end
    end)
    local islandScale = new("UIScale", {Scale = 1}, island)
    Library.IslandFrame = island

    local islandCompact = new("Frame", {
        Name = "CompactView",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = true,
        ZIndex = 851,
    }, island)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, islandCompact)

    local islandDot = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 7, 0, 7),
        BackgroundColor3 = SUCCESS_COLOR,
        BorderSizePixel = 0,
        ZIndex = 852,
    }, islandCompact)
    pill(islandDot)

    local islandLogo = new("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 13, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 1,
        Image = "rbxassetid://133495621202705",
        ZIndex = 852,
    }, islandCompact)

    local islandTitle = new("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 35, 0.5, 0),
        Size = UDim2.new(0, 75, 0, 16),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = WHITE,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = mainName,
        ZIndex = 852,
    }, islandCompact)

    local islandVisualizer = new("Frame", {
        Name = "IslandVisualizer",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 52, 0, 20),
        BackgroundTransparency = 1,
        ZIndex = 852,
    }, islandCompact)

    islandMascot = new("ImageLabel", {
        Name = "IslandMascot",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundTransparency = 1,
        Image = "rbxassetid://10149736886",
        ZIndex = 853,
    }, islandVisualizer)
    pill(islandMascot)

    local islandBarsHolder = new("Frame", {
        Name = "BarsHolder",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 16),
        BackgroundTransparency = 1,
        ZIndex = 853,
    }, islandVisualizer)

    bar1 = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(0, 3, 0, 5),
        BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        BorderSizePixel = 0,
        ZIndex = 854,
    }, islandBarsHolder)
    pill(bar1)

    bar2 = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 6, 1, -1),
        Size = UDim2.new(0, 3, 0, 8),
        BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        BorderSizePixel = 0,
        ZIndex = 854,
    }, islandBarsHolder)
    pill(bar2)

    bar3 = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 12, 1, -1),
        Size = UDim2.new(0, 3, 0, 11),
        BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        BorderSizePixel = 0,
        ZIndex = 854,
    }, islandBarsHolder)
    pill(bar3)

    bar4 = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 18, 1, -1),
        Size = UDim2.new(0, 3, 0, 14),
        BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        BorderSizePixel = 0,
        ZIndex = 854,
    }, islandBarsHolder)
    pill(bar4)

    local islandExpanded = new("Frame", {
        Name = "ExpandedView",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 851,
    }, island)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
    }, islandExpanded)

    local expHeader = new("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        ZIndex = 852,
    }, islandExpanded)

    local playerHead = new("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 36, 0, 36),
        BackgroundColor3 = Color3.fromRGB(28, 30, 38),
        BorderSizePixel = 0,
        ZIndex = 853,
    }, expHeader)
    pill(playerHead)
    stroke(playerHead, genv.uiline or Color3.fromRGB(45, 48, 60), 1, 0.4)
    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and url then playerHead.Image = url end
    end)

    local islandPlayerName = new("TextLabel", {
        Position = UDim2.new(0, 44, 0, 0),
        Size = UDim2.new(1, -125, 0, 15),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = WHITE,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = LocalPlayer.DisplayName,
        ZIndex = 853,
    }, expHeader)

    local islandUsername = new("TextLabel", {
        Position = UDim2.new(0, 44, 0, 15),
        Size = UDim2.new(1, -125, 0, 13),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextColor3 = MUTED,
        TextSize = 10,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "@" .. LocalPlayer.Name .. "  •  " .. execName,
        ZIndex = 853,
    }, expHeader)

    local islandGameLabel = new("TextLabel", {
        Position = UDim2.new(0, 44, 0, 28),
        Size = UDim2.new(1, -125, 0, 13),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        TextSize = 10,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = detectedGameName,
        ZIndex = 853,
    }, expHeader)

    local islandSessionBadge = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 72, 0, 22),
        BackgroundColor3 = Color3.fromRGB(24, 26, 33),
        BorderSizePixel = 0,
        ZIndex = 853,
    }, expHeader)
    corner(islandSessionBadge, 6)
    stroke(islandSessionBadge, genv.uiline or Color3.fromRGB(38, 40, 50), 1, 0.3)

    local islandSession = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.SemiBold),
        TextColor3 = GRAY,
        TextSize = 10,
        Text = "0m 0s",
        ZIndex = 854,
    }, islandSessionBadge)

    local expSep = new("Frame", {
        Position = UDim2.new(0, 0, 0, 50),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = genv.uiline or Color3.fromRGB(35, 38, 48),
        BorderSizePixel = 0,
        ZIndex = 852,
    }, islandExpanded)

    local expMetrics = new("Frame", {
        Position = UDim2.new(0, 0, 0, 58),
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundTransparency = 1,
        ZIndex = 852,
    }, islandExpanded)

    local fpsTile = new("Frame", {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.485, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(22, 24, 30),
        BorderSizePixel = 0,
        ZIndex = 853,
    }, expMetrics)
    corner(fpsTile, 7)
    stroke(fpsTile, genv.uiline or Color3.fromRGB(35, 37, 46), 1, 0.3)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, fpsTile)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
    }, fpsTile)

    local fpsTileIcon = new("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Image = "rbxassetid://110273524101447",
        ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        ZIndex = 854,
    }, fpsTile)

    local islandFpsVal = new("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        RichText = true,
        Text = "<font color=\"#8e92a4\">FPS</font>  <font color=\"#ffffff\"><b>60</b></font>",
        ZIndex = 854,
    }, fpsTile)

    local pingTile = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0.485, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(18, 19, 25),
        BorderSizePixel = 0,
        ZIndex = 853,
    }, expMetrics)
    corner(pingTile, 8)
    stroke(pingTile, Color3.fromRGB(36, 38, 48), 1, 0.4)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, pingTile)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
    }, pingTile)

    local pingTileIcon = new("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Image = "rbxassetid://78424889355261",
        ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        ZIndex = 854,
    }, pingTile)

    local islandPingVal = new("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        RichText = true,
        Text = "<font color=\"#8e92a4\">Ping</font>  <font color=\"#ffffff\"><b>0</b><font color=\"#8e92a4\"> ms</font></font>",
        ZIndex = 854,
    }, pingTile)

    local plrTile = new("Frame", {
        Position = UDim2.new(0, 0, 0, 38),
        Size = UDim2.new(0.485, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(18, 19, 25),
        BorderSizePixel = 0,
        ZIndex = 853,
    }, expMetrics)
    corner(plrTile, 8)
    stroke(plrTile, Color3.fromRGB(36, 38, 48), 1, 0.4)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, plrTile)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
    }, plrTile)

    local plrTileIcon = new("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Image = "rbxassetid://115398113982385",
        ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        ZIndex = 854,
    }, plrTile)

    local islandPlrVal = new("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        RichText = true,
        Text = "<font color=\"#8e92a4\">Plrs</font>  <font color=\"#ffffff\"><b>1</b></font>",
        ZIndex = 854,
    }, plrTile)

    local actTile = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 38),
        Size = UDim2.new(0.485, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(18, 19, 25),
        BorderSizePixel = 0,
        ZIndex = 853,
    }, expMetrics)
    corner(actTile, 8)
    stroke(actTile, Color3.fromRGB(36, 38, 48), 1, 0.4)
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, actTile)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
    }, actTile)

    local actTileIcon = new("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Image = "rbxassetid://138635884129147",
        ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        ZIndex = 854,
    }, actTile)

    local islandActiveVal = new("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Medium),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        RichText = true,
        Text = "<font color=\"#8e92a4\">Active</font>  <font color=\"#ffffff\"><b>0</b></font>",
        ZIndex = 854,
    }, actTile)

    table.insert(gameNameListeners, function(name)
        if islandGameLabel and islandGameLabel.Parent then
            islandGameLabel.Text = name
        end
    end)

    local restoreBtn = new("TextButton", {
        Position = UDim2.new(0, 0, 0, 140),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(26, 28, 38),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 853,
    }, islandExpanded)
    corner(restoreBtn, 10)
    local restStrk = stroke(restoreBtn, Color3.fromRGB(44, 48, 64), 1, 0.5)

    local restIcon = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -48, 0.5, 0),
        Size = UDim2.new(0, 13, 0, 13),
        BackgroundTransparency = 1,
        Image = "rbxassetid://92473583511724",
        ImageColor3 = WHITE,
        ZIndex = 854,
    }, restoreBtn)

    local restLabel = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 8, 0.5, 0),
        Size = UDim2.new(0, 96, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = WHITE,
        TextSize = 11,
        Text = "Restore Window",
        ZIndex = 854,
    }, restoreBtn)

    restoreBtn.MouseEnter:Connect(function()
        TweenService:Create(restoreBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(34, 37, 50)}):Play()
        if restStrk then TweenService:Create(restStrk, TweenInfo.new(0.15), {Color = genv.accent or Color3.fromRGB(168, 85, 247)}):Play() end
    end)
    restoreBtn.MouseLeave:Connect(function()
        TweenService:Create(restoreBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(26, 28, 38)}):Play()
        if restStrk then TweenService:Create(restStrk, TweenInfo.new(0.2), {Color = Color3.fromRGB(44, 48, 64)}):Play() end
    end)

    local islandExpandedState = false
    local function setIslandExpanded(state)
        islandExpandedState = state
        local targetSize = state and UDim2.new(0, 320, 0, 194) or UDim2.new(0, 204, 0, 32)
        local targetRadius = state and 22 or 17
        if state then
            islandCompact.Visible = false
            islandExpanded.Visible = true
        else
            islandExpanded.Visible = false
            islandCompact.Visible = true
        end
        if islandCorner then
            TweenService:Create(islandCorner, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CornerRadius = UDim.new(0, targetRadius)}):Play()
        end
        TweenService:Create(island, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    end

    Library.SetIslandExpanded = setIslandExpanded

    island.MouseEnter:Connect(function()
        if Library.IslandStyle == "Show on Hover" then
            setIslandExpanded(true)
        end
    end)
    island.MouseLeave:Connect(function()
        if Library.IslandStyle == "Show on Hover" and not islandDragging then
            setIslandExpanded(false)
        end
    end)

    local islandDragging = false
    local islandMoved = false
    local islandDragStart, islandStartPos
    island.InputBegan:Connect(function(input)
        if not Library.IslandDraggable then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            islandDragging = true
            islandMoved = false
            islandDragStart = input.Position
            islandStartPos = island.Position
            TweenService:Create(islandScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Scale = 0.96}):Play()
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if not islandDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - islandDragStart
            if delta.Magnitude > 4 then islandMoved = true end
            local view = screen.AbsoluteSize
            local curX = islandStartPos.X.Scale * view.X + islandStartPos.X.Offset + delta.X
            local curY = islandStartPos.Y.Scale * view.Y + islandStartPos.Y.Offset + delta.Y
            curX = math.clamp(curX, 160, view.X - 160)
            curY = math.clamp(curY, 6, view.Y - 180)
            island.Position = UDim2.fromOffset(curX, curY)
        end
    end)
    bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if islandDragging then
                islandDragging = false
                TweenService:Create(islandScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Scale = 1}):Play()
                if not islandMoved and Library.IslandStyle == "Click to Expand" then
                    setIslandExpanded(not islandExpandedState)
                end
            end
        end
    end)

    local ToggleBtn = new("TextButton", {
        Name = "ToggleBar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.new(0, 48, 0, 48),
        BackgroundColor3 = genv.uicontainer or Color3.fromRGB(18, 19, 25),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Visible = false,
        ZIndex = 800,
    }, screen)
    corner(ToggleBtn, 14)
    local toggleStroke = stroke(ToggleBtn, genv.accent or Color3.fromRGB(168, 85, 247), 1.5, 0.3)
    Library.ToggleBarBtn = ToggleBtn

    local toggleDot = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -6, 0, 6),
        Size = UDim2.new(0, 5, 0, 5),
        BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
        BorderSizePixel = 0,
        ZIndex = 802,
    }, ToggleBtn)
    pill(toggleDot)

    task.spawn(function()
        while ToggleBtn and ToggleBtn.Parent do
            TweenService:Create(toggleDot, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.55}):Play()
            task.wait(1.2)
            if not ToggleBtn or not ToggleBtn.Parent then break end
            TweenService:Create(toggleDot, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0}):Play()
            task.wait(1.2)
        end
    end)

    local toggleIcon = new("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundTransparency = 1,
        Image = "rbxassetid://133495621202705",
        ImageColor3 = WHITE,
        ZIndex = 801,
    }, ToggleBtn)

    local toggleScale = new("UIScale", {Scale = 1}, ToggleBtn)

    local isIconWobbling = false
    local function wobbleToggleIcon()
        if isIconWobbling then return end
        isIconWobbling = true
        task.spawn(function()
            local w1 = TweenService:Create(toggleIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 14})
            w1:Play()
            w1.Completed:Wait()
            local w2 = TweenService:Create(toggleIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = -12})
            w2:Play()
            w2.Completed:Wait()
            local w3 = TweenService:Create(toggleIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 8})
            w3:Play()
            w3.Completed:Wait()
            local w4 = TweenService:Create(toggleIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 0})
            w4:Play()
            w4.Completed:Wait()
            isIconWobbling = false
        end)
    end

    ToggleBtn.MouseEnter:Connect(function()
        TweenService:Create(toggleScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.12}):Play()
        TweenService:Create(ToggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(26, 28, 38)}):Play()
        if toggleStroke then
            TweenService:Create(toggleStroke, TweenInfo.new(0.2), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0}):Play()
        end
        wobbleToggleIcon()
    end)
    ToggleBtn.MouseLeave:Connect(function()
        if not toggleDragging then
            TweenService:Create(toggleScale, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Scale = 1}):Play()
            TweenService:Create(ToggleBtn, TweenInfo.new(0.25), {BackgroundColor3 = genv.uicontainer or Color3.fromRGB(18, 19, 25)}):Play()
            if toggleStroke then
                TweenService:Create(toggleStroke, TweenInfo.new(0.2), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0.35}):Play()
            end
        end
    end)

    local toggleDragging = false
    local toggleDragStart, toggleStartPos, toggleMoved
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            toggleDragging = true
            toggleMoved = false
            toggleDragStart = input.Position
            toggleStartPos = ToggleBtn.Position
            TweenService:Create(toggleScale, TweenInfo.new(0.12), {Scale = 0.88}):Play()
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if not toggleDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - toggleDragStart
            if delta.Magnitude > 4 then toggleMoved = true end
            local view = screen.AbsoluteSize
            local curX = toggleStartPos.X.Scale * view.X + toggleStartPos.X.Offset + delta.X
            local curY = toggleStartPos.Y.Scale * view.Y + toggleStartPos.Y.Offset + delta.Y
            curX = math.clamp(curX, 0, view.X - 48)
            curY = math.clamp(curY, 0, view.Y - 48)
            ToggleBtn.Position = UDim2.fromOffset(curX, curY)
        end
    end)
    bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if toggleDragging then
                toggleDragging = false
                TweenService:Create(toggleScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
                if not toggleMoved then
                    wobbleToggleIcon()
                    Library:visible()
                end
            end
        end
    end)

    local NotchBar = new("TextButton", {
        Name = "NotchBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(0, 134, 0, 28),
        BackgroundColor3 = genv.uicontainer or Color3.fromRGB(20, 22, 28),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Visible = false,
        ZIndex = 850,
    }, screen)
    corner(NotchBar, 10)
    local notchStroke = stroke(NotchBar, genv.accent or Color3.fromRGB(55, 58, 70), 1, 0.4)
    Library.NotchBarBtn = NotchBar

    NotchBar.MouseEnter:Connect(function()
        TweenService:Create(NotchBar, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Size = UDim2.new(0, 142, 0, 32)}):Play()
        if notchStroke then
            TweenService:Create(notchStroke, TweenInfo.new(0.2), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0}):Play()
        end
    end)
    NotchBar.MouseLeave:Connect(function()
        if not notchDragging then
            TweenService:Create(NotchBar, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 134, 0, 28)}):Play()
            if notchStroke then
                TweenService:Create(notchStroke, TweenInfo.new(0.2), {Color = genv.accent or Color3.fromRGB(55, 58, 70), Transparency = 0.4}):Play()
            end
        end
    end)

    local notchLogo = new("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 1,
        Image = "rbxassetid://133495621202705",
        ZIndex = 851,
    }, NotchBar)

    local notchTitle = new("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 28, 0.5, 0),
        Size = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = WHITE,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = mainName,
        ZIndex = 851,
    }, NotchBar)

    local notchDot = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = genv.accent or SUCCESS_COLOR,
        BorderSizePixel = 0,
        ZIndex = 851,
    }, NotchBar)
    pill(notchDot)

    local notchDragging = false
    local notchDragStart, notchStartPos, notchMoved
    NotchBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            notchDragging = true
            notchMoved = false
            notchDragStart = input.Position
            notchStartPos = NotchBar.Position
        end
    end)
    bind(UserInputService.InputChanged, function(input)
        if not notchDragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - notchDragStart
            if delta.Magnitude > 4 then notchMoved = true end
            local view = screen.AbsoluteSize
            local curX = notchStartPos.X.Scale * view.X + notchStartPos.X.Offset + delta.X
            curX = math.clamp(curX, 70, view.X - 70)
            NotchBar.Position = UDim2.new(0, curX, 0, 0)
        end
    end)
    bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if notchDragging then
                notchDragging = false
                if not notchMoved then
                    Library:visible()
                end
            end
        end
    end)

    local function updateToggleVisibility()
        local isMobileUser = (Library.IsMobile ~= nil) and Library.IsMobile or IsMobile
        local enabled = Library.ToggleBarEnabled and (Library.ToggleBarStyle ~= "Disabled")
        local platformMatch = false
        if Library.ToggleBarPlatform == "Both" then
            platformMatch = true
        elseif Library.ToggleBarPlatform == "Mobile Only" or Library.ToggleBarPlatform == "Mobile" then
            platformMatch = isMobileUser
        elseif Library.ToggleBarPlatform == "PC Only" then
            platformMatch = not isMobileUser
        end
        local active = enabled and platformMatch
        if ToggleBtn then
            ToggleBtn.Visible = active and (Library.ToggleBarStyle == "Floating Button")
        end
        if NotchBar then
            NotchBar.Visible = active and (Library.ToggleBarStyle == "Top Notch")
        end
    end
    Library.UpdateToggleBarVisibility = updateToggleVisibility
    updateToggleVisibility()

    local modalData = {
        actionButtons = {},
        linkRows = {},
        metricTiles = {}
    }
    local function updateHUDThemes()
        local cContainer = genv.uicontainer or Color3.fromRGB(19, 20, 24)
        local cLine = genv.uiline or Color3.fromRGB(34, 35, 42)
        local cAccent = genv.accent or Color3.fromRGB(59, 130, 246)
        local cShadow = genv.shadowcolor or Color3.fromRGB(0, 0, 0)

        if Container then
            Container.BackgroundColor3 = cContainer
            local cStroke = Container:FindFirstChildOfClass("UIStroke")
            if cStroke then cStroke.Color = cLine end
        end
        if Shadow then
            Shadow.ImageColor3 = cShadow
        end
        if ToggleBtn then
            ToggleBtn.BackgroundColor3 = cContainer
            local tStroke = ToggleBtn:FindFirstChildOfClass("UIStroke")
            if tStroke then tStroke.Color = cAccent end
        end
        if NotchBar then
            NotchBar.BackgroundColor3 = cContainer
            if notchStroke then notchStroke.Color = cAccent end
            if notchDot then notchDot.BackgroundColor3 = cAccent end
        end
        if watermark then
            watermark.BackgroundColor3 = cContainer
            if wmStroke then wmStroke.Color = cLine end
            if wmDiv1 then wmDiv1.BackgroundColor3 = cLine end
            if wmDiv2 then wmDiv2.BackgroundColor3 = cLine end
            if wmDiv3 then wmDiv3.BackgroundColor3 = cLine end
            if wmPingIcon then wmPingIcon.ImageColor3 = cAccent end
            if wmFpsIcon then wmFpsIcon.ImageColor3 = cAccent end
            if wmPlrIcon then wmPlrIcon.ImageColor3 = cAccent end
            if wmPlrBtn then wmPlrBtn.BackgroundColor3 = cContainer end
        end
        if modalData.infoModal then
            modalData.infoModal.BackgroundColor3 = cContainer
            if modalData.modalStroke then modalData.modalStroke.Color = cAccent end
            if modalData.modalScroll then modalData.modalScroll.ScrollBarImageColor3 = cAccent end
        end
        local cardBg = cContainer:lerp(WHITE, 0.04)
        local rowBg = cContainer:lerp(WHITE, 0.06)
        if modalData.commCard then
            modalData.commCard.BackgroundColor3 = cardBg
            if modalData.commStroke then modalData.commStroke.Color = cLine end
            if modalData.commHeaderIcon then modalData.commHeaderIcon.ImageColor3 = cAccent end
        end
        if modalData.gameCard then
            modalData.gameCard.BackgroundColor3 = cardBg
            if modalData.gameStroke then modalData.gameStroke.Color = cLine end
            if modalData.gameHeaderIcon then modalData.gameHeaderIcon.ImageColor3 = cAccent end
            if modalData.plrCount then modalData.plrCount.TextColor3 = cAccent end
            if modalData.plrBadge then modalData.plrBadge.BackgroundColor3 = rowBg end
            if modalData.gameIcon then
                local gStrk = modalData.gameIcon:FindFirstChildOfClass("UIStroke")
                if gStrk then gStrk.Color = cLine end
            end
        end
        if modalData.perfCard then
            modalData.perfCard.BackgroundColor3 = cardBg
            if modalData.perfStroke then modalData.perfStroke.Color = cLine end
            if modalData.perfHeaderIcon then modalData.perfHeaderIcon.ImageColor3 = cAccent end
        end
        for _, lr in ipairs(modalData.linkRows) do
            if lr.row then lr.row.BackgroundColor3 = rowBg end
            if lr.rowStrk then lr.rowStrk.Color = cLine end
            if lr.icon then lr.icon.ImageColor3 = cAccent end
            if lr.copyBtn and lr.copyStrk then lr.copyStrk.Color = cLine end
        end
        for _, ab in ipairs(modalData.actionButtons) do
            if ab.btn then ab.btn.BackgroundColor3 = rowBg end
            if ab.btnStrk then ab.btnStrk.Color = cLine end
            if ab.icon then ab.icon.ImageColor3 = Color3.fromRGB(180, 182, 195) end
        end
        for _, mt in ipairs(modalData.metricTiles) do
            if mt.tile then mt.tile.BackgroundColor3 = rowBg end
            if mt.stroke then mt.stroke.Color = cLine end
            if mt.icon then mt.icon.ImageColor3 = cAccent end
        end
        if bar1 then
            bar1.BackgroundColor3 = cAccent
            bar2.BackgroundColor3 = cAccent
            bar3.BackgroundColor3 = cAccent
            bar4.BackgroundColor3 = cAccent
        end
        if nearbyFrame then
            nearbyFrame.BackgroundColor3 = cContainer
            if nearbyStroke then nearbyStroke.Color = cLine end
            if nearbySep then nearbySep.BackgroundColor3 = cLine end
        end
        if keybindList then
            keybindList.BackgroundColor3 = cContainer
            if kbStroke then kbStroke.Color = cLine end
            if kbLine then kbLine.BackgroundColor3 = cLine end
            if kbCountStroke then kbCountStroke.Color = cAccent end
            if kbCountText then kbCountText.TextColor3 = cAccent end
        end
        if userCard then
            userCard.BackgroundColor3 = genv.tabcolor or cContainer
            if userCardStroke then userCardStroke.Color = cLine end
        end
        if island then
            island.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            if islandStroke then islandStroke.Color = cLine end
            if restoreBtn then restoreBtn.BackgroundColor3 = cAccent end
            if expSep then expSep.BackgroundColor3 = cLine end
            if islandGameLabel then islandGameLabel.TextColor3 = cAccent end
            if fpsTileIcon then fpsTileIcon.ImageColor3 = cAccent end
            if pingTileIcon then pingTileIcon.ImageColor3 = cAccent end
            if plrTileIcon then plrTileIcon.ImageColor3 = cAccent end
            if actTileIcon then actTileIcon.ImageColor3 = cAccent end
            if islandLogo then islandLogo.ImageColor3 = WHITE end
        end
        if Library.activeNotifications then
            for notif, data in pairs(Library.activeNotifications) do
                if notif and notif.Parent and data then
                    if data.card then data.card.BackgroundColor3 = cContainer end
                    if data.stroke then data.stroke.Color = cLine end
                    if data.accentBar and (data.nType == "Info" or not data.nType) then
                        data.accentBar.BackgroundColor3 = cAccent
                    end
                end
            end
        end
        if Library.UpdateKeybindList then
            Library:UpdateKeybindList()
        end
    end
    Library.UpdateHUDThemes = updateHUDThemes

    local sessionStart = tick()
    local frames, fpsClock, currentFps = 0, tick(), 60
    bind(RunService.RenderStepped, function()
        frames += 1
        local now = tick()
        if now - fpsClock >= 0.5 then
            currentFps = math.floor(frames / (now - fpsClock) + 0.5)
            frames = 0
            fpsClock = now
        end
        if islandMascot and islandMascot.Parent then
            islandMascot.Rotation = math.sin(now * 3.5) * 8
            islandMascot.Position = UDim2.new(0, 0, 0.5, math.sin(now * 6) * 1.5)
        end

    end)

    task.spawn(function()
        while screen and screen.Parent do
            local elapsed = math.floor(tick() - sessionStart)
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            local timeStr = mins .. "m " .. secs .. "s"
            islandSession.Text = timeStr

            local ping = 0
            local okPing, pVal = pcall(function()
                return math.floor(LocalPlayer:GetNetworkPing() * 1000)
            end)
            if okPing and pVal and pVal > 0 then
                ping = pVal
            else
                local okStat, sVal = pcall(function()
                    return math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
                if okStat and sVal then ping = sVal end
            end

            local activeCount = 0
            for _, val in pairs(Library.Flags) do
                if val == true then activeCount += 1 end
            end

            local playerCount = #Players:GetPlayers()

            if islandStats then
                islandStats.Text = currentFps .. " fps  •  " .. ping .. " ms"
            end
            islandFpsVal.Text = string.format("<font color=\"#8e92a4\">FPS</font>  <font color=\"#ffffff\"><b>%d</b></font>", currentFps)
            islandPingVal.Text = string.format("<font color=\"#8e92a4\">Ping</font>  <font color=\"#ffffff\"><b>%d</b><font color=\"#8e92a4\"> ms</font></font>", ping)
            islandPlrVal.Text = string.format("<font color=\"#8e92a4\">Plrs</font>  <font color=\"#ffffff\"><b>%d</b></font>", playerCount)
            islandActiveVal.Text = string.format("<font color=\"#8e92a4\">Active</font>  <font color=\"#ffffff\"><b>%d</b></font>", activeCount)

            wmPingText.Text = string.format("<font color=\"#ffffff\"><b>%d</b></font> <font color=\"#8e92a4\">ms</font>", ping)

            local pingLevel = 4
            if ping > 200 then pingLevel = 1
            elseif ping > 140 then pingLevel = 2
            elseif ping > 80 then pingLevel = 3
            else pingLevel = 4 end
            local cAcc = genv.accent or Color3.fromRGB(168, 85, 247)
            local cDim = Color3.fromRGB(60, 64, 76)
            if bar1 and bar1.Parent then
                bar1.BackgroundColor3 = pingLevel >= 1 and cAcc or cDim
                bar2.BackgroundColor3 = pingLevel >= 2 and cAcc or cDim
                bar3.BackgroundColor3 = pingLevel >= 3 and cAcc or cDim
                bar4.BackgroundColor3 = pingLevel >= 4 and cAcc or cDim
                bar1.BackgroundTransparency = pingLevel >= 1 and 0 or 0.6
                bar2.BackgroundTransparency = pingLevel >= 2 and 0 or 0.6
                bar3.BackgroundTransparency = pingLevel >= 3 and 0 or 0.6
                bar4.BackgroundTransparency = pingLevel >= 4 and 0 or 0.6
            end
            wmFpsText.Text = string.format("<font color=\"#ffffff\"><b>%d</b></font> <font color=\"#8e92a4\">fps</font>", currentFps)
            wmPlrText.Text = string.format("<font color=\"#ffffff\"><b>%d</b></font> <font color=\"#8e92a4\">players</font>", playerCount)

            local dotColor = (currentFps >= 45 and ping <= 120) and SUCCESS_COLOR or ((currentFps >= 25) and WARNING_COLOR or ERROR_COLOR)
            islandDot.BackgroundColor3 = dotColor

            if nearbyFrame and nearbyFrame.Visible then
                updateNearbyPlayers()
            end

            if modalData.infoModal and modalData.infoModal.Visible then
                if modalData.pingVal then modalData.pingVal.Text = ping .. " ms" end
                if modalData.fpsVal then modalData.fpsVal.Text = currentFps .. " fps" end
                if modalData.memVal then
                    local okMem, mVal = pcall(function() return math.floor(StatsService:GetTotalMemoryUsageMb()) end)
                    if okMem and mVal then modalData.memVal.Text = mVal .. " MB" end
                end
                if modalData.plrCount then
                    modalData.plrCount.Text = playerCount .. "/" .. Players.MaxPlayers .. " Players"
                end
            end

            task.wait(0.5)
        end
    end)

    local hideTween = TweenInfo.new(0.35, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut)
    local function setHidden(state)
        Library.hidden = state
        Library.enabled = not state
        if not state then
            MainHolder.Visible = true
            TweenService:Create(mainScale, hideTween, {Scale = Library.UIScale or 1}):Play()
            if nearbyFrame then nearbyFrame.Visible = false end
        else
            local tw = TweenService:Create(mainScale, hideTween, {Scale = 0})
            tw:Play()
            tw.Completed:Connect(function()
                if Library.hidden then
                    MainHolder.Visible = false
                end
            end)
        end
        if Library.IslandEnabled then
            island.Visible = state
            if state then
                if Library.IslandStyle == "Always Show" then
                    setIslandExpanded(true)
                else
                    setIslandExpanded(false)
                end
            end
        else
            island.Visible = false
        end
        if Library.UpdateKeybindList then
            Library:UpdateKeybindList()
        end
    end
    Library.setHidden = setHidden

    bindTap(minimizeBtn, function()
        setHidden(true)
    end)
    bindTap(closeBtn, function()
        Library:disconnect()
        pcall(function() screen:Destroy() end)
    end)
    bindTap(restoreBtn, function()
        setHidden(false)
    end)

    bind(UserInputService.InputEnded, function(input)
        local tap = Library.activeTaps[input]
        if tap then
            Library.activeTaps[input] = nil
            if (input.Position - tap.pos).Magnitude < 12 then
                tap.fire(tap.pos)
            end
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Library.dragging = false
            Library.drag_position = nil
            Library.start_position = nil
        end
    end)

    local dragInput
    local function beginDrag(input)
        if Library.slider_drag then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Library.dragging = true
        dragInput = input
        Library.drag_position = input.Position
        Library.start_position = MainHolder.Position
    end

    Top.InputBegan:Connect(beginDrag)
    Container.InputBegan:Connect(beginDrag)

    bind(UserInputService.InputChanged, function(input)
        if not Library.dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
        elseif input.UserInputType == Enum.UserInputType.Touch then
            if input ~= dragInput then return end
        else
            return
        end
        if not Library.drag_position or not Library.start_position then return end
        local delta = input.Position - Library.drag_position
        local start = Library.start_position
        local position = UDim2.new(start.X.Scale, start.X.Offset + delta.X, start.Y.Scale, start.Y.Offset + delta.Y)
        MainHolder.Position = position
    end)

    bind(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if not Library.exist() then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local chosenKey = Library.Flags.toggleui or "H"
        local keyName = (typeof(chosenKey) == "EnumItem" and chosenKey.Name) or tostring(chosenKey)
        if input.KeyCode.Name == keyName then
            setHidden(not Library.hidden)
        end
    end)



    local tabs = new("ScrollingFrame", {
        Name = "Tabs",
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.new(0, 10, 0.0915492922, 0),
        Size = UDim2.new(0.21, -10, 0.72, 0),
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ZIndex = 10,
    }, Container)

    local tabsLayout = new("UIListLayout", {
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, tabs)
    new("UIPadding", {PaddingTop = UDim.new(0, 15)}, tabs)
    corner(tabs, 8)

    tabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local need = tabsLayout.AbsoluteContentSize.Y + 20
        tabs.CanvasSize = UDim2.new(0, 0, 0, math.max(need, tabs.AbsoluteSize.Y))
        tabs.ScrollingEnabled = need > tabs.AbsoluteSize.Y
    end)

    local userCard = new("TextButton", {
        Name = "UserCard",
        BackgroundColor3 = genv.tabcolor or genv.uicontainer or Color3.fromRGB(22, 23, 29),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Position = UDim2.new(0, 10, 1, -68),
        Size = UDim2.new(0.21, -10, 0, 56),
        ZIndex = 2,
    }, Container)
    table.insert(genv.UIElements, userCard)
    corner(userCard, 9)
    local userCardStroke = stroke(userCard, genv.uiline or Color3.fromRGB(36, 38, 48), 1, 0.5)

    local avatar = new("ImageLabel", {
        Name = "Avatar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.new(0, 32, 0, 32),
        BackgroundColor3 = Color3.fromRGB(18, 19, 24),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, userCard)
    corner(avatar, 8)
    stroke(avatar, Color3.fromRGB(44, 46, 58), 1, 0.6)

    local nickLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 48, 0.36, 0),
        Size = UDim2.new(1, -72, 0, 14),
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = Color3.fromRGB(240, 242, 248),
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = LocalPlayer.DisplayName,
        ZIndex = 3,
    }, userCard)
    nickLabel:SetAttribute("ThemeText", true)
    table.insert(genv.UIElements, nickLabel)

    local userTagLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 48, 0.68, 0),
        Size = UDim2.new(1, -72, 0, 12),
        FontFace = font(Enum.FontWeight.Regular),
        TextColor3 = Color3.fromRGB(140, 144, 158),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "@" .. LocalPlayer.Name,
        ZIndex = 3,
    }, userCard)

    local userChevron = new("ImageLabel", {
        Name = "UserChevron",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Image = "rbxassetid://92473583511724",
        ImageColor3 = Color3.fromRGB(120, 124, 138),
        ZIndex = 3,
    }, userCard)

    userCard.MouseEnter:Connect(function()
        local baseCol = genv.tabcolor or genv.uicontainer or Color3.fromRGB(22, 23, 29)
        TweenService:Create(userCard, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = baseCol:lerp(WHITE, 0.08)}):Play()
        if userCardStroke then
            TweenService:Create(userCardStroke, TweenInfo.new(0.2), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0.2}):Play()
        end
        TweenService:Create(userChevron, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position = UDim2.new(1, -7, 0.5, 0), ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247)}):Play()
    end)

    userCard.MouseLeave:Connect(function()
        local baseCol = genv.tabcolor or genv.uicontainer or Color3.fromRGB(22, 23, 29)
        TweenService:Create(userCard, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = baseCol}):Play()
        if userCardStroke then
            TweenService:Create(userCardStroke, TweenInfo.new(0.2), {Color = genv.uiline or Color3.fromRGB(36, 38, 48), Transparency = 0.5}):Play()
        end
        TweenService:Create(userChevron, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = UDim2.new(1, -10, 0.5, 0), ImageColor3 = Color3.fromRGB(120, 124, 138)}):Play()
    end)

    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and content then avatar.Image = content end
    end)

    local function initModal()
        local isModalOpen = false
        local infoModalOverlay = new("TextButton", {
            Name = "InfoModalOverlay",
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            Text = "",
            AutoButtonColor = false,
            Visible = false,
            ZIndex = 890,
        }, screen)

        local infoModal = new("Frame", {
            Name = "InfoModal",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = genv.uicontainer or Color3.fromRGB(19, 20, 25),
            BorderSizePixel = 0,
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 520, 0, 396),
            Visible = false,
            ClipsDescendants = true,
            ZIndex = 891,
        }, screen)
        table.insert(genv.UIElements, infoModal)
        corner(infoModal, 14)
        modalData.infoModal = infoModal
        modalData.modalStroke = stroke(infoModal, genv.accent or Color3.fromRGB(60, 62, 78), 1, 0.35)

        local modalScale = new("UIScale", {
            Scale = 0.88,
        }, infoModal)
        modalData.modalScale = modalScale

        openInfoModal = function()
            if isModalOpen then return end
            isModalOpen = true
            if updateHUDThemes then updateHUDThemes() end
            infoModalOverlay.Visible = true
            infoModal.Visible = true
            modalScale.Scale = 0.88
            infoModalOverlay.BackgroundTransparency = 1
            TweenService:Create(infoModalOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.45}):Play()
            TweenService:Create(modalScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end

        closeInfoModal = function()
            if not isModalOpen then return end
            isModalOpen = false
            local twO = TweenService:Create(infoModalOverlay, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 1})
            local twM = TweenService:Create(modalScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Scale = 0.88})
            twO:Play()
            twM:Play()
            twM.Completed:Connect(function()
                if not isModalOpen then
                    infoModal.Visible = false
                    infoModalOverlay.Visible = false
                end
            end)
        end

        infoModalOverlay.MouseButton1Click:Connect(closeInfoModal)
        userCard.MouseButton1Click:Connect(openInfoModal)
        userCard.TouchTap:Connect(openInfoModal)

        UserInputService.InputBegan:Connect(function(input)
            if not isModalOpen then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local mousePos = input.Position
                local modalPos = infoModal.AbsolutePosition
                local modalSize = infoModal.AbsoluteSize
                if mousePos.X < modalPos.X or mousePos.X > modalPos.X + modalSize.X
                    or mousePos.Y < modalPos.Y or mousePos.Y > modalPos.Y + modalSize.Y then
                    closeInfoModal()
                end
            end
        end)

        local modalHeader = new("Frame", {
            Name = "ModalHeader",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 16, 0, 10),
            Size = UDim2.new(1, -32, 0, 42),
            ZIndex = 892,
        }, infoModal)

        local modalAvatar = new("ImageLabel", {
            Name = "ModalAvatar",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(0, 36, 0, 36),
            BackgroundColor3 = Color3.fromRGB(28, 30, 38),
            BorderSizePixel = 0,
            ZIndex = 893,
        }, modalHeader)
        corner(modalAvatar, 8)
        stroke(modalAvatar, genv.uiline or Color3.fromRGB(44, 46, 58), 1, 0.5)

        task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and content then modalAvatar.Image = content end
        end)

        new("TextLabel", {
            Name = "ModalNick",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 46, 0, 2),
            Size = UDim2.new(1, -190, 0, 18),
            FontFace = font(Enum.FontWeight.Bold),
            TextColor3 = WHITE,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = LocalPlayer.DisplayName,
            ZIndex = 893,
        }, modalHeader)

        new("TextLabel", {
            Name = "ModalTag",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 46, 0, 20),
            Size = UDim2.new(1, -190, 0, 14),
            FontFace = font(Enum.FontWeight.Regular),
            TextColor3 = Color3.fromRGB(150, 154, 168),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "@" .. LocalPlayer.Name,
            ZIndex = 893,
        }, modalHeader)

        local modalOnlinePill = new("Frame", {
            Name = "OnlinePill",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -38, 0.5, 0),
            Size = UDim2.new(0, 68, 0, 22),
            BackgroundColor3 = Color3.fromRGB(18, 34, 24),
            BorderSizePixel = 0,
            ZIndex = 893,
        }, modalHeader)
        corner(modalOnlinePill, 11)
        stroke(modalOnlinePill, Color3.fromRGB(34, 197, 94), 1, 0.5)

        local onlineDot = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.new(0, 6, 0, 6),
            BackgroundColor3 = Color3.fromRGB(34, 197, 94),
            BorderSizePixel = 0,
            ZIndex = 894,
        }, modalOnlinePill)
        corner(onlineDot, 3)

        new("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 18, 0.5, 0),
            Size = UDim2.new(1, -22, 1, 0),
            FontFace = font(Enum.FontWeight.Medium),
            TextColor3 = Color3.fromRGB(74, 222, 128),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Online",
            ZIndex = 894,
        }, modalOnlinePill)

        local modalClose = new("TextButton", {
            Name = "ModalClose",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 26, 0, 26),
            BackgroundColor3 = Color3.fromRGB(27, 28, 36),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            FontFace = font(Enum.FontWeight.Bold),
            TextColor3 = Color3.fromRGB(170, 172, 185),
            TextSize = 13,
            Text = "X",
            ZIndex = 893,
        }, modalHeader)
        corner(modalClose, 7)
        stroke(modalClose, Color3.fromRGB(45, 47, 60), 1, 0.5)
        modalClose.MouseEnter:Connect(function()
            TweenService:Create(modalClose, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(220, 38, 38), TextColor3 = WHITE}):Play()
        end)
        modalClose.MouseLeave:Connect(function()
            local baseCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.05)
            TweenService:Create(modalClose, TweenInfo.new(0.2), {BackgroundColor3 = baseCol, TextColor3 = Color3.fromRGB(170, 172, 185)}):Play()
        end)
        bindTap(modalClose, closeInfoModal)

        new("Frame", {
            BackgroundColor3 = genv.uiline or Color3.fromRGB(34, 35, 45),
            BorderSizePixel = 0,
            Position = UDim2.new(0, 16, 0, 56),
            Size = UDim2.new(1, -32, 0, 1),
            ZIndex = 892,
        }, infoModal)

        local modalScroll = new("ScrollingFrame", {
            Name = "ModalScroll",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 14, 0, 62),
            Size = UDim2.new(1, -28, 1, -68),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
            ZIndex = 892,
        }, infoModal)
        modalData.modalScroll = modalScroll

        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 9),
        }, modalScroll)
        new("UIPadding", {
            PaddingBottom = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 4),
        }, modalScroll)

        do
            local modalCommCard = new("Frame", {
                Name = "CommunityCard",
                BackgroundColor3 = Color3.fromRGB(24, 25, 33),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 1,
                ZIndex = 893,
            }, modalScroll)
            corner(modalCommCard, 10)
            modalData.commCard = modalCommCard
            modalData.commStroke = stroke(modalCommCard, genv.uiline or Color3.fromRGB(36, 38, 48), 1, 0.5)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 9),
                PaddingBottom = UDim.new(0, 9),
                PaddingLeft = UDim.new(0, 11),
                PaddingRight = UDim.new(0, 11),
            }, modalCommCard)

            new("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 7),
            }, modalCommCard)

            local commTitleRow = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                LayoutOrder = 1,
                ZIndex = 894,
            }, modalCommCard)
            modalData.commHeaderIcon = new("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 13, 0, 13),
                BackgroundTransparency = 1,
                Image = "rbxassetid://114238209622913",
                ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
                ZIndex = 894,
            }, commTitleRow)
            new("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 18, 0.5, 0),
                Size = UDim2.new(1, -18, 1, 0),
                FontFace = font(Enum.FontWeight.Bold),
                TextColor3 = WHITE,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "Community & Official Resources",
                ZIndex = 894,
            }, commTitleRow)

            local discordLink = options.Discord or (type(options.Home) == "table" and options.Home.Discord) or genv.discord or "discord.gg/moondiety"
            local websiteLink = options.Website or (type(options.Home) == "table" and options.Home.Website) or genv.website or "moondiety.com"

            local dRow = new("Frame", {
                BackgroundColor3 = Color3.fromRGB(28, 30, 40),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 48),
                LayoutOrder = 2,
                ZIndex = 894,
            }, modalCommCard)
            corner(dRow, 8)
            local dRowStrk = stroke(dRow, genv.uiline or Color3.fromRGB(40, 42, 54), 1, 0.6)

            local dIcon = new("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 10, 0.5, 0),
                Size = UDim2.new(0, 22, 0, 22),
                BackgroundTransparency = 1,
                Image = "rbxassetid://9750871469",
                ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
                ZIndex = 895,
            }, dRow)

            task.spawn(function()
                local tw = TweenService:Create(dIcon, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {ImageTransparency = 0.3})
                tw:Play()
            end)

            local dWobbling = false
            local function wobbleDiscord()
                if dWobbling then return end
                dWobbling = true
                task.spawn(function()
                    local w1 = TweenService:Create(dIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 14, Size = UDim2.new(0, 24, 0, 24)})
                    w1:Play()
                    w1.Completed:Wait()
                    local w2 = TweenService:Create(dIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = -12})
                    w2:Play()
                    w2.Completed:Wait()
                    local w3 = TweenService:Create(dIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 8})
                    w3:Play()
                    w3.Completed:Wait()
                    local w4 = TweenService:Create(dIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = -4})
                    w4:Play()
                    w4.Completed:Wait()
                    local w5 = TweenService:Create(dIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Rotation = 0, Size = UDim2.new(0, 22, 0, 22)})
                    w5:Play()
                    w5.Completed:Wait()
                    dWobbling = false
                end)
            end

            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 40, 0, 4),
                Size = UDim2.new(1, -120, 0, 14),
                FontFace = font(Enum.FontWeight.Bold),
                TextColor3 = WHITE,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "Official Discord",
                ZIndex = 895,
            }, dRow)

            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 40, 0, 18),
                Size = UDim2.new(1, -120, 0, 13),
                FontFace = font(Enum.FontWeight.Regular),
                TextColor3 = Color3.fromRGB(150, 154, 168),
                TextSize = 10,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = discordLink,
                ZIndex = 895,
            }, dRow)

            local dStatsRow = new("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 40, 0, 32),
                Size = UDim2.new(1, -120, 0, 12),
                ZIndex = 895,
            }, dRow)

            local dDot = new("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 5, 0, 5),
                BackgroundColor3 = Color3.fromRGB(34, 197, 94),
                BorderSizePixel = 0,
                ZIndex = 896,
            }, dStatsRow)
            corner(dDot, 3)

            local dStatsLabel = new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 9, 0, 0),
                Size = UDim2.new(1, -9, 1, 0),
                FontFace = font(Enum.FontWeight.Medium),
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                RichText = true,
                Text = discordFetched and string.format("<font color=\"#4ade80\"><b>%s</b></font>  <font color=\"#64748b\">•</font>  <font color=\"#cbd5e1\">%s</font>", discordOnlineCountStr, discordMemberCountStr) or "<font color=\"#4ade80\"><b>Join</b></font>  <font color=\"#64748b\">•</font>  <font color=\"#cbd5e1\">Official Community</font>",
                ZIndex = 896,
            }, dStatsRow)
            modalData.discordStatsLabel = dStatsLabel

            table.insert(discordStatsListeners, function(members, online)
                if dStatsLabel and dStatsLabel.Parent then
                    dStatsLabel.Text = string.format("<font color=\"#4ade80\"><b>%s</b></font>  <font color=\"#64748b\">•</font>  <font color=\"#cbd5e1\">%s</font>", online, members)
                end
            end)
            fetchDiscordStats(discordLink)

            local dCopyBtn = new("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0, 78, 0, 26),
                BackgroundColor3 = Color3.fromRGB(34, 36, 48),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                ZIndex = 895,
            }, dRow)
            corner(dCopyBtn, 7)
            local dCopyStrk = stroke(dCopyBtn, genv.uiline or Color3.fromRGB(50, 52, 68), 1, 0.5)

            local dCopyIcon = new("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.new(0, 12, 0, 12),
                BackgroundTransparency = 1,
                Image = "rbxassetid://78979572434545",
                ImageColor3 = WHITE,
                ZIndex = 896,
            }, dCopyBtn)

            local dCopyLabel = new("TextLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 24, 0.5, 0),
                Size = UDim2.new(1, -26, 1, 0),
                BackgroundTransparency = 1,
                FontFace = font(Enum.FontWeight.Medium),
                TextColor3 = WHITE,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "Copy",
                ZIndex = 896,
            }, dCopyBtn)

            dRow.MouseEnter:Connect(function()
                local hoverCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.1)
                TweenService:Create(dRow, TweenInfo.new(0.15), {BackgroundColor3 = hoverCol}):Play()
                if dRowStrk then TweenService:Create(dRowStrk, TweenInfo.new(0.15), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0.4}):Play() end
                wobbleDiscord()
            end)
            dRow.MouseLeave:Connect(function()
                local baseCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.06)
                TweenService:Create(dRow, TweenInfo.new(0.2), {BackgroundColor3 = baseCol}):Play()
                if dRowStrk then TweenService:Create(dRowStrk, TweenInfo.new(0.2), {Color = genv.uiline or Color3.fromRGB(40, 42, 54), Transparency = 0.6}):Play() end
            end)
            dRow.TouchTap:Connect(wobbleDiscord)

            dCopyBtn.MouseEnter:Connect(function()
                TweenService:Create(dCopyBtn, TweenInfo.new(0.15), {BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247)}):Play()
            end)
            dCopyBtn.MouseLeave:Connect(function()
                if dCopyLabel.Text == "Copy" then
                    local baseCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.09)
                    TweenService:Create(dCopyBtn, TweenInfo.new(0.2), {BackgroundColor3 = baseCol}):Play()
                end
            end)
            bindTap(dCopyBtn, function()
                if copyclipboard then pcall(copyclipboard, discordLink) end
                dCopyLabel.Text = "Copied!"
                dCopyLabel.TextColor3 = Color3.fromRGB(74, 222, 128)
                dCopyIcon.Image = "rbxassetid://134724289526879"
                dCopyIcon.ImageColor3 = Color3.fromRGB(74, 222, 128)
                dCopyBtn.BackgroundColor3 = Color3.fromRGB(24, 48, 32)
                if dCopyStrk then dCopyStrk.Color = Color3.fromRGB(34, 197, 94) end
                Library:Notify({
                    Title = "Link Copied",
                    Content = "Copied Official Discord to clipboard",
                    Duration = 2.5,
                    Type = "Success",
                })
                task.delay(1.5, function()
                    if dCopyBtn and dCopyBtn.Parent then
                        dCopyLabel.Text = "Copy"
                        dCopyLabel.TextColor3 = WHITE
                        dCopyIcon.Image = "rbxassetid://78979572434545"
                        dCopyIcon.ImageColor3 = WHITE
                        dCopyBtn.BackgroundColor3 = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.09)
                        if dCopyStrk then dCopyStrk.Color = genv.uiline or Color3.fromRGB(50, 52, 68) end
                    end
                end)
            end)

            table.insert(modalData.linkRows, {row = dRow, rowStrk = dRowStrk, icon = dIcon, copyBtn = dCopyBtn, copyStrk = dCopyStrk})

            local wRow = new("Frame", {
                BackgroundColor3 = Color3.fromRGB(28, 30, 40),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 42),
                LayoutOrder = 3,
                ZIndex = 894,
            }, modalCommCard)
            corner(wRow, 8)
            local wRowStrk = stroke(wRow, genv.uiline or Color3.fromRGB(40, 42, 54), 1, 0.6)

            local wIcon = new("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 10, 0.5, 0),
                Size = UDim2.new(0, 20, 0, 20),
                BackgroundTransparency = 1,
                Image = "rbxassetid://114238209622913",
                ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
                ZIndex = 895,
            }, wRow)

            task.spawn(function()
                local tw = TweenService:Create(wIcon, TweenInfo.new(12, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
                tw:Play()
            end)

            local wWobbling = false
            local function wobbleWeb()
                if wWobbling then return end
                wWobbling = true
                task.spawn(function()
                    local w1 = TweenService:Create(wIcon, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 23, 0, 23)})
                    w1:Play()
                    w1.Completed:Wait()
                    local w2 = TweenService:Create(wIcon, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 20, 0, 20)})
                    w2:Play()
                    w2.Completed:Wait()
                    wWobbling = false
                end)
            end

            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 40, 0, 6),
                Size = UDim2.new(1, -120, 0, 15),
                FontFace = font(Enum.FontWeight.Bold),
                TextColor3 = WHITE,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "Official Website",
                ZIndex = 895,
            }, wRow)

            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 40, 0, 21),
                Size = UDim2.new(1, -120, 0, 14),
                FontFace = font(Enum.FontWeight.Regular),
                TextColor3 = Color3.fromRGB(150, 154, 168),
                TextSize = 10,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = websiteLink,
                ZIndex = 895,
            }, wRow)

            local wCopyBtn = new("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0, 78, 0, 26),
                BackgroundColor3 = Color3.fromRGB(34, 36, 48),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                ZIndex = 895,
            }, wRow)
            corner(wCopyBtn, 7)
            local wCopyStrk = stroke(wCopyBtn, genv.uiline or Color3.fromRGB(50, 52, 68), 1, 0.5)

            local wCopyIcon = new("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.new(0, 12, 0, 12),
                BackgroundTransparency = 1,
                Image = "rbxassetid://78979572434545",
                ImageColor3 = WHITE,
                ZIndex = 896,
            }, wCopyBtn)

            local wCopyLabel = new("TextLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 24, 0.5, 0),
                Size = UDim2.new(1, -26, 1, 0),
                BackgroundTransparency = 1,
                FontFace = font(Enum.FontWeight.Medium),
                TextColor3 = WHITE,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "Copy",
                ZIndex = 896,
            }, wCopyBtn)

            wRow.MouseEnter:Connect(function()
                local hoverCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.1)
                TweenService:Create(wRow, TweenInfo.new(0.15), {BackgroundColor3 = hoverCol}):Play()
                if wRowStrk then TweenService:Create(wRowStrk, TweenInfo.new(0.15), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0.4}):Play() end
                wobbleWeb()
            end)
            wRow.MouseLeave:Connect(function()
                local baseCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.06)
                TweenService:Create(wRow, TweenInfo.new(0.2), {BackgroundColor3 = baseCol}):Play()
                if wRowStrk then TweenService:Create(wRowStrk, TweenInfo.new(0.2), {Color = genv.uiline or Color3.fromRGB(40, 42, 54), Transparency = 0.6}):Play() end
            end)
            wRow.TouchTap:Connect(wobbleWeb)

            wCopyBtn.MouseEnter:Connect(function()
                TweenService:Create(wCopyBtn, TweenInfo.new(0.15), {BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247)}):Play()
            end)
            wCopyBtn.MouseLeave:Connect(function()
                if wCopyLabel.Text == "Copy" then
                    local baseCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.09)
                    TweenService:Create(wCopyBtn, TweenInfo.new(0.2), {BackgroundColor3 = baseCol}):Play()
                end
            end)
            bindTap(wCopyBtn, function()
                if copyclipboard then pcall(copyclipboard, websiteLink) end
                wCopyLabel.Text = "Copied!"
                wCopyLabel.TextColor3 = Color3.fromRGB(74, 222, 128)
                wCopyIcon.Image = "rbxassetid://134724289526879"
                wCopyIcon.ImageColor3 = Color3.fromRGB(74, 222, 128)
                wCopyBtn.BackgroundColor3 = Color3.fromRGB(24, 48, 32)
                if wCopyStrk then wCopyStrk.Color = Color3.fromRGB(34, 197, 94) end
                Library:Notify({
                    Title = "Link Copied",
                    Content = "Copied Official Website to clipboard",
                    Duration = 2.5,
                    Type = "Success",
                })
                task.delay(1.5, function()
                    if wCopyBtn and wCopyBtn.Parent then
                        wCopyLabel.Text = "Copy"
                        wCopyLabel.TextColor3 = WHITE
                        wCopyIcon.Image = "rbxassetid://78979572434545"
                        wCopyIcon.ImageColor3 = WHITE
                        wCopyBtn.BackgroundColor3 = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.09)
                        if wCopyStrk then wCopyStrk.Color = genv.uiline or Color3.fromRGB(50, 52, 68) end
                    end
                end)
            end)

            table.insert(modalData.linkRows, {row = wRow, rowStrk = wRowStrk, icon = wIcon, copyBtn = wCopyBtn, copyStrk = wCopyStrk})
        end

        do
            local modalGameCard = new("Frame", {
                Name = "GameCard",
                BackgroundColor3 = Color3.fromRGB(24, 25, 33),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
                ZIndex = 893,
            }, modalScroll)
            corner(modalGameCard, 10)
            modalData.gameCard = modalGameCard
            modalData.gameStroke = stroke(modalGameCard, genv.uiline or Color3.fromRGB(36, 38, 48), 1, 0.5)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 9),
                PaddingBottom = UDim.new(0, 9),
                PaddingLeft = UDim.new(0, 11),
                PaddingRight = UDim.new(0, 11),
            }, modalGameCard)

            new("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 7),
            }, modalGameCard)

            local gameTitleRow = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                LayoutOrder = 1,
                ZIndex = 894,
            }, modalGameCard)
            modalData.gameHeaderIcon = new("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 13, 0, 13),
                BackgroundTransparency = 1,
                Image = "rbxassetid://106482186851411",
                ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
                ZIndex = 894,
            }, gameTitleRow)
            new("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 18, 0.5, 0),
                Size = UDim2.new(1, -18, 1, 0),
                FontFace = font(Enum.FontWeight.Bold),
                TextColor3 = WHITE,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "Game & Server Details",
                ZIndex = 894,
            }, gameTitleRow)

            local gameInfoRow = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 42),
                LayoutOrder = 2,
                ZIndex = 894,
            }, modalGameCard)

            local modalGameIcon = new("ImageLabel", {
                Name = "GameThumbnail",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 38, 0, 38),
                BackgroundColor3 = Color3.fromRGB(18, 19, 25),
                BorderSizePixel = 0,
                Image = detectedGameIcon,
                ZIndex = 895,
            }, gameInfoRow)
            corner(modalGameIcon, 8)
            stroke(modalGameIcon, genv.uiline or Color3.fromRGB(44, 46, 58), 1, 0.5)
            modalData.gameIcon = modalGameIcon

            local modalGameTitle = new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 46, 0, 4),
                Size = UDim2.new(1, -165, 0, 16),
                FontFace = font(Enum.FontWeight.Bold),
                TextColor3 = WHITE,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = detectedGameName,
                ZIndex = 895,
            }, gameInfoRow)
            modalData.gameTitle = modalGameTitle

            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 46, 0, 22),
                Size = UDim2.new(1, -165, 0, 14),
                FontFace = font(Enum.FontWeight.Regular),
                TextColor3 = Color3.fromRGB(150, 154, 168),
                TextSize = 10,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "Place: " .. tostring(game.PlaceId) .. "  •  Job: " .. string.sub(game.JobId, 1, 8) .. "...",
                ZIndex = 895,
            }, gameInfoRow)

            local plrBadge = new("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.new(0, 100, 0, 24),
                BackgroundColor3 = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.08),
                BorderSizePixel = 0,
                ZIndex = 895,
            }, gameInfoRow)
            modalData.plrBadge = plrBadge
            corner(plrBadge, 6)
            stroke(plrBadge, Color3.fromRGB(44, 46, 60), 1, 0.5)

            local modalPlrCount = new("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                FontFace = font(Enum.FontWeight.Medium),
                TextColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Center,
                Text = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers) .. " Players",
                ZIndex = 896,
            }, plrBadge)
            modalData.plrCount = modalPlrCount

            table.insert(gameNameListeners, function(name, icon)
                if modalGameTitle and modalGameTitle.Parent then
                    modalGameTitle.Text = name
                end
                if modalGameIcon and modalGameIcon.Parent and icon then
                    modalGameIcon.Image = icon
                end
            end)

            local gameActionsRow = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 26),
                LayoutOrder = 3,
                ZIndex = 894,
            }, modalGameCard)
            new("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
            }, gameActionsRow)

            local function createActionButton(order, text, iconId, callback)
                local btn = new("TextButton", {
                    BackgroundColor3 = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.06),
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Size = UDim2.new(0.333, -4, 1, 0),
                    Text = "",
                    LayoutOrder = order,
                    ZIndex = 895,
                }, gameActionsRow)
                corner(btn, 6)
                local btnStrk = stroke(btn, genv.uiline or Color3.fromRGB(44, 46, 58), 1, 0.5)

                local btnIcon = new("ImageLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 8, 0.5, 0),
                    Size = UDim2.new(0, 11, 0, 11),
                    BackgroundTransparency = 1,
                    Image = iconId,
                    ImageColor3 = Color3.fromRGB(180, 182, 195),
                    ZIndex = 896,
                }, btn)

                new("TextLabel", {
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 22, 0.5, 0),
                    Size = UDim2.new(1, -24, 1, 0),
                    FontFace = font(Enum.FontWeight.Medium),
                    TextColor3 = WHITE,
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = text,
                    ZIndex = 896,
                }, btn)

                btn.MouseEnter:Connect(function()
                    local hoverCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.12)
                    TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = hoverCol}):Play()
                    if btnStrk then TweenService:Create(btnStrk, TweenInfo.new(0.15), {Color = genv.accent or Color3.fromRGB(168, 85, 247)}):Play() end
                    TweenService:Create(btnIcon, TweenInfo.new(0.15), {ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247)}):Play()
                end)
                btn.MouseLeave:Connect(function()
                    local baseCol = (genv.uicontainer or Color3.fromRGB(24, 25, 33)):lerp(WHITE, 0.06)
                    TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = baseCol}):Play()
                    if btnStrk then TweenService:Create(btnStrk, TweenInfo.new(0.2), {Color = genv.uiline or Color3.fromRGB(44, 46, 58)}):Play() end
                    TweenService:Create(btnIcon, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(180, 182, 195)}):Play()
                end)
                bindTap(btn, callback)
                table.insert(modalData.actionButtons, {btn = btn, btnStrk = btnStrk, icon = btnIcon})
                return btn
            end

            createActionButton(1, "Rejoin", "rbxassetid://138133190015277", function()
                if #Players:GetPlayers() <= 1 or game.JobId == "" then
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                else
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                end
            end)

            createActionButton(2, "Server Hop", "rbxassetid://114238209622913", function()
                task.spawn(function()
                    local ok, result = pcall(function()
                        local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100"
                        if httpRequest then
                            local res = httpRequest({Url = url, Method = "GET"})
                            return HttpService:JSONDecode(res.Body)
                        else
                            return HttpService:JSONDecode(game:HttpGet(url))
                        end
                    end)
                    if ok and result and result.data then
                        local candidates = {}
                        for _, s in ipairs(result.data) do
                            if type(s) == "table" and s.id ~= game.JobId and s.playing < s.maxPlayers then
                                table.insert(candidates, s)
                            end
                        end
                        if #candidates > 0 then
                            local target = candidates[math.random(1, #candidates)]
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer)
                            return
                        end
                    end
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end)
            end)

            createActionButton(3, "Copy Job ID", "rbxassetid://78979572434545", function()
                if copyclipboard then pcall(copyclipboard, game.JobId) end
                Library:Notify({
                    Title = "Job ID Copied",
                    Content = "Copied server Job ID to clipboard",
                    Duration = 3,
                    Type = "Success",
                })
            end)
        end

        do
            local modalPerfCard = new("Frame", {
                Name = "PerfCard",
                BackgroundColor3 = Color3.fromRGB(24, 25, 33),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 3,
                ZIndex = 893,
            }, modalScroll)
            corner(modalPerfCard, 10)
            modalData.perfCard = modalPerfCard
            modalData.perfStroke = stroke(modalPerfCard, genv.uiline or Color3.fromRGB(36, 38, 48), 1, 0.5)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 9),
                PaddingBottom = UDim.new(0, 9),
                PaddingLeft = UDim.new(0, 11),
                PaddingRight = UDim.new(0, 11),
            }, modalPerfCard)

            new("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 7),
            }, modalPerfCard)

            local perfTitleRow = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                LayoutOrder = 1,
                ZIndex = 894,
            }, modalPerfCard)
            modalData.perfHeaderIcon = new("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 13, 0, 13),
                BackgroundTransparency = 1,
                Image = "rbxassetid://94212016861936",
                ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
                ZIndex = 894,
            }, perfTitleRow)
            new("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 18, 0.5, 0),
                Size = UDim2.new(1, -18, 1, 0),
                FontFace = font(Enum.FontWeight.Bold),
                TextColor3 = WHITE,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "System Performance",
                ZIndex = 894,
            }, perfTitleRow)

            local perfGrid = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 48),
                LayoutOrder = 2,
                ZIndex = 894,
            }, modalPerfCard)
            new("UIGridLayout", {
                CellPadding = UDim2.fromOffset(6, 0),
                CellSize = UDim2.new(0.25, -5, 1, 0),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, perfGrid)

            local function createMetricTile(order, iconId, labelText, defaultVal)
                local tile = new("Frame", {
                    BackgroundColor3 = Color3.fromRGB(28, 30, 40),
                    BorderSizePixel = 0,
                    LayoutOrder = order,
                    ZIndex = 895,
                }, perfGrid)
                corner(tile, 8)
                local tileStrk = stroke(tile, genv.uiline or Color3.fromRGB(40, 42, 54), 1, 0.6)
                local tileIcon = new("ImageLabel", {
                    Position = UDim2.new(0, 6, 0, 6),
                    Size = UDim2.new(0, 12, 0, 12),
                    BackgroundTransparency = 1,
                    Image = iconId,
                    ImageColor3 = genv.accent or Color3.fromRGB(168, 85, 247),
                    ZIndex = 896,
                }, tile)
                new("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 22, 0, 6),
                    Size = UDim2.new(1, -24, 0, 12),
                    FontFace = font(Enum.FontWeight.Regular),
                    TextColor3 = Color3.fromRGB(150, 154, 168),
                    TextSize = 9,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = labelText,
                    ZIndex = 896,
                }, tile)
                local valLabel = new("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 6, 0, 20),
                    Size = UDim2.new(1, -12, 0, 22),
                    FontFace = font(Enum.FontWeight.Bold),
                    TextColor3 = WHITE,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = defaultVal,
                    ZIndex = 896,
                }, tile)
                table.insert(modalData.metricTiles, {tile = tile, stroke = tileStrk, icon = tileIcon, label = valLabel})
                return valLabel
            end

            modalData.pingVal = createMetricTile(1, "rbxassetid://78424889355261", "Ping", "0 ms")
            modalData.fpsVal = createMetricTile(2, "rbxassetid://110273524101447", "FPS", "60 fps")
            modalData.memVal = createMetricTile(3, "rbxassetid://77549309870247", "Memory", "0 MB")
            createMetricTile(4, "rbxassetid://138635884129147", "Executor", (identifyexecutor and identifyexecutor()) or "Potassium")
        end
    end
    initModal()
    local WindowController = {}
    local Tab = {}
    local tabCount = 0

    function Tab.open_tab(selfOrData, tabData)
        local data = (type(selfOrData) == "table" and (selfOrData.section or selfOrData.tab)) and selfOrData or tabData
        if not data then return end
        Tab.current_tab = data
        for _, object in ipairs(Container:GetChildren()) do
            local objName = object.Name
            if objName == "ItemsSection" or objName == "StickyLeft" or objName == "StickyRight" or objName == "StickyMerge" or objName == "ColorPalette" then
                object.Visible = false
            end
        end
        if data.section then data.section.Visible = true end

        if data.tab then
            TweenService:Create(data.tab.Fill, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
            if data.tab:FindFirstChild("TextLabel") then
                data.tab.TextLabel.TextColor3 = WHITE
                data.tab.TextLabel.FontFace = font(Enum.FontWeight.Bold)
                TweenService:Create(data.tab.TextLabel, TweenInfo.new(0.25), {TextTransparency = 0, Position = UDim2.new(0, 34, 0.5, 0)}):Play()
            end
            if data.tab:FindFirstChild("Logo") then
                data.tab.Logo.ImageColor3 = WHITE
                TweenService:Create(data.tab.Logo, TweenInfo.new(0.25), {ImageTransparency = 0, Position = UDim2.new(0, 10, 0.5, 0)}):Play()
            end
            for _, object in tabs:GetChildren() do
                if object.Name == "Tab" and object ~= data.tab then
                    TweenService:Create(object, TweenInfo.new(0.25), {BackgroundColor3 = genv.tabcolor or Color3.fromRGB(27, 28, 33)}):Play()
                    TweenService:Create(object.Fill, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
                    if object:FindFirstChild("TextLabel") then
                        object.TextLabel.TextColor3 = Color3.fromRGB(150, 155, 170)
                        object.TextLabel.FontFace = font(Enum.FontWeight.Medium)
                        TweenService:Create(object.TextLabel, TweenInfo.new(0.25), {TextTransparency = 0.55, Position = UDim2.new(0, 32, 0.5, 0)}):Play()
                    end
                    if object:FindFirstChild("Logo") then
                        object.Logo.ImageColor3 = Color3.fromRGB(150, 155, 170)
                        TweenService:Create(object.Logo, TweenInfo.new(0.25), {ImageTransparency = 0.55, Position = UDim2.new(0, 8, 0.5, 0)}):Play()
                    end
                end
            end
        end
    end

    function Tab.create_tab(selfOrName, nameOrIcon, iconId)
        local name = (type(selfOrName) == "string") and selfOrName or nameOrIcon
        local resolvedIcon = (type(selfOrName) == "string") and nameOrIcon or iconId
        local tabBtn = new("TextButton", {
            Name = "Tab",
            BackgroundColor3 = genv.tabcolor or Color3.fromRGB(27, 28, 33),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 36),
            ZIndex = 2,
            AutoButtonColor = false,
            Text = "",
        }, tabs)
        table.insert(genv.UIElements, tabBtn)
        tabBtn.ClipsDescendants = true
        corner(tabBtn, 7)
        local tabScale = new("UIScale", {Scale = 1}, tabBtn)

        local Logo = new("ImageLabel", {
            Name = "Logo",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.new(0, 16, 0, 16),
            BackgroundTransparency = 1,
            Image = "rbxassetid://" .. tostring(resolvedIcon or iconId or ""),
            ImageColor3 = Color3.fromRGB(150, 155, 170),
            ImageTransparency = 0.55,
            ZIndex = 4,
        }, tabBtn)

        local TabText = new("TextLabel", {
            Name = "TextLabel",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 32, 0.5, 0),
            Size = UDim2.new(1, -40, 0, 14),
            BackgroundTransparency = 1,
            FontFace = font(Enum.FontWeight.Medium),
            Text = name,
            TextColor3 = Color3.fromRGB(150, 155, 170),
            TextScaled = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 0.55,
            ZIndex = 4,
        }, tabBtn)

        local Fill = new("Frame", {
            Name = "Fill",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = WHITE,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 2,
        }, tabBtn)
        corner(Fill, 7)

        local gradient = new("UIGradient", {
            Name = "tabselectedcolor",
            Color = genv.tabselectedcolor,
            Rotation = 20,
        }, Fill)
        table.insert(genv.UIElements, gradient)

        local itemsSection = new("ScrollingFrame", {
            Name = "ItemsSection",
            Active = true,
            ScrollingEnabled = true,
            ClipsDescendants = true,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0.245, 0, 0.127, 0),
            Size = UDim2.new(0.74, 0, 0.87, 0),
            ScrollBarThickness = 0,
            ScrollBarImageTransparency = 1,
            ElasticBehavior = Enum.ElasticBehavior.Never,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
        }, Container)

        local GAP = 6
        local LEFT_W = 0.48993
        local RIGHT_X = 0.51007
        local ItemsList = {}
        local SCROLL_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        local function relayout(animate)
            local leftY, rightY = 0, 0
            local info = {}
            for _, e in ipairs(ItemsList) do
                if not e.hidden then
                    local t = {h = e.height}
                    if e.side == "right" then
                        t.pos = UDim2.new(RIGHT_X, 0, 0, rightY)
                        t.w = LEFT_W
                        rightY = rightY + e.height + GAP
                    elseif e.side == "middle" then
                        local y = math.max(leftY, rightY)
                        t.pos = UDim2.new(0, 0, 0, y)
                        t.w = 1
                        leftY = y + e.height + GAP
                        rightY = leftY
                    else
                        t.pos = UDim2.new(0, 0, 0, leftY)
                        t.w = LEFT_W
                        leftY = leftY + e.height + GAP
                    end
                    info[e] = t
                end
            end

            local totalY = math.max(leftY, rightY) + 6
            local windowH = itemsSection.AbsoluteWindowSize.Y
            local maxScroll = math.max(0, totalY - windowH)
            local targetScroll = math.min(itemsSection.CanvasPosition.Y, maxScroll)
            local targetCanvas = UDim2.new(0, 0, 0, totalY)

            if animate then
                TweenService:Create(itemsSection, SCROLL_TWEEN, {
                    CanvasSize = targetCanvas,
                    CanvasPosition = Vector2.new(itemsSection.CanvasPosition.X, targetScroll)
                }):Play()
            else
                itemsSection.CanvasSize = targetCanvas
                itemsSection.CanvasPosition = Vector2.new(itemsSection.CanvasPosition.X, targetScroll)
            end

            for _, e in ipairs(ItemsList) do
                local t = info[e]
                if t then
                    e.obj.Visible = true
                    local size = UDim2.new(t.w, 0, 0, t.h)
                    if animate then
                        TweenService:Create(e.obj, SCROLL_TWEEN, {Position = t.pos, Size = size}):Play()
                    else
                        e.obj.Position = t.pos
                        e.obj.Size = size
                    end
                else
                    e.obj.Visible = false
                end
            end
        end

        local function registerItem(obj, side, height, searchName)
            local itemData = {
                obj = obj,
                side = side or "left",
                height = height or ELEMENT_HEIGHT,
                searchName = string.lower(searchName or ""),
                hidden = false,
            }
            table.insert(ItemsList, itemData)
            relayout(false)
            return obj
        end

        local function updateItemHeight(obj, newHeight, animate)
            for _, e in ipairs(ItemsList) do
                if e.obj == obj then
                    e.height = newHeight
                    break
                end
            end
            if animate == nil then animate = true end
            relayout(animate)
        end

        itemsSection:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
            relayout(false)
        end)

        local function makeSticky(stickyName, x, w, z)
            local frame = new("Frame", {
                Name = stickyName,
                BackgroundColor3 = genv.uicontainer or Color3.fromRGB(22, 23, 28),
                BorderSizePixel = 0,
                Position = UDim2.new(x, 0, 0.127, 0),
                Size = UDim2.new(w, 0, 0, 24),
                ZIndex = z,
                Visible = false,
            }, Container)
            table.insert(genv.UIElements, frame)
            return frame
        end

        local stickyLayerLeft = makeSticky("StickyLeft", 0.245, 0.36255, 50)
        local stickyLayerRight = makeSticky("StickyRight", 0.62245, 0.36255, 50)
        local stickyMerge = makeSticky("StickyMerge", 0.245, 0.74, 49)
        local stickyLeftList, stickyRightList = {}, {}

        local function updateSticky(list, layer)
            if not itemsSection.Visible or not itemsSection.Parent then
                layer.Visible = false
                for _, e in ipairs(list) do e.clone.Visible = false end
                return
            end
            local secTop = itemsSection.AbsolutePosition.Y
            local anyStuck = false
            for i, entry in ipairs(list) do
                local relTop = entry.title.AbsolutePosition.Y - secTop
                local h = entry.title.AbsoluteSize.Y
                if relTop >= 0 then
                    entry.clone.Visible = false
                else
                    local pushY = 0
                    local nextEntry = list[i + 1]
                    if nextEntry then
                        local nextTop = nextEntry.title.AbsolutePosition.Y - secTop
                        if nextTop < h then pushY = nextTop - h end
                    end
                    if pushY + h <= 7 then
                        entry.clone.Visible = false
                    else
                        entry.clone.Position = UDim2.new(0, 0, 0, pushY)
                        entry.clone.Visible = true
                        anyStuck = true
                    end
                end
            end
            layer.Visible = anyStuck
        end

        bind(RunService.RenderStepped, function()
            updateSticky(stickyLeftList, stickyLayerLeft)
            updateSticky(stickyRightList, stickyLayerRight)
            stickyMerge.Visible = stickyLayerLeft.Visible and stickyLayerRight.Visible
        end)

        tabBtn.MouseEnter:Connect(function()
            if Tab.current_tab and Tab.current_tab.tab == tabBtn then
                TweenService:Create(tabScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.03}):Play()
                TweenService:Create(Logo, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 12, 0.5, 0)}):Play()
                TweenService:Create(TabText, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 36, 0.5, 0)}):Play()
                return
            end
            TweenService:Create(tabScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.02}):Play()
            TweenService:Create(tabBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = (genv.tabcolor or Color3.fromRGB(27, 28, 33)):lerp(WHITE, 0.07)}):Play()
            TweenService:Create(Logo, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 10, 0.5, 0), ImageTransparency = 0.2}):Play()
            TweenService:Create(TabText, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 34, 0.5, 0), TextTransparency = 0.2}):Play()
        end)
        tabBtn.MouseLeave:Connect(function()
            TweenService:Create(tabScale, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Scale = 1}):Play()
            if Tab.current_tab and Tab.current_tab.tab == tabBtn then
                TweenService:Create(Logo, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 10, 0.5, 0)}):Play()
                TweenService:Create(TabText, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 34, 0.5, 0)}):Play()
                return
            end
            TweenService:Create(tabBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundColor3 = genv.tabcolor or Color3.fromRGB(27, 28, 33)}):Play()
            TweenService:Create(Logo, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 8, 0.5, 0), ImageTransparency = 0.55}):Play()
            TweenService:Create(TabText, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 32, 0.5, 0), TextTransparency = 0.55}):Play()
        end)

        bindTap(tabBtn, function()
            Tab.open_tab({tab = tabBtn, section = itemsSection})
        end)

        if tabCount == 0 then
            Tab.open_tab({tab = tabBtn, section = itemsSection})
        end
        tabCount += 1

        local Module = {}

        local function resolve(arg1, arg2)
            if type(arg1) == "table" and (arg1.name or arg1.title or arg1.flag or arg1.section or arg1.callback) then
                return arg1
            end
            if type(arg2) == "table" then
                return arg2
            end
            return arg1 or {}
        end

        local function getSide(obj)
            local s = obj and obj.section
            if s == "right" then return "right" end
            if s == "middle" then return "middle" end
            return "left"
        end

        local function row(rowName, themeKey, fallback)
            local obj = new("TextButton", {
                Name = rowName,
                BackgroundColor3 = genv[themeKey] or fallback or Color3.fromRGB(27, 28, 33),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
            }, itemsSection)
            corner(obj, 10)
            table.insert(genv.UIElements, obj)

            local rScale = new("UIScale", {Scale = 1}, obj)
            obj.MouseEnter:Connect(function()
                local baseCol = genv[themeKey] or fallback or Color3.fromRGB(27, 28, 33)
                TweenService:Create(obj, TweenInfo.new(0.18, Enum.EasingStyle.Quint), {BackgroundColor3 = baseCol:lerp(WHITE, 0.06)}):Play()
                TweenService:Create(rScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.014}):Play()
            end)
            obj.MouseLeave:Connect(function()
                local baseCol = genv[themeKey] or fallback or Color3.fromRGB(27, 28, 33)
                TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = baseCol}):Play()
                TweenService:Create(rScale, TweenInfo.new(0.18, Enum.EasingStyle.Quint), {Scale = 1}):Play()
            end)
            obj.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local baseCol = genv[themeKey] or fallback or Color3.fromRGB(27, 28, 33)
                    TweenService:Create(obj, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = baseCol:lerp(WHITE, 0.1)}):Play()
                    TweenService:Create(rScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.98}):Play()
                end
            end)
            obj.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local baseCol = genv[themeKey] or fallback or Color3.fromRGB(27, 28, 33)
                    TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundColor3 = baseCol}):Play()
                    TweenService:Create(rScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
                end
            end)
            return obj
        end

        local function rowTexts(parent, rowTitle, rowDesc, rightPad)
            local hasDesc = rowDesc ~= nil and rowDesc ~= ""
            new("TextLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, hasDesc and 0.38 or 0.5, 0),
                Size = UDim2.new(1, -rightPad, 0, 14),
                FontFace = font(),
                TextColor3 = WHITE,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = rowTitle or "",
                ZIndex = 3,
            }, parent)
            if hasDesc then
                new("TextLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0.72, 0),
                    Size = UDim2.new(1, -rightPad, 0, 12),
                    FontFace = font(Enum.FontWeight.Regular),
                    TextColor3 = GRAY,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = rowDesc,
                    ZIndex = 3,
                }, parent)
            end
        end

        local function simpleLabel(parent, labelText, widthScale)
            return new("TextLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 12, 0.5, 0),
                Size = UDim2.new(widthScale or 0.4, 0, 0, 13),
                BackgroundTransparency = 1,
                FontFace = font(),
                TextColor3 = WHITE,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = labelText or "",
                ZIndex = 3,
            }, parent)
        end

        local function buildSwitch(parent)
            local Switch = new("Frame", {
                Name = "Switch",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 30, 0, 15),
                BackgroundColor3 = Color3.fromRGB(23, 23, 27),
                BorderSizePixel = 0,
                ZIndex = 3,
            }, parent)
            table.insert(genv.UIElements, Switch)
            pill(Switch)
            local Circle = new("Frame", {
                Size = UDim2.new(0, 11, 0, 11),
                Position = UDim2.new(0, 2, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = WHITE,
                BorderSizePixel = 0,
                ZIndex = 4,
            }, Switch)
            pill(Circle)
            return Switch, Circle
        end

        local function makeToggleObject(cfg, Switch, Circle)
            local obj = {state = cfg.enabled or false, callback = cfg.callback, flag = cfg.flag}
            if Library.savedFlags and type(Library.savedFlags[cfg.flag]) == "boolean" then
                obj.state = Library.savedFlags[cfg.flag]
            end

            function obj:UpdateToggle(newState, skipCallback)
                if newState ~= nil then self.state = newState else self.state = not self.state end
                Library.Flags[self.flag] = self.state
                Switch:SetAttribute("State", self.state)
                local tiStretch = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local tiSlide = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                local colorTi = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                if self.state then
                    TweenService:Create(Switch, colorTi, {BackgroundColor3 = genv.togglecoloron or genv.accent or Color3.fromRGB(168, 85, 247)}):Play()
                    TweenService:Create(Circle, tiStretch, {Size = UDim2.new(0, 14, 0, 11)}):Play()
                    TweenService:Create(Circle, tiSlide, {Position = UDim2.new(1, -13, 0.5, 0)}):Play()
                    task.delay(0.09, function()
                        if Circle and Circle.Parent then
                            TweenService:Create(Circle, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 11, 0, 11)}):Play()
                        end
                    end)
                else
                    TweenService:Create(Switch, colorTi, {BackgroundColor3 = genv.togglecoloroff or Color3.fromRGB(60, 64, 72)}):Play()
                    TweenService:Create(Circle, tiStretch, {Size = UDim2.new(0, 14, 0, 11)}):Play()
                    TweenService:Create(Circle, tiSlide, {Position = UDim2.new(0, 2, 0.5, 0)}):Play()
                    task.delay(0.09, function()
                        if Circle and Circle.Parent then
                            TweenService:Create(Circle, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 11, 0, 11)}):Play()
                        end
                    end)
                end
                Library.save_flags()
                if Library.UpdateKeybindList then Library:UpdateKeybindList() end
                if not skipCallback and self.callback then self.callback(self.state) end
            end

            function obj:GetValue() return self.state end
            function obj:SetValue(v) self:UpdateToggle(v, true) end

            Library.Flags[cfg.flag] = obj.state
            Library:RegisterObject(cfg.flag, obj)
            obj:UpdateToggle(obj.state, true)
            return obj
        end

        function Module:create_title(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local title = new("TextLabel", {
                Name = "Title",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 15),
                ZIndex = 2,
                FontFace = font(),
                TextColor3 = WHITE,
                TextScaled = true,
                TextSize = 13,
                Text = cfg.name or "",
                TextXAlignment = Enum.TextXAlignment.Left,
            }, itemsSection)
            new("UIPadding", {PaddingLeft = UDim.new(0, 4)}, title)
            registerItem(title, side, 15, cfg.name)

            if side ~= "middle" then
                local layer = side == "right" and stickyLayerRight or stickyLayerLeft
                local list = side == "right" and stickyRightList or stickyLeftList
                local clone = title:Clone()
                clone.Position = UDim2.new(0, 0, 0, 0)
                clone.Visible = false
                clone.ZIndex = 51
                clone.Parent = layer
                table.insert(list, {title = title, clone = clone})
            end
        end

        function Module:create_toggle(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local toggle = row("Toggle", "togglecolor")
            local Switch, Circle = buildSwitch(toggle)

            local rightPad = 50
            if cfg.colorpicker then rightPad = rightPad + 28 end
            if cfg.keybind then rightPad = rightPad + 56 end

            rowTexts(toggle, cfg.name, cfg.description, rightPad)
            attachTooltip(toggle, cfg.tooltip or cfg.desc)
            registerItem(toggle, side, ELEMENT_HEIGHT, cfg.name)

            local obj = makeToggleObject(cfg, Switch, Circle)

            local function addInlineKeybind(kbOpts)
                kbOpts = kbOpts or {}
                local kbFlag = kbOpts.flag or ((cfg.flag or "toggle") .. "_bind")
                local defaultKey = kbOpts.default or (kbOpts.keycode and kbOpts.keycode.Name) or "None"

                local Box = new("TextButton", {
                    Name = "InlineKeybindBox",
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -48, 0.5, 0),
                    Size = UDim2.new(0, 48, 0, 20),
                    BackgroundColor3 = genv.KeybindBox or Color3.fromRGB(24, 25, 30),
                    BorderSizePixel = 0,
                    Text = "",
                    ZIndex = 4,
                }, toggle)
                table.insert(genv.UIElements, Box)
                corner(Box, 4)
                stroke(Box, Color3.fromRGB(45, 48, 60), 1, 0.5)

                local KeyText = new("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = WHITE,
                    FontFace = font(),
                    TextSize = 10,
                    Text = defaultKey,
                    ZIndex = 5,
                }, Box)

                Library.Flags[kbFlag] = defaultKey
                Library:RegisterKeybind(kbFlag, cfg.name or kbFlag, defaultKey, function()
                    return obj:GetValue()
                end, function()
                    obj:UpdateToggle(not obj:GetValue())
                end, function()
                    obj:UpdateToggle(not obj:GetValue())
                end)

                local setting = false
                bindTap(Box, function()
                    if setting then return end
                    setting = true
                    KeyText.Text = "..."
                    local conn
                    conn = UserInputService.InputBegan:Connect(function(input)
                        local pressed = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name
                        if not pressed then return end
                        Library.Flags[kbFlag] = pressed
                        Library:UpdateKeybind(kbFlag, pressed)
                        KeyText.Text = pressed
                        setting = false
                        conn:Disconnect()
                    end)
                end)

                bind(UserInputService.InputBegan, function(input, processed)
                    if processed or setting then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == Library.Flags[kbFlag] then
                        obj:UpdateToggle()
                        if kbOpts.callback then kbOpts.callback(obj:GetValue()) end
                    end
                end)
            end

            if cfg.keybind then
                addInlineKeybind(type(cfg.keybind) == "table" and cfg.keybind or {})
            end

            function obj:AddKeybind(kbOpts)
                addInlineKeybind(kbOpts)
                return self
            end

            bindTap(toggle, function(pos)
                obj:UpdateToggle()
            end)

            return obj
        end

        function Module:create_checkbox(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local checkbox = row("Checkbox1", "tabcolor")
            checkbox.Name = "Checkbox1"

            local Checkbox = new("Frame", {
                Name = "Checkbox",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 16, 0, 16),
                BackgroundColor3 = genv.checkboxturnoff or Color3.fromRGB(22, 23, 27),
                BorderSizePixel = 0,
            }, checkbox)
            table.insert(genv.UIElements, Checkbox)
            corner(Checkbox, 4)
            local checkScale = new("UIScale", {Scale = 1}, Checkbox)

            local Glow = new("ImageLabel", {
                Name = "Glow",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 23, 0, 23),
                Image = "rbxassetid://17290798394",
                ImageTransparency = 1,
            }, Checkbox)

            local Fill = new("Frame", {
                Name = "Fill",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 16, 0, 16),
                BackgroundColor3 = WHITE,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
            }, Checkbox)
            corner(Fill, 4)

            local gradient = new("UIGradient", {
                Name = "checkboxturnon",
                Color = genv.checkboxturnon,
                Rotation = 20,
            }, Fill)
            table.insert(genv.UIElements, gradient)

            rowTexts(checkbox, cfg.name, cfg.description, 35)
            attachTooltip(checkbox, cfg.tooltip or cfg.desc)
            registerItem(checkbox, side, ELEMENT_HEIGHT, cfg.name)

            local obj = {state = cfg.enabled or false, callback = cfg.callback, flag = cfg.flag}
            if Library.savedFlags and type(Library.savedFlags[cfg.flag]) == "boolean" then
                obj.state = Library.savedFlags[cfg.flag]
            end

            function obj:UpdateToggle(newState, skipCallback)
                if newState ~= nil then self.state = newState else self.state = not self.state end
                Library.Flags[self.flag] = self.state
                local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                TweenService:Create(Fill, ti, {BackgroundTransparency = self.state and 0 or 1}):Play()
                TweenService:Create(Glow, ti, {ImageTransparency = self.state and 0 or 1}):Play()
                if self.state then
                    TweenService:Create(checkScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.18}):Play()
                    task.delay(0.1, function()
                        if Checkbox and Checkbox.Parent then
                            TweenService:Create(checkScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
                        end
                    end)
                else
                    TweenService:Create(checkScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.88}):Play()
                    task.delay(0.1, function()
                        if Checkbox and Checkbox.Parent then
                            TweenService:Create(checkScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
                        end
                    end)
                end
                Library.save_flags()
                if not skipCallback and self.callback then self.callback(self.state) end
            end

            function obj:GetValue() return self.state end
            function obj:SetValue(v) self:UpdateToggle(v, true) end

            Library.Flags[cfg.flag] = obj.state
            Library:RegisterObject(cfg.flag, obj)
            obj:UpdateToggle(obj.state, true)

            bindTap(checkbox, function()
                obj:UpdateToggle()
            end)
            return obj
        end

        function Module:create_toggle_colorpicker(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local open = false
            local cflag = (cfg.flag or "colorpicker") .. "_color"

            local toggle = row("Toggle", "togglecolor")
            local Switch, Circle = buildSwitch(toggle)
            rowTexts(toggle, cfg.name, cfg.description, 110)
            attachTooltip(toggle, cfg.tooltip or cfg.desc)

            local ColorSquare = new("Frame", {
                Name = "ColorSquare",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -50, 0.5, 0),
                Size = UDim2.new(0, 20, 0, 20),
                BackgroundColor3 = cfg.default_color or Color3.fromRGB(120, 120, 126),
                BorderSizePixel = 0,
                ZIndex = 3,
            }, toggle)
            corner(ColorSquare, 5)

            registerItem(toggle, side, ELEMENT_HEIGHT, cfg.name)

            local Palette = new("TextButton", {
                Name = "ColorPalette",
                BackgroundColor3 = genv.dropdownoptionscolor or Color3.fromRGB(22, 23, 27),
                BorderSizePixel = 0,
                Size = UDim2.new(0, 200, 0, 200),
                ZIndex = 100,
                Visible = false,
                AutoButtonColor = false,
                Text = "",
            }, Container)
            table.insert(genv.UIElements, Palette)
            corner(Palette, 8)
            stroke(Palette, genv.uiline or Color3.fromRGB(45, 45, 55), 1, 0.4)

            local HeaderRow = new("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 8),
                Size = UDim2.new(1, -16, 0, 20),
                ZIndex = 101,
            }, Palette)

            local Preview = new("Frame", {
                Name = "Preview",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 22, 0, 18),
                BackgroundColor3 = ColorSquare.BackgroundColor3,
                BorderSizePixel = 0,
                ZIndex = 102,
            }, HeaderRow)
            corner(Preview, 5)

            local HexLabel = new("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 30, 0.5, 0),
                Size = UDim2.new(1, -60, 1, 0),
                FontFace = font(),
                TextColor3 = WHITE,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "#FFFFFF",
                ZIndex = 102,
            }, HeaderRow)

            local CloseBtn = new("TextButton", {
                Name = "CloseBtn",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.new(0, 24, 0, 24),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "x",
                FontFace = font(Enum.FontWeight.Bold),
                TextColor3 = Color3.fromRGB(220, 220, 220),
                TextSize = 18,
                ZIndex = 102,
            }, HeaderRow)

            local SV = new("TextButton", {
                Name = "SV",
                Position = UDim2.new(0, 8, 0, 36),
                Size = UDim2.new(1, -16, 0, 116),
                BackgroundColor3 = Color3.fromRGB(255, 0, 0),
                BorderSizePixel = 0,
                ZIndex = 101,
                ClipsDescendants = true,
                AutoButtonColor = false,
                Text = "",
            }, Palette)
            corner(SV, 6)

            local SatOverlay = new("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = WHITE,
                BorderSizePixel = 0,
                ZIndex = 102,
            }, SV)
            new("UIGradient", {
                Color = ColorSequence.new(Color3.new(1, 1, 1)),
                Transparency = NumberSequence.new{
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1)
                },
            }, SatOverlay)

            local ValOverlay = new("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BorderSizePixel = 0,
                ZIndex = 103,
            }, SV)
            new("UIGradient", {
                Rotation = 90,
                Color = ColorSequence.new(Color3.new(0, 0, 0)),
                Transparency = NumberSequence.new{
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0)
                },
            }, ValOverlay)

            local SVCursor = new("Frame", {
                Size = UDim2.new(0, 10, 0, 10),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 104,
            }, SV)
            new("UIStroke", {Thickness = 2, Color = Color3.new(1, 1, 1)}, SVCursor)
            pill(SVCursor)

            local HueBar = new("TextButton", {
                Name = "HueBar",
                Position = UDim2.new(0, 8, 0, 162),
                Size = UDim2.new(1, -16, 0, 18),
                BackgroundColor3 = Color3.fromRGB(255, 0, 0),
                BorderSizePixel = 0,
                ZIndex = 101,
                ClipsDescendants = true,
                AutoButtonColor = false,
                Text = "",
            }, Palette)
            corner(HueBar, 6)
            new("UIGradient", {
                Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0 / 12, Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(1 / 12, Color3.fromRGB(255, 128, 0)),
                    ColorSequenceKeypoint.new(2 / 12, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(3 / 12, Color3.fromRGB(128, 255, 0)),
                    ColorSequenceKeypoint.new(4 / 12, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(5 / 12, Color3.fromRGB(0, 255, 128)),
                    ColorSequenceKeypoint.new(6 / 12, Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(7 / 12, Color3.fromRGB(0, 128, 255)),
                    ColorSequenceKeypoint.new(8 / 12, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(9 / 12, Color3.fromRGB(128, 0, 255)),
                    ColorSequenceKeypoint.new(10 / 12, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(11 / 12, Color3.fromRGB(255, 0, 128)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                },
            }, HueBar)

            local HueCursor = new("Frame", {
                Size = UDim2.new(0, 4, 1, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = WHITE,
                BorderSizePixel = 0,
                ZIndex = 102,
            }, HueBar)

            local h, s, v = 0, 1, 1

            local function refreshVisuals(skipCallback, skipSave)
                SV.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                SVCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                HueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                local c = Color3.fromHSV(h, s, v)
                local r = math.floor(c.R * 255 + 0.5)
                local g = math.floor(c.G * 255 + 0.5)
                local b = math.floor(c.B * 255 + 0.5)
                HexLabel.Text = string.format("#%02X%02X%02X", r, g, b)
                Preview.BackgroundColor3 = c
                ColorSquare.BackgroundColor3 = c
                Library.Flags[cflag] = {r, g, b}
                if not skipCallback and cfg.color_callback then cfg.color_callback(c) end
                if not skipSave then Library.save_flags() end
            end

            local function setFromColor(color)
                h, s, v = color:ToHSV()
                refreshVisuals(true, true)
            end

            local savedColor = Library.savedFlags and Library.savedFlags[cflag]
            if type(savedColor) == "table" and #savedColor >= 3 then
                setFromColor(Color3.fromRGB(savedColor[1], savedColor[2], savedColor[3]))
            else
                setFromColor(ColorSquare.BackgroundColor3)
            end

            local draggingSV, draggingHue = false, false
            local pickInput

            local function updateSV(x, y)
                local pos, size = SV.AbsolutePosition, SV.AbsoluteSize
                if size.X <= 0 or size.Y <= 0 then return end
                s = math.clamp((x - pos.X) / size.X, 0, 1)
                v = 1 - math.clamp((y - pos.Y) / size.Y, 0, 1)
                refreshVisuals(false, true)
            end

            local function updateHue(x)
                local pos, size = HueBar.AbsolutePosition, HueBar.AbsoluteSize
                if size.X <= 0 then return end
                h = math.clamp((x - pos.X) / size.X, 0, 1)
                refreshVisuals(false, true)
            end

            SV.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSV = true
                    pickInput = input
                    updateSV(input.Position.X, input.Position.Y)
                end
            end)

            HueBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingHue = true
                    pickInput = input
                    updateHue(input.Position.X)
                end
            end)

            bind(UserInputService.InputChanged, function(input)
                if not (draggingSV or draggingHue) then return end
                if input.UserInputType == Enum.UserInputType.Touch and input ~= pickInput then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    if draggingSV then
                        updateSV(input.Position.X, input.Position.Y)
                    else
                        updateHue(input.Position.X)
                    end
                end
            end)

            bind(UserInputService.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if draggingSV or draggingHue then
                        draggingSV, draggingHue = false, false
                        Library.save_flags()
                    end
                end
            end)

            local obj = makeToggleObject(cfg, Switch, Circle)
            function obj:GetColor() return Color3.fromHSV(h, s, v) end
            function obj:SetColor(c) setFromColor(c); Library.save_flags() end

            Library:RegisterObject(cflag, {
                GetValue = function() return Library.Flags[cflag] end,
                SetValue = function(_, value)
                    if type(value) == "table" and #value >= 3 then
                        setFromColor(Color3.fromRGB(value[1], value[2], value[3]))
                    end
                end,
            })

            local syncConn
            local function syncPosition()
                if not toggle.Parent then return end
                local scale = Library.UIScale or 1
                if scale <= 0 then scale = 1 end
                local tAbs, tSize = toggle.AbsolutePosition, toggle.AbsoluteSize
                local cAbs, cSize = Container.AbsolutePosition, Container.AbsoluteSize
                local px = (tAbs.X - cAbs.X + tSize.X + 8) / scale
                local py = (tAbs.Y - cAbs.Y) / scale
                local palW = Palette.AbsoluteSize.X / scale
                local palH = Palette.AbsoluteSize.Y / scale
                local contW = cSize.X / scale
                local contH = cSize.Y / scale
                if px + palW > contW - 4 then
                    px = (tAbs.X - cAbs.X) / scale - palW - 8
                end
                if px < 4 then px = 4 end
                if py + palH > contH - 4 then
                    py = contH - palH - 4
                end
                if py < 4 then py = 4 end
                Palette.Position = UDim2.fromOffset(px, py)
            end

            local function closePalette()
                open = false
                Palette.Visible = false
                if syncConn then syncConn:Disconnect(); syncConn = nil end
            end

            local function openPalette()
                open = true
                Palette.Visible = true
                syncPosition()
                if syncConn then syncConn:Disconnect() end
                syncConn = RunService.Heartbeat:Connect(function()
                    if open then syncPosition() end
                end)
            end

            bindTap(CloseBtn, closePalette)

            bindTap(toggle, function(pos)
                local overSquare = false
                if pos then
                    local a, sz = ColorSquare.AbsolutePosition, ColorSquare.AbsoluteSize
                    overSquare = pos.X >= a.X - 6 and pos.X <= a.X + sz.X + 6 and pos.Y >= a.Y - 6 and pos.Y <= a.Y + sz.Y + 6
                end
                if overSquare then
                    if open then closePalette() else openPalette() end
                else
                    if open then closePalette() else obj:UpdateToggle() end
                end
            end)

            return obj
        end

        function Module:create_note(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local accent = hexToColor(cfg.color, Color3.fromRGB(97, 62, 167))
            local STRIPE_INSET, STRIPE_W, PAD_RIGHT, PAD_Y, GAP_N = 8, 4, 12, 10, 6
            local TEXT_LEFT = STRIPE_INSET + STRIPE_W + 10

            local note = new("Frame", {
                Name = "Note",
                BackgroundColor3 = genv.tabcolor or Color3.fromRGB(27, 28, 33),
                BorderSizePixel = 0,
                ClipsDescendants = true,
            }, itemsSection)
            table.insert(genv.UIElements, note)
            corner(note, 10)

            local stripe = new("Frame", {
                Name = "Stripe",
                BackgroundColor3 = accent,
                BorderSizePixel = 0,
                Position = UDim2.new(0, STRIPE_INSET, 0, STRIPE_INSET),
                Size = UDim2.new(0, STRIPE_W, 1, -STRIPE_INSET * 2),
                ZIndex = 2,
            }, note)
            pill(stripe)

            local content = new("Frame", {
                Name = "Content",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, TEXT_LEFT, 0, PAD_Y),
                Size = UDim2.new(1, -TEXT_LEFT - PAD_RIGHT, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            }, note)

            local contentLayout = new("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, GAP_N),
            }, content)

            local titleLabel = new("TextLabel", {
                Name = "Title",
                LayoutOrder = 1,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                FontFace = font(),
                TextColor3 = genv.tabtextcolor or WHITE,
                TextSize = 17,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                Text = cfg.title or "",
                Visible = cfg.title ~= nil and cfg.title ~= "",
            }, content)
            titleLabel:SetAttribute("ThemeText", true)
            table.insert(genv.UIElements, titleLabel)

            local descLabel = new("TextLabel", {
                Name = "Description",
                LayoutOrder = 2,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                FontFace = font(Enum.FontWeight.Medium),
                TextColor3 = GRAY,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
                Text = cfg.description or "",
                Visible = cfg.description ~= nil and cfg.description ~= "",
            }, content)

            registerItem(note, side, 40, cfg.title or cfg.description)

            local lastSetH = -1
            local function applyHeight()
                local ch = content.AbsoluteSize.Y
                if not ch or ch <= 0 then return end
                local targetH = ch + PAD_Y * 2
                if math.abs(targetH - lastSetH) < 0.5 then return end
                lastSetH = targetH
                updateItemHeight(note, targetH, false)
            end

            content:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyHeight)
            contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(applyHeight)
            task.defer(applyHeight)

            local obj = {flag = cfg.flag}
            function obj:GetValue() return descLabel.Text end
            function obj:SetValue(value)
                descLabel.Text = tostring(value or "")
                descLabel.Visible = descLabel.Text ~= ""
            end
            function obj:SetTitle(value)
                titleLabel.Text = tostring(value or "")
                titleLabel.Visible = titleLabel.Text ~= ""
            end
            function obj:SetColor(hex)
                stripe.BackgroundColor3 = hexToColor(hex, accent)
            end

            if cfg.flag then Library:RegisterObject(cfg.flag, obj) end
            return obj
        end

        function Module:create_button(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local button = row("Button", "tabcolor")
            local rightPad = cfg.keybind and 56 or 20
            rowTexts(button, cfg.name, cfg.description, rightPad)
            attachTooltip(button, cfg.tooltip or cfg.desc)
            registerItem(button, side, ELEMENT_HEIGHT, cfg.name)

            local pressing = false
            local function fireButton()
                if pressing then return end
                pressing = true
                local baseColor = genv.buttoncolor or genv.originalColor or Color3.fromRGB(27, 28, 33)
                local pressedColor = baseColor:lerp(WHITE, 0.12)
                TweenService:Create(button, TweenInfo.new(0.08), {BackgroundColor3 = pressedColor}):Play()
                task.delay(0.08, function()
                    TweenService:Create(button, TweenInfo.new(0.08), {BackgroundColor3 = genv.buttoncolor or baseColor}):Play()
                    pressing = false
                end)
                if cfg.flag then
                    Library.Flags[cfg.flag] = not Library.Flags[cfg.flag]
                    Library.save_flags()
                    if cfg.callback then task.spawn(cfg.callback, Library.Flags[cfg.flag]) end
                else
                    if cfg.callback then task.spawn(cfg.callback) end
                end
            end

            bindTap(button, fireButton)

            local obj = {
                button = button,
                name = cfg.name,
                callback = cfg.callback,
            }

            local function addInlineKeybind(kbOpts)
                kbOpts = kbOpts or {}
                local kbFlag = kbOpts.flag or ((cfg.flag or cfg.name or "button") .. "_bind")
                local defaultKey = kbOpts.default or (kbOpts.keycode and kbOpts.keycode.Name) or "None"

                local Box = new("TextButton", {
                    Name = "InlineKeybindBox",
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -12, 0.5, 0),
                    Size = UDim2.new(0, 48, 0, 20),
                    BackgroundColor3 = genv.KeybindBox or Color3.fromRGB(24, 25, 30),
                    BorderSizePixel = 0,
                    Text = "",
                    ZIndex = 4,
                }, button)
                table.insert(genv.UIElements, Box)
                corner(Box, 4)
                stroke(Box, Color3.fromRGB(45, 48, 60), 1, 0.5)

                local KeyText = new("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    TextColor3 = WHITE,
                    FontFace = font(),
                    TextSize = 10,
                    Text = defaultKey,
                    ZIndex = 5,
                }, Box)

                Library.Flags[kbFlag] = defaultKey
                Library:RegisterKeybind(kbFlag, cfg.name or kbFlag, defaultKey, nil, fireButton, fireButton, true)

                local setting = false
                bindTap(Box, function()
                    if setting then return end
                    setting = true
                    KeyText.Text = "..."
                    local conn
                    conn = UserInputService.InputBegan:Connect(function(input)
                        local pressed = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name
                        if not pressed then return end
                        Library.Flags[kbFlag] = pressed
                        Library:UpdateKeybind(kbFlag, pressed)
                        KeyText.Text = pressed
                        setting = false
                        conn:Disconnect()
                    end)
                end)

                bind(UserInputService.InputBegan, function(input, processed)
                    if processed or setting then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == Library.Flags[kbFlag] then
                        fireButton()
                    end
                end)
            end

            if cfg.keybind then
                addInlineKeybind(type(cfg.keybind) == "table" and cfg.keybind or {})
            end

            function obj:AddKeybind(kbOpts)
                addInlineKeybind(kbOpts)
                return self
            end

            return obj
        end

        function Module.create_blocked_button(arg)
            local cfg = resolve(nil, arg)
            local side = getSide(cfg)
            local button = row("Button", "tabcolor")
            rowTexts(button, cfg.name or "Button", cfg.description, 20)

            local overlay = new("Frame", {
                Name = "BlockedOverlay",
                BackgroundColor3 = genv.blockedoverlay or Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 0.45,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 5,
                Active = true,
            }, button)
            table.insert(genv.UIElements, overlay)
            corner(overlay, 10)

            local lockRow = new("Frame", {
                Name = "LockRow",
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 0, 0, 18),
                AutomaticSize = Enum.AutomaticSize.X,
                ZIndex = 6,
            }, overlay)

            new("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Padding = UDim.new(0, 6),
            }, lockRow)

            local lockIcon = new("ImageLabel", {
                Name = "LockIcon",
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundTransparency = 1,
                Image = "rbxassetid://134724289526879",
                ImageColor3 = genv.blockedtext or Color3.fromRGB(210, 210, 210),
                ZIndex = 6,
            }, lockRow)
            table.insert(genv.UIElements, lockIcon)

            local lockLabel = new("TextLabel", {
                Name = "BlockedText",
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                FontFace = font(Enum.FontWeight.Medium),
                TextColor3 = genv.blockedtext or Color3.fromRGB(210, 210, 210),
                TextSize = 13,
                Text = cfg.lockText or "Locked",
                ZIndex = 6,
            }, lockRow)
            table.insert(genv.UIElements, lockLabel)

            registerItem(button, side, ELEMENT_HEIGHT, cfg.name)
            return button
        end

        function Module:create_slider(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local PADL, PADR = 4, 4

            local slider = row("slider", "slider")

            local track = new("Frame", {
                Name = "trackcolor",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.78, 0),
                Size = UDim2.new(0.9, 0, 0, 5),
                BackgroundColor3 = genv.trackcolor or Color3.fromRGB(40, 40, 40),
                BorderSizePixel = 0,
                Active = true,
            }, slider)
            table.insert(genv.UIElements, track)
            pill(track)

            local fill = new("Frame", {
                Name = "sliderfill",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = genv.sliderfill or Color3.fromRGB(90, 90, 90),
                BorderSizePixel = 0,
            }, track)
            table.insert(genv.UIElements, fill)
            pill(fill)

            local knob = new("Frame", {
                Name = "knob",
                Size = UDim2.new(0, 15, 0, 15),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = genv.knob or Color3.fromRGB(120, 120, 120),
                BorderSizePixel = 0,
                Active = true,
            }, track)
            table.insert(genv.UIElements, knob)
            pill(knob)

            local hole = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0.5, 0, 0.5, 0),
                BackgroundColor3 = Color3.fromRGB(27, 28, 33),
                BorderSizePixel = 0,
            }, knob)
            pill(hole)

            new("TextLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 12, 0.32, 0),
                Size = UDim2.new(1, -70, 0, 13),
                BackgroundTransparency = 1,
                FontFace = font(),
                TextColor3 = WHITE,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = cfg.name or "",
            }, slider)

            local number = new("TextLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(0.97, 0, 0.32, 0),
                Size = UDim2.new(0, 50, 0, 13),
                BackgroundTransparency = 1,
                FontFace = font(),
                TextColor3 = WHITE,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Right,
                Text = "0",
            }, slider)

            attachTooltip(slider, cfg.tooltip or cfg.desc)
            registerItem(slider, side, ELEMENT_HEIGHT, cfg.name)

            local min_v = tonumber(cfg.minimum_value or (cfg.range and cfg.range[1])) or 0
            local max_v = tonumber(cfg.maximum_value or (cfg.range and cfg.range[2])) or 100
            if max_v <= min_v then max_v = min_v + 1 end

            local step = tonumber(cfg.step or cfg.increment)
            if not step or step <= 0 then
                local range = max_v - min_v
                if min_v == math.floor(min_v) and max_v == math.floor(max_v) and range >= 1 then step = 1
                elseif range <= 1 then step = 0.01
                elseif range <= 10 then step = 0.1
                elseif range <= 100 then step = 0.5
                else step = 1 end
            end

            local decimals = 3
            if step >= 1 then decimals = 0
            elseif step >= 0.1 then decimals = 1
            elseif step >= 0.01 then decimals = 2 end

            local function roundValue(val)
                if type(val) ~= "number" then return min_v end
                local rounded = math.floor((val - min_v) / step + 0.5) * step + min_v
                rounded = math.clamp(rounded, min_v, max_v)
                if decimals > 0 then
                    rounded = tonumber(string.format("%." .. decimals .. "f", rounded)) or min_v
                else
                    rounded = math.floor(rounded + 0.5)
                end
                return math.clamp(rounded, min_v, max_v)
            end

            local function formatNumber(value)
                local sfx = cfg.suffix or ""
                if decimals > 0 then return string.format("%." .. decimals .. "f", value) .. sfx end
                return tostring(math.floor(value + 0.5)) .. sfx
            end

            local function setFromPercent(percent)
                percent = math.clamp(tonumber(percent) or 0, 0, 1)
                fill.Size = UDim2.new(percent, 0, 1, 0)
                knob.Position = UDim2.new(percent, math.floor(7 - percent * 14), 0.5, 0)
                local final = roundValue(min_v + percent * (max_v - min_v))
                Library.Flags[cfg.flag] = final
                number.Text = formatNumber(final)
                if cfg.callback then cfg.callback(final) end
            end

            local function updateFromX(x)
                local trackWidth = track.AbsoluteSize.X
                if trackWidth <= 0 then return end
                local minX = track.AbsolutePosition.X
                setFromPercent((x - minX) / trackWidth)
            end

            local initialValue
            if type(Library.Flags[cfg.flag]) == "number" then
                initialValue = Library.Flags[cfg.flag]
            elseif Library.savedFlags and type(Library.savedFlags[cfg.flag]) == "number" then
                initialValue = Library.savedFlags[cfg.flag]
            else
                initialValue = tonumber(cfg.value or cfg.default or cfg.currentvalue) or min_v
            end
            Library.Flags[cfg.flag] = roundValue(initialValue)
            setFromPercent(math.clamp((Library.Flags[cfg.flag] - min_v) / (max_v - min_v), 0, 1))

            task.defer(function()
                if track.AbsoluteSize.X > 0 then
                    setFromPercent(math.clamp((Library.Flags[cfg.flag] - min_v) / (max_v - min_v), 0, 1))
                end
            end)

            local dragging = false
            local slideInput

            local function animate(sz)
                TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = sz}):Play()
            end

            local function beginDrag(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                dragging = true
                slideInput = input
                Library.slider_drag = true
                Library.dragging = false
                itemsSection.ScrollingEnabled = false
                animate(UDim2.new(0, 19, 0, 19))
                TweenService:Create(fill, TweenInfo.new(0.12), {BackgroundColor3 = genv.accent or Color3.fromRGB(168, 85, 247)}):Play()
                TweenService:Create(number, TweenInfo.new(0.12), {TextColor3 = genv.accent or WHITE}):Play()
                updateFromX(input.Position.X)
            end

            local function endDrag()
                dragging = false
                Library.slider_drag = false
                itemsSection.ScrollingEnabled = true
                animate(UDim2.new(0, 15, 0, 15))
                TweenService:Create(fill, TweenInfo.new(0.2), {BackgroundColor3 = genv.sliderfill or genv.accent or Color3.fromRGB(90, 90, 90)}):Play()
                TweenService:Create(number, TweenInfo.new(0.2), {TextColor3 = WHITE}):Play()
                Library.save_flags()
            end

            track.InputBegan:Connect(beginDrag)
            knob.InputBegan:Connect(beginDrag)
            slider.InputBegan:Connect(beginDrag)

            bind(UserInputService.InputChanged, function(input)
                if not dragging then return end
                if input.UserInputType == Enum.UserInputType.Touch then
                    if input == slideInput then updateFromX(input.Position.X) end
                elseif input.UserInputType == Enum.UserInputType.MouseMovement then
                    updateFromX(input.Position.X)
                end
            end)

            bind(UserInputService.InputEnded, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                    endDrag()
                end
            end)

            local obj = {min = min_v, max = max_v, step = step, flag = cfg.flag, callback = cfg.callback}
            function obj:GetValue() return Library.Flags[self.flag] end
            function obj:SetValue(value)
                if type(value) ~= "number" then return end
                setFromPercent(math.clamp((value - self.min) / (self.max - self.min), 0, 1))
                Library.save_flags()
            end

            Library:RegisterObject(cfg.flag, obj)
            return obj
        end
        Module.create_slider2 = Module.create_slider
        Tab.create_slider2 = Tab.create_slider

        local function buildTextEntry(cfg, side, nameKey, boxKey, rowName, boxName)
            local container = row(rowName, nameKey)
            simpleLabel(container, cfg.name, 0.4)

            local box = new("TextBox", {
                Name = boxName,
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = genv[boxKey] or Color3.fromRGB(22, 23, 27),
                BorderSizePixel = 0,
                Position = UDim2.new(0.96, 0, 0.5, 0),
                Size = UDim2.new(0.46, 0, 0, 24),
                ClearTextOnFocus = false,
                Text = "",
                PlaceholderText = cfg.placeholder or cfg.placeholdertext or "...",
                PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
                TextColor3 = WHITE,
                TextSize = 13,
                FontFace = font(),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ClipsDescendants = true,
                ZIndex = 3,
            }, container)
            table.insert(genv.UIElements, box)
            corner(box, 4)
            local boxStroke = stroke(box, Color3.fromRGB(45, 48, 60), 1, 0.4)
            box.Focused:Connect(function()
                TweenService:Create(boxStroke, TweenInfo.new(0.2), {Color = genv.accent or Color3.fromRGB(168, 85, 247), Transparency = 0}):Play()
            end)
            box.FocusLost:Connect(function()
                TweenService:Create(boxStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(45, 48, 60), Transparency = 0.4}):Play()
            end)
            attachTooltip(container, cfg.tooltip or cfg.desc)
            registerItem(container, side, ELEMENT_HEIGHT, cfg.name)
            return box
        end

        function Module:create_textbox(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local box = buildTextEntry(cfg, side, "tabcolor", "InputBox", "TextBox", "TextHolder")
            local Textbox = {}

            if Library.Flags[cfg.flag] == nil then
                local saved = Library.savedFlags and Library.savedFlags[cfg.flag]
                Library.Flags[cfg.flag] = saved ~= nil and saved or (cfg.value or cfg.default or "")
            end
            box.Text = tostring(Library.Flags[cfg.flag])

            if cfg.callback then cfg.callback(Library.Flags[cfg.flag]) end

            box.FocusLost:Connect(function()
                Library.Flags[cfg.flag] = box.Text
                if cfg.callback then cfg.callback(box.Text) end
                Library.save_flags()
            end)

            function Textbox:update(text)
                box.Text = tostring(text or "")
                Library.Flags[cfg.flag] = box.Text
                if cfg.callback then cfg.callback(box.Text) end
            end
            function Textbox:GetValue() return box.Text end
            function Textbox:SetValue(value) box.Text = tostring(value or "") end

            Library:RegisterObject(cfg.flag, Textbox)
            return Textbox
        end

        function Module.create_input(arg)
            local options = resolve(nil, arg)
            local cfg = {
                name = options.name or "Input",
                flag = options.flag or "input_flag",
                section = options.section or "left",
                placeholder = options.placeholder or options.placeholdertext or "",
                tooltip = options.tooltip or options.desc,
            }
            local side = getSide(cfg)
            local box = buildTextEntry(cfg, side, "inputButton", "InputBox", "Input", "InputBox")
            box.TextXAlignment = Enum.TextXAlignment.Center
            box.Text = options.default or options.value or ""

            local obj = {value = box.Text, callback = options.callback, flag = cfg.flag}

            function obj:UpdateInput(text)
                text = tostring(text or "")
                self.value = text
                box.Text = text
                Library.Flags[self.flag] = text
                Library.save_flags()
            end
            function obj:ClearInput() self:UpdateInput("") end
            function obj:GetInput() return box.Text end
            function obj:GetValue() return box.Text end
            function obj:SetValue(value) self:UpdateInput(value) end

            Library.Flags[cfg.flag] = box.Text
            Library:RegisterObject(cfg.flag, obj)

            box:GetPropertyChangedSignal("Text"):Connect(function()
                obj.value = box.Text
                Library.Flags[cfg.flag] = box.Text
                Library.save_flags()
            end)

            box.FocusLost:Connect(function()
                if obj.callback then obj.callback(box.Text) end
            end)

            return obj
        end

        function Module:create_keybind(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local keybind = row("Keybind", "Keybind")
            simpleLabel(keybind, cfg.name, 0.5)

            local Box = new("Frame", {
                Name = "KeybindBox",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 50, 0, 22),
                BackgroundColor3 = genv.KeybindBox or Color3.fromRGB(24, 25, 30),
                BorderSizePixel = 0,
                ZIndex = 3,
            }, keybind)
            table.insert(genv.UIElements, Box)
            corner(Box, 4)
            stroke(Box, Color3.fromRGB(45, 48, 60), 1, 0.5)

            local KeyText = new("TextLabel", {
                Size = UDim2.new(1, -4, 1, -4),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                TextColor3 = WHITE,
                FontFace = font(),
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 4,
            }, Box)

            attachTooltip(keybind, cfg.tooltip or cfg.desc)
            registerItem(keybind, side, ELEMENT_HEIGHT, cfg.name)

            local function displayOf(value)
                if not value then return "" end
                local n = tostring(value):match("^MouseButton(%d+)$")
                if n then return "Mouse" .. n end
                return tostring(value)
            end

            local function pressedName(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    return input.KeyCode.Name
                end
                local n = input.UserInputType.Name
                if n:match("^MouseButton%d+$") then return n end
                return nil
            end

            local defaultKey = cfg.keycode and cfg.keycode.Name or cfg.default or "H"
            Library.Flags[cfg.flag] = Library.Flags[cfg.flag] or defaultKey
            if Library.savedFlags and Library.savedFlags[cfg.flag] then
                Library.Flags[cfg.flag] = Library.savedFlags[cfg.flag]
            end
            KeyText.Text = displayOf(Library.Flags[cfg.flag])

            local kbState = false
            local function toggleKb()
                if cfg.flag == "toggleui" then
                    Library:visible()
                    return
                end
                kbState = not kbState
                if cfg.callback then task.spawn(cfg.callback, kbState, Library.Flags[cfg.flag]) end
                if Library.UpdateKeybindList then Library:UpdateKeybindList() end
            end
            Library:RegisterKeybind(cfg.flag, cfg.name, Library.Flags[cfg.flag], function()
                if cfg.flag == "toggleui" then
                    return not Library.hidden
                end
                return kbState
            end, toggleKb, toggleKb)

            local function updateSize()
                Box.Size = UDim2.new(0, math.max(40, KeyText.TextBounds.X + 12), 0, 22)
            end
            KeyText:GetPropertyChangedSignal("Text"):Connect(updateSize)
            updateSize()

            local setting = false
            local lastBound = 0

            bindTap(keybind, function()
                if setting then return end
                if tick() - lastBound < 0.2 then return end
                setting = true
                KeyText.Text = "..."
                local conn
                conn = UserInputService.InputBegan:Connect(function(input)
                    local pressed = pressedName(input)
                    if not pressed then return end
                    Library.Flags[cfg.flag] = pressed
                    Library:UpdateKeybind(cfg.flag, pressed)
                    Library.save_flags()
                    KeyText.Text = displayOf(pressed)
                    updateSize()
                    setting = false
                    lastBound = tick()
                    conn:Disconnect()
                end)
            end)

            bind(UserInputService.InputBegan, function(input, processed)
                if processed or setting then return end
                if cfg.flag == "toggleui" then return end
                local pressed = pressedName(input)
                if pressed and pressed == Library.Flags[cfg.flag] then
                    toggleKb()
                end
            end)

            local obj = {flag = cfg.flag, callback = cfg.callback}
            function obj:GetValue() return Library.Flags[self.flag] end
            function obj:SetValue(value)
                Library.Flags[self.flag] = value
                Library:UpdateKeybind(self.flag, value)
                KeyText.Text = displayOf(value)
                updateSize()
            end

            Library:RegisterObject(cfg.flag, obj)
            return obj
        end

        local DropdownKeys = {
            inline_single = {row = "Dropdown", rowKey = "dropdowncolor", box = "Box", boxKey = "dropdownboxscolor", opt = "Options", optKey = "dropdownoptionscolor"},
            inline_multi = {row = "dropdown1", rowKey = "multidropdowncolor", box = "Box1", boxKey = "multidropdownboxcolor", opt = "Options1", optKey = "multidropdownoptioncolor"},
            side_single = {row = "SideDropdown", rowKey = "sidedropdowncolor", box = "SideBox", boxKey = "sidedropdownboxcolor", opt = "SideOptions", optKey = "sidedropdownoptionscolor"},
            side_multi = {row = "multisidedropdown", rowKey = "multisidedropdown", box = "multisidedropdownBox", boxKey = "multisidedropdownBox", opt = "multisidedropdownOptions", optKey = "multisidedropdownOptions"},
        }

        local function buildDropdown(cfg, multi, sideStyle)
            local side = getSide(cfg)
            local keys = DropdownKeys[(sideStyle and "side_" or "inline_") .. (multi and "multi" or "single")]
            local OPT_H = sideStyle and 18 or 20
            local OPT_GAP, PT, PB, MAX_H = 6, 8, 8, 140
            local open = false
            local optionsHeight = 0
            local animToken = 0
            local searchQuery = ""

            local dropdownRow = row(keys.row, keys.rowKey)
            dropdownRow.ZIndex = 1

            local Title
            if sideStyle then
                Title = new("TextLabel", {
                    Position = UDim2.new(0.04, 0, 0, (ELEMENT_HEIGHT - 15) / 2),
                    Size = UDim2.new(0.4, 0, 0, 15),
                    BackgroundTransparency = 1,
                    FontFace = font(),
                    TextColor3 = WHITE,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = cfg.name or "",
                    ZIndex = 1,
                }, dropdownRow)
            end

            local Box = new("TextButton", {
                Name = keys.box,
                BackgroundColor3 = genv[keys.boxKey] or Color3.fromRGB(22, 23, 27),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                ZIndex = 2,
            }, dropdownRow)
            if sideStyle then
                Box.AnchorPoint = Vector2.new(1, 0)
                Box.Position = UDim2.new(0.96, 0, 0, (ELEMENT_HEIGHT - BOX_HEIGHT) / 2)
                Box.Size = UDim2.new(0.46, 0, 0, BOX_HEIGHT)
            else
                Box.AnchorPoint = Vector2.new(0.5, 0)
                Box.Position = UDim2.new(0.5, 0, 0, 5)
                Box.Size = UDim2.new(1, -12, 0, BOX_HEIGHT)
            end
            table.insert(genv.UIElements, Box)
            corner(Box, 6)

            local Options
            if sideStyle then
                Options = new("ScrollingFrame", {
                    ScrollBarThickness = 0,
                    ScrollBarImageTransparency = 1,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollingDirection = Enum.ScrollingDirection.Y,
                    ElasticBehavior = Enum.ElasticBehavior.Never,
                    Active = true,
                }, Box)
            else
                Options = new("Frame", {}, Box)
            end
            Options.Name = keys.opt
            Options.BackgroundColor3 = genv[keys.optKey] or Color3.fromRGB(22, 23, 27)
            Options.BorderSizePixel = 0
            Options.ClipsDescendants = true
            Options.Position = UDim2.new(0, 0, 1, 0)
            Options.Size = UDim2.new(1, 0, 0, 0)
            Options.ZIndex = 3
            Options.Visible = false
            table.insert(genv.UIElements, Options)
            corner(Options, 6)

            new("UIPadding", {
                PaddingLeft = UDim.new(0, 10),
                PaddingTop = UDim.new(0, PT),
                PaddingBottom = UDim.new(0, PB),
            }, Options)

            new("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, OPT_GAP),
            }, Options)

            local searchBox
            if #cfg.options > 6 or cfg.searchable then
                searchBox = new("TextBox", {
                    Name = "SearchBox",
                    Size = UDim2.new(1, -10, 0, 20),
                    BackgroundColor3 = Color3.fromRGB(18, 19, 23),
                    BorderSizePixel = 0,
                    Text = "",
                    PlaceholderText = "Search...",
                    PlaceholderColor3 = Color3.fromRGB(140, 140, 140),
                    TextColor3 = WHITE,
                    TextSize = 11,
                    FontFace = font(),
                    LayoutOrder = 0,
                    ZIndex = 54,
                    ClipsDescendants = true,
                }, Options)
                corner(searchBox, 4)
            end

            local Selected = new("TextLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Position = UDim2.new(sideStyle and 0.07 or 0.05, 0, 0.5, 0),
                Size = UDim2.new(1, -28, 1, 0),
                ZIndex = 3,
                FontFace = font(),
                TextColor3 = WHITE,
                TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, Box)

            local Arrow = new("ImageLabel", {
                Name = "Arrow",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Position = UDim2.new(0.92, 0, 0.5, 0),
                Size = UDim2.new(0, 10, 0, 10),
                ZIndex = 3,
                Image = "rbxassetid://17400678941",
            }, Box)

            attachTooltip(dropdownRow, cfg.tooltip or cfg.desc)
            registerItem(dropdownRow, side, ELEMENT_HEIGHT, cfg.name)

            local placeholder
            if sideStyle then
                placeholder = multi and "" or (cfg.option or "")
            else
                placeholder = multi and (cfg.name or "") or (cfg.option or cfg.name or "")
            end

            local D = {
                options = cfg.options or {},
                selectedOption = nil,
                selectedOptions = {},
                flag = cfg.flag,
                callback = cfg.callback,
                name = cfg.name,
            }

            local function isSelected(value)
                if multi then return table.find(D.selectedOptions, value) ~= nil end
                return D.selectedOption == value
            end

            local function setText()
                if multi then
                    Selected.Text = #D.selectedOptions > 0 and table.concat(D.selectedOptions, ", ") or placeholder
                else
                    Selected.Text = D.selectedOption ~= nil and tostring(D.selectedOption) or placeholder
                end
            end

            local function setBump(active)
                if not sideStyle then return end
                dropdownRow.ZIndex = active and 50 or 1
                Box.ZIndex = active and 51 or 2
                Options.ZIndex = active and 52 or 3
                if Title then Title.ZIndex = active and 53 or 1 end
                Selected.ZIndex = active and 53 or 3
                Arrow.ZIndex = active and 53 or 3
                for _, child in ipairs(Options:GetChildren()) do
                    if child:IsA("TextButton") or child:IsA("TextBox") then
                        child.ZIndex = active and 53 or 4
                    end
                end
            end

            local function applyOpenSize()
                local h = sideStyle and math.min(optionsHeight, MAX_H) or optionsHeight
                TweenService:Create(Options, TweenInfo.new(0.4), {Size = UDim2.new(1, 0, 0, h)}):Play()
                if not sideStyle then
                    updateItemHeight(dropdownRow, ELEMENT_HEIGHT + optionsHeight)
                end
            end

            function D:open()
                open = true
                animToken += 1
                Options.Visible = true
                setBump(true)
                applyOpenSize()
                TweenService:Create(Arrow, TweenInfo.new(0.4), {Rotation = 180}):Play()
            end

            function D:close()
                open = false
                animToken += 1
                local token = animToken
                itemsSection.ScrollingEnabled = true
                local tweenClose = TweenService:Create(Options, TweenInfo.new(0.4), {Size = UDim2.new(1, 0, 0, 0)})
                tweenClose:Play()
                if not sideStyle then
                    updateItemHeight(dropdownRow, ELEMENT_HEIGHT)
                end
                TweenService:Create(Arrow, TweenInfo.new(0.4), {Rotation = 0}):Play()
                tweenClose.Completed:Once(function()
                    if token ~= animToken then return end
                    Options.Visible = false
                    if sideStyle then
                        Options.CanvasPosition = Vector2.new(0, 0)
                        setBump(false)
                    end
                end)
            end

            function D:clear()
                for _, object in ipairs(Options:GetChildren()) do
                    if object:IsA("TextButton") then object:Destroy() end
                end
            end

            function D:update()
                self:clear()
                local count = 0
                for index, value in ipairs(self.options) do
                    local strVal = tostring(value)
                    if searchQuery == "" or string.find(string.lower(strVal), string.lower(searchQuery), 1, true) then
                        count += 1
                        local btn = new("TextButton", {
                            Name = "Option",
                            LayoutOrder = index + 1,
                            BackgroundTransparency = 1,
                            BorderSizePixel = 0,
                            AutoButtonColor = false,
                            Size = UDim2.new(1, 0, 0, OPT_H),
                            ZIndex = (sideStyle and open) and 53 or 4,
                            FontFace = font(),
                            TextColor3 = WHITE,
                            TextSize = 12,
                            TextTransparency = isSelected(value) and 0 or 0.5,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = strVal,
                        }, Options)

                        btn.MouseEnter:Connect(function()
                            TweenService:Create(btn, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
                        end)
                        btn.MouseLeave:Connect(function()
                            if not isSelected(value) then
                                TweenService:Create(btn, TweenInfo.new(0.3), {TextTransparency = 0.5}):Play()
                            end
                        end)

                        bindTap(btn, function()
                            if multi then
                                local idx = table.find(D.selectedOptions, value)
                                if idx then
                                    table.remove(D.selectedOptions, idx)
                                else
                                    table.insert(D.selectedOptions, value)
                                end
                                Library.Flags[D.flag] = D.selectedOptions
                                setText()
                                D:update()
                                Library.save_flags()
                                if D.callback then D.callback(D.selectedOptions) end
                            else
                                D.selectedOption = value
                                Library.Flags[D.flag] = value
                                setText()
                                D:update()
                                D:close()
                                Library.save_flags()
                                if D.callback then D.callback(value) end
                            end
                        end)
                    end
                end

                local searchH = searchBox and 26 or 0
                optionsHeight = 0
                if count > 0 or searchBox then
                    optionsHeight = count * OPT_H + (count - 1) * OPT_GAP + PT + PB + searchH
                end
                if sideStyle then
                    Options.CanvasSize = UDim2.new(0, 0, 0, optionsHeight)
                end
                if open then applyOpenSize() end
            end

            if searchBox then
                searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                    searchQuery = searchBox.Text
                    D:update()
                end)
            end

            function D:UpdateOptions(newOptions)
                self.options = newOptions or {}
                if multi then self.selectedOptions = {} end
                setText()
                self:update()
            end

            function D:GetValue()
                if multi then return self.selectedOptions end
                return self.selectedOption
            end

            function D:SetValue(value)
                if multi then
                    if type(value) ~= "table" then return end
                    self.selectedOptions = value
                    Library.Flags[self.flag] = value
                else
                    self.selectedOption = value
                    Library.Flags[self.flag] = value
                end
                setText()
                self:update()
            end

            local saved = Library.savedFlags and Library.savedFlags[cfg.flag]
            if multi then
                if type(saved) == "table" then D.selectedOptions = saved end
            else
                if saved ~= nil then D.selectedOption = saved end
            end

            setText()
            D:update()

            Library.Flags[cfg.flag] = multi and D.selectedOptions or D.selectedOption
            Library:RegisterObject(cfg.flag, D)

            if sideStyle then
                Options.MouseEnter:Connect(function()
                    itemsSection.ScrollingEnabled = false
                end)
                Options.MouseLeave:Connect(function()
                    itemsSection.ScrollingEnabled = true
                end)
            end

            bindTap(Box, function()
                if open then D:close() else D:open() end
            end)

            return D
        end

        function Module:create_dropdown(arg)
            return buildDropdown(resolve(self, arg), false, false)
        end

        function Module:create_multidropdown(arg)
            return buildDropdown(resolve(self, arg), true, false)
        end

        function Module:create_sidedropdown(arg)
            return buildDropdown(resolve(self, arg), false, true)
        end

        function Module:create_multisidedropdown(arg)
            return buildDropdown(resolve(self, arg), true, true)
        end

        function Module:create_divider(arg)
            local cfg = resolve(self, arg)
            local side = getSide(cfg)
            local div = new("Frame", {
                Name = "Divider",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14),
                ZIndex = 2,
            }, itemsSection)
            local lineDiv = new("Frame", {
                Position = UDim2.new(0, 4, 0.5, 0),
                Size = UDim2.new(1, -8, 0, 1),
                BackgroundColor3 = genv.uiline or Color3.fromRGB(35, 36, 42),
                BorderSizePixel = 0,
                ZIndex = 3,
            }, div)
            registerItem(div, side, 14, "")
            return div
        end

        return Module
    end


    task.defer(function()
        Library:LoadAutoload()
    end)

    WindowController.create_tab = function(selfOrName, nameOrIcon, iconId)
        local tabName = (type(selfOrName) == "string") and selfOrName or nameOrIcon
        local tabIcon = (type(selfOrName) == "string") and nameOrIcon or iconId
        return Tab.create_tab(Tab, tabName, tabIcon)
    end
    WindowController.Tab = WindowController.create_tab
    WindowController.FinishLoading = function()
        Library:FinishLoading()
    end
    WindowController.Notify = function(_, opts)
        return Library:Notify(opts)
    end
    WindowController.SetScale = function(_, s)
        return Library:SetScale(s)
    end
    WindowController.Toggle = function(_)
        Library:visible()
    end

    return WindowController
end

return Library
