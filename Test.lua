

getgenv().Config = {
    ['Areas'] = {
        "2 | Colorful Forest",
        "3 | Castle",
        "4 | Green Forest",
        "5 | Autumn",
        "6 | Cherry Blossom",
    }
}

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = game.Players.LocalPlayer

local Library = ReplicatedStorage.Library
local Client = ReplicatedStorage.Library.Client

local Network = require(Client.Network)
local Save = require(Client.Save)

local Breakables = workspace['__THINGS'].Breakables
local Map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("Map2") or workspace:FindFirstChild("Map3")
local Areas = {}

for _,v in ipairs(Config.Areas) do
    local Area = Map and Map:FindFirstChild(v)
    if Area then table.insert(Areas, Area)
    else warn("Area not found: " .. v) end
end

-- Chống Treo Máy (Anti-AFK) & Tự Động Nhặt Quà (Auto Claim)
game.Players.LocalPlayer.PlayerScripts.Scripts.Core["Idle Tracking"].Enabled = false;
game.Players.LocalPlayer.Idled:connect(function()
    game:GetService("VirtualUser"):Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    game:GetService("VirtualUser"):Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

workspace.__THINGS:FindFirstChild("Lootbags").ChildAdded:Connect(function(lootbag)
    task.wait()
    if lootbag then Network.Fire("Lootbags_Claim", { lootbag.Name }) end
end)

hookfunction(require(Client.PlayerPet).CalculateSpeedMultiplier, function() return 9999 end)

Network.Fired("Orbs: Create"):Connect(function(InfoTable)
    local Orbs = {}
    for _, v in ipairs(InfoTable) do table.insert(Orbs, v.id) end
    Network.Fire("Orbs: Collect", Orbs)
end)

-- Tự động quét và phá hủy Lucky Block từ xa
task.spawn(function()
    while task.wait() do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        for _, v in pairs(Breakables:GetChildren()) do
            if v:IsA("Model") then
                local bID = v:GetAttribute("BreakableID")
                -- Quét tất cả các loại khối có tên hoặc thuộc tính chứa chữ "Lucky"
                if bID == "Lucky Block" or bID == "Mini Lucky Block" or string.find(v.Name, "Lucky") then
                    local pos = v:GetPivot().Position
                    local dist = (pos - hrp.Position).Magnitude

                    if dist <= 300 then
                        Network.UnreliableFire("Breakables_PlayerDealDamage", v.Name)
                        task.wait(0.04) -- Tăng nhẹ tốc độ đập khối
                    end
                end
            end
        end
    end
end)

-- Hàm kiểm tra vật phẩm trong kho đồ
local ItemUid = nil
local CurrentItemType = nil

local GetItemUID = function()
    local Misc = Save.Get().Inventory.Misc
   
    -- Ưu tiên tìm Mini Lucky Block trước
    for uid, v in pairs(Misc) do
        if v.id == "Mini Lucky Block" then
            ItemUid = uid
            CurrentItemType = "MiniLuckyBlock"
            return uid
        end
    end
   
    -- Nếu hết Mini Lucky Block, tìm sang Lucky Block lớn
    for uid, v in pairs(Misc) do
        if v.id == "Lucky Block" then
            ItemUid = uid
            CurrentItemType = "LuckyBlock"
            return uid
        end
    end
   
    CurrentItemType = nil
    return nil
end

-- Vòng lặp chính: Dịch chuyển, đặt block và kích hoạt
while task.wait() do
    local uid = GetItemUID()
    if uid and CurrentItemType then
        for _, v in pairs(Areas) do
            if not v:FindFirstChild("INTERACT") then
                repeat
                    LocalPlayer.Character.HumanoidRootPart.CFrame = v.PERSISTENT.Teleport.CFrame
                    task.wait(0.1)
                until v:FindFirstChild("INTERACT")
            end
           
            LocalPlayer.Character.HumanoidRootPart.CFrame = v.INTERACT.BREAK_ZONES.BREAK_ZONE.CFrame
           
            -- Lựa chọn lệnh tương ứng với loại vật phẩm đang có
            local remoteName = (CurrentItemType == "MiniLuckyBlock") and "MiniLuckyBlock_Consume" or "LuckyBlock_Consume"
           
            local success, err = Network.Invoke(remoteName, uid)
            if not success and err ~= "There is already something in this area!" and err ~= "There are too many random events already in the world!" then
                repeat
                    if not GetItemUID() then break end
                    success, err = Network.Invoke(remoteName, uid)
                    task.wait(0.1)
                until success
            end
        end
    else
        print("Hết sạch Mini Lucky Block và Lucky Block trong kho đồ!")
        break
    end
end


