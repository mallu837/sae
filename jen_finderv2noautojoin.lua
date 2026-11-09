-- an u do add webhook notif on discord where they joined 
-- language: Lua, file: jen_finder.lua, target: Roblox executor

-- Jen Finder — Full Working Finder (Instant-Fire Join + Fast Feed + Typed Income Gate + Compact Join-Only Notifs + Discord Webhook)
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local player = Players.LocalPlayer
local parent = player:WaitForChild('PlayerGui', 15)
local Teleports = game:GetService('TeleportService')
local requestFn = request or http_request or (syn and syn.request) or (http and http.request)

local function module(path)
  local obj = RS
  for part in path:gmatch('[^.]+') do obj = obj:FindFirstChild(part) end
  return obj and require(obj) or nil
end

local cycleModule

local function ensureCycleModule()
  if cycleModule then return cycleModule end
  cycleModule = module('Shared.Util.AreaEggCycle')
  return cycleModule
end

local function cycleInfo()
  local cm = ensureCycleModule()
  if not cm then return nil end
  local ok, info = pcall(function()
    local now = workspace:GetServerTimeNow()
    local running = cm.IsRunning()
    local remaining = cm.SecondsUntilReset(now)
    local respawnAt
    if type(cm.PeriodStartTime) == 'function' and type(cm.PeriodIndexAt) == 'function' then
      local known, value = pcall(function() return cm.PeriodStartTime(cm.PeriodIndexAt(now)) * 1000 end)
      if known and type(value) == 'number' then respawnAt = value end
    end
    return {resetAt = cm.NextResetTime(now) * 1000, respawnAt = respawnAt, remaining = remaining, running = running}
  end)
  return ok and info or nil
end

local gui = Instance.new('ScreenGui')
gui.Name = 'TENSHI_FINDER_BETA'
gui:SetAttribute('TenshiUIBuild','PUBLIC-V10-FASTFEED-NOTIF-WEBHOOK')
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
pcall(function() gui.ClipToDeviceSafeArea = false end)
gui.DisplayOrder = 1200
gui.Parent = parent

local function make(class, props, holder)
  local obj = Instance.new(class)
  for k, v in pairs(props) do obj[k] = v end
  obj.Parent = holder
  return obj
end
local function label(holder, text, pos, size, color, fontSize)
  return make('TextLabel', {Text=text,Position=pos,Size=size,BackgroundTransparency=1,
    TextColor3=color or Color3.new(1,1,1),Font=Enum.Font.GothamBold,
    TextSize=fontSize or 13,TextXAlignment=Enum.TextXAlignment.Left,
    TextTruncate=Enum.TextTruncate.AtEnd}, holder)
end

local D = {
  gui = gui, localPanel = {Visible=false}, player = player, make = make, label = label,
  entries = function() return {} end,
  metadata = function() return nil end,
  ready = function() return true end,
  money = function(v)
    if not v then return 'Income unavailable' end
    for _, e in ipairs({{1e18,'Qi'},{1e15,'Qa'},{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}}) do
      if v >= e[1] then return string.format('$%.2f%s/s', v/e[1], e[2]) end
    end
    return string.format('$%.2f/s', v)
  end,
  stopFarm = function() end,
}

local PREMIUM_EDITION = false
local AUTO_KEY = ''
local DISCORD = 'https://discord.gg/8zxVj7Ygeg'

-- ============================================================
-- DISCORD WEBHOOK CONFIG
-- Paste your webhook URL below. Leave as '' to disable.
-- Format: https://discord.com/api/webhooks/ID/TOKEN
-- ============================================================
local DISCORD_WEBHOOK = 'https://discord.com/api/webhooks/1569351050597765120/SQE2hCeuuaLf7ducoBPyTuiGgfvXuEUGA--y3J-PWILFdnUrjHJM5M2cP2U44iTOF7-l' -- ⬅️ paste webhook URL here
local DISCORD_WEBHOOK_ENABLED = true -- toggle at runtime (set false to silence)

local Http = game:GetService('HttpService')

local active = true
local othersOnly = false
local autoJoinEnabled = true
local incomeAutoJoinEnabled = true
local queryEpoch = 0
local config, configAt = nil, -math.huge
local feed, feedAt = {}, 0
local clockOffset = 0
local reportStatus = 'Connecting'
local queryStatus = ''
local minRate, minRank = 0, 6
local minIncome = 0
local joining, joiningKey = false, nil
local reporterId = Http:GenerateGUID(false)
local networkBusy = false
local latestEntries = {}
local lastJoinErrorMsg, lastJoinErrorAt = nil, 0
local currentTopEntries = {}
local blockedServers = {}
local BLOCK_TTL = 300
local recentlyAttempted = {}
local ATTEMPT_TTL = 30
local panelShownAt = 0
local fastScanSignal = false
D.entries = function() return latestEntries end

-- ============================================================
-- NOTIFICATION STATE
-- ============================================================
local notifReady = false
local notifQueue = {}

-- ============================================================
-- PET/EGG JOIN NOTIFICATION (compact side-panel toast)
-- Shows: Name · Kg · $/s · Rarity (single tight card)
-- ============================================================
local Notif = {}
do
  local notifGui = Instance.new('ScreenGui')
  notifGui.Name = 'JenJoinNotifs'
  notifGui.ResetOnSpawn = false
  notifGui.IgnoreGuiInset = true
  notifGui.DisplayOrder = 1250
  pcall(function() notifGui.ScreenInsets = Enum.ScreenInsets.None end)
  notifGui.Parent = parent

  local container = Instance.new('Frame')
  container.Name = 'NotifStack'
  container.AnchorPoint = Vector2.new(1, 1)
  container.Position = UDim2.new(1, -10, 1, -10)
  container.Size = UDim2.new(0, 220, 1, -20)
  container.BackgroundTransparency = 1
  container.Parent = notifGui

  local layout = Instance.new('UIListLayout')
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
  layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
  layout.Padding = UDim.new(0, 5)
  layout.Parent = container

  local order = 0
  local alive = true
  notifGui.Destroying:Connect(function() alive = false end)

  local accent = {
    divine=Color3.fromRGB(255,205,55), eternal=Color3.fromRGB(218,202,236),
    secret=Color3.fromRGB(255,255,255), cosmic=Color3.fromRGB(190,85,255),
    mythic=Color3.fromRGB(255,75,85), legendary=Color3.fromRGB(255,155,45),
    epic=Color3.fromRGB(255,110,200), rare=Color3.fromRGB(65,165,255),
    uncommon=Color3.fromRGB(105,220,120), common=Color3.fromRGB(220,225,235),
  }

  local function fmtWeight(v)
    if type(v) ~= 'number' or v ~= v or v <= 0 then return '—' end
    if v >= 1e12 then return string.format('%.2g', v) .. 'Kg' end
    if v >= 1e9 then return string.format('%.2fB', v/1e9):gsub('0+$',''):gsub('%.$','') .. 'Kg' end
    if v >= 1e6 then return string.format('%.2fM', v/1e6):gsub('0+$',''):gsub('%.$','') .. 'Kg' end
    if v >= 1000 then return string.format('%.2fK', v/1000):gsub('0+$',''):gsub('%.$','') .. 'Kg' end
    return string.format('%.2f', v):gsub('0+$',''):gsub('%.$','') .. 'Kg'
  end

  local function fmtMoney(v)
    if type(v) ~= 'number' or v ~= v or v < 0 then return '—' end
    for _, e in ipairs({{1e18,'Qi'},{1e15,'Qa'},{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}}) do
      if v >= e[1] then return string.format('$%.2f%s/s', v/e[1], e[2]) end
    end
    return string.format('$%.2f/s', v)
  end

  function Notif.push(name, weightKg, incomePerSec, rarityName)
    if not alive then return end
    order = order + 1
    local card = Instance.new('Frame')
    card.Size = UDim2.new(1, 0, 0, 46)
    card.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
    card.BackgroundTransparency = 0.06
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = container

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    local key = tostring(rarityName or ''):lower():gsub('%s+','')
    local accentColor = accent[key] or Color3.fromRGB(120, 200, 255)

    local stroke = Instance.new('UIStroke')
    stroke.Color = accentColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = card

    local stripe = Instance.new('Frame')
    stripe.Size = UDim2.new(0, 3, 1, 0)
    stripe.BackgroundColor3 = accentColor
    stripe.BorderSizePixel = 0
    stripe.Parent = card
    local stripeCorner = Instance.new('UICorner')
    stripeCorner.CornerRadius = UDim.new(0, 6)
    stripeCorner.Parent = stripe

    local title = Instance.new('TextLabel')
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 8, 0, 4)
    title.Size = UDim2.new(1, -90, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextColor3 = accentColor
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Text = tostring(name or 'Unknown')
    title.Parent = card

    local moneyLabel = Instance.new('TextLabel')
    moneyLabel.BackgroundTransparency = 1
    moneyLabel.Position = UDim2.new(1, -82, 0, 4)
    moneyLabel.Size = UDim2.new(0, 74, 0, 18)
    moneyLabel.Font = Enum.Font.GothamBold
    moneyLabel.TextSize = 12
    moneyLabel.TextColor3 = Color3.fromRGB(120, 240, 140)
    moneyLabel.TextXAlignment = Enum.TextXAlignment.Right
    moneyLabel.TextTruncate = Enum.TextTruncate.AtEnd
    moneyLabel.Text = fmtMoney(incomePerSec)
    moneyLabel.Parent = card

    local weightLabel = Instance.new('TextLabel')
    weightLabel.BackgroundTransparency = 1
    weightLabel.Position = UDim2.new(0, 8, 0, 23)
    weightLabel.Size = UDim2.new(0.5, -10, 0, 18)
    weightLabel.Font = Enum.Font.Gotham
    weightLabel.TextSize = 12
    weightLabel.TextColor3 = Color3.fromRGB(185, 220, 255)
    weightLabel.TextXAlignment = Enum.TextXAlignment.Left
    weightLabel.TextTruncate = Enum.TextTruncate.AtEnd
    weightLabel.Text = fmtWeight(weightKg)
    weightLabel.Parent = card

    local rarityLabel = Instance.new('TextLabel')
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Position = UDim2.new(0.5, 0, 0, 23)
    rarityLabel.Size = UDim2.new(0.5, -8, 0, 18)
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.TextSize = 11
    rarityLabel.TextColor3 = accentColor
    rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
    rarityLabel.TextTruncate = Enum.TextTruncate.AtEnd
    rarityLabel.Text = tostring(rarityName or 'Unknown')
    rarityLabel.Parent = card

    local TweenService = game:GetService('TweenService')
    card.Position = UDim2.new(0, 40, 0, 0)
    TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
      Position = UDim2.new(0, 0, 0, 0),
      BackgroundTransparency = 0.06,
    }):Play()

    task.delay(4, function()
      if not card.Parent then return end
      local t = TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 40, 0, 0),
        BackgroundTransparency = 1,
      })
      t:Play()
      t.Completed:Connect(function() if card.Parent then card:Destroy() end end)
    end)
  end
end
notifReady = true
for _, q in ipairs(notifQueue) do pcall(Notif.push, q[1], q[2], q[3], q[4]) end
table.clear(notifQueue)

-- ============================================================
-- DISCORD WEBHOOK — fires when the finder teleports into a server
-- ============================================================
local rarityColorsHex = {
  divine=0xFFCD37, eternal=0xDACAEC, secret=0xFFFFFF, cosmic=0xBE55FF,
  mythic=0xFF4B55, legendary=0xFF9B2D, epic=0xFF6EC8, rare=0x41A5FF,
  uncommon=0x69DC78, common=0xDCE1EB,
}

local webhookLastSent = 0
local webhookMinInterval = 1.5 -- seconds; prevents spam if multiple joins in quick succession

local function sendDiscordWebhook(entry, placeId, jobId)
  if not DISCORD_WEBHOOK_ENABLED then return end
  if type(DISCORD_WEBHOOK) ~= 'string' or DISCORD_WEBHOOK == '' then return end
  if type(requestFn) ~= 'function' or not entry then return end
  if os.clock() - webhookLastSent < webhookMinInterval then return end
  webhookLastSent = os.clock()

  local function fm(v)
    if type(v) ~= 'number' or v ~= v or v < 0 then return '—' end
    for _, e in ipairs({{1e18,'Qi'},{1e15,'Qa'},{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}}) do
      if v >= e[1] then return string.format('$%.2f%s/s', v/e[1], e[2]) end
    end
    return string.format('$%.2f/s', v)
  end

  local function fw(v)
    if type(v) ~= 'number' or v ~= v or v <= 0 then return '—' end
    if v >= 1e12 then return string.format('%.2fT Kg', v/1e12) end
    if v >= 1e9 then return string.format('%.2fB Kg', v/1e9) end
    if v >= 1e6 then return string.format('%.2fM Kg', v/1e6) end
    if v >= 1000 then return string.format('%.2fK Kg', v/1000) end
    return string.format('%.2f Kg', v)
  end

  local key = tostring(entry.rarity or ''):lower():gsub('%s+','')
  local color = rarityColorsHex[key] or 0x78C8FF

  local resolvedPlace = tostring(placeId or entry.placeId or game.PlaceId)
  local resolvedJob = tostring(jobId or entry.jobId or game.JobId)
  local link = string.format('https://www.roblox.com/games/%s?gameInstanceId=%s', resolvedPlace, resolvedJob)

  local mutations = tostring(entry.mutations or entry.mutationText or '')
  if mutations == '' or mutations:lower():find('none', 1, true) then mutations = 'None' end

  local body = Http:JSONEncode({
    username = 'Jen Finder',
    avatar_url = 'https://github.com/mallu837/sae/blob/main/Jen.png',
    embeds = {{
      title = '✅ Joined Server',
      url = link,
      description = string.format('**%s**\n[Join Server »](%s)',
        tostring(entry.name or 'Unknown'), link),
      color = color,
      fields = {
        {name = '💰 Income', value = fm(entry.rate), inline = true},
        {name = '⚖️ Weight', value = fw(entry.weight), inline = true},
        {name = '⭐ Rarity', value = tostring(entry.rarity or 'Unknown'), inline = true},
        {name = '🧬 Mutations', value = mutations, inline = true},
        {name = '🌐 Place ID', value = '`'..resolvedPlace..'`', inline = true},
        {name = '👤 Player', value = '`'..tostring(D.player.Name or '?')..'`', inline = true},
        {name = '🎯 Job ID', value = '`'..resolvedJob..'`', inline = false},
      },
      footer = {text = 'Jen Finder • '..os.date('%H:%M:%S')},
      timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }},
  })

  task.spawn(function()
    local ok, err = pcall(requestFn, {
      Url = DISCORD_WEBHOOK,
      Method = 'POST',
      Headers = {['Content-Type'] = 'application/json'},
      Body = body,
      Timeout = 5,
    })
    if not ok then
      warn('[Jen Webhook] failed:', tostring(err))
    end
  end)
end

