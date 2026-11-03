-- Dᴇᴏʙғᴜsᴄᴀᴛᴇᴅ ʙʏ GPT-6 Lᴜɴᴀ Mᴀx
print('[Jen Finder] Loading...')
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local player = Players.LocalPlayer
assert(player, 'Join the game first')
local parent = player:WaitForChild('PlayerGui', 15)
assert(parent, 'PlayerGui unavailable')
local old = parent:FindFirstChild('JEN_FINDER_PANEL')
if old then old:Destroy() end
local gui = Instance.new('ScreenGui')
gui.Name = 'JEN_FINDER_PANEL'
gui.ResetOnSpawn = false
gui.DisplayOrder = 1200
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
gui.Parent = parent
local alive = true
local highlight
gui.Destroying:Connect(function() alive = false; if highlight then highlight:Destroy() end end)
local function make(class, props, holder)
    local obj = Instance.new(class)
    for key, value in pairs(props) do pcall(function() obj[key] = value end) end
    obj.Parent = holder
    return obj
end
local function label(holder, text, pos, size, color, fontSize) return make('TextLabel', {Text=text,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=color or Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=fontSize or 13,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},holder) end
local function module(path) local obj = RS for part in path:gmatch('[^.]+') do obj = obj:FindFirstChild(part) assert(obj, 'Missing game module: '..path) end return require(obj) end
local function numberField(record, keys) for _, key in ipairs(keys) do local value = record and record[key] if type(value)=='number' and value==value and math.abs(value)<math.huge then return value end end end
local function modelFor(uid) if type(uid)~='string' then return end local folder = workspace:FindFirstChild('AreaEggSlotsClient') local obj = (folder and folder:FindFirstChild(uid)) or workspace:FindFirstChild(uid) if obj and obj:IsA('Model') then return obj end end
local function displayedRate(model) if not model then return end for _,obj in ipairs(model:GetDescendants()) do if obj:IsA('TextLabel') or obj:IsA('TextButton') then local text=obj.Text:gsub('<[^>]+>',''):gsub(',','') local amount,suffix=text:match('%$?%s*(%d+%.?%d*)%s*(%a*)%s*/[sS]') local powers={['']=1,k=1e3,m=1e6,b=1e9,t=1e12,qa=1e15,q=1e15,qi=1e18} local factor=suffix and powers[suffix:lower()] if amount and factor then return tonumber(amount)*factor end end end end
local function money(value) if not value then return 'Income unavailable' end for _,entry in ipairs({{1e18,'Qi'},{1e15,'Qa'},{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}}) do if value>=entry[1] then return string.format('$%.2f%s/s',value/entry[1],entry[2]) end end return string.format('$%.2f/s',value) end
local function valid(value) return type(value)=='number' and value==value and value>=0 and value<math.huge end
local function computedRate(base, scale, muts, mutationModule) if not valid(base) or not valid(scale) or scale==0 then return nil end local multi=1 if type(muts)~='table' then return nil end if next(muts) then local fn=mutationModule and mutationModule.EarningsFor if type(fn)~='function' then return nil end local ok,result=pcall(fn,muts) if not ok or not valid(result) then return nil end multi=result end local factor=scale>5 and (scale/5)^1.2*19.637875755794113 or scale^1.85 local result=base*factor*multi return valid(result) and result or nil end
local function canonical(value) return tostring(value or ''):lower():gsub('^halloween%s*',''):gsub('%s*egg$',''):gsub('[^%w]','') end
local function resolveSpec(specs, source, modelName) if source and specs[source] then return specs[source] end local result local wanted=canonical(source or modelName) if wanted=='' then return nil end for key,spec in pairs(specs) do if type(spec)=='table' then for _,alias in pairs({key,spec.Id,spec.DisplayName,spec.Source,spec.EggSource,spec.EggModel}) do if canonical(alias)==wanted then if result and result~=spec then return nil end result=spec end end end end return result end
local function eventTraits(model,record) local names,seen,sources={},{},{} local known=false local function insert(v) if type(v)=='string' and v~='' and v~='None' and v~='Normal' and not seen[v] then seen[v]=true; names[#names+1]=v end end local function parse(value) if type(value)=='table' then for key,v in pairs(value) do if v==true and type(key)=='string' then insert(key) elseif type(v)=='string' then insert(v) end end elseif type(value)=='string' then local ok,parsed=pcall(function() return game:GetService('HttpService'):JSONDecode(value) end) if ok and type(parsed)=='table' then parse(parsed) else for v in value:gmatch('[^,;|]+') do insert(v:match('^%s*(.-)%s*$')) end end end end local keys={'Mutations','Mutation','BaseMutation','MutationIds','MutationId'} local function inspect(attrs,source,authoritative) for _,key in ipairs(keys) do local value=attrs[key] if type(value)=='string' or type(value)=='table' then parse(value) if authoritative or #names>0 then known=true end sources[source]=true end end end if type(record)=='table' then inspect(record,'UID record',true) end inspect(model:GetAttributes(),'model attrs',true) for _,child in ipairs(model:GetDescendants()) do inspect(child:GetAttributes(),'child attrs',false) if child:IsA('StringValue') then for _,key in ipairs(keys) do if child.Name==key then parse(child.Value); sources['StringValue']=true; if #names>0 then known=true end end end end end table.sort(names) local origin={}; for source in pairs(sources) do origin[#origin+1]=source end; table.sort(origin) return names,known,table.concat(origin,' + ') end
local function meshSignature(model) local ids={} for _,obj in ipairs(model:GetDescendants()) do if obj:IsA('MeshPart') or obj:IsA('SpecialMesh') then local id=tostring(obj.MeshId):match('%d+') if id then ids[#ids+1]=id end end end table.sort(ids) return #ids>0 and table.concat(ids,':') or nil end
local function uniqueMatch(candidates) local found for _,candidate in ipairs(candidates) do if found and found~=candidate then return nil end found=candidate end return found end
local function readTraitNames(record) local names,seen={},{} local known=record.Mutations~=nil or record.BaseMutation~=nil local function add(value) if type(value)=='string' and value~='' and value~='None' and value~='Normal' and not seen[value] then seen[value]=true;names[#names+1]=value end end if type(record.Mutations)=='table' then for key,value in pairs(record.Mutations) do if value==true and type(key)=='string' then add(key) elseif type(value)=='string' then add(value) elseif type(value)=='table' then local id=value.Id or value._id or value.Name; if type(id)=='string' then add(id) else known=false end end end elseif type(record.Mutations)=='string' then for value in record.Mutations:gmatch('[^,;|]+') do add(value:match('^%s*(.-)%s*$')) end end add(record.BaseMutation);table.sort(names) return names,known end

local DISCORD_LINK = 'https://discord.gg/8zxVj7Ygeg'

local function createFinder(D)
    local originalMake,originalLabel=D.make,D.label
    D.make=function(class,props,parent) if class=='TextButton' or class=='TextBox' then props.Font=Enum.Font.GothamBold;props.TextSize=math.max(props.TextSize or 14,14) end if class=='TextBox' then props.TextColor3=Color3.fromRGB(25,25,30) end local obj=originalMake(class,props,parent) if class=='TextButton' or class=='TextBox' then originalMake('UICorner',{CornerRadius=UDim.new(0,5)},obj) end return obj end
    D.label=function(parent,text,pos,size,color,fontSize) local obj=originalLabel(parent,text,pos,size,color or Color3.fromRGB(245,225,250),math.max(fontSize or 14,13)) obj.Font=Enum.Font.GothamBold;obj.TextStrokeColor3=Color3.new(0,0,0);obj.TextStrokeTransparency=0.45;return obj end
    local Http=game:GetService('HttpService')
    local Teleports=game:GetService('TeleportService')
    local requestFn=request or http_request or (syn and syn.request) or (http and http.request)
    local active,othersOnly=true,false
    local reporterId=Http:GenerateGUID(false)
    local config,configAt=nil,-math.huge
    local feed,feedAt={},0
    local clockOffset=0
    local networkBusy=false
    local reportStatus='Connecting'
    local queryStatus=''
    local minRate,minRank=0,0
    local joining=false
    local localHighlight
    local nextOffset=nil
    local queryEpoch=0
    local settingsPath='jen_finder_ui_v3.json'
    local settings={}
    if type(readfile)=='function' then pcall(function() local data=Http:JSONDecode(readfile(settingsPath));if type(data)=='table' then settings=data end end) end
    if type(settings.myServer)=='boolean' then othersOnly=settings.myServer end
    if type(settings.minRank)=='number' then minRank=math.clamp(math.floor(settings.minRank),0,10) end

    local THEME = {
        bg            = Color3.fromRGB(28, 16, 42),
        panelStroke   = Color3.fromRGB(200, 100, 220),
        headerFrom    = Color3.fromRGB(120, 50, 180),
        headerTo      = Color3.fromRGB(235, 90, 190),
        btnPurple     = Color3.fromRGB(100, 55, 150),
        btnPurpleDark = Color3.fromRGB(70, 35, 110),
        btnPink       = Color3.fromRGB(190, 75, 175),
        btnPinkDark   = Color3.fromRGB(150, 50, 130),
        accentPink    = Color3.fromRGB(255, 160, 220),
        textPrimary   = Color3.fromRGB(240, 220, 250),
        rowBg         = Color3.fromRGB(38, 24, 54),
        rowStroke     = Color3.fromRGB(90, 60, 110),
        closeBtn      = Color3.fromRGB(200, 55, 110),
        hideBtn       = Color3.fromRGB(140, 70, 175),
        moneyGreen    = Color3.fromRGB(200, 240, 180),
        discordBlue   = Color3.fromRGB(88, 101, 242),
    }

    -- ============ BOTTOM NOTICE — CLICKABLE, COPIES DISCORD LINK ============
    local sharingNotice=D.make('TextButton',{
        Text='JEN FINDER ON • Sharing egg sightings • discord.gg/8zxVj7Ygeg',
        Position=UDim2.new(0,12,1,-28),
        Size=UDim2.new(1,-24,0,22),
        BackgroundTransparency=1,
        TextColor3=THEME.accentPink,
        Font=Enum.Font.GothamBold,
        TextSize=12,
        TextWrapped=true,
        TextStrokeColor3=Color3.new(0,0,0),
        TextStrokeTransparency=0.15,
        TextXAlignment=Enum.TextXAlignment.Left,
        AutoButtonColor=false,
    },D.gui)
    sharingNotice.Activated:Connect(function()
        if type(setclipboard)=='function' then
            local ok=pcall(setclipboard,DISCORD_LINK)
            if ok then
                sharingNotice.Text='COPIED DISCORD LINK!'
                task.delay(1.5,function()
                    if sharingNotice and sharingNotice.Parent then
                        sharingNotice.Text='JEN FINDER ON • Sharing egg sightings • discord.gg/8zxVj7Ygeg'
                    end
                end)
                return
            end
        end
        -- Fallback: show URL so user can copy manually
        sharingNotice.Text=DISCORD_LINK
        task.delay(3,function()
            if sharingNotice and sharingNotice.Parent then
                sharingNotice.Text='JEN FINDER ON • Sharing egg sightings • discord.gg/8zxVj7Ygeg'
            end
        end)
    end)

    local panel=D.make('Frame',{
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.new(0.5,0,0.5,0),
        Size=UDim2.fromOffset(290,440),
        BackgroundColor3=THEME.bg,
        BackgroundTransparency=0,
        Visible=true,
        ClipsDescendants=true
    },D.gui)
    D.make('UISizeConstraint',{MinSize=Vector2.new(260,380),MaxSize=Vector2.new(360,520)},panel)
    D.make('UICorner',{CornerRadius=UDim.new(0,8)},panel)
    D.make('UIStroke',{Color=THEME.panelStroke,Thickness=2},panel)

    local function restorePosition(target,value)
        if type(value)~='table' then return end
        for i=1,4 do
            if type(value[i])~='number' or value[i]~=value[i] or math.abs(value[i])>5000 then return end
        end
        local pos=UDim2.new(value[1],value[2],value[3],value[4])
        local cam=workspace.CurrentCamera
        if cam then
            local vp=cam.ViewportSize
            local px=pos.X.Scale*vp.X+pos.X.Offset
            local py=pos.Y.Scale*vp.Y+pos.Y.Offset
            if px<-100 or px>vp.X+100 or py<-100 or py>vp.Y+100 then return end
        end
        target.Position=pos
    end
    restorePosition(panel,settings.panel)
    local function saveSettings() if type(writefile)~='function' then return end pcall(function() local function coords(p) return {p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset} end writefile(settingsPath,Http:JSONEncode({myServer=othersOnly,minRank=minRank,panel=coords(panel.Position)})) end) end

    local Input=game:GetService('UserInputService')
    local drag
    local function draggable(target,handle)
        handle.Active=true
        handle.InputBegan:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
            drag={target=target,input=input,startPos=target.Position,startMouse=input.Position,moved=false}
        end)
    end

    local bar=D.make('Frame',{Size=UDim2.new(1,0,0,44),BackgroundColor3=THEME.headerFrom,BorderSizePixel=0},panel)
    D.make('UIGradient',{Color=ColorSequence.new(THEME.headerFrom,THEME.headerTo),Rotation=0},bar)
    D.label(panel,'Jen Finder',UDim2.fromOffset(14,7),UDim2.new(1,-80,0,30),nil,20)
    draggable(panel,bar)

    local hideBtn=D.make('TextButton',{
        Text='—',
        Position=UDim2.new(1,-64,0,8),
        Size=UDim2.fromOffset(24,24),
        BackgroundColor3=THEME.hideBtn,
        TextColor3=Color3.new(1,1,1),
        TextSize=18
    },panel)
    D.make('UICorner',{CornerRadius=UDim.new(0,5)},hideBtn)
    D.make('UIStroke',{Color=THEME.accentPink,Thickness=1},hideBtn)

    local closeBtn=D.make('TextButton',{
        Text='×',
        Position=UDim2.new(1,-34,0,8),
        Size=UDim2.fromOffset(24,24),
        BackgroundColor3=THEME.closeBtn,
        TextColor3=Color3.new(1,1,1),
        TextSize=18
    },panel)
    D.make('UICorner',{CornerRadius=UDim.new(0,5)},closeBtn)
    D.make('UIStroke',{Color=THEME.accentPink,Thickness=1},closeBtn)

    local launcher=D.make('TextButton',{
        AnchorPoint=Vector2.new(1,0),
        Position=UDim2.new(1,-20,0,60),
        Size=UDim2.fromOffset(110,32),
        BackgroundColor3=THEME.btnPurple,
        TextColor3=Color3.new(1,1,1),
        Text='Jen Finder',
        TextSize=13,
        Visible=false
    },D.gui)
    D.make('UICorner',{CornerRadius=UDim.new(0,8)},launcher)
    D.make('UIStroke',{Color=THEME.accentPink,Thickness=2},launcher)
    D.make('UIGradient',{Color=ColorSequence.new(THEME.btnPurple,THEME.btnPink),Rotation=0},launcher)

    hideBtn.Activated:Connect(function() panel.Visible=false; launcher.Visible=true end)
    launcher.Activated:Connect(function() panel.Visible=true; launcher.Visible=false end)
    closeBtn.Activated:Connect(function() gui:Destroy() end)

    local moveConnection=Input.InputChanged:Connect(function(input)
        if not drag then return end
        local isMouse=drag.input.UserInputType==Enum.UserInputType.MouseButton1
        if isMouse then
            if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
        else
            if input~=drag.input then return end
        end
        local dx=input.Position.X-drag.startMouse.X
        local dy=input.Position.Y-drag.startMouse.Y
        if dx*dx+dy*dy>16 then drag.moved=true end
        if not drag.moved then return end
        local newXOff=drag.startPos.X.Offset+dx
        local newYOff=drag.startPos.Y.Offset+dy
        local cam=workspace.CurrentCamera
        if cam then
            local view=cam.ViewportSize
            local size=drag.target.AbsoluteSize
            local anchor=drag.target.AnchorPoint
            local absX=drag.startPos.X.Scale*view.X+newXOff-anchor.X*size.X
            local absY=drag.startPos.Y.Scale*view.Y+newYOff-anchor.Y*size.Y
            local maxX=math.max(0,view.X-size.X)
            local maxY=math.max(0,view.Y-size.Y)
            local clampedX=math.clamp(absX,0,maxX)
            local clampedY=math.clamp(absY,0,maxY)
            newXOff=newXOff+(clampedX-absX)
            newYOff=newYOff+(clampedY-absY)
        end
        drag.target.Position=UDim2.new(drag.startPos.X.Scale,newXOff,drag.startPos.Y.Scale,newYOff)
    end)
    local endConnection=Input.InputEnded:Connect(function(input)
        if drag and (input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then
            if drag.moved then saveSettings() end
            drag=nil
        end
    end)
    D.gui.Destroying:Connect(function() moveConnection:Disconnect();endConnection:Disconnect();drag=nil end)

    task.spawn(function()
        local url='https://raw.githubusercontent.com/mallu837/JenicakesObsiUI/main/assets/background.png.txt'
        local text
        if type(requestFn)=='function' then
            local ok,res=pcall(requestFn,{Url=url,Method='GET',Timeout=5})
            if ok and type(res)=='table' and type(res.Body)=='string' then text=res.Body end
        end
        if not text and type(game.HttpGet)=='function' then
            local ok,res=pcall(function() return game:HttpGet(url) end)
            if ok and type(res)=='string' then text=res end
        end
        if type(text)~='string' or text=='' then warn('[Jen Finder] Background fetch failed; using solid color'); return end
        local b64=text:match('base64,(.+)') or text
        b64=b64:gsub('%s+','')
        if b64:sub(1,1)=='"' then b64=b64:sub(2,-2) end
        if type(base64decode)~='function' or type(writefile)~='function' or type(getcustomasset)~='function' then warn('[Jen Finder] base64decode/writefile/getcustomasset unavailable; using solid color'); return end
        local ok,err=pcall(function()
            writefile('jenicakes_bg.png',base64decode(b64))
            local asset=getcustomasset('jenicakes_bg.png')
            if type(asset)=='string' and asset~='' then
                local bgImg=D.make('ImageLabel',{Image=asset,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ImageTransparency=0.15,ScaleType=Enum.ScaleType.Crop},panel)
                panel.BackgroundTransparency=1
                D.make('UICorner',{CornerRadius=UDim.new(0,8)},bgImg)
                local overlay=D.make('Frame',{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(45, 20, 60),BackgroundTransparency=0.45,BorderSizePixel=0},panel)
                D.make('UICorner',{CornerRadius=UDim.new(0,8)},overlay)
                bgImg.ZIndex=-2; overlay.ZIndex=-1
                for _,c in ipairs(panel:GetChildren()) do if c~=bgImg and c~=overlay and c~=bar then c.ZIndex=2 end end
                bar.ZIndex=3
                print('[Jen Finder] Background loaded')
            end
        end)
        if not ok then warn('[Jen Finder] Background apply failed:',err) end
    end)

    local status=D.label(panel,'Connecting…',UDim2.fromOffset(14,48),UDim2.new(1,-28,0,22),THEME.textPrimary,13)
    status.TextWrapped=true
    status.ZIndex=2

    local scope=D.make('TextButton',{Text='ALL SERVERS',Position=UDim2.fromOffset(10,76),Size=UDim2.new(0.5,-15,0,32),BackgroundColor3=THEME.btnPurple,TextColor3=Color3.new(1,1,1),TextSize=11,ZIndex=2},panel)
    D.make('UIStroke',{Color=THEME.accentPink,Thickness=1},scope)
    scope.Activated:Connect(function() othersOnly=not othersOnly; scope.Text=othersOnly and 'MY SERVER' or 'ALL SERVERS'; queryEpoch+=1; feedAt=-math.huge; saveSettings() end)
    scope.Text=othersOnly and 'MY SERVER' or 'ALL SERVERS'

    local rarityNames={'Any','Common','Uncommon','Rare','Epic','Legendary','Mythic','Cosmic','Secret','Eternal','Divine'}
    local rarityIndex=minRank+1
    local rarity=D.make('TextButton',{Text='MIN RARITY: Any',Position=UDim2.new(0.5,5,0,76),Size=UDim2.new(0.5,-15,0,32),BackgroundColor3=THEME.btnPurpleDark,TextColor3=Color3.new(1,1,1),TextSize=11,ZIndex=2},panel)
    D.make('UIStroke',{Color=THEME.accentPink,Thickness=1},rarity)
    rarity.Activated:Connect(function() rarityIndex=rarityIndex%#rarityNames+1; minRank=rarityIndex-1; rarity.Text='MIN RARITY: '..rarityNames[rarityIndex];queryEpoch+=1;feed={};feedAt=-math.huge;saveSettings() end)
    rarity.Text='MIN RARITY: '..rarityNames[rarityIndex]

    local refreshButton=D.make('TextButton',{Text='REFRESH',Position=UDim2.fromOffset(10,112),Size=UDim2.new(1,-20,0,28),BackgroundColor3=THEME.btnPink,TextColor3=Color3.new(1,1,1),TextSize=13,ZIndex=2},panel)
    D.make('UIStroke',{Color=THEME.accentPink,Thickness=1},refreshButton)
    D.make('UIGradient',{Color=ColorSequence.new(THEME.btnPurple,THEME.btnPink),Rotation=0},refreshButton)

    local refreshing=false
    -- List height restored (footer button removed)
    local list=D.make('ScrollingFrame',{Position=UDim2.fromOffset(8,146),Size=UDim2.new(1,-16,1,-154),BackgroundTransparency=1,AutomaticCanvasSize=Enum.AutomaticSize.None,CanvasSize=UDim2.new(),ScrollBarThickness=4,ZIndex=2},panel)
    D.make('UIListLayout',{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},list)
    local aliveMessage=D.label(list,'Waiting for participant reports',UDim2.new(),UDim2.new(1,-10,0,40),THEME.accentPink,12)

    local function network(url,method,body,headers,raw) if type(requestFn)~='function' then return nil,'Executor HTTP POST unavailable' end if networkBusy then return nil,'Network request still pending' end networkBusy=true local done,result=false,nil task.spawn(function() result=table.pack(pcall(requestFn,{Url=url,Method=method,Headers=headers or {},Body=body,Timeout=10})) done=true; networkBusy=false end) local deadline=os.clock()+12 while active and not done and os.clock()<deadline do task.wait(0.1) end if not done then return nil,'Network timeout' end if not result[1] then return nil,'Network request failed' end local response=result[2] if type(response)~='table' then return nil,'Invalid HTTP response' end local code=tonumber(response.StatusCode or response.Status) if code~=200 then return nil,'HTTP '..tostring(code) end if raw then return response.Body end local ok,decoded=pcall(Http.JSONDecode,Http,response.Body or '') if not ok then return nil,'Invalid JSON response' end return decoded end

    local function loadConfig()
        local data,err=network('https://raw.githubusercontent.com/syss1211/Tenshi-script/main/NYX-Finder-Config.json?nyx='..os.time(),'GET')
        if not data then return false,err end
        if type(data.endpoint)~='string' or not data.endpoint:match('^https://[%w%.%-]+$') or type(data.roomKey)~='string' then return false,'Finder configuration unavailable' end
        config=data; configAt=os.clock()
        return true
    end
    local function headers() return {['Content-Type']='application/json',['X-NYX-Room']=config.roomKey} end
    local function snapshot()
        local eggs={}
        for _,entry in ipairs(D.entries()) do
            if not entry.unresolved and entry.uid and entry.rate and entry.rate>0 then
                eggs[#eggs+1]={uid=tostring(entry.uid),name=entry.name,category=entry.category,rarity=entry.rarity,rank=entry.tier,rate=entry.rate,scale=entry.scale,weight=entry.weight,icon=entry.icon,area=entry.areaKey or entry.area,mutations=entry.mutationText or (entry.traitsKnown==false and 'UNKNOWN' or ''),traitsKnown=entry.traitsKnown~=false,estimated=entry.estimated==true or entry.unmutatedRate~=nil or entry.scaleFromModel==true,visualId=entry.visualId==true,source=entry.isEvent and 'event' or 'field'}
            end
        end
        table.sort(eggs,function(a,b) return a.rate>b.rate end)
        while #eggs>40 do eggs[#eggs]=nil end
        return eggs
    end
    local function report()
        if game.JobId=='' then return false,'No live server ID' end
        local data,err=network(config.endpoint..'/v1/report','POST',Http:JSONEncode({placeId=game.PlaceId,jobId=game.JobId,reporterId=reporterId,eggs=snapshot()}),headers())
        return data and data.ok==true,err or (data and 'Shared '..tostring(data.accepted)..' eggs')
    end
    local function refresh()
        local epoch=queryEpoch
        local query='?placeId='..game.PlaceId..'&limit=50&tier=public&offset=0&minRate='..tostring(minRate)..'&minRank='..tostring(minRank)
        if othersOnly then query=query..'&onlyJob='..Http:UrlEncode(game.JobId) end
        local data,err=network(config.endpoint..'/v1/eggs'..query,'GET',nil,headers())
        if epoch~=queryEpoch then return true end
        if not data or type(data.items)~='table' then return false,err or 'Invalid finder feed' end
        nextOffset=tonumber(data.nextOffset)
        clockOffset=(tonumber(data.serverTime) or os.time()*1000)/1000-os.clock()
        feed=data.items
        feedAt=os.clock()
        queryStatus=string.format('Updated | %d servers | %d reporters',data.servers or 0,data.participants or 0)
        return true
    end

    local lastRender
    local rarityColors={ divine=Color3.fromRGB(255,205,55),eternal=Color3.fromRGB(255,160,225), secret=Color3.fromRGB(255,255,255),cosmic=Color3.fromRGB(190,85,255), mythic=Color3.fromRGB(255,75,85),legendary=Color3.fromRGB(255,155,45), epic=Color3.fromRGB(255,110,200),rare=Color3.fromRGB(65,165,255), uncommon=Color3.fromRGB(105,220,120),common=Color3.fromRGB(220,225,235) }

    local function mutationCaption(entry)
        if entry.isEvent or entry.source=='event' then return nil end
        local raw=tostring(entry.mutations or entry.mutationText or ''):gsub('%s*%[[^%]]*%]',''):match('^%s*(.-)%s*$')
        local lower=raw:lower()
        if entry.traitsKnown==false or lower:find('unknown',1,true) or lower:find('unverified',1,true) then return 'Mutation: unknown' end
        if raw=='' or lower=='none' or lower=='normal' or lower=='none (explicit data)' then return nil end
        return 'Mutation: '..raw
    end

    local function mutationStyle(label,name)
        local key=name:lower()
        local colors
        if key=='silver' then colors={{100,110,125},{240,245,255},{155,165,180},{255,255,255},{120,130,145}}
        elseif key=='golden' or key=='gold' then colors={{185,110,10},{255,215,55},{255,250,185},{255,190,25},{205,130,10}}
        elseif key=='rainbow' then colors={{255,70,85},{255,175,35},{255,240,80},{80,235,135},{55,200,255},{150,100,255},{255,100,220}} end
        if not colors then return end
        local points={}
        for i,c in ipairs(colors) do points[i]=ColorSequenceKeypoint.new((i-1)/(#colors-1),Color3.fromRGB(c[1],c[2],c[3])) end
        label.TextColor3=Color3.new(1,1,1)
        label.TextStrokeTransparency=0.1
        D.make('UIGradient',{Color=ColorSequence.new(points),Rotation=key=='rainbow' and 0 or 20},label)
    end

    local function render()
        local now=(os.clock()+clockOffset)*1000
        local entries,parts={},{}
        local source,seen={},{}
        if not othersOnly then
            for _,e in ipairs(feed) do
                if e.jobId~=game.JobId and type(e.expiresAt)=='number' and e.expiresAt>now then source[#source+1]=e;seen[e.key]=true end
            end
        end
        for _,e in ipairs(D.entries()) do
            if (e.rate or 0)>=minRate and (e.tier or 0)>=minRank then
                local key=game.PlaceId..':'..game.JobId..':'..tostring(e.uid or e.key)
                if not seen[key] then
                    seen[key]=true
                    source[#source+1]={key=key,name=e.name,rate=e.rate or 0,missingRate=e.rate==nil,scale=e.scale,weight=e.weight,icon=e.icon,rarity=e.rarity,mutations=e.mutationText,traitsKnown=e.traitsKnown~=false,area=e.areaKey or e.area,model=e.model,isLocal=true,source=e.isEvent and 'event' or 'field',estimated=e.estimated or e.unmutatedRate~=nil,placeId=game.PlaceId,jobId=game.JobId,expiresAt=now+5000,seenAt=0}
                end
            end
        end
        table.sort(source,function(a,b) if a.rate~=b.rate then return a.rate>b.rate end; return a.key<b.key end)
        if not othersOnly then
            local limit=50
            while #source>limit do source[#source]=nil end
        end
        for i,e in ipairs(source) do e.displayRank=i end
        for _,entry in ipairs(source) do
            if type(entry)=='table' and type(entry.expiresAt)=='number' and now<entry.expiresAt and type(entry.rate)=='number' and type(entry.jobId)=='string' then
                entries[#entries+1]=entry
                parts[#parts+1]=table.concat({entry.key,tostring(entry.seenAt),tostring(entry.rate),tostring(entry.scale),tostring(entry.name),tostring(entry.area),tostring(entry.rarity),tostring(entry.mutations),tostring(entry.traitsKnown)},':')
            end
        end
        local signature=tostring(othersOnly)..table.concat(parts,'|')
        if signature==lastRender then return end
        lastRender=signature
        local savedScroll=list.CanvasPosition
        local canvasHeight=#entries==0 and 40 or 0
        for _,child in ipairs(list:GetChildren()) do if child:IsA('Frame') then child:Destroy() end end
        aliveMessage.Visible=#entries==0
        aliveMessage.Text=othersOnly and 'No matching eggs in this server' or 'No matching eggs right now'
        for i,entry in ipairs(entries) do
            local row=D.make('Frame',{Size=UDim2.new(1,-6,0,90),LayoutOrder=i,BackgroundColor3=THEME.rowBg,BackgroundTransparency=0.15},list)
            D.make('UICorner',{CornerRadius=UDim.new(0,6)},row)
            D.make('UIStroke',{Color=THEME.rowStroke,Thickness=1},row)
            D.make('ImageLabel',{Image=entry.icon or '',BackgroundTransparency=1,Size=UDim2.fromOffset(60,70),Position=UDim2.fromOffset(4,8),ScaleType=Enum.ScaleType.Fit},row)
            local rarityKey=tostring(entry.rarity):lower():gsub('%s+','')
            local nameColor=rarityColors[rarityKey] or Color3.fromRGB(240,220,250)
            local nameLabel=D.label(row,tostring(entry.displayRank or entry.globalRank or i)..'. '..tostring(entry.name),UDim2.fromOffset(74,5),UDim2.new(1,-80,0,26),rarityKey=='eternal' and Color3.new(1,1,1) or nameColor,18)
            if rarityKey=='eternal' then D.make('UIGradient',{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,120,210)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(245,215,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(200,125,255))}),Rotation=0},nameLabel) end
            D.label(row,entry.missingRate and 'Income unavailable' or (entry.estimated and '~ ' or '')..D.money(entry.rate),UDim2.fromOffset(74,33),UDim2.new(1,-170,0,23),THEME.moneyGreen,15)
            local details=entry.scale and string.format('×%.2f',entry.scale) or 'Size ?'
            details=details..' | '..tostring(entry.rarity)..(entry.isLocal and '' or (' | '..math.max(0,math.floor((now-entry.seenAt)/1000))..'s'))
            D.label(row,details,UDim2.fromOffset(74,59),UDim2.new(1,-170,0,21),nameColor,13)
            local mutationText=mutationCaption(entry)
            if mutationText then
                local height=22
                pcall(function() height=math.max(22,game:GetService('TextService'):GetTextSize(mutationText,13,Enum.Font.GothamBold,Vector2.new(math.max(140,panel.AbsoluteSize.X-100),1000)).Y) end)
                row.Size=UDim2.new(1,-6,0,89+height)
                local mutationLabel=D.label(row,mutationText,UDim2.fromOffset(74,83),UDim2.new(1,-84,0,height),THEME.accentPink,13)
                mutationLabel.TextWrapped=true
                local badges={}
                for _,name in ipairs({'Silver','Golden','Rainbow'}) do if mutationText:lower():find(name:lower(),1,true) then badges[#badges+1]=name end end
                for index,name in ipairs(badges) do
                    local badge=D.label(row,name,UDim2.fromOffset(1,68-(#badges-index)*16),UDim2.fromOffset(68,20),Color3.new(1,1,1),13)
                    badge.TextXAlignment=Enum.TextXAlignment.Center
                    mutationStyle(badge,name)
                end
                local value=mutationText:match('^Mutation: (.+)$')
                if value then mutationStyle(mutationLabel,value) end
            end
            local here=entry.isLocal or entry.jobId==game.JobId
            local join=D.make('TextButton',{Text=here and 'HERE' or 'JOIN',Position=UDim2.new(1,-92,0,33),Size=UDim2.fromOffset(82,42),BackgroundColor3=here and THEME.btnPurple or THEME.btnPink,TextColor3=Color3.new(1,1,1),TextSize=12},row)
            D.make('UIStroke',{Color=THEME.accentPink,Thickness=1},join)
            join.Activated:Connect(function()
                if joining or entry.jobId==game.JobId then return end
                if (os.clock()+clockOffset)*1000>=entry.expiresAt then queryStatus='Report expired; refreshing'; feedAt=0; return end
                joining=true; queryStatus='Joining '..entry.name
                if not config then joining=false;queryStatus='Finder not connected';return end
                local claim,claimError=network(config.endpoint..'/v1/join','POST',Http:JSONEncode({placeId=entry.placeId,jobId=entry.jobId,uid=entry.uid,reporterId=reporterId}),headers())
                if not claim or claim.allowed~=true then
                    joining=false;feedAt=-math.huge
                    if claim then for index=#feed,1,-1 do if feed[index].jobId==entry.jobId then table.remove(feed,index) end end end
                    queryStatus=claim and 'Server reserved; choose another' or ('Join reservation failed: '..tostring(claimError))
                    return
                end
                D.stopFarm()
                local ok,err=pcall(function() Teleports:TeleportToPlaceInstance(entry.placeId,entry.jobId,D.player) end)
                if not ok then queryStatus='Join failed: '..tostring(err); joining=false end
                task.delay(12,function() joining=false end)
            end)
            canvasHeight+=row.Size.Y.Offset+5
        end
        list.CanvasSize=UDim2.fromOffset(0,canvasHeight)
        list.CanvasPosition=savedScroll
    end

    refreshButton.Activated:Connect(function()
        if refreshing or not active then return end
        refreshing=true;refreshButton.Text='REFRESHING…'
        task.spawn(function()
            local ok,err=pcall(function()
                local deadline=os.clock()+12
                while active and networkBusy and os.clock()<deadline do task.wait(0.1) end
                if not active then return end
                if networkBusy then error('Network busy; try again') end
                if not config or os.clock()-configAt>60 then local loaded,message=loadConfig();if not loaded then error(message) end end
                if not othersOnly then local loaded,message=refresh();if not loaded then error(message) end end
                lastRender=nil;render()
            end)
            refreshing=false
            if active then refreshButton.Text='REFRESH' queryStatus=ok and 'List refreshed' or ('Refresh failed: '..tostring(err)) end
        end)
    end)

    local failed=Teleports.TeleportInitFailed:Connect(function(who,_,message)
        if who==D.player then joining=false; queryStatus='Join failed: '..tostring(message) end
    end)
    D.gui.Destroying:Connect(function() active=false; failed:Disconnect();if localHighlight then localHighlight:Destroy() end end)

    task.spawn(function()
        local lastReport=-math.huge
        while active do
            local ok,err=pcall(function()
                if refreshing then return end
                if not config or os.clock()-configAt>60 then local success,message=loadConfig(); if not success then error(message) end end
                if os.clock()-lastReport>=20 then lastReport=os.clock(); local success,message=report(); reportStatus=success and message or 'Share: '..tostring(message) end
                if not othersOnly and os.clock()-feedAt>=8 then local success,message=refresh(); if not success then queryStatus='Finder: '..tostring(message) end end
            end)
            if not ok then queryStatus=tostring(err) end
            task.wait(2)
        end
    end)

    task.spawn(function()
        while active do
            status.Text=joining and 'Joining server…' or tostring(queryStatus~='' and queryStatus or reportStatus)
            sharingNotice.Visible=true
            local ok=pcall(render)
            if not ok then queryStatus='Unable to display finder feed' end
            task.wait(1)
        end
    end)
    print('[Jen Finder] Panel created')
end

local function run()
    local EggState=module('Client.EggState')
    local Assets=module('Data.Assets')
    local States=module('Shared.Types.AreaEggs').States
    local mutations,eggRecords,halloweenPets,rarities
    pcall(function() mutations=module('Shared.Modules.Mutations') end)
    pcall(function() eggRecords=module('Shared.Util.EggRecords') end)
    pcall(function() halloweenPets=module('Data.HalloweenPets') end)
    pcall(function() rarities=module('Data.Rarity') end)
    assert(type(EggState.ReadFieldEggs)=='function','ReadFieldEggs unavailable')
    assert(type(Assets.Directory)=='table' and States and States.Slot~=nil,'Game schema changed')
    local latestEntries={}
    local function parseValue(text) local amount,suffix=tostring(text):gsub(',',''):match('^%s*%$?%s*(%d+%.?%d*)%s*(%a*)%s*$') local powers={['']=1,k=1e3,m=1e6,b=1e9,t=1e12,qa=1e15,qi=1e18} local factor=suffix and powers[suffix:lower()] if not amount or not factor then return nil end local value=tonumber(amount)*factor return valid(value) and value or nil end
    local lastScan=0
    createFinder({gui=gui,localPanel={Visible=false},player=player,make=make,label=label,entries=function() return os.clock()-lastScan<10 and latestEntries or {} end,parseValue=parseValue,money=money,stopFarm=function() end})
    local notified={}
    local exported={}
    for _,path in ipairs({'Shared.Types.HalloweenDimension','Shared.Util.HalloweenDimension','Controllers.Game.HalloweenDimensionController'}) do local ok,value=pcall(module,path) if ok and type(value)=='table' then exported[#exported+1]=value end end
    local function exportedRecords(wanted)
        local found,visited={},{}
        local budget=2500
        local function walk(t,depth)
            if depth==0 or visited[t] or budget<=0 then return end
            visited[t]=true
            local uid=rawget(t,'Uid') or rawget(t,'HalloweenEggUid')
            if type(uid)=='string' and wanted[uid] then found[uid]=t end
            for key,value in pairs(t) do
                budget=budget-1; if budget<0 then break end
                if type(value)=='table' then
                    if type(key)=='string' and wanted[key] then found[key]=value end
                    walk(value,depth-1)
                end
            end
        end
        for _,value in ipairs(exported) do walk(value,5) end
        return found
    end
    local meshIndex={}
    local indexedAt=-math.huge
    local templateCount=0
    local function matchTemplate(model)
        local signature=meshSignature(model)
        if signature=='70705556141109:85596455133555' then
            local specs=halloweenPets and halloweenPets.Specs or {}
            local spec=specs['Graveyard Brute']
            if spec then return spec,'visual' end
        end
        if os.clock()-indexedAt>15 then
            indexedAt=os.clock(); meshIndex={}; templateCount=0
            local byName={}
            for _,spec in pairs(halloweenPets and halloweenPets.Specs or {}) do if type(spec)=='table' and type(spec.EggModel)=='string' then byName[spec.EggModel]=byName[spec.EggModel] or {} table.insert(byName[spec.EggModel],spec) end end
            for _,template in ipairs(RS:GetDescendants()) do
                local specs=byName[template.Name]
                if specs and template:IsA('Model') then
                    local signature=meshSignature(template)
                    if signature then
                        templateCount=templateCount+1
                        meshIndex[signature]=meshIndex[signature] or {}
                        for _,spec in ipairs(specs) do table.insert(meshIndex[signature],spec) end
                    end
                end
            end
        end
        local signature=meshSignature(model)
        return signature and uniqueMatch(meshIndex[signature] or {}) or nil
    end

    while alive do
        local ok,err=pcall(function()
            if not halloweenPets or type(halloweenPets.Specs)~='table' then pcall(function() halloweenPets=module('Data.HalloweenPets') end) end
            if not rarities then pcall(function() rarities=module('Data.Rarity') end) end
            local snapshot=EggState.ReadFieldEggs()
            assert(type(snapshot)=='table' and type(snapshot.Records)=='table','Field snapshot unavailable')
            local eggs,seen={},{}
            local fieldCount,eventCount,missingIncome=0,0,0
            for recordKey,record in pairs(snapshot.Records) do
                if record.State==States.Slot then
                    local asset=Assets.Directory[record.AssetCategory] or {}
                    local rarity=asset.Rarity or {}
                    local uid=record.Uid or recordKey
                    local model=modelFor(uid)
                    local scale=numberField(record,{'AssetScale'})
                    local weight
                    if eggRecords and type(eggRecords.WeightKg)=='function' then local good,result=pcall(eggRecords.WeightKg,record) if good and valid(result) then weight=result end end
                    local rate=displayedRate(model)
                    local estimated=false
                    if not rate then rate=computedRate(asset.EarningRate,scale,record.Mutations or {},mutations) estimated=rate~=nil end
                    fieldCount=fieldCount+1
                    seen[tostring(uid)]=true
                    local traits,traitsKnown=readTraitNames(record)
                    table.insert(eggs,{key='field:'..tostring(uid),uid=uid,traitsKnown=traitsKnown,category=record.AssetCategory,areaKey=record.AreaId,worldPos=typeof(record.BottomCFrame)=='CFrame' and record.BottomCFrame.Position or nil,area=tostring(record.AreaId)..' | Mut: '..(#traits>0 and table.concat(traits,', ') or traitsKnown and 'None' or 'UNKNOWN'),model=model,icon=asset.Icon,name=asset.DisplayName or record.AssetCategory or 'Unknown',rarity=rarity.DisplayName or rarity._id or 'Unknown',tier=tonumber(rarity.Rank) or 0,color=typeof(rarity.Color)=='Color3' and rarity.Color or Color3.new(1,1,1),scale=scale,weight=weight,rate=rate,estimated=estimated})
                end
            end
            local dimension=workspace:FindFirstChild('HalloweenDimension')
            local folder=dimension and dimension:FindFirstChild('WorldEggs')
            local wanted={}
            for _,obj in ipairs(folder and folder:GetDescendants() or {}) do if obj:IsA('Model') then local uid=obj:GetAttribute('HalloweenEggUid'); if type(uid)=='string' then wanted[uid]=true end end end
            local records=exportedRecords(wanted)
            for _,model in ipairs(folder and folder:GetDescendants() or {}) do
                if model:IsA('Model') and model:GetAttribute('HalloweenEggCanPickUp')==true then
                    local category=model:GetAttribute('PreparedSourceName')
                    local uid=model:GetAttribute('HalloweenEggUid')
                    local identity=uid and tostring(uid) or model:GetFullName()
                    if not seen[identity] then
                        seen[identity]=true
                        local spec=resolveSpec(halloweenPets and halloweenPets.Specs or {},category,model.Name)
                        local matchedMesh=false
                        local matchKind
                        if not spec then spec,matchKind=matchTemplate(model); matchedMesh=spec~=nil end
                        spec=spec or {}
                        local rarity=type(spec.Rarity)=='table' and spec.Rarity or nil
                        if not rarity and rarities then local directory=rarities.Rarities or rarities.Directory or {} rarity=directory[spec.Rarity] end
                        rarity=rarity or {}
                        if not rarity.Rank then
                            for _,asset in pairs(Assets.Directory) do
                                local candidate=asset.Rarity
                                if type(candidate)=='table' and (candidate._id==spec.Rarity or candidate.DisplayName==spec.Rarity) then rarity=candidate; break end
                            end
                        end
                        local scale=numberField(model:GetAttributes(),{'AssetScale','Scale'})
                        local weight=numberField(model:GetAttributes(),{'WeightKg'})
                        local rate=displayedRate(model)
                        local modelScale
                        pcall(function() local value=model:GetScale(); if valid(value) and value>0 then modelScale=value end end)
                        local traits,traitsKnown,traitSource=eventTraits(model,records[tostring(uid)])
                        local calculated=false
                        local scaleFromModel=false
                        if not scale then scale=modelScale; scaleFromModel=scale~=nil end
                        if not rate and traitsKnown then rate=computedRate(spec.EarningRate,scale,traits,mutations) calculated=rate~=nil end
                        eventCount=eventCount+1
                        local traitText=traitsKnown and (#traits>0 and table.concat(traits,', ') or 'None (explicit data)') or 'UNKNOWN'
                        if matchedMesh then traitText=traitText..(matchKind=='visual' and ' [visual ID]' or ' [mesh ID match]') end
                        table.insert(eggs,{key='event:'..identity,uid=uid,category=spec.Id or category,areaKey='Halloween / '..tostring(model:GetAttribute('Zone') or ''),worldPos=model:GetPivot().Position,isEvent=true,model=model,icon=spec.Icon,name=spec.DisplayName or category or model.Name,area='HW '..tostring(model:GetAttribute('Zone') or '')..' | Mut: '..traitText,rarity=rarity.DisplayName or tostring(spec.Rarity or 'Unknown'),tier=tonumber(rarity.Rank) or 0,color=typeof(rarity.Color)=='Color3' and rarity.Color or Color3.fromRGB(220,140,255),scale=scale,modelScale=modelScale,scaleFromModel=scaleFromModel,weight=weight,rate=rate,estimated=calculated,traitsKnown=traitsKnown})
                        eggs[#eggs].unresolved=spec.DisplayName==nil or spec.Rarity==nil
                        eggs[#eggs].traitSource=traitSource
                        if not traitsKnown then local candidate=computedRate(spec.EarningRate,scale,{},mutations) eggs[#eggs].unmutatedRate=candidate end
                    end
                end
            end
            for _,entry in ipairs(eggs) do entry.rate=entry.rate or entry.unmutatedRate end
            for _,entry in ipairs(eggs) do entry.mutationText=tostring(entry.area or ''):match('Mut:%s*(.*)') or '' end
            latestEntries=eggs
            lastScan=os.clock()
        end)
        if not ok then warn('Jen Finder scan:',err) end
        task.wait(2)
    end
end

task.spawn(function()
    local ok,err=pcall(run)
    if not ok then warn('Jen Finder startup:',err) end
end)
