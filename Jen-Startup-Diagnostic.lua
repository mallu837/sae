-- Readable startup diagnostic for the exact published v0.5 client.
local player=game:GetService('Players').LocalPlayer
assert(player,'Join the game first')
local parent=player:FindFirstChildOfClass('PlayerGui') or player:WaitForChild('PlayerGui',15)
assert(parent,'PlayerGui unavailable')
local old=parent:FindFirstChild('Jen_STARTUP_DIAGNOSTIC');if old then old:Destroy() end
local gui=Instance.new('ScreenGui');gui.Name='Jen_STARTUP_DIAGNOSTIC';gui.ResetOnSpawn=false;gui.DisplayOrder=32000;gui.IgnoreGuiInset=true;gui.Parent=parent
local frame=Instance.new('Frame');frame.Size=UDim2.new(0.9,0,0,170);frame.Position=UDim2.new(0.05,0,0.1,0);frame.BackgroundColor3=Color3.fromRGB(24,27,36);frame.Parent=gui
local text=Instance.new('TextBox');text.Size=UDim2.new(1,-48,1,-16);text.Position=UDim2.fromOffset(8,8);text.BackgroundTransparency=1;text.TextColor3=Color3.fromRGB(255,220,90);text.Font=Enum.Font.Code;text.TextSize=15;text.TextWrapped=true;text.MultiLine=true;text.ClearTextOnFocus=false;text.TextXAlignment=Enum.TextXAlignment.Left;text.TextYAlignment=Enum.TextYAlignment.Top;text.Text='Jen: downloading verified v0.5...';text.Parent=frame
local close=Instance.new('TextButton');close.Size=UDim2.fromOffset(32,32);close.Position=UDim2.new(1,-36,0,4);close.Text='X';close.TextColor3=Color3.new(1,1,1);close.BackgroundColor3=Color3.fromRGB(170,40,45);close.Parent=frame;close.Activated:Connect(function() gui:Destroy() end)
local failed=false
local function show(message,error)
 if not text.Parent then return end
 text.Text=tostring(message);text.TextColor3=error and Color3.fromRGB(255,110,110) or Color3.fromRGB(130,255,155)
 if error then failed=true end
end
local nativeLoadstring=loadstring
local nativeWarn=warn
local env=setmetatable({},{__index=getfenv()})
env.warn=function(...)
 nativeWarn(...)
 local parts={};for i=1,select('#',...) do parts[i]=tostring(select(i,...)) end
 local message=table.concat(parts,' ')
 if message:find('Jen Finder startup:',1,true) then show(message,true) end
end
env.loadstring=function(source,name)
 local fn,err=nativeLoadstring(source,name)
 if fn then setfenv(fn,env) end
 return fn,err
end
task.spawn(function()
 local ok,err=pcall(function()
  local source=game:HttpGet('https://raw.githubusercontent.com/mallu837/sae/refs/heads/main/jen_finderv2noautojoin.lua?diagnostic='..tostring(os.time()))
  assert(type(source)=='string' and #source>100,'Empty download')
  text.Text='Jen: compiling and starting v0.5...'
  local fn,compileError=env.loadstring(source,'Jen v0.5 diagnostic');assert(fn,compileError);fn()
 end)
 if not ok then show(err,true);return end
 task.delay(8,function()
  if failed or not text.Parent then return end
  local client=parent:FindFirstChild('Jen_FINDER_BETA')
  local panel=client and client:FindFirstChildWhichIsA('Frame')
  if panel and panel.Visible then
   show('Jen v0.5 opened. Public sent: '..tostring(client:GetAttribute('JenPublicSent'))..' | accepted: '..tostring(client:GetAttribute('JenPublicAccepted')),false)
  else show('Client did not finish opening. Send this screen and any new red startup error.',true) end
 end)
end)