-- ============================================================
-- JOIN-TIME NOTIF HELPER (fires ONLY when you actually teleport)
-- ============================================================
local function notifOnJoin(entry)
  if not entry then return end
  local name = entry.name
  local weight = entry.weight
  local income = entry.rate
  local rarity = entry.rarity
  if notifReady then
    pcall(Notif.push, name, weight, income, rarity)
  else
    notifQueue[#notifQueue+1] = {name, weight, income, rarity}
  end
  pcall(sendDiscordWebhook, entry, entry.placeId, entry.jobId)
  pcall(function()
    print(string.format('[Jen Join] -> %s | %s Kg | %s | %s',
      tostring(name), tostring(weight or '?'),
      tostring(income or '?'), tostring(rarity or '?')))
  end)
end

-- ============================================================
-- /s CHAT COMMAND — manually fire notif for top entry
-- ============================================================
task.spawn(function()
  local ok = pcall(function()
    local plr = Players.LocalPlayer
    plr.Chatted:Connect(function(msg)
      local lower = tostring(msg):lower():gsub('^%s+',''):gsub('%s+$','')
      if lower == '/s' then
        local best = latestEntries[1] or currentTopEntries[1]
        if best then
          Notif.push(best.name, best.weight, best.rate, best.rarity)
        else
          Notif.push('No pet found', nil, nil, 'common')
        end
      end
    end)
  end)
  if not ok then warn('[Jen] /s chat hook failed') end
end)

local cardsByKey = {}
local rendering, renderPending, renderQueued = false, false, false
local render

local function queueRender()
  if renderQueued or not active then return end
  renderQueued = true
  task.defer(function() renderQueued = false; if active then render() end end)
end

local settingsPath = 'jen_finder_ui.json'
local settings = {}
if type(readfile) == 'function' then
  pcall(function()
    local data = Http:JSONDecode(readfile(settingsPath))
    if type(data) == 'table' then settings = data end
  end)
end
if type(settings.myServer) == 'boolean' then othersOnly = settings.myServer end
if type(settings.autoJoinEnabled) == 'boolean' then autoJoinEnabled = settings.autoJoinEnabled end
if type(settings.incomeAutoJoinEnabled) == 'boolean' then incomeAutoJoinEnabled = settings.incomeAutoJoinEnabled end
if type(settings.minRank) == 'number' then
  local saved = math.floor(settings.minRank)
  if saved >= 6 and saved <= 10 then minRank = saved
  elseif saved == 0 and settings.rarityMenu == 'mythic-up-v1' then minRank = 0 end
end
if type(settings.minIncome) == 'number' and settings.minIncome == settings.minIncome and settings.minIncome >= 0 then
  minIncome = math.floor(settings.minIncome)
end

local originalMake, originalLabel = D.make, D.label
D.make = function(class, props, parent)
  if class == 'TextButton' or class == 'TextBox' then
    props.Font = Enum.Font.GothamBold; props.TextSize = math.max(props.TextSize or 15, 15)
  end
  if class == 'TextBox' then props.TextColor3 = Color3.fromRGB(25,25,30) end
  local obj = originalMake(class, props, parent)
  if class == 'TextButton' or class == 'TextBox' then
    originalMake('UICorner', {CornerRadius=UDim.new(0,5)}, obj)
  end
  return obj
end
D.label = function(parent, text, pos, size, color, fontSize)
  local obj = originalLabel(parent, text, pos, size, color or Color3.fromRGB(240,242,255), math.max(fontSize or 15, 14))
  obj.Font = Enum.Font.GothamBold; obj.TextStrokeColor3 = Color3.new(0,0,0); obj.TextStrokeTransparency = 0.45
  return obj
end

local panel = D.make('Frame', {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-18,0.5,0),
  Size=UDim2.new(0.94,0,0.86,0), BackgroundColor3=Color3.fromRGB(22,23,27), Visible=false}, D.gui)
local responsiveScale = D.make('UIScale', {Scale=0.8}, panel)
D.make('UICorner', {CornerRadius=UDim.new(0,4)}, panel)
D.make('UIStroke', {Color=Color3.fromRGB(125,128,138), Thickness=2}, panel)
local wallpaper = D.make('ImageLabel', {Name='JenWallpaper', Size=UDim2.fromScale(1,1),
  BackgroundTransparency=1, ImageTransparency=0.22, Image='', ScaleType=Enum.ScaleType.Crop, Active=false, ZIndex=1}, panel)
D.make('UICorner', {CornerRadius=UDim.new(0,4)}, wallpaper)
local wallpaperShade = D.make('Frame', {Name='WallpaperShade', Size=UDim2.fromScale(1,1),
  BackgroundColor3=Color3.fromRGB(10,13,26), BackgroundTransparency=0.25, BorderSizePixel=0, Active=false, ZIndex=1}, wallpaper)
D.make('UICorner', {CornerRadius=UDim.new(0,4)}, wallpaperShade)
local function contentLayer(child)
  if child:IsA('GuiObject') and child ~= wallpaper and not child:IsDescendantOf(wallpaper) and child.ZIndex < 2 then child.ZIndex = 2 end
end
for _, child in ipairs(panel:GetDescendants()) do contentLayer(child) end
panel.DescendantAdded:Connect(contentLayer)

local bar = D.make('Frame', {Position=UDim2.fromOffset(1,1), Size=UDim2.new(1,-2,0,45),
  BackgroundColor3=Color3.fromRGB(46,47,52), BorderSizePixel=0}, panel)
D.make('UICorner', {CornerRadius=UDim.new(0,4)}, bar)
D.make('UIGradient', {Color=ColorSequence.new(Color3.fromRGB(125,130,137), Color3.fromRGB(70,72,80)), Rotation=0}, bar)

local heading = D.label(panel, PREMIUM_EDITION and 'Jen Finder / PREMIUM' or 'Jen Finder',
  UDim2.fromOffset(14,8), UDim2.new(1,-55,0,32), nil, 22)
local open = D.make('ImageButton', {Image='', Position=UDim2.fromOffset(18,80), Size=UDim2.fromOffset(82,82),
  BackgroundColor3=Color3.fromRGB(250,250,250), ScaleType=Enum.ScaleType.Fit, ClipsDescendants=true}, D.gui)
D.make('UICorner', {CornerRadius=UDim.new(1,0)}, open)
D.make('UIStroke', {Color=Color3.fromRGB(185,25,40), Thickness=3}, open)
local fallback = D.label(open, 'Jen', UDim2.new(), UDim2.fromScale(1,1), Color3.fromRGB(150,25,40), 19)
local iconCaption = D.label(open, 'FINDER', UDim2.new(0.5,-44,1,5), UDim2.fromOffset(88,27), Color3.new(1,1,1), 18)
open.ClipsDescendants = false
iconCaption.TextStrokeTransparency = 0.15
iconCaption.TextXAlignment = Enum.TextXAlignment.Center

task.spawn(function()
  local asset = getcustomasset or getsynasset
  if type(asset) ~= 'function' or type(writefile) ~= 'function' then return end
  local filename = 'jen_launcher_v1.png'
  local exists = false
  if type(isfile) == 'function' then pcall(function() exists = isfile(filename) end) end
  if not exists then
    local ok, bytes = pcall(function() return game:HttpGet('https://raw.githubusercontent.com/mallu837/sae/main/Jen.png') end)
    if not ok or type(bytes) ~= 'string' or #bytes < 100 then return end
    if bytes:sub(1,8) ~= string.char(137)..'PNG'..string.char(13,10,26,10) then return end
    pcall(function() writefile(filename, bytes) end)
  end
  local ok, uri = pcall(asset, filename)
  if ok and type(uri) == 'string' and open.Parent then open.Image = uri; fallback.Visible = false end
end)

local function restorePosition(target, value)
  if type(value) ~= 'table' then return end
  for i = 1, 4 do
    if type(value[i]) ~= 'number' or value[i] ~= value[i] or math.abs(value[i]) > 5000 then return end
  end
  local pos = UDim2.new(value[1], value[2], value[3], value[4])
  local cam = workspace.CurrentCamera
  if cam then
    local vp = cam.ViewportSize
    if vp.X > 0 and vp.Y > 0 then
      local px = pos.X.Scale * vp.X + pos.X.Offset
      local py = pos.Y.Scale * vp.Y + pos.Y.Offset
      if px < -100 or px > vp.X + 100 or py < -100 or py > vp.Y + 100 then return end
    end
  end
  target.Position = pos
end
restorePosition(panel, settings.panel)
restorePosition(open, settings.icon)

local sizePercent = 100
local sizeFactor = sizePercent / 100
local launcherScale = D.make('UIScale', {Scale=0.8}, open)

local function fitFinder()
  local view = D.gui.AbsoluteSize
  if view.X <= 0 or view.Y <= 0 then return end
  local landscape = view.X > view.Y
  local width = math.min(321.6*sizeFactor, view.X*(landscape and 0.40 or 0.92), view.X-16)
  local height = math.min(592*sizeFactor, view.Y*0.90)
  local scale = math.min(0.8*sizeFactor, width/402, height/680)
  responsiveScale.Scale = scale
  panel.Size = UDim2.fromOffset(402, height/scale)
  launcherScale.Scale = math.min(0.8, math.max(0.5, math.min(view.X,view.Y)/650))
  local function keepVisible(target, caption)
    local size = target.AbsoluteSize
    local p = target.Position; local anchor = target.AnchorPoint
    local x = p.X.Scale*view.X + p.X.Offset; local y = p.Y.Scale*view.Y + p.Y.Offset
    x = math.clamp(x, 8+size.X*anchor.X, math.max(8+size.X*anchor.X, view.X-8-size.X*(1-anchor.X)))
    y = math.clamp(y, 8+size.Y*anchor.Y, math.max(8+size.Y*anchor.Y, view.Y-8-caption-size.Y*(1-anchor.Y)))
    target.Position = UDim2.fromScale(x/view.X, y/view.Y)
  end
  task.defer(function() if panel.Parent then keepVisible(panel, 0); keepVisible(open, 28*launcherScale.Scale) end end)
end
local resizeConnection = D.gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(fitFinder)
D.gui.Destroying:Connect(function() resizeConnection:Disconnect() end)
task.defer(fitFinder)

local function saveSettings()
  if type(writefile) ~= 'function' then return end
  pcall(function()
    local function coords(p) return {p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset} end
    writefile(settingsPath, Http:JSONEncode({
      myServer=othersOnly, minRank=minRank, rarityMenu='mythic-up-v1',
      autoJoinEnabled=autoJoinEnabled, incomeAutoJoinEnabled=incomeAutoJoinEnabled, minIncome=minIncome,
      menuHotkey=(settings.menuHotkey or 'F'), hotkeyDefaultVersion=2,
      sizeFactor=sizeFactor, panel=coords(panel.Position), icon=coords(open.Position)
    }))
  end)
end

heading.Text = 'Jen Finder'; heading.TextSize = 18; heading.Font = Enum.Font.Arcade
heading.TextScaled = true; heading.TextWrapped = false; heading.TextTruncate = Enum.TextTruncate.None
D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=20}, heading)
heading.TextStrokeTransparency = 0.65
open.BackgroundTransparency = 1
iconCaption.Visible = false
for _, decoration in ipairs(open:GetChildren()) do
  if decoration:IsA('UIStroke') then decoration.Enabled = false end
end

local sizeMinus = D.make('TextButton', {Name='SizeMinus', Text='', Position=UDim2.new(1,-182,0,3),
  Size=UDim2.fromOffset(40,40), BackgroundColor3=Color3.fromRGB(190,45,55), TextColor3=Color3.new(1,1,1)}, panel)
local sizePlus = D.make('TextButton', {Name='SizePlus', Text='', Position=UDim2.new(1,-94,0,3),
  Size=UDim2.fromOffset(40,40), BackgroundColor3=Color3.fromRGB(45,150,80), TextColor3=Color3.new(1,1,1)}, panel)
local sizeLabel = D.label(panel, '100%', UDim2.new(1,-138,0,13), UDim2.fromOffset(40,20), Color3.new(1,1,1), 14)
sizeLabel.TextXAlignment = Enum.TextXAlignment.Center; sizeLabel.TextScaled = true; sizeLabel.TextWrapped = false
D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=14}, sizeLabel)
for _, button in ipairs({sizeMinus, sizePlus}) do
  local corner = button:FindFirstChildOfClass('UICorner'); if corner then corner.CornerRadius = UDim.new(0,6) end
  local line = D.make('Frame', {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(16,4), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0}, button)
  D.make('UICorner', {CornerRadius=UDim.new(1,0)}, line)
end
local upright = D.make('Frame', {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
  Size=UDim2.fromOffset(4,16), BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0}, sizePlus)
D.make('UICorner', {CornerRadius=UDim.new(1,0)}, upright)

local function paintSize()
  sizeLabel.Text = tostring(sizePercent)..'%'
  sizeMinus.Active = sizePercent > 70; sizeMinus.Selectable = sizePercent > 70
  sizePlus.Active = sizePercent < 120; sizePlus.Selectable = sizePercent < 120
end
local function changeSizeBy(delta)
  local nextPercent = math.clamp(sizePercent + delta, 70, 120)
  if nextPercent == sizePercent then return end
  sizePercent = nextPercent; sizeFactor = sizePercent / 100
  paintSize(); fitFinder(); saveSettings()
end
sizeMinus.Activated:Connect(function() changeSizeBy(-10) end)
sizePlus.Activated:Connect(function() changeSizeBy(10) end)
paintSize()

local close = D.make('TextButton', {Text='×', Position=UDim2.new(1,-33,0,4), Size=UDim2.fromOffset(27,27),
  BackgroundColor3=Color3.fromRGB(160,35,50), TextColor3=Color3.new(1,1,1), TextSize=22}, panel)
local closeArt = D.make('ImageLabel', {Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Image='',
  ScaleType=Enum.ScaleType.Fit, Active=false}, close)

local suppressOpenUntil = 0
close.Activated:Connect(function() panel.Visible = false; D.localPanel.Visible = true end)

local Input = game:GetService('UserInputService')
local drag
local function draggable(target, handle, isLauncher)
  handle.Active = true
  handle.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    drag = {target=target,input=input,start=input.Position,position=target.Position,
      absolute=target.AbsolutePosition,size=target.AbsoluteSize,launcher=isLauncher,moved=false}
  end)
end
draggable(panel, heading, false)
for _, spec in ipairs({
  {UDim2.fromOffset(0,46), UDim2.new(0,8,1,-46)},
  {UDim2.new(1,-8,0,46), UDim2.new(0,8,1,-46)},
  {UDim2.new(0,8,1,-8), UDim2.new(1,-16,0,8)}
}) do
  local grip = D.make('Frame', {Name='PanelDragEdge', Position=spec[1], Size=spec[2],
    BackgroundTransparency=1, Active=true, ZIndex=20}, panel)
  draggable(panel, grip, false)
end
draggable(panel, bar, false)
draggable(open, open, true)
local launcherHit = D.make('TextButton', {Name='LauncherHitArea', Text='', AutoButtonColor=false,
  BackgroundTransparency=1, Position=UDim2.fromOffset(-8,-8), Size=UDim2.new(1,16,1,16), ZIndex=5}, open)
draggable(open, launcherHit, true)

local function prewarmOnOpen()
  if not config or os.clock() - configAt > 30 then pcall(loadConfig) end
  if not othersOnly then pcall(refresh) end
  queueRender()
end

local function togglePanel()
  if os.clock() < suppressOpenUntil then return end
  panel.Visible = not panel.Visible
  D.localPanel.Visible = not panel.Visible
  if panel.Visible then
    panelShownAt = os.clock()
    task.spawn(prewarmOnOpen)
  end
end
open.Activated:Connect(togglePanel)
launcherHit.Activated:Connect(togglePanel)

local moveConnection = Input.InputChanged:Connect(function(input)
  if not drag then return end
  local mouse = drag.input.UserInputType == Enum.UserInputType.MouseButton1
  if (mouse and input.UserInputType ~= Enum.UserInputType.MouseMovement) or (not mouse and input ~= drag.input) then return end
  local dx, dy = input.Position.X - drag.start.X, input.Position.Y - drag.start.Y
  if dx*dx + dy*dy > 25 then drag.moved = true end
  if not drag.moved then return end
  if drag.launcher then suppressOpenUntil = os.clock() + 0.5 end
  local view = D.gui.AbsoluteSize; local origin = D.gui.AbsolutePosition
  if view.X <= 0 or view.Y <= 0 then return end
  local left = drag.absolute.X - origin.X; local top = drag.absolute.Y - origin.Y
  local x = math.clamp(left+dx, 0, math.max(0, view.X - drag.size.X))
  local y = math.clamp(top+dy, 0, math.max(0, view.Y - drag.size.Y - (drag.launcher and 28*launcherScale.Scale or 0)))
  local anchor = drag.target.AnchorPoint
  drag.target.Position = UDim2.fromScale((x+anchor.X*drag.size.X)/view.X, (y+anchor.Y*drag.size.Y)/view.Y)
end)
local endConnection = Input.InputEnded:Connect(function(input)
  if drag and (input == drag.input or input.UserInputType == Enum.UserInputType.MouseButton1) then
    if drag.moved and drag.launcher then suppressOpenUntil = os.clock() + 0.3 end
    if drag.moved then saveSettings() end
    drag = nil
  end
end)
D.gui.Destroying:Connect(function() moveConnection:Disconnect(); endConnection:Disconnect(); drag = nil end)

local status = D.label(panel, '', UDim2.fromOffset(14,46), UDim2.new(1,-28,0,10), Color3.fromRGB(200,210,230), 11)
status.Visible = true; status.TextWrapped = false; status.TextScaled = true
D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=11}, status)

local discordSubtitle = D.label(panel, DISCORD, UDim2.fromOffset(10,27), UDim2.fromOffset(205,14), Color3.new(1,1,1), 11)
discordSubtitle.TextSize = 11; discordSubtitle.TextScaled = true; discordSubtitle.TextWrapped = false; discordSubtitle.Visible = true
D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=11}, discordSubtitle)

do
  local clicker = D.make('TextButton', {Text='', BackgroundTransparency=1, Position=UDim2.new(),
    Size=UDim2.fromScale(1,1), AutoButtonColor=false, ZIndex=discordSubtitle.ZIndex+1}, discordSubtitle)
  clicker.Activated:Connect(function()
    if type(setclipboard) == 'function' and pcall(setclipboard, DISCORD) then
      local oldText = discordSubtitle.Text
      discordSubtitle.Text = 'COPIED DISCORD LINK!'
      task.delay(1.5, function()
        if discordSubtitle.Parent and discordSubtitle.Text == 'COPIED DISCORD LINK!' then discordSubtitle.Text = oldText end
      end)
    end
  end)
end

local scope = D.make('TextButton', {Name='AllServers', Text='ALL SERVERS', Position=UDim2.new(0,10,1,-136),
  Size=UDim2.new(0.5,-15,0,34), BackgroundColor3=Color3.fromRGB(67,70,80), TextColor3=Color3.new(1,1,1), TextSize=14}, panel)
local myScope = D.make('TextButton', {Name='MyServer', Text='MY SERVER', Position=UDim2.new(0.5,5,1,-136),
  Size=UDim2.new(0.5,-15,0,34), BackgroundColor3=Color3.fromRGB(67,70,80), TextColor3=Color3.new(1,1,1), TextSize=14}, panel)
for _, button in ipairs({scope, myScope}) do
  button.TextScaled = true; button.TextWrapped = false
  D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=14}, button)
end
local function styleScope()
  scope.BackgroundColor3 = othersOnly and Color3.fromRGB(67,70,80) or Color3.fromRGB(45,130,75)
  myScope.BackgroundColor3 = othersOnly and Color3.fromRGB(45,130,75) or Color3.fromRGB(67,70,80)
  scope.TextColor3 = Color3.new(1,1,1); myScope.TextColor3 = Color3.new(1,1,1)
end
local requestScopeRender
local function setScope(myServer)
  if othersOnly == myServer then return end
  othersOnly = myServer; styleScope()
  queryEpoch = queryEpoch + 1; feedAt = -math.huge
  task.defer(saveSettings)
  if requestScopeRender then requestScopeRender() end
end
scope.Activated:Connect(function() setScope(false) end)
myScope.Activated:Connect(function() setScope(true) end)
styleScope()

local rarityOptions = {
  {name='Mythic', rank=6}, {name='Cosmic', rank=7}, {name='Secret', rank=8},
  {name='Eternal', rank=9}, {name='Divine', rank=10}, {name='Any', rank=0}
}
local rarityIndex = 1
for i, option in ipairs(rarityOptions) do if option.rank == minRank then rarityIndex = i break end end
minRank = rarityOptions[rarityIndex].rank
local function rarityButtonText()
  local name = rarityOptions[rarityIndex].name
  local colors = {Mythic='#FF4B55', Cosmic='#BE55FF', Secret='#FFFFFF', Eternal='#DACAEC', Divine='#FFCD37', Any='#FFFFFF'}
  return 'MIN RARITY: <font color="'..colors[name]..'">'..name..'</font>'
end
local rarity = D.make('TextButton', {Text=rarityButtonText(), RichText=true, Position=UDim2.new(0,10,1,-96),
  Size=UDim2.new(0.60,-15,0,36), BackgroundColor3=Color3.fromRGB(45,90,175), TextColor3=Color3.new(1,1,1), TextSize=12}, panel)
rarity.Activated:Connect(function()
  rarityIndex = rarityIndex % #rarityOptions + 1; minRank = rarityOptions[rarityIndex].rank
  rarity.Text = rarityButtonText(); queryEpoch = queryEpoch + 1; feed = {}; feedAt = -math.huge; saveSettings()
end)

local access = PREMIUM_EDITION and AUTO_KEY == '' and D.make('TextBox', {Text='', PlaceholderText='PREMIUM code',
  Position=UDim2.new(0,10,1,-44), Size=UDim2.new(1,-20,0,34), ClearTextOnFocus=false,
  BackgroundColor3=Color3.fromRGB(45,48,60), TextColor3=Color3.new(1,1,1), TextSize=12}, panel) or {Text=''}
local unlock = D.make('TextButton', {Text='PREMIUM', Position=UDim2.new(0.60,5,1,-96),
  Size=UDim2.new(0.40,-15,0,36), BackgroundColor3=Color3.fromRGB(210,170,35), TextColor3=Color3.new(1,1,1), TextSize=12}, panel)
access.Visible = PREMIUM_EDITION and AUTO_KEY == ''

local autoJoinBtn = D.make('TextButton', {Text='AUTO JOIN: '..(autoJoinEnabled and 'ON' or 'OFF'), Position=UDim2.new(0,10,1,-44),
  Size=UDim2.new(1,-20,0,34), BackgroundColor3=autoJoinEnabled and Color3.fromRGB(40,160,85) or Color3.fromRGB(160,50,50), TextColor3=Color3.new(1,1,1), TextSize=12}, panel)

local function refreshAutoJoinButtons()
  local onColor, offColor = Color3.fromRGB(40,160,85), Color3.fromRGB(160,50,50)
  autoJoinBtn.Text = 'AUTO JOIN: '..(autoJoinEnabled and 'ON' or 'OFF')
  autoJoinBtn.BackgroundColor3 = autoJoinEnabled and onColor or offColor
end
autoJoinBtn.Activated:Connect(function()
  autoJoinEnabled = not autoJoinEnabled
  refreshAutoJoinButtons()
  saveSettings()
end)

local themeModal, loadUiAsset, syncCloseArt

local refreshButton = D.make('TextButton', {Text='REFRESH', Position=UDim2.fromOffset(10,54),
  Size=UDim2.new(1,-20,0,30), BackgroundColor3=Color3.fromRGB(115,215,45),
  BackgroundTransparency=0.15, TextColor3=Color3.new(1,1,1), TextSize=14}, panel)
local resetTimer = D.label(refreshButton, 'RESET --:--', UDim2.fromOffset(8,0), UDim2.new(0.28,-8,1,0), Color3.fromRGB(230,245,255), 13)
resetTimer.TextXAlignment = Enum.TextXAlignment.Left; resetTimer.TextTruncate = Enum.TextTruncate.AtEnd; resetTimer.Active = false
local refreshing = false

local list = D.make('ScrollingFrame', {Position=UDim2.fromOffset(14,92), Size=UDim2.new(1,-16,1,-238),
  BackgroundTransparency=1, BorderSizePixel=0, AutomaticCanvasSize=Enum.AutomaticSize.None,
  CanvasSize=UDim2.new(), ScrollBarThickness=6, ScrollBarImageColor3=Color3.fromRGB(137,140,150), ScrollBarImageTransparency=0}, panel)
D.make('UIListLayout', {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder}, list)
local loadingVisible = true
local function loadingText(now) return 'Loading '..string.rep('.', math.floor(now/0.4) % 3 + 1) end
local aliveMessage = D.label(list, loadingText(os.clock()), UDim2.new(), UDim2.new(1,-10,0,40), nil, 12)

local function styleRaisedButton(button)
  if button:FindFirstChild('StuddedSurface') then return end
  local corner = button:FindFirstChildOfClass('UICorner'); if corner then corner.CornerRadius = UDim.new(0,3) end
  button.ClipsDescendants = true
  local texture = D.make('ImageLabel', {Name='StuddedSurface', Image='',
    Size=UDim2.fromScale(1,1), BackgroundTransparency=1, ImageTransparency=0.65,
    ImageColor3=button.BackgroundColor3, ScaleType=Enum.ScaleType.Tile, TileSize=UDim2.fromOffset(256,256), Active=false, ZIndex=button.ZIndex}, button)
  local function tint() texture.ImageColor3 = button.BackgroundColor3 end
  button:GetPropertyChangedSignal('BackgroundColor3'):Connect(tint)
  D.make('UIStroke', {Color=Color3.fromRGB(5,12,24), Thickness=2, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, button)
  D.make('UIGradient', {Color=ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(165,175,195)), Rotation=90}, button)
  D.make('Frame', {Position=UDim2.fromOffset(3,2), Size=UDim2.new(1,-6,0,1), BackgroundColor3=Color3.new(1,1,1),
    BackgroundTransparency=0.55, BorderSizePixel=0, Active=false, ZIndex=button.ZIndex+1}, button)
  D.make('Frame', {Position=UDim2.new(0,3,1,-3), Size=UDim2.new(1,-6,0,1), BackgroundColor3=Color3.new(0,0,0),
    BackgroundTransparency=0.25, BorderSizePixel=0, Active=false, ZIndex=button.ZIndex+1}, button)
  local caption = D.make('TextLabel', {Name='RaisedCaption', Text=button.Text, RichText=button.RichText,
    Size=UDim2.fromScale(1,1), BackgroundTransparency=1, TextColor3=button.TextColor3, TextSize=button.TextSize,
    Font=button.Font, TextScaled=button.TextScaled, TextWrapped=false, TextTransparency=0,
    TextStrokeColor3=Color3.fromRGB(5,10,20), TextStrokeTransparency=0.35, Active=false, ZIndex=button.ZIndex+2}, button)
  local function sync()
    local glyph = button:FindFirstChild('CustomButtonFont')
    caption.Text = button.Text; caption.TextColor3 = button.TextColor3
    caption.TextTransparency = (glyph and glyph.ImageTransparency == 0) and 1 or 0
    if button.TextTransparency ~= 1 then button.TextTransparency = 1 end
  end
  sync()
  button:GetPropertyChangedSignal('Text'):Connect(sync)
  button:GetPropertyChangedSignal('TextTransparency'):Connect(sync)
  button:GetPropertyChangedSignal('TextColor3'):Connect(sync)
  for _, child in ipairs(button:GetDescendants()) do
    if child:IsA('GuiObject') and child ~= texture and child ~= caption and child.Name ~= 'StuddedSurface' then
      child.ZIndex = math.max(child.ZIndex, button.ZIndex + 3)
    end
  end
end

task.spawn(function()
  local url = 'https://raw.githubusercontent.com/mallu837/JenicakesObsiUI/main/assets/background.png.txt'
  local text
  if type(game.HttpGet) == 'function' then
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == 'string' and #res > 100 then text = res end
  end
  if type(text) ~= 'string' or text == '' then return end
  local b64 = text:match('base64,(.+)') or text; b64 = b64:gsub('%s+', '')
  if b64:sub(1,1) == '"' then b64 = b64:sub(2, -2) end
  if type(base64decode) ~= 'function' or type(writefile) ~= 'function' or type(getcustomasset) ~= 'function' then return end
  pcall(function()
    writefile('jenicakes_bg.png', base64decode(b64))
    local asset = getcustomasset('jenicakes_bg.png')
    if type(asset) == 'string' and asset ~= '' and wallpaper.Parent then
      wallpaper.Image = asset; wallpaper.ScaleType = Enum.ScaleType.Crop; wallpaper.TileSize = UDim2.fromOffset(0, 0)
      wallpaper.ImageColor3 = Color3.new(1, 1, 1); wallpaper.ImageTransparency = 0.2
      wallpaperShade.BackgroundColor3 = Color3.fromRGB(45, 20, 60); wallpaperShade.BackgroundTransparency = 0.5
    end
  end)
end)

for _, button in ipairs({scope, myScope, rarity, unlock, refreshButton, sizeMinus, sizePlus, autoJoinBtn}) do styleRaisedButton(button) end
for _, button in ipairs({scope, myScope, rarity, unlock, autoJoinBtn}) do
  button.Font = Enum.Font.FredokaOne
  local caption = button:FindFirstChild('RaisedCaption')
  if caption then
    caption.Font = Enum.Font.FredokaOne; caption.TextScaled = true; caption.TextSize = 20
    caption.TextStrokeTransparency = 1; caption.Position = UDim2.fromOffset(6, 2); caption.Size = UDim2.new(1,-12,1,-4)
    D.make('UITextSizeConstraint', {MinTextSize=10, MaxTextSize=20}, caption)
    D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=2}, caption)
  end
end

loadUiAsset = function(target, key) end
themeModal = function(box)
  box.BackgroundColor3 = Color3.fromRGB(43,45,50); box.BackgroundTransparency = 0.03
  D.make('UIGradient', {Color=ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(165,168,178)), Rotation=90}, box)
  D.make('UIStroke', {Color=Color3.fromRGB(100,104,116), Thickness=2, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, box)
end
syncCloseArt = function(button)
  button.BackgroundTransparency = 1; button.Font = Enum.Font.FredokaOne; button.TextSize = 30
  button.TextColor3 = Color3.fromRGB(245,45,45); button.TextStrokeColor3 = Color3.new(0,0,0)
  local art = D.make('ImageLabel', {Name='SharedClosePNG', Image='', AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5), Size=UDim2.new(1,-8,1,-8), BackgroundTransparency=1,
    ScaleType=Enum.ScaleType.Fit, Active=false, ZIndex=button.ZIndex+1}, button)
  local function sync()
    if not art.Parent then return end
    local uri = closeArt.Image; art.Image = uri
    local hasImage = type(uri) == 'string' and uri ~= ''
    button.Text = hasImage and '' or '×'; button.TextTransparency = hasImage and 1 or 0; button.TextStrokeTransparency = hasImage and 1 or 0
  end
  closeArt:GetPropertyChangedSignal('Image'):Connect(sync); sync()
end

heading.AnchorPoint = Vector2.new(0.5, 0); heading.Position = UDim2.new(0.5,-10,0,2)
heading.Size = UDim2.new(1,-112,0,24); heading.TextXAlignment = Enum.TextXAlignment.Center
heading.Font = Enum.Font.Arcade; heading.TextTransparency = 0
discordSubtitle.AnchorPoint = Vector2.new(0.5, 0); discordSubtitle.Position = UDim2.new(0.5,0,0,27)
discordSubtitle.Size = UDim2.new(1,-112,0,14); discordSubtitle.TextXAlignment = Enum.TextXAlignment.Center

local settingsButton = D.make('TextButton', {Name='OpenSettings', Text='⚙', TextSize=30, Font=Enum.Font.GothamBold,
  Position=UDim2.fromOffset(6,3), Size=UDim2.fromOffset(40,40), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), ZIndex=6}, panel)
local gear = D.make('ImageLabel', {Name='SettingsGear', Image='', Position=UDim2.fromOffset(-1,-1),
  Size=UDim2.fromOffset(42,42), BackgroundTransparency=1, ScaleType=Enum.ScaleType.Fit, Active=false, ZIndex=7}, settingsButton)
loadUiAsset(gear, 'gear')

local settingsOverlay = D.make('TextButton', {Name='SettingsOverlay', Text='', Visible=false,
  Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.32, AutoButtonColor=false, Active=true, ZIndex=50}, panel)
local settingsBox = D.make('Frame', {Name='SettingsBox', AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
  Size=UDim2.new(1,-28,0,410), BackgroundColor3=Color3.fromRGB(43,45,50), Active=true, ZIndex=51}, settingsOverlay)
D.make('UICorner', {CornerRadius=UDim.new(0,4)}, settingsBox)
themeModal(settingsBox)

local function settingsLabel(text, y, xOffset, widthScale)
  local lbl = D.label(settingsBox, text, UDim2.fromOffset(xOffset or 14, y),
    UDim2.new(widthScale or 1, -28, 0, 28), Color3.new(1,1,1), 20)
  lbl.Font = Enum.Font.FredokaOne; lbl.TextXAlignment = Enum.TextXAlignment.Center; lbl.TextScaled = true; lbl.ZIndex = 54
  D.make('UITextSizeConstraint', {MinTextSize=12, MaxTextSize=20}, lbl); return lbl
end
settingsLabel('SETTINGS', 10)
settingsLabel('CUSTOM GUI', 59)

local incomeHeader = D.label(settingsBox, 'MIN INCOME ($/S)', UDim2.fromOffset(14,160),
  UDim2.new(0.60,-14,0,28), Color3.new(1,1,1), 18)
incomeHeader.Font = Enum.Font.FredokaOne; incomeHeader.TextXAlignment = Enum.TextXAlignment.Left
incomeHeader.TextScaled = true; incomeHeader.ZIndex = 54
D.make('UITextSizeConstraint', {MinTextSize=12, MaxTextSize=18}, incomeHeader)

local incomeToggle = D.make('TextButton', {Name='IncomeAutoToggle',
  Text='AUTO: '..(incomeAutoJoinEnabled and 'ON' or 'OFF'),
  Font=Enum.Font.FredokaOne, Position=UDim2.new(0.60,4,0,160),
  Size=UDim2.new(0.40,-18,0,28),
  BackgroundColor3=incomeAutoJoinEnabled and Color3.fromRGB(40,160,85) or Color3.fromRGB(160,50,50),
  TextColor3=Color3.new(1,1,1), TextSize=15, ZIndex=55}, settingsBox)
D.make('UICorner', {CornerRadius=UDim.new(0,5)}, incomeToggle)
D.make('UIStroke', {Color=Color3.fromRGB(30,32,38), Thickness=2, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, incomeToggle)
incomeToggle.Activated:Connect(function()
  incomeAutoJoinEnabled = not incomeAutoJoinEnabled
  incomeToggle.Text = 'AUTO: '..(incomeAutoJoinEnabled and 'ON' or 'OFF')
  incomeToggle.BackgroundColor3 = incomeAutoJoinEnabled and Color3.fromRGB(40,160,85) or Color3.fromRGB(160,50,50)
  saveSettings()
end)

settingsLabel('CUSTOM HOTKEY MENU', 250)

sizeMinus.Parent = settingsBox; sizePlus.Parent = settingsBox; sizeLabel.Parent = settingsBox
sizeMinus.Position = UDim2.new(0.5,-78,0,94); sizeMinus.Size = UDim2.fromOffset(48,48)
sizePlus.Position = UDim2.new(0.5,30,0,94); sizePlus.Size = UDim2.fromOffset(48,48)
sizeLabel.Position = UDim2.new(0.5,-28,0,107); sizeLabel.Size = UDim2.fromOffset(56,22)
for _, obj in ipairs({sizeMinus, sizePlus, sizeLabel}) do
  obj.ZIndex = 55
  for _, child in ipairs(obj:GetDescendants()) do if child:IsA('GuiObject') then child.ZIndex = 56 end end
end

local function formatIncome(v)
  if type(v) ~= 'number' or v ~= v or v <= 0 then return 'Any' end
  for _, e in ipairs({{1e18,'Qi'},{1e15,'Qa'},{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}}) do
    if v >= e[1] then
      local num = v/e[1]
      local shown = (num == math.floor(num)) and string.format('%d', num) or string.format('%.2f', num):gsub('0+$',''):gsub('%.$','')
      return '$'..shown..e[2]..'/s'
    end
  end
  return '$'..string.format('%.0f', v)..'/s'
end
local function parseIncome(raw)
  if type(raw) ~= 'string' then return nil end
  local s = raw:gsub('[%s$,]', ''):lower():gsub('/s$', ''):gsub('persecond$', ''):gsub('persec$', '')
  if s == '' or s == 'any' or s == '0' then return 0 end
  local num, suffix = s:match('^(%d+%.?%d*)(%a*)$')
  if not num then return nil end
  local value = tonumber(num)
  if not value or value ~= value or value < 0 then return nil end
  local powers = {['']=1, k=1e3, m=1e6, b=1e9, t=1e12, qa=1e15, q=1e15, qi=1e18}
  local factor = powers[suffix]
  if not factor then return nil end
  return value * factor
end

local incomeBox = D.make('TextBox', {Name='IncomeGate',
  Text=(minIncome > 0) and formatIncome(minIncome) or 'Any',
  PlaceholderText='Any (e.g. 2.5m)',
  Position=UDim2.new(0,14,0,199), Size=UDim2.new(1,-28,0,42),
  BackgroundColor3=(minIncome > 0) and Color3.fromRGB(40,140,90) or Color3.fromRGB(67,71,82),
  TextColor3=Color3.new(1,1,1), Font=Enum.Font.FredokaOne, TextSize=18,
  ClearTextOnFocus=true, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=55}, settingsBox)
D.make('UICorner', {CornerRadius=UDim.new(0,5)}, incomeBox)
D.make('UIStroke', {Color=Color3.fromRGB(30,32,38), Thickness=2, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, incomeBox)

local function commitIncome()
  local parsed = parseIncome(incomeBox.Text)
  if parsed == nil then
    incomeBox.Text = (minIncome > 0) and formatIncome(minIncome) or 'Any'
    incomeBox.BackgroundColor3 = (minIncome > 0) and Color3.fromRGB(40,140,90) or Color3.fromRGB(67,71,82)
    return
  end
  minIncome = math.floor(parsed)
  incomeBox.Text = (minIncome > 0) and formatIncome(minIncome) or 'Any'
  incomeBox.BackgroundColor3 = (minIncome > 0) and Color3.fromRGB(40,140,90) or Color3.fromRGB(67,71,82)
  saveSettings()
end

incomeBox.FocusLost:Connect(function(enterPressed)
  commitIncome()
  if enterPressed then incomeBox:ReleaseFocus() end
end)

incomeBox:GetPropertyChangedSignal('Text'):Connect(function()
  if incomeBox:IsFocused() then
    local parsed = parseIncome(incomeBox.Text)
    incomeBox.BackgroundColor3 = (parsed and parsed > 0) and Color3.fromRGB(40,140,90) or Color3.fromRGB(67,71,82)
  end
end)

local menuHotkey = Enum.KeyCode.F
if type(settings.menuHotkey) == 'string' then
  pcall(function()
    local saved = Enum.KeyCode[settings.menuHotkey]
    if saved and saved ~= Enum.KeyCode.Unknown and not (settings.menuHotkey == 'RightShift' and settings.hotkeyDefaultVersion ~= 2) then
      menuHotkey = saved
    end
  end)
end

local hotkeyButton = D.make('TextButton', {Name='HotkeyBind', Text=menuHotkey.Name, Font=Enum.Font.FredokaOne,
  Position=UDim2.new(0,14,0,289), Size=UDim2.new(1,-28,0,42), BackgroundColor3=Color3.fromRGB(67,71,82),
  TextColor3=Color3.new(1,1,1), TextSize=18, ZIndex=55}, settingsBox)
local waitingForHotkey = false
local function stopSettings() waitingForHotkey = false; settingsOverlay.Visible = false; hotkeyButton.Text = menuHotkey.Name end
local settingsClose = D.make('TextButton', {Name='CloseSettings', Text='×', Position=UDim2.new(1,-46,0,4),
  Size=UDim2.fromOffset(40,40), BackgroundColor3=Color3.fromRGB(170,45,55), TextColor3=Color3.new(1,1,1), TextSize=24, ZIndex=55}, settingsBox)
syncCloseArt(settingsClose); settingsClose.Activated:Connect(stopSettings); settingsOverlay.Activated:Connect(stopSettings)
settingsButton.Activated:Connect(function() if settingsOverlay.Visible then stopSettings() else settingsOverlay.Visible = true end end)
hotkeyButton.Activated:Connect(function() waitingForHotkey = true; hotkeyButton.Text = 'PRESS A KEY  (ESC TO CANCEL)' end)
local hotkeyConnection = Input.InputBegan:Connect(function(input, processed)
  if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.Unknown then return end
  if waitingForHotkey then
    waitingForHotkey = false
    if input.KeyCode ~= Enum.KeyCode.Escape then menuHotkey = input.KeyCode; saveSettings() end
    hotkeyButton.Text = menuHotkey.Name; return
  end
  if processed or Input:GetFocusedTextBox() then return end
  if input.KeyCode == menuHotkey then
    panel.Visible = not panel.Visible; D.localPanel.Visible = not panel.Visible
    if not panel.Visible then stopSettings() end
  end
end)
D.gui.Destroying:Connect(function() hotkeyConnection:Disconnect() end)

local premiumPopup
local function showPremiumPopup()
  if premiumPopup then premiumPopup.Visible = true; return end
  premiumPopup = D.make('Frame', {Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(0,0,0),
    BackgroundTransparency=0.3, Active=true, ZIndex=30}, panel)
  local box = D.make('Frame', {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.new(1,-28,0,232), BackgroundColor3=Color3.fromRGB(43,45,50), ZIndex=31}, premiumPopup)
  D.make('UICorner', {CornerRadius=UDim.new(0,4)}, box); themeModal(box)
  local title = D.label(box, 'JOIN DISCORD TO GET PREMIUM', UDim2.fromOffset(12,76), UDim2.new(1,-24,0,52), Color3.new(1,1,1), 20)
  title.Font = Enum.Font.FredokaOne; title.TextScaled = true; title.TextWrapped = true
  title.TextXAlignment = Enum.TextXAlignment.Center; title.ZIndex = 32
  D.make('UITextSizeConstraint', {MinTextSize=12, MaxTextSize=21}, title)
  local linkBar = D.make('Frame', {Position=UDim2.fromOffset(12,148), Size=UDim2.new(1,-24,0,64),
    BackgroundColor3=Color3.fromRGB(57,60,68), ZIndex=32}, box)
  D.make('UICorner', {CornerRadius=UDim.new(0,5)}, linkBar)
  local link = D.label(linkBar, DISCORD, UDim2.fromOffset(8,6), UDim2.new(1,-116,1,-12), Color3.fromRGB(200,210,255), 12)
  link.TextSize = 12; link.TextWrapped = true; link.ZIndex = 33
  local popupCopy = D.make('TextButton', {Font=Enum.Font.FredokaOne, Text='COPY LINK', Position=UDim2.new(1,-103,0.5,-18),
    Size=UDim2.fromOffset(96,36), BackgroundColor3=Color3.fromRGB(85,105,220), TextColor3=Color3.new(1,1,1), TextSize=14, ZIndex=33}, linkBar)
  popupCopy.Activated:Connect(function()
    if type(setclipboard) == 'function' and pcall(setclipboard, DISCORD) then
      popupCopy.Text = 'COPIED'; task.delay(1.5, function() if active then popupCopy.Text = 'COPY LINK' end end)
    else popupCopy.Text = 'COPY UNAVAILABLE' end
  end)
  local dismiss = D.make('TextButton', {Text='×', Position=UDim2.new(1,-34,0,5), Size=UDim2.fromOffset(28,26),
    BackgroundColor3=Color3.fromRGB(135,55,90), TextColor3=Color3.new(1,1,1), TextSize=22, ZIndex=32}, box)
  syncCloseArt(dismiss); dismiss.Activated:Connect(function() premiumPopup.Visible = false end)
end
unlock.Activated:Connect(function() if not PREMIUM_EDITION then showPremiumPopup() end end)

local mutationPalettes = {
  title = {Color3.fromRGB(223,221,221), Color3.fromRGB(255,255,255), Color3.fromRGB(214,214,214)},
  discord = {Color3.fromRGB(255,0,225), Color3.fromRGB(161,0,255)},
}
local filterPalettes = {
  cosmic = {Color3.fromRGB(67,37,239), Color3.fromRGB(113,29,255), Color3.fromRGB(41,12,217)},
  secret = {Color3.fromRGB(40,40,40), Color3.fromRGB(195,195,201)},
  eternal = {Color3.fromRGB(143,203,193), Color3.fromRGB(227,236,234), Color3.fromRGB(182,165,198), Color3.fromRGB(218,202,236)},
}
local rarityColors = {
  divine=Color3.fromRGB(255,205,55), eternal=Color3.fromRGB(218,202,236), secret=Color3.fromRGB(255,255,255),
  cosmic=Color3.fromRGB(190,85,255), mythic=Color3.fromRGB(255,75,85), legendary=Color3.fromRGB(255,155,45),
  epic=Color3.fromRGB(255,110,200), rare=Color3.fromRGB(65,165,255), uncommon=Color3.fromRGB(105,220,120),
  common=Color3.fromRGB(220,225,235),
}
local mutationGradients = {discord={}, title={}}
local rarityGradientBuckets = {cosmic={}, secret={}, eternal={}}
local function mutationSequence(palette, now)
  local phase = (now/4) % 1
  local points = {}
  for i = 0, 16 do
    local sample = ((i/16 - phase) % 1) * #palette
    local index = math.floor(sample)
    points[#points+1] = ColorSequenceKeypoint.new(i/16, palette[index+1]:Lerp(palette[(index+1) % #palette + 1], sample - index))
  end
  return ColorSequence.new(points)
end
local function mutationStyle(object, name)
  local key = name:lower(); if key == 'gold' then key = 'golden' end
  local palette = mutationPalettes[key]; if not palette then return end
  if object:IsA('TextLabel') then object.TextColor3 = Color3.new(1,1,1); object.TextStrokeTransparency = 1
  else object.ImageColor3 = Color3.new(1,1,1) end
  local gradient = D.make('UIGradient', {Color=mutationSequence(palette, os.clock()), Rotation=0}, object)
  local bucket = mutationGradients[key]; bucket[#bucket+1] = gradient
end
mutationStyle(discordSubtitle, 'discord'); mutationStyle(heading, 'title')

local filterWords = D.make('Frame', {Name='RarityFontParts', AnchorPoint=Vector2.new(0.5,0.5),
  Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromOffset(1,26), BackgroundTransparency=1, Active=false, ZIndex=rarity.ZIndex+5}, rarity)
local function filterLabel(text)
  local lbl = D.make('TextLabel', {Text=text, Font=Enum.Font.FredokaOne, TextSize=20, TextColor3=Color3.new(1,1,1),
    TextStrokeTransparency=1, BackgroundTransparency=1, TextWrapped=false, TextScaled=false, Active=false, ZIndex=filterWords.ZIndex}, filterWords)
  D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=2}, lbl); return lbl
end
local filterPrefix = filterLabel('MIN RARITY:')
local filterWord = filterLabel('Any')
local filterGradient = D.make('UIGradient', {Enabled=false, Rotation=0}, filterWord)
local filterName = rarityOptions[rarityIndex].name:lower()
local function updateFilterColor(now)
  local palette = filterPalettes[filterName]
  if palette then
    filterWord.TextColor3 = Color3.new(1,1,1); filterGradient.Enabled = true; filterGradient.Color = mutationSequence(palette, now)
  else
    filterGradient.Enabled = false; filterWord.TextColor3 = rarityColors[filterName] or Color3.new(1,1,1)
  end
end
local function refreshFilterWord()
  local name = rarityOptions[rarityIndex].name; filterName = name:lower(); filterWord.Text = name
  filterGradient.Rotation = filterName == 'eternal' and 90 or 0
  rarity.TextTransparency = 1
  local caption = rarity:FindFirstChild('RaisedCaption'); if caption then caption.Visible = false end
  local panelWidth = panel.Size.X.Offset > 0 and panel.Size.X.Offset or 402
  local available = math.max(20, panelWidth * rarity.Size.X.Scale + rarity.Size.X.Offset - 20)
  local service = game:GetService('TextService')
  local size, prefixWidth, wordWidth = 22, 0, 0
  repeat
    prefixWidth = math.ceil(service:GetTextSize(filterPrefix.Text, size, Enum.Font.FredokaOne, Vector2.new(1000,1000)).X) + 4
    wordWidth = math.ceil(service:GetTextSize(name, size, Enum.Font.FredokaOne, Vector2.new(1000,1000)).X) + 4
    if prefixWidth + wordWidth + 6 <= available or size <= 10 then break end
    size = size - 1
  until false
  filterWords.Size = UDim2.fromOffset(prefixWidth + wordWidth + 6, 26)
  filterPrefix.Position = UDim2.new(); filterPrefix.Size = UDim2.fromOffset(prefixWidth, 26); filterPrefix.TextSize = size
  filterWord.Position = UDim2.fromOffset(prefixWidth + 6, 0); filterWord.Size = UDim2.fromOffset(wordWidth, 26); filterWord.TextSize = size
  updateFilterColor(os.clock())
end
rarity:GetPropertyChangedSignal('Text'):Connect(refreshFilterWord); refreshFilterWord()
local function styleRarityLabel(lbl, key)
  local palette = filterPalettes[key]; if not palette then return end
  lbl.TextColor3 = Color3.new(1,1,1)
  if key == 'secret' then lbl.TextStrokeColor3 = Color3.new(0,0,0); lbl.TextStrokeTransparency = 0.25 end
  local gradient = D.make('UIGradient', {Color=mutationSequence(palette, os.clock()), Rotation=key == 'eternal' and 90 or 0}, lbl)
  rarityGradientBuckets[key][gradient] = true
end
local lastMutationUpdate = 0
local mutationMotion = game:GetService('RunService').Heartbeat:Connect(function()
  local now = os.clock(); if now - lastMutationUpdate < 1/20 then return end; lastMutationUpdate = now
  if refreshing then
    local text = 'REFRESHING'..string.rep('.', math.floor(now/0.4) % 3 + 1)
    if refreshButton.Text ~= text then refreshButton.Text = text end
  end
  if loadingVisible and aliveMessage.Visible then
    local text = loadingText(now); if aliveMessage.Text ~= text then aliveMessage.Text = text end
  end
  updateFilterColor(now)
  for key, bucket in pairs(rarityGradientBuckets) do
    if next(bucket) then
      local colors = mutationSequence(filterPalettes[key], now)
      for gradient in pairs(bucket) do if gradient.Parent then gradient.Color = colors else bucket[gradient] = nil end end
    end
  end
  for key, bucket in pairs(mutationGradients) do
    if #bucket > 0 then
      local colors = mutationSequence(mutationPalettes[key], now)
      for i = #bucket, 1, -1 do
        local gradient = bucket[i]
        if not gradient.Parent then table.remove(bucket, i) else gradient.Color = colors end
      end
    end
  end
end)
D.gui.Destroying:Connect(function() mutationMotion:Disconnect() end)

local ageLabels = {}
local function resetAgeText(cycle)
  if not cycle or type(cycle.remaining) ~= 'number' or cycle.remaining ~= cycle.remaining then return '--' end
  local remaining = math.clamp(math.ceil(cycle.remaining), 0, 300)
  return tostring(math.floor((300 - remaining) / 60))..'m ago'
end
local function resetAgeColor(cycle)
  local text = resetAgeText(cycle); local minutes = tonumber(text:match('^(%d+)m ago$'))
  if minutes and minutes >= 4 then return Color3.fromRGB(255,85,85) end
  if minutes and minutes >= 2 then return Color3.fromRGB(255,215,65) end
  return Color3.fromRGB(210,216,230)
end
local function updateSpawnAges(cycle)
  local text = resetAgeText(cycle); local color = resetAgeColor(cycle)
  for _, item in ipairs(ageLabels) do
    if item.label.Parent then
      if item.label.Text ~= text then item.label.Text = text end
      if item.label.TextColor3 ~= color then item.label.TextColor3 = color end
    end
  end
end

local function compactCardHeight() return math.clamp(math.floor((panel.Size.Y.Offset-238-16)/5), 76, 112) end
local function joinPresentation(entry)
  local here = entry.isLocal or entry.jobId == game.JobId
  if othersOnly and here then return 'HERE', Color3.fromRGB(86,90,100), false end
  if entry.takenConfirmed then return 'TAKEN', Color3.fromRGB(235,55,65), false end
  if entry.full or entry.unavailable then return 'FULL', Color3.fromRGB(255,75,85), false end
  if here then return 'HERE', Color3.fromRGB(86,90,100), false end
  if joining and joiningKey == entry.key then return 'JOINING...', Color3.fromRGB(40,160,85), false end
  return 'JOIN', Color3.fromRGB(40,160,85), true
end
local rankWidthCache, raritySizeCache = {}, {}
local function cardSignature(entry)
  return Http:JSONEncode({tostring(entry.rarity), tostring(entry.mutations), tostring(entry.mutationText),
    tostring(entry.traitsKnown), tostring(entry.isEvent), tostring(entry.source), tostring(entry.full), tostring(entry.unavailable)})
end
local function compactWeightToFit(text, available, size, service)
  local function fits(v) return service:GetTextSize(v, size, Enum.Font.GothamBlack, Vector2.new(1000,1000)).X <= available end
  local result = text
  while not fits(result) do
    local prefix, whole, fraction, suffix = result:match('^(.-)(%d+)%.(%d+)(.*)$')
    if not fraction then break end
    fraction = fraction:sub(1, -2); result = prefix..whole..(#fraction > 0 and '.'..fraction or '')..suffix
  end
  return result
end
local function weightPresentation(entry)
  local isKg = type(entry.weight) == 'number'
  local value = isKg and entry.weight or entry.scale
  local neutral = Color3.fromRGB(220,224,235)
  if type(value) ~= 'number' or value ~= value or value < 0 or value == math.huge then return '—', neutral end
  local compact = value >= 1000; local number
  if value >= 1e15 then number = string.format('%.2g', value)
  elseif value >= 1e12 then number = string.format('%.2f', value/1e12):gsub('0+$',''):gsub('%.$','')..'T'
  elseif value >= 1e9 then number = string.format('%.2f', value/1e9):gsub('0+$',''):gsub('%.$','')..'B'
  elseif value >= 1e6 then number = string.format('%.2f', value/1e6):gsub('0+$',''):gsub('%.$','')..'M'
  elseif compact then number = string.format('%.2f', value/1000):gsub('0+$',''):gsub('%.$','')..'K'
  else number = string.format('%.2f', value) end
  local color = neutral
  if not isKg and not compact then
    if value < 0.60 then color = Color3.fromRGB(245,85,85)
    elseif value < 0.80 then color = Color3.fromRGB(255,210,75)
    elseif value > 2.50 then color = Color3.fromRGB(100,240,140) end
  end
  return (isKg and number..' KG' or '×'..number), color
end
local function fitFinanceText(card)
  local rowWidth = panel.Size.X.Offset - 28; local width = rowWidth - 184
  local service = game:GetService('TextService')
  local weightSize = type(card.entry.weight) == 'number' and 16 or 19
  local weightAvailable = width*0.46 - 10
  local text = weightPresentation(card.entry)
  card.weightLabel.Text = compactWeightToFit(text, weightAvailable, weightSize, service)
  for _, spec in ipairs({{card.incomeLabel, width*0.54-10, 20}, {card.weightLabel, weightAvailable, weightSize}}) do
    local lbl, avail, size = spec[1], spec[2], spec[3]
    while size > 8 and service:GetTextSize(lbl.Text, size, Enum.Font.GothamBlack, Vector2.new(1000,1000)).X > avail do size = size - 1 end
    lbl.TextSize = size
  end
end
local function mutationNames(entry)
  if entry.isEvent or entry.source == 'event' then return {} end
  local raw = tostring(entry.mutations or entry.mutationText or ''):gsub('%s*%[[^%]]*%]',''):match('^%s*(.-)%s*$')
  raw = raw:gsub('^[Mm]utation[sS]?%s*:%s*','')
  local lower = raw:lower()
  if entry.traitsKnown == false or lower:find('unknown',1,true) or lower:find('unverified',1,true) then return {'Unknown'} end
  if raw == '' or lower == 'none' or lower == 'normal' or lower == 'none (explicit data)' then return {} end
  local result, seen = {}, {}
  for token in raw:gmatch('[^,;|+]+') do
    local name = token:match('^%s*(.-)%s*$'); local key = name:lower()
    if key == 'gold' or key == 'golden' then name = 'Golden'; key = 'golden'
    elseif key == 'silver' then name = 'Silver'
    elseif key == 'rainbow' then name = 'Rainbow' end
    if name ~= '' and not seen[key] then result[#result+1] = name; seen[key] = true end
  end
  local order = {golden=1, silver=2, rainbow=3}
  table.sort(result, function(a,b)
    local left, right = order[a:lower()] or 4, order[b:lower()] or 4
    if left ~= right then return left < right end
    return a:lower() < b:lower()
  end)
  return result
end
local function mutationWidth(name, textService, available)
  return math.min(available, math.ceil(textService:GetTextSize(name,22,Enum.Font.Arcade,Vector2.new(1000,28)).X)+8)
end
local function mutationWord(row, name, position, width)
  local word = D.label(row, name, position, UDim2.fromOffset(width,28), Color3.fromRGB(245,210,125), 22)
  word.Font = Enum.Font.Arcade; word.TextXAlignment = Enum.TextXAlignment.Center
  word.TextTruncate = Enum.TextTruncate.None; word.TextScaled = true; word.TextWrapped = false
  D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=22}, word)
  mutationStyle(word, name)
  word.TextStrokeColor3 = Color3.new(0,0,0); word.TextStrokeTransparency = 0
  D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=1.1}, word)
  return word
end
local function updateCard(card, entry, i)
  local height = compactCardHeight()
  if card.compactHeight ~= height or card.renderScale ~= responsiveScale.Scale then
    card.renderScale = responsiveScale.Scale; card.compactHeight = height
    card.row.Size = UDim2.new(1,-12,0,height)
    local renderScale = responsiveScale.Scale; if type(renderScale) ~= 'number' or renderScale <= 0 then renderScale = 1 end
    local iconSize = math.floor(math.min(80, height-22)*renderScale)/renderScale
    card.icon.Size = UDim2.fromOffset(iconSize, iconSize)
    card.icon.Position = UDim2.fromOffset(math.floor((4+(78-iconSize)/2)*renderScale)/renderScale, 0)
    card.spotlight.Position = card.icon.Position; card.spotlight.Size = card.icon.Size
    card.join.Position = UDim2.new(1,-98,0,math.min(29, height-54))
  end
  local rankText = '#'..tostring(entry.displayRank or entry.globalRank or i)
  if card.rankLabel.Text ~= rankText then
    local width = rankWidthCache[rankText]
    if not width then
      width = math.ceil(game:GetService('TextService'):GetTextSize(rankText, 20, Enum.Font.FredokaOne, Vector2.new(1000,28)).X)+4
      rankWidthCache[rankText] = width
    end
    card.rankLabel.Text = rankText; card.rankLabel.Size = UDim2.fromOffset(width, 28)
    card.nameLabel.Position = UDim2.fromOffset(86+width, 3); card.nameLabel.Size = UDim2.new(1, -94-width, 0, 26)
  end
  if card.nameLabel.Text ~= tostring(entry.name) then card.nameLabel.Text = tostring(entry.name) end
  if card.icon.Image ~= (entry.icon or '') then card.icon.Image = entry.icon or '' end
  if not card.financeReady or card.rate ~= entry.rate or card.missingRate ~= entry.missingRate then
    card.incomeLabel.Text = entry.missingRate and 'Income unavailable' or D.money(entry.rate)
    card.rate = entry.rate; card.missingRate = entry.missingRate
  end
  if not card.financeReady or card.scale ~= entry.scale or card.weight ~= entry.weight then
    local text, color = weightPresentation(entry)
    local isScale = type(entry.weight) ~= 'number' and type(entry.scale) == 'number'
    card.weightLabel.Text = text; card.weightLabel.TextColor3 = color
    card.weightLabel.Font = Enum.Font.GothamBlack; card.weightLabel.TextSize = isScale and 19 or 16
    card.weightLimit.MaxTextSize = isScale and 19 or 16
    card.scale = entry.scale; card.weight = entry.weight
  end
  if not card.financeReady or card.fittedRate ~= entry.rate or card.fittedWeight ~= entry.weight or card.fittedScale ~= entry.scale then
    fitFinanceText(card); card.fittedRate = entry.rate; card.fittedWeight = entry.weight; card.fittedScale = entry.scale
  end
  card.financeReady = true
  local text, color, enabled = joinPresentation(entry)
  if card.join.Text ~= text then card.join.Text = text end
  if card.buttonText ~= text or card.buttonEnabled ~= enabled then
    card.join.BackgroundColor3 = color; card.join.Active = enabled; card.join.AutoButtonColor = enabled
    card.join.Selectable = enabled; card.buttonText = text; card.buttonEnabled = enabled
  end
end

local function network(url, method, body, hdrs, raw, timeout)
  if type(requestFn) ~= 'function' then return nil, 'Executor HTTP unavailable' end
  timeout = timeout or 6
  local waitDeadline = os.clock() + 1.5
  while networkBusy and os.clock() < waitDeadline and active do task.wait(0.02) end
  if networkBusy then return nil, 'Network busy' end
  networkBusy = true
  local done, result = false, nil
  task.spawn(function()
    result = table.pack(pcall(requestFn, {Url=url, Method=method, Headers=hdrs or {}, Body=body, Timeout=timeout}))
    done = true; networkBusy = false
  end)
  local deadline = os.clock() + timeout + 1
  while active and not done and os.clock() < deadline do task.wait(0.03) end
  if not done then return nil, 'Network timeout' end
  if not result[1] then return nil, 'Network failed' end
  local response = result[2]
  if type(response) ~= 'table' then return nil, 'Invalid response' end
  local code = tonumber(response.StatusCode or response.Status)
  if code ~= 200 then
    local msg = 'HTTP '..tostring(code)
    local ok, details = pcall(Http.JSONDecode, Http, response.Body or '')
    if ok and type(details) == 'table' and type(details.error) == 'string' then msg = msg..': '..details.error:sub(1, 120) end
    return nil, msg
  end
  if raw then return response.Body end
  local ok, decoded = pcall(Http.JSONDecode, Http, response.Body or '')
  if not ok then return nil, 'Invalid JSON' end
  return decoded
end

local function loadConfig()
  local data, err = network('https://raw.githubusercontent.com/syss1211/Tenshi-script/main/NYX-Finder-Config.json?nyx='..os.time(), 'GET', nil, nil, false, 6)
  if not data then return false, err end
  if type(data.endpoint) ~= 'string' or not data.endpoint:match('^https://[%w%.%-]+$') or type(data.roomKey) ~= 'string' then
    return false, 'Invalid config'
  end
  config = data; configAt = os.clock()
  return true
end

local function headers()
  return {['Content-Type']='application/json', ['X-NYX-Room']=config and config.roomKey or ''}
end

local function snapshot()
  local eggs = {}
  for _, entry in ipairs(latestEntries) do
    if not entry.unresolved and entry.uid and entry.rate and entry.rate > 0 then
      eggs[#eggs+1] = {
        uid=tostring(entry.uid), name=entry.name, category=entry.category,
        rarity=entry.rarity, rank=entry.tier, rate=entry.rate, scale=entry.scale,
        weight=entry.weight, icon=entry.icon, area=entry.areaKey or entry.area,
        mutations=entry.mutationText or (entry.traitsKnown == false and 'UNKNOWN' or ''),
        traitsKnown=entry.traitsKnown ~= false,
        estimated=entry.estimated == true or entry.unmutatedRate ~= nil,
        source=entry.isEvent and 'event' or 'field',
      }
    end
  end
  table.sort(eggs, function(a,b) return a.rate > b.rate end)
  while #eggs > 40 do eggs[#eggs] = nil end
  return eggs
end

local function report()
  if game.JobId == '' then return false, 'No live server ID' end
  if not config then return false, 'No config' end
  local body = {placeId=game.PlaceId, jobId=game.JobId, reporterId=reporterId, eggs=snapshot()}
  local data, err = network(config.endpoint..'/v1/report', 'POST', Http:JSONEncode(body), headers(), false, 6)
  if data and data.ok == true then return true, 'Shared '..tostring(data.accepted)..' eggs' end
  return false, err or 'Report failed'
end

local function refresh()
  local epoch = queryEpoch
  if not config then return false, 'No config' end
  local query = '?placeId='..game.PlaceId..'&limit=50&tier=public&offset=0&minRate='..tostring(minRate)..'&minRank='..tostring(minRank)
  if othersOnly then query = query..'&onlyJob='..Http:UrlEncode(game.JobId) end
  local data, err = network(config.endpoint..'/v1/eggs'..query, 'GET', nil, headers(), false, 5)
  if epoch ~= queryEpoch then return true end
  if not data or type(data.items) ~= 'table' then return false, err or 'Invalid feed' end
  clockOffset = (tonumber(data.serverTime) or os.time()*1000)/1000 - os.clock()
  feed = data.items
  feedAt = os.clock()
  queryStatus = string.format('Updated | %d servers | %d participants', data.servers or 0, data.participants or 0)
  return true
end

local function isBlocked(jobId)
  local t = blockedServers[jobId]
  if not t then return false end
  if os.clock() - t > BLOCK_TTL then blockedServers[jobId] = nil; return false end
  return true
end

local function markBlocked(jobId, reason)
  if type(jobId) ~= 'string' then return end
  blockedServers[jobId] = os.clock()
  print('[Jen Auto-Join] blocked', jobId, reason)
end

local function isRecentlyAttempted(jobId)
  local t = recentlyAttempted[jobId]
  if not t then return false end
  if os.clock() - t > ATTEMPT_TTL then recentlyAttempted[jobId] = nil; return false end
  return true
end
local function markAttempted(jobId)
  if type(jobId) == 'string' and jobId ~= '' then recentlyAttempted[jobId] = os.clock() end
end

local function isFullErr(msg)
  if type(msg) ~= 'string' then return false end
  local m = msg:lower()
  return m:find('full', 1, true) ~= nil
      or m:find('no available', 1, true) ~= nil
      or m:find('queue', 1, true) ~= nil
      or m:find('maximum', 1, true) ~= nil
end

local function isBlockedErr(msg)
  if type(msg) ~= 'string' then return false end
  local m = msg:lower()
  return m:find('restricted', 1, true) ~= nil
      or m:find('not allowed', 1, true) ~= nil
      or m:find('blocked', 1, true) ~= nil
      or m:find('private', 1, true) ~= nil
      or m:find('access denied', 1, true) ~= nil
      or m:find('kicked', 1, true) ~= nil
      or m:find('banned', 1, true) ~= nil
end

local function passesIncomeGate(entry)
  if minIncome <= 0 then return true end
  local rate = tonumber(entry.rate)
  return type(rate) == 'number' and rate >= minIncome
end

local function passesMainGate(entry)
  local rank = tonumber(entry.rank or entry.tier)
  if type(rank) == 'number' and rank < minRank then return false end
  if entry.full or entry.unavailable or entry.takenConfirmed then return false end
  if isBlocked(entry.jobId) then return false end
  return true
end

local function executeJoinWithFallback(chain, startIdx)
  if joining or type(chain) ~= 'table' or #chain == 0 then return end
  local idx = startIdx or 1
  local tried = {}

  local function fireOne(entry)
    if not entry or entry.jobId == game.JobId or not entry.placeId then return false end
    if isBlocked(entry.jobId) or entry.full or entry.unavailable then return false end
    local placeId = tonumber(entry.placeId)
    local jobId = entry.jobId
    if not placeId or type(jobId) ~= 'string' or jobId == '' then return false end
    if (os.clock() + clockOffset) * 1000 >= (entry.expiresAt or 0) then return false end

    local card = cardsByKey[entry.key]
    joining = true; joiningKey = entry.key
    if card then pcall(updateCard, card, entry, card.row.LayoutOrder or 1) end

    local ok, err = pcall(function()
      Teleports:TeleportToPlaceInstance(placeId, jobId, D.player)
    end)

    if ok then
      entry.verifiedAt = os.clock()
      notifOnJoin(entry)
      if config and config.endpoint then
        task.spawn(function()
          local claim = network(config.endpoint..'/v1/join', 'POST',
            Http:JSONEncode({placeId=placeId, jobId=jobId, uid=entry.uid,
              reporterId=reporterId, userId=D.player.UserId}), headers(), false, 2.5)
          if claim and claim.allowed ~= true then
            entry.full = claim.full == true
            entry.unavailable = claim.unavailable == true
            entry.takenConfirmed = claim.takenConfirmed == true
            local c = cardsByKey[entry.key]
            if c then pcall(updateCard, c, entry, c.row.LayoutOrder or 1) end
          end
        end)
      end
      if config then task.spawn(function() pcall(report) end) end
    else
      local msg = tostring(err)
      joining = false; joiningKey = nil
      lastJoinErrorMsg = 'Join failed: '..msg; lastJoinErrorAt = os.clock()
      if isBlockedErr(msg) then markBlocked(jobId, msg)
      elseif isFullErr(msg) then entry.full = true end
      if card then pcall(updateCard, card, entry, card.row.LayoutOrder or 1) end
      return false
    end

    local waitStart = os.clock()
    while joining and active and os.clock() - waitStart < 0.4 do task.wait(0.02) end
    if joining then joining = false; joiningKey = nil end
    return true
  end

  while active and idx <= #chain do
    local entry = chain[idx]; idx = idx + 1
    if entry and not tried[entry.key] then
      tried[entry.key] = true
      if fireOne(entry) then break end
    end
  end

  task.delay(20, function() if joining then joining = false; joiningKey = nil end end)
end

local function startSpamJoin()
  print('[Jen Auto-Join] Triggered.')

  if not config or os.clock() - configAt > 60 then
    local ok, err = loadConfig()
    if not ok then
      queryStatus = 'Auto-join: config unavailable ('..tostring(err)..')'
      print('[Jen Auto-Join] config load failed:', err)
      return
    end
  end

  task.spawn(function() pcall(refresh) end)

  local waitStart = os.clock()
  local function haveRemote()
    for _, e in ipairs(currentTopEntries) do
      if e and e.jobId and e.jobId ~= game.JobId and passesMainGate(e) then return true end
    end
    for _, e in ipairs(feed) do
      if e and e.jobId and e.jobId ~= game.JobId and passesMainGate(e) then return true end
    end
    return false
  end

  while active and not haveRemote() do
    if os.clock() - waitStart > 10 then
      queryStatus = 'Auto-join: no remote target in feed'
      print('[Jen Auto-Join] Timed out waiting for remote targets.')
      return
    end
    pcall(function() if config and os.clock() - feedAt > 2 then refresh() end end)
    task.wait(0.15)
  end

  local startTime = os.clock(); local DURATION = 10; local attempts = 0
  task.spawn(function()
    while active and (os.clock() - startTime) < DURATION do
      local chain = {}
      for i = 1, math.min(5, #currentTopEntries) do
        local e = currentTopEntries[i]
        if e and e.jobId ~= game.JobId and e.placeId and passesMainGate(e) then
          chain[#chain + 1] = e
        end
      end
      if #chain == 0 then
        for _, e in ipairs(feed) do
          if e and e.jobId and e.jobId ~= game.JobId and e.placeId and passesMainGate(e) then
            chain[#chain + 1] = e
            if #chain >= 5 then break end
          end
        end
      end
      if #chain == 0 then
        task.wait(0.15)
      else
        local joinStart = os.clock()
        while joining and active and (os.clock() - joinStart) < 1.5
              and (os.clock() - startTime) < DURATION do task.wait(0.08) end
        if not active or (os.clock() - startTime) >= DURATION then break end
        local target = chain[1]
        print('[Jen Auto-Join] attempting:', tostring(target.name), '| income:', tostring(target.rate))
        attempts = attempts + 1
        executeJoinWithFallback(chain, 1)
        local settle = os.clock()
        while joining and active and (os.clock() - settle) < 2.5
              and (os.clock() - startTime) < DURATION do task.wait(0.1) end
      end
    end
    print('[Jen Auto-Join] 10s window ended. Attempts: '..attempts)
  end)
end

local function renderOnce()
  local passEpoch = queryEpoch
  local batchStarted = os.clock()
  local function checkpoint()
    if os.clock() - batchStarted < 0.008 then return true end
    task.wait(); batchStarted = os.clock()
    if not active then return false end
    if queryEpoch ~= passEpoch then renderPending = true; return false end
    return true
  end
  local cycle = cycleInfo(); local resetAge = resetAgeText(cycle)
  local now = (os.clock() + clockOffset) * 1000
  local source, seen = {}, {}

  if not othersOnly and type(feed) == 'table' then
    for _, e in ipairs(feed) do
      if e.jobId ~= game.JobId and type(e.expiresAt) == 'number' and e.expiresAt > now
        and (e.rate or 0) >= minRate and (e.rank or 0) >= minRank then
        source[#source+1] = e; seen[e.key] = true
      end
    end
  end

  for _, e in ipairs(D.entries() or {}) do
    if (e.rate or 0) >= minRate and (e.tier or 0) >= minRank then
      local key = game.PlaceId..':'..game.JobId..':'..tostring(e.uid or e.key)
      if not seen[key] then
        seen[key] = true
        source[#source+1] = {
          key = key, uid = e.uid, name = e.name,
          rate = e.rate or 0, missingRate = e.rate == nil,
          scale = e.scale, weight = e.weight, icon = e.icon,
          rarity = e.rarity, tier = e.tier, rank = e.tier,
          mutations = e.mutationText or e.mutations, mutationText = e.mutationText or e.mutations,
          traitsKnown = e.traitsKnown ~= false,
          area = e.areaKey or e.area, isLocal = true, isEvent = e.isEvent,
          source = e.isEvent and 'event' or 'field', estimated = e.estimated,
          placeId = game.PlaceId, jobId = game.JobId,
          expiresAt = now + 5000, seenAt = now,
        }
      end
    end
  end

  do
    local filtered = {}
    for _, e in ipairs(source) do
      local here = e.isLocal or e.jobId == game.JobId
      if not (e.full or e.unavailable or e.takenConfirmed) then
        filtered[#filtered + 1] = e
      elseif here and othersOnly then
        filtered[#filtered + 1] = e
      end
    end
    source = filtered
  end

  table.sort(source, function(a, b)
    local ra, rb = a.rate or 0, b.rate or 0
    if ra ~= rb then return ra > rb end
    return tostring(a.key) < tostring(b.key)
  end)
  local limit = PREMIUM_EDITION and 10 or 30
  while #source > limit do source[#source] = nil end
  for i, e in ipairs(source) do e.displayRank = i end

  currentTopEntries = {}
  for i = 1, math.min(5, #source) do currentTopEntries[i] = source[i] end

  if #source > 0 and not list.Visible then list.Visible = true end

  local savedScroll = list.CanvasPosition
  local canvasHeight = #source == 0 and 40 or 0
  ageLabels = {}
  local wanted = {}
  for _, entry in ipairs(source) do wanted[entry.key] = true end
  for key, card in pairs(cardsByKey) do
    if not wanted[key] then
      card.row:Destroy(); cardsByKey[key] = nil
      if not checkpoint() then return end
    end
  end
  loadingVisible = #source == 0
  aliveMessage.Visible = #source == 0
  aliveMessage.Text = loadingVisible and loadingText(os.clock()) or 'No matching eggs'

  for i, entry in ipairs(source) do
    local signature = cardSignature(entry)
    local card = cardsByKey[entry.key]
    if not card or not card.row.Parent or card.signature ~= signature then
      if card and card.row.Parent then card.row:Destroy() end
      card = {entry=entry, signature=signature}
      local row = D.make('Frame', {Size=UDim2.new(1,-12,0,90), LayoutOrder=i,
        BackgroundColor3=Color3.fromRGB(105,106,110), BackgroundTransparency=0.24, BorderSizePixel=0}, list)
      card.row = row; row.ClipsDescendants = true
      D.make('UICorner', {CornerRadius=UDim.new(0,1)}, row)
      D.make('UIGradient', {Color=ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(145,148,155)), Rotation=90}, row)
      D.make('UIStroke', {Color=Color3.fromRGB(20,21,24), Thickness=2, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, row)
      D.make('Frame', {Name='CardBevelTop', Position=UDim2.fromOffset(2,1), Size=UDim2.new(1,-4,0,1),
        BackgroundColor3=Color3.fromRGB(190,192,198), BackgroundTransparency=0.3, BorderSizePixel=0, Active=false}, row)
      D.make('Frame', {Name='CardBevelBottom', Position=UDim2.new(0,2,1,-2), Size=UDim2.new(1,-4,0,1),
        BackgroundColor3=Color3.fromRGB(24,25,28), BorderSizePixel=0, Active=false}, row)
      local spotlight = D.make('Frame', {Name='PetSpotlight', Position=UDim2.fromOffset(2,0), Size=UDim2.new(0,82,1,-22),
        BackgroundTransparency=0.85, BackgroundColor3=Color3.fromRGB(180,180,200),
        BorderSizePixel=0, ClipsDescendants=false, Active=false, ZIndex=row.ZIndex+1}, row)
      D.make('UICorner', {CornerRadius=UDim.new(1,0)}, spotlight)
      card.spotlight = spotlight
      card.icon = D.make('ImageLabel', {Name='PetIcon', Image=entry.icon or '', ZIndex=spotlight.ZIndex+1,
        BackgroundTransparency=1, Size=UDim2.fromOffset(88,88), Position=UDim2.fromOffset(4,4), ScaleType=Enum.ScaleType.Fit}, row)
      pcall(function() card.icon.ResampleMode = Enum.ResamplerMode.Default end)
      local rarityKey = tostring(entry.rarity):lower():gsub('%s+','')
      local nameColor = rarityColors[rarityKey] or Color3.fromRGB(225,225,235)
      local rankText = '#'..tostring(entry.displayRank or entry.globalRank or i)
      local textService = game:GetService('TextService')
      local rankWidth = rankWidthCache[rankText]
      if not rankWidth then
        rankWidth = math.ceil(textService:GetTextSize(rankText, 20, Enum.Font.FredokaOne, Vector2.new(1000,28)).X)+4
        rankWidthCache[rankText] = rankWidth
      end
      local rankLabel = D.label(row, rankText, UDim2.fromOffset(86,3), UDim2.fromOffset(rankWidth,26), Color3.fromRGB(220,224,235), 20)
      rankLabel.Font = Enum.Font.FredokaOne; rankLabel.TextTruncate = Enum.TextTruncate.None
      rankLabel.TextStrokeColor3 = Color3.new(0,0,0); rankLabel.TextStrokeTransparency = 1
      D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=1.5}, rankLabel)
      card.rankLabel = rankLabel
      local nameLabel = D.label(row, tostring(entry.name), UDim2.fromOffset(86+rankWidth,3),
        UDim2.new(1,-94-rankWidth,0,26), nameColor, 21)
      nameLabel.Font = Enum.Font.GothamBlack; nameLabel.TextStrokeColor3 = Color3.new(0,0,0); nameLabel.TextStrokeTransparency = 1
      D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=1.1}, nameLabel)
      card.nameLabel = nameLabel
      local rarityCell = D.make('Frame', {Name='RarityCell', Position=UDim2.new(0,2,1,rarityKey=='secret' and -26 or -22),
        Size=UDim2.fromOffset(82,22), BackgroundTransparency=1, ClipsDescendants=true}, row)
      local rarityText = tostring(entry.rarity)
      local rarityTextSize = raritySizeCache[rarityText]
      if not rarityTextSize then
        rarityTextSize = 20
        while rarityTextSize > 1 do
          local bounds = textService:GetTextSize(rarityText, rarityTextSize, Enum.Font.GothamBlack, Vector2.new(1000,1000))
          if bounds.X <= 76 and bounds.Y <= 20 then break end
          rarityTextSize = rarityTextSize - 1
        end
        raritySizeCache[rarityText] = rarityTextSize
      end
      local rarityLabel = D.label(rarityCell, rarityText, UDim2.fromOffset(3,1), UDim2.new(1,-6,1,-2), nameColor, rarityTextSize)
      rarityLabel.Font = Enum.Font.GothamBlack; rarityLabel.TextStrokeColor3 = Color3.new(0,0,0); rarityLabel.TextStrokeTransparency = 0.2
      rarityLabel.TextXAlignment = Enum.TextXAlignment.Center; rarityLabel.TextYAlignment = Enum.TextYAlignment.Center
      rarityLabel.TextTruncate = Enum.TextTruncate.None; rarityLabel.TextScaled = false; rarityLabel.TextWrapped = false
      styleRarityLabel(nameLabel, rarityKey)
      local finance = D.make('Frame', {Name='IncomeAndWeight', Position=UDim2.fromOffset(86,31), Size=UDim2.new(1,-184,0,22), BackgroundTransparency=1}, row)
      local incomeCell = D.make('Frame', {Name='IncomeCell', Position=UDim2.new(), Size=UDim2.new(0.54,-4,1,0),
        BackgroundTransparency=1, ClipsDescendants=false}, finance)
      local incomeLabel = D.label(incomeCell, entry.missingRate and 'Income unavailable' or D.money(entry.rate),
        UDim2.fromOffset(3,2), UDim2.new(1,-6,1,-4), Color3.fromRGB(135,240,140), 20)
      incomeLabel.TextStrokeColor3 = Color3.new(0,0,0); incomeLabel.TextStrokeTransparency = 1; incomeLabel.Font = Enum.Font.GothamBlack
      D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=1.1}, incomeLabel)
      incomeLabel.TextTruncate = Enum.TextTruncate.None; incomeLabel.TextScaled = false; incomeLabel.TextWrapped = false
      D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=20}, incomeLabel)
      card.incomeLabel = incomeLabel
      local weightText, weightColor = weightPresentation(entry)
      local isScale = type(entry.weight) ~= 'number' and type(entry.scale) == 'number'
      local weightCell = D.make('Frame', {Name='WeightCell', Position=UDim2.new(0.54,4,0,0), Size=UDim2.new(0.46,-4,1,0),
        BackgroundTransparency=1, ClipsDescendants=false}, finance)
      local weightLabel = D.label(weightCell, weightText, UDim2.fromOffset(3,2), UDim2.new(1,-6,1,-4), weightColor, isScale and 19 or 16)
      D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=1.1}, weightLabel)
      weightLabel.TextStrokeColor3 = Color3.new(0,0,0); weightLabel.TextStrokeTransparency = 1; weightLabel.Font = Enum.Font.GothamBlack
      weightLabel.TextTruncate = Enum.TextTruncate.None; weightLabel.TextScaled = false; weightLabel.TextWrapped = false
      D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=isScale and 19 or 16}, weightLabel)
      card.weightLabel = weightLabel
      card.weightLimit = weightLabel:FindFirstChildOfClass('UITextSizeConstraint')
      local ageLabel = D.label(finance, resetAge, UDim2.new(1,-98,1,-23), UDim2.fromOffset(90,22), Color3.fromRGB(210,216,230), 17)
      ageLabel.Font = Enum.Font.FredokaOne; ageLabel.TextXAlignment = Enum.TextXAlignment.Center
      ageLabel.TextYAlignment = Enum.TextYAlignment.Center; ageLabel.TextStrokeColor3 = Color3.new(0,0,0); ageLabel.TextStrokeTransparency = 1
      D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=1.8}, ageLabel)
      ageLabel.Parent = row; ageLabel.Name = 'SpawnAge'; ageLabel.TextScaled = true; ageLabel.TextWrapped = false
      ageLabel.TextTruncate = Enum.TextTruncate.None
      D.make('UITextSizeConstraint', {MinTextSize=1, MaxTextSize=17}, ageLabel)
      card.ageLabel = ageLabel
      rarityLabel.TextColor3 = nameLabel.TextColor3
      local nameGradient = nameLabel:FindFirstChildOfClass('UIGradient')
      if nameGradient then
        local gradient = nameGradient:Clone(); gradient.Parent = rarityLabel
        rarityGradientBuckets[rarityKey] = rarityGradientBuckets[rarityKey] or {}
        rarityGradientBuckets[rarityKey][gradient] = true
      end
      local names = mutationNames(entry)
      local available = math.max(100, panel.Size.X.Offset - 130)
      local widths, total = {}, 0
      for mi, name in ipairs(names) do widths[mi] = mutationWidth(name, textService, available); total = total + widths[mi] + 5 end
      local strip = D.make('Frame', {Name='MutationStrip', Position=UDim2.new(0,86,1,-29), Size=UDim2.new(1,-94,0,28),
        BackgroundTransparency=1, ClipsDescendants=true}, row)
      local words = D.make('Frame', {Name='MutationWords', Position=UDim2.fromOffset(4,0),
        Size=UDim2.fromOffset(math.max(1,total),28), BackgroundTransparency=1}, strip)
      D.make('UIScale', {Scale=math.min(1, available/math.max(1,total))}, words)
      local x = 0
      for mi, name in ipairs(names) do mutationWord(words, name, UDim2.fromOffset(x,0), widths[mi]); x = x + widths[mi] + 5 end
      row.Size = UDim2.new(1,-12,0,compactCardHeight())
      local here = entry.isLocal or entry.jobId == game.JobId
      local join = D.make('TextButton', {Text=select(1, joinPresentation(entry)), Position=UDim2.new(1,-98,0,29),
        Size=UDim2.fromOffset(90,32),
        BackgroundColor3=(entry.full or entry.unavailable) and Color3.fromRGB(255,75,85)
          or here and Color3.fromRGB(86,90,100) or Color3.fromRGB(40,160,85),
        TextColor3=Color3.new(1,1,1), TextSize=13}, row)
      card.join = join
      local joinCorner = join:FindFirstChildOfClass('UICorner'); if joinCorner then joinCorner.CornerRadius = UDim.new(0,3) end
      join.Font = Enum.Font.FredokaOne
      styleRaisedButton(join)
      local caption = join:FindFirstChild('RaisedCaption')
      if caption then
        caption.Font = Enum.Font.FredokaOne; caption.TextScaled = true; caption.TextSize = 20
        caption.TextStrokeTransparency = 1; caption.Position = UDim2.fromOffset(5,2); caption.Size = UDim2.new(1,-10,1,-4)
        D.make('UITextSizeConstraint', {MinTextSize=10, MaxTextSize=20}, caption)
        D.make('UIStroke', {Color=Color3.new(0,0,0), Thickness=2}, caption)
      end
      join.Active = not (entry.full or entry.unavailable)
      join.AutoButtonColor = not (entry.full or entry.unavailable)
      join.Selectable = not (entry.full or entry.unavailable)
      join.Activated:Connect(function()
        if joining then return end
        local e = card.entry
        if not e or e.isLocal or e.jobId == game.JobId then return end
        if e.full or e.unavailable or e.takenConfirmed then return end
        if isBlocked(e.jobId) then return end
        local placeId = tonumber(e.placeId)
        local jobId = e.jobId
        if not placeId or type(jobId) ~= 'string' or jobId == '' then return end
        if (os.clock() + clockOffset) * 1000 >= (e.expiresAt or 0) then return end

        joining = true; joiningKey = e.key
        pcall(updateCard, card, e, card.row.LayoutOrder or 1)

        local ok, err = pcall(function()
          Teleports:TeleportToPlaceInstance(placeId, jobId, D.player)
        end)

        if ok then
          e.verifiedAt = os.clock()
          notifOnJoin(e)
          if config and config.endpoint then
            task.spawn(function()
              local claim = network(config.endpoint..'/v1/join', 'POST',
                Http:JSONEncode({placeId=placeId, jobId=jobId, uid=e.uid,
                  reporterId=reporterId, userId=D.player.UserId}), headers(), false, 2.5)
              if claim and claim.allowed ~= true then
                e.full = claim.full == true
                e.unavailable = claim.unavailable == true
                e.takenConfirmed = claim.takenConfirmed == true
                local c = cardsByKey[e.key]
                if c then pcall(updateCard, c, e, c.row.LayoutOrder or 1) end
              end
            end)
          end
          if config then task.spawn(function() pcall(report) end) end
          task.delay(1.5, function() if joining and joiningKey == e.key then joining = false; joiningKey = nil end end)
        else
          local msg = tostring(err)
          joining = false; joiningKey = nil
          lastJoinErrorMsg = 'Join failed: '..msg; lastJoinErrorAt = os.clock()
          if isBlockedErr(msg) then markBlocked(jobId, msg)
          elseif isFullErr(msg) then e.full = true end
          pcall(updateCard, card, e, card.row.LayoutOrder or 1)
        end
      end)
    end
    card.entry = entry
    updateCard(card, entry, i)
    card.row.LayoutOrder = i
    cardsByKey[entry.key] = card
    ageLabels[#ageLabels+1] = {label=card.ageLabel, entry=entry}
    canvasHeight = canvasHeight + card.row.Size.Y.Offset + 4
    if not checkpoint() then return end
  end
  list.CanvasSize = UDim2.fromOffset(0, canvasHeight)
  list.CanvasPosition = savedScroll
  list.Visible = true
end
render = function()
  if not active then return end
  if rendering then renderPending = true; return end
  rendering = true
  local ok, err = pcall(renderOnce)
  rendering = false
  if renderPending then renderPending = false; queueRender() end
  if not ok then list.Visible = true; warn('render:', err) end
end
requestScopeRender = function()
  list.Visible = false; list.CanvasPosition = Vector2.new(0, 0); queueRender()
end

refreshButton.Activated:Connect(function()
  if refreshing or not active then return end
  refreshing = true; refreshButton.Text = 'REFRESHING.'
  task.spawn(function()
    local ok, err = pcall(function()
      local deadline = os.clock() + 15
      while active and networkBusy and os.clock() < deadline do task.wait(0.1) end
      if not active then return end
      if networkBusy then error('Network busy') end
      if not config or os.clock() - configAt > 60 then
        local loaded, message = loadConfig()
        if not loaded then error(message) end
      end
      if not othersOnly then
        local loaded, message = refresh()
        if not loaded then error(message) end
      end
      render()
    end)
    refreshing = false
    if active then
      refreshButton.Text = 'REFRESH'
      queryStatus = ok and 'List refreshed' or ('Refresh failed: '..tostring(err))
    end
  end)
end)

Teleports.TeleportInitFailed:Connect(function(who, result, message)
  if who ~= D.player then return end
  joining = false
  local key = joiningKey; joiningKey = nil
  local msg = tostring(message or '')
  local isFull = (result == Enum.TeleportResult.GameFull or result == Enum.TeleportResult.GamePrivate)
  if isFull or isFullErr(msg) then
    for _, e in ipairs(currentTopEntries) do
      if e.key == key then e.full = true; break end
    end
    lastJoinErrorMsg = 'Target full — trying next'
    lastJoinErrorAt = os.clock(); queryStatus = lastJoinErrorMsg
    print('[Jen Auto-Join] full/private:', key, result, msg)
  elseif isBlockedErr(msg) then
    for _, e in ipairs(currentTopEntries) do
      if e.key == key then markBlocked(e.jobId, msg); break end
    end
    lastJoinErrorMsg = 'Server blocked — skipping'
    lastJoinErrorAt = os.clock(); queryStatus = lastJoinErrorMsg
    print('[Jen Auto-Join] blocked:', key, msg)
  else
    lastJoinErrorMsg = 'Teleport failed: '..msg
    lastJoinErrorAt = os.clock(); queryStatus = lastJoinErrorMsg
    print('[Jen Join] TeleportInitFailed:', msg)
  end
end)

D.gui.Destroying:Connect(function() active = false end)

task.spawn(function()
  local lastReport = -math.huge
  while active do
    local ok, err = pcall(function()
      if refreshing then return end
      if not config or os.clock() - configAt > 60 then
        local success, message = loadConfig()
        if not success then error(message) end
      end
      if os.clock() - lastReport >= 20 then
        lastReport = os.clock()
        local success, message = report()
        reportStatus = success and message or 'Share: '..tostring(message)
      end
      local refreshInterval = incomeAutoJoinEnabled and 2.5 or 8
      if not othersOnly and os.clock() - feedAt >= refreshInterval then
        local success, message = refresh()
        if not success then queryStatus = 'Finder: '..tostring(message)
        else fastScanSignal = true end
      end
    end)
    if not ok then queryStatus = tostring(err) end
    task.wait(0.5)
  end
end)

task.spawn(function()
  while active do
    if incomeAutoJoinEnabled and not othersOnly and not joining then
      local now = (os.clock() + clockOffset) * 1000
      local best
      for _, e in ipairs(feed) do
        if e.jobId ~= game.JobId
           and type(e.expiresAt) == 'number' and e.expiresAt > now
           and (e.rank or 0) >= minRank
           and passesIncomeGate(e)
           and not e.full and not e.unavailable and not e.takenConfirmed
           and not isBlocked(e.jobId)
           and not isRecentlyAttempted(e.jobId) then
          if not best or (e.rate or 0) > (best.rate or 0) then best = e end
        end
      end
      if best then
        markAttempted(best.jobId)
        executeJoinWithFallback({best}, 1)
      end
    end
    if fastScanSignal then
      fastScanSignal = false
      task.wait()
    else
      task.wait(0.1)
    end
  end
end)

do
  local Tweens = game:GetService('TweenService')
  local states = {}
  local function attachButtonMotion(button)
    if not (button:IsA('TextButton') or button:IsA('ImageButton')) then return end
    if button.Name == 'SettingsOverlay' or button.Name == 'LauncherHitArea' or button:GetAttribute('JenButtonMotion') then return end
    button:SetAttribute('JenButtonMotion', true)
    local motion = D.make('UIScale', {Name='ButtonMotion', Scale=1}, button)
    local state = {button=button, motion=motion, base=button.Position, hover=false, input=nil, tween=nil, writing=false, alive=true}
    states[button] = state
    local function enabled() return button.Active ~= false and button.Selectable ~= false end
    local function center()
      if not state.alive or not button.Parent then return end
      local delta = motion.Scale - 1
      local x, y = 0.5 - button.AnchorPoint.X, 0.5 - button.AnchorPoint.Y
      local size = button.Size
      local goal = UDim2.new(state.base.X.Scale - size.X.Scale*delta*x, state.base.X.Offset - size.X.Offset*delta*x,
        state.base.Y.Scale - size.Y.Scale*delta*y, state.base.Y.Offset - size.Y.Offset*delta*y)
      state.lastPosition = goal
      if button.Position == goal then return end
      state.writing = true; button.Position = goal; state.writing = false
    end
    local function update()
      if not state.alive then return end
      if state.tween then state.tween:Cancel(); state.tween = nil end
      local target = 1
      if enabled() then
        if state.input then target = 0.95
        elseif state.hover then
          local width = math.max(1, button.AbsoluteSize.X/math.max(0.01, motion.Scale))
          target = math.min(1.06, 1 + 5/width)
        end
      else state.input = nil; state.hover = false end
      state.tween = Tweens:Create(motion, TweenInfo.new(state.input and 0.08 or 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=target})
      state.tween:Play()
    end
    state.update = update
    motion:GetPropertyChangedSignal('Scale'):Connect(center)
    button:GetPropertyChangedSignal('Position'):Connect(function()
      if not state.writing and button.Position ~= state.lastPosition then state.base = button.Position; center() end
    end)
    button:GetPropertyChangedSignal('Size'):Connect(center)
    button:GetPropertyChangedSignal('AnchorPoint'):Connect(center)
    button:GetPropertyChangedSignal('Active'):Connect(update)
    button:GetPropertyChangedSignal('Selectable'):Connect(update)
    button.MouseEnter:Connect(function()
      if Input:GetLastInputType() == Enum.UserInputType.Touch then return end
      state.hover = true; update()
    end)
    button.MouseLeave:Connect(function() state.hover = false; update() end)
    button.SelectionGained:Connect(function() state.hover = true; update() end)
    button.SelectionLost:Connect(function() state.hover = false; update() end)
    button.InputBegan:Connect(function(input)
      if not enabled() then return end
      if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if input.UserInputType == Enum.UserInputType.Touch then state.hover = false end
        state.input = input; update()
      end
    end)
    button.Destroying:Connect(function() state.alive = false; if state.tween then state.tween:Cancel() end; states[button] = nil end)
  end
  local release = Input.InputEnded:Connect(function(input)
    for _, state in pairs(states) do
      if state.input and (state.input == input or (state.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
        state.input = nil; state.update()
      end
    end
  end)
  for _, button in ipairs(panel:GetDescendants()) do attachButtonMotion(button) end
  local added = panel.DescendantAdded:Connect(function(button)
    if button:IsA('TextButton') or button:IsA('ImageButton') then
      task.defer(function() if active and button.Parent then attachButtonMotion(button) end end)
    end
  end)
  local hidden = panel:GetPropertyChangedSignal('Visible'):Connect(function()
    if panel.Visible then return end
    for _, state in pairs(states) do state.input = nil; state.hover = false; state.update() end
  end)
  D.gui.Destroying:Connect(function()
    release:Disconnect(); added:Disconnect(); hidden:Disconnect()
    for _, state in pairs(states) do state.alive = false; if state.tween then state.tween:Cancel() end end
    table.clear(states)
  end)
end

do
  local Tweens = game:GetService('TweenService')
  local hovered, moving, scheduled = false, false, false
  local lastMovement = 0; local tween
  local function paint()
    if tween then tween:Cancel() end
    local highlighted = hovered or moving
    tween = Tweens:Create(list, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
      ScrollBarThickness=highlighted and 9 or 6,
      ScrollBarImageColor3=highlighted and Color3.fromRGB(200,205,220) or Color3.fromRGB(137,140,150),
      ScrollBarImageTransparency=highlighted and 0 or 0.18
    })
    tween:Play()
  end
  local function idle()
    if not active or not list.Parent then scheduled = false; return end
    if os.clock() - lastMovement < 0.22 then task.delay(0.12, idle); return end
    scheduled = false; moving = false; paint()
  end
  local enter = list.MouseEnter:Connect(function()
    if Input:GetLastInputType() == Enum.UserInputType.Touch then return end
    hovered = true; paint()
  end)
  local leave = list.MouseLeave:Connect(function() hovered = false; paint() end)
  local scrolled = list:GetPropertyChangedSignal('CanvasPosition'):Connect(function()
    lastMovement = os.clock()
    if not moving then moving = true; paint() end
    if not scheduled then scheduled = true; task.delay(0.24, idle) end
  end)
  local hidden = panel:GetPropertyChangedSignal('Visible'):Connect(function()
    if not panel.Visible then hovered = false; moving = false; paint() end
  end)
  D.gui.Destroying:Connect(function()
    enter:Disconnect(); leave:Disconnect(); scrolled:Disconnect(); hidden:Disconnect()
    if tween then tween:Cancel() end
  end)
  paint()
end

local function run()
  local EggState = module('Client.EggState')
  local Assets = module('Data.Assets')
  local StatesObj = module('Shared.Types.AreaEggs')
  if not EggState or not Assets or type(EggState.ReadFieldEggs) ~= 'function' or type(Assets.Directory) ~= 'table' then
    warn('Jen Finder scanner: game modules unavailable')
    return
  end
  local States = StatesObj and StatesObj.States
  if not States or States.Slot == nil then return end
  local mutations, eggRecords, halloweenPets, rarities
  pcall(function() mutations = module('Shared.Modules.Mutations') end)
  pcall(function() eggRecords = module('Shared.Util.EggRecords') end)
  pcall(function() halloweenPets = module('Data.HalloweenPets') end)
  pcall(function() rarities = module('Data.Rarity') end)

  local function numberField(record, keys)
    for _, key in ipairs(keys) do
      local value = record and record[key]
      if type(value) == 'number' and value == value and math.abs(value) < math.huge then return value end
    end
  end
  local function modelFor(uid)
    if type(uid) ~= 'string' then return end
    local folder = workspace:FindFirstChild('AreaEggSlotsClient')
    local obj = (folder and folder:FindFirstChild(uid)) or workspace:FindFirstChild(uid)
    if obj and obj:IsA('Model') then return obj end
  end
  local function displayedRate(model)
    if not model then return end
    for _, obj in ipairs(model:GetDescendants()) do
      if obj:IsA('TextLabel') or obj:IsA('TextButton') then
        local text = obj.Text:gsub('<[^>]+>', ''):gsub(',', '')
        local amount, suffix = text:match('%$?%s*(%d+%.?%d*)%s*(%a*)%s*/[sS]')
        local powers = {['']=1, k=1e3, m=1e6, b=1e9, t=1e12, qa=1e15, q=1e15, qi=1e18}
        local factor = suffix and powers[suffix:lower()]
        if amount and factor then return tonumber(amount) * factor end
      end
    end
  end
  local function valid(v) return type(v) == 'number' and v == v and v >= 0 and v < math.huge end
  local function computedRate(base, scale, muts, mutModule)
    if not valid(base) or not valid(scale) or scale == 0 then return nil end
    local multi = 1
    if type(muts) ~= 'table' then return nil end
    if next(muts) then
      local fn = mutModule and mutModule.EarningsFor
      if type(fn) ~= 'function' then return nil end
      local ok, result = pcall(fn, muts)
      if not ok or not valid(result) then return nil end
      multi = result
    end
    local factor = scale > 5 and (scale/5)^1.2 * 19.637875755794113 or scale^1.85
    local result = base * factor * multi
    return valid(result) and result or nil
  end
  local function readTraitNames(record)
    local names, seen = {}, {}
    local known = record.Mutations ~= nil or record.BaseMutation ~= nil
    local function add(value)
      if type(value) == 'string' and value ~= '' and value ~= 'None' and value ~= 'Normal' and not seen[value] then
        seen[value] = true; names[#names+1] = value
      end
    end
    if type(record.Mutations) == 'table' then
      for key, value in pairs(record.Mutations) do
        if value == true and type(key) == 'string' then add(key)
        elseif type(value) == 'string' then add(value)
        elseif type(value) == 'table' then
          local id = value.Id or value._id or value.Name
          if type(id) == 'string' then add(id) else known = false end
        end
      end
    elseif type(record.Mutations) == 'string' then
      for value in record.Mutations:gmatch('[^,;|]+') do add(value:match('^%s*(.-)%s*$')) end
    end
    add(record.BaseMutation); table.sort(names); return names, known
  end
  local function canonical(value) return tostring(value or ''):lower():gsub('^halloween%s*',''):gsub('%s*egg$',''):gsub('[^%w]','') end
  local function resolveSpec(specs, source, modelName)
    if source and specs[source] then return specs[source] end
    local wanted = canonical(source or modelName)
    if wanted == '' then return nil end
    local result
    for key, spec in pairs(specs) do
      if type(spec) == 'table' then
        for _, alias in pairs({key, spec.Id, spec.DisplayName, spec.Source, spec.EggSource, spec.EggModel}) do
          if canonical(alias) == wanted then
            if result and result ~= spec then return nil end
            result = spec
          end
        end
      end
    end
    return result
  end

  while active do
    local ok, err = pcall(function()
      if not halloweenPets then halloweenPets = module('Data.HalloweenPets') end
      if not rarities then rarities = module('Data.Rarity') end
      local snapshot = EggState.ReadFieldEggs()
      if type(snapshot) ~= 'table' or type(snapshot.Records) ~= 'table' then return end
      local eggs, seen = {}, {}
      for recordKey, record in pairs(snapshot.Records) do
        if record.State == States.Slot then
          local asset = Assets.Directory[record.AssetCategory] or {}
          local rarity = asset.Rarity or {}
          local uid = record.Uid or recordKey
          local model = modelFor(uid)
          local scale = numberField(record, {'AssetScale'})
          local weight
          if eggRecords and type(eggRecords.WeightKg) == 'function' then
            local good, result = pcall(eggRecords.WeightKg, record)
            if good and valid(result) then weight = result end
          end
          local rate = displayedRate(model)
          local estimated = false
          if not rate then rate = computedRate(asset.EarningRate, scale, record.Mutations or {}, mutations); estimated = rate ~= nil end
          seen[tostring(uid)] = true
          local traits, traitsKnown = readTraitNames(record)
          table.insert(eggs, {
            key = 'field:'..tostring(uid), uid = uid, traitsKnown = traitsKnown,
            category = record.AssetCategory, areaKey = record.AreaId,
            worldPos = typeof(record.BottomCFrame) == 'CFrame' and record.BottomCFrame.Position or nil,
            area = tostring(record.AreaId)..' | Mut: '..(#traits > 0 and table.concat(traits, ', ') or traitsKnown and 'None' or 'UNKNOWN'),
            model = model, icon = asset.Icon, name = asset.DisplayName or record.AssetCategory or 'Unknown',
            rarity = rarity.DisplayName or rarity._id or 'Unknown', tier = tonumber(rarity.Rank) or 0,
            color = typeof(rarity.Color) == 'Color3' and rarity.Color or Color3.new(1,1,1),
            scale = scale, weight = weight, rate = rate, estimated = estimated,
          })
        end
      end
      local dimension = workspace:FindFirstChild('HalloweenDimension')
      local folder = dimension and dimension:FindFirstChild('WorldEggs')
      if folder then
        for _, model in ipairs(folder:GetDescendants()) do
          if model:IsA('Model') and model:GetAttribute('HalloweenEggCanPickUp') == true then
            local uid = model:GetAttribute('HalloweenEggUid')
            local identity = uid and tostring(uid) or model:GetFullName()
            if not seen[identity] then
              seen[identity] = true
              local category = model:GetAttribute('PreparedSourceName')
              local spec = resolveSpec(halloweenPets and halloweenPets.Specs or {}, category, model.Name) or {}
              local rarity = type(spec.Rarity) == 'table' and spec.Rarity or nil
              if not rarity and rarities then rarity = (rarities.Rarities or rarities.Directory or {})[spec.Rarity] end
              rarity = rarity or {}
              if not rarity.Rank then
                for _, asset in pairs(Assets.Directory) do
                  local candidate = asset.Rarity
                  if type(candidate) == 'table' and (candidate._id == spec.Rarity or candidate.DisplayName == spec.Rarity) then
                    rarity = candidate; break
                  end
                end
              end
              local scale = numberField(model:GetAttributes(), {'AssetScale', 'Scale'})
              local weight = numberField(model:GetAttributes(), {'WeightKg'})
              local rate = displayedRate(model)
              local traits, traitsKnown = {}, false
              for _, key in ipairs({'Mutations', 'Mutation', 'BaseMutation'}) do
                local v = model:GetAttribute(key)
                if type(v) == 'string' and v ~= '' and v ~= 'None' then
                  for token in v:gmatch('[^,;|]+') do
                    local n = token:match('^%s*(.-)%s*$')
                    if n ~= '' and n ~= 'None' and n ~= 'Normal' then
                      traitsKnown = true
                      traits[#traits+1] = n
                    end
                  end
                end
              end
              if not rate and traitsKnown then rate = computedRate(spec.EarningRate, scale, traits, mutations) end
              local traitText = traitsKnown and (#traits > 0 and table.concat(traits, ', ') or 'None') or 'UNKNOWN'
              table.insert(eggs, {
                key = 'event:'..identity, uid = uid, category = spec.Id or category,
                areaKey = 'Halloween / '..tostring(model:GetAttribute('Zone') or ''),
                worldPos = model:GetPivot().Position, isEvent = true, model = model,
                icon = spec.Icon, name = spec.DisplayName or category or model.Name,
                area = 'HW '..tostring(model:GetAttribute('Zone') or '')..' | Mut: '..traitText,
                rarity = rarity.DisplayName or tostring(spec.Rarity or 'Unknown'),
                tier = tonumber(rarity.Rank) or 0,
                color = typeof(rarity.Color) == 'Color3' and rarity.Color or Color3.fromRGB(220,140,255),
                scale = scale, weight = weight, rate = rate, estimated = false, traitsKnown = traitsKnown,
              })
              eggs[#eggs].unresolved = spec.DisplayName == nil or spec.Rarity == nil
              if not traitsKnown then eggs[#eggs].unresolvedRate = computedRate(spec.EarningRate, scale, {}, mutations) end
            end
          end
        end
      end
      for _, entry in ipairs(eggs) do entry.rate = entry.rate or entry.unmutatedRate or entry.unresolvedRate end
      for _, entry in ipairs(eggs) do entry.mutationText = tostring(entry.area or ''):match('Mut:%s*(.*)') or '' end
      latestEntries = eggs
    end)
    if not ok then warn('Jen Finder scan:', err) end
    task.wait(2)
  end
end

task.spawn(function()
  local ok, err = pcall(run)
  if not ok then warn('Jen Finder startup:', err) end
end)

fitFinder()
panel.Visible = true
panelShownAt = os.clock()
task.spawn(prewarmOnOpen)
render()

task.spawn(function()
  local cycle0 = cycleInfo()
  local lastReset = cycle0 and cycle0.resetAt or nil
  local cycleMissingLogged = false
  while active do
    local cycle = cycleInfo()
    if cycle then
      if lastReset == nil then
        lastReset = cycle.resetAt
        print('[Jen Auto-Join] reset watcher armed | resetAt=', tostring(cycle.resetAt))
      elseif lastReset ~= cycle.resetAt then
        lastReset = cycle.resetAt
        feedAt = -math.huge
        print('[Jen Auto-Join] Reset detected! Waiting 5 seconds...')
        task.spawn(function()
          task.wait(5)
          if not active then return end
          if not autoJoinEnabled then
            queryStatus = 'Auto-join: toggle is OFF'
            print('[Jen Auto-Join] skipped — autoJoinEnabled=false')
            return
          end
          queryStatus = 'Auto-join: firing on reset'
          pcall(startSpamJoin)
        end)
      end
      local seconds = math.max(0, math.ceil(cycle.remaining))
      resetTimer.Text = cycle.running and string.format('RESET %02d:%02d', math.floor(seconds/60), seconds%60) or 'RESET PAUSED'
      resetTimer.TextColor3 = cycle.running and seconds <= 60 and Color3.fromRGB(255,85,85)
        or cycle.running and seconds <= 150 and Color3.fromRGB(255,215,65) or Color3.fromRGB(230,245,255)
    else
      resetTimer.Text = 'RESET --:--'; resetTimer.TextColor3 = Color3.fromRGB(230,245,255)
      if not cycleMissingLogged then
        cycleMissingLogged = true
        print('[Jen Auto-Join] cycleInfo() is nil — AreaEggCycle module not resolvable. Reset watcher cannot fire.')
        queryStatus = 'Auto-join: cycle module unavailable'
      end
    end
    if joining then
      status.Text = 'Joining server…'
    elseif lastJoinErrorMsg and os.clock() - lastJoinErrorAt < 5 then
      status.Text = lastJoinErrorMsg
    else
      status.Text = tostring(queryStatus ~= '' and queryStatus or reportStatus)
    end
    updateSpawnAges(cycle)
    local ok = pcall(render)
    if not ok then queryStatus = 'Unable to display finder feed' end
    task.wait((#feed < 3 or #currentTopEntries < 3) and 0.25 or 1)
  end
end)
