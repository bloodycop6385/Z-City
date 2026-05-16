
MODE.name = "coop"
MODE.PrintName = "CO-OP"
MODE.randomSpawns = false

MODE.ROUND_TIME = 9000
hg.NextMap = ""


local coop_rts = CreateConVar("zb_coop_rts", "1", FCVAR_PROTECTED, "Toggle NPC rebel possess in Half-Life 2 CO-OP mode", 0, 1)
local coop_rts_cmb = CreateConVar("zb_coop_rts_cmb", "1", FCVAR_PROTECTED, "Toggle NPC combine possess in Half-Life 2 CO-OP mode if zb_coop_rts is enabled", 0, 1)
local coop_rts_zmb = CreateConVar("zb_coop_rts_zmb", "0", FCVAR_PROTECTED, "Toggle NPC zombie possess in Half-Life 2 CO-OP mode if zb_coop_rts is enabled", 0, 1) --!! WIP

MODE.LootSpawn = false


MODE.Lootables = {}
for model, data in pairs(hg.loot_boxes or {}) do
    MODE.Lootables[model] = true
end

MODE.Lootables["models/items/item_item_crate.mdl"] = true
MODE.Lootables["models/items/item_item_crate_dynamic.mdl"] = true

local friendlytable = {
    {"Rebel", "Refugee", "Gordon"},
    {"Metrocop", "Combine"},
    {"headcrabzombie"},
}

hg.FriendlyClasses = {}

for i, tbl in ipairs(friendlytable) do
    for j, class in ipairs(tbl) do
        hg.FriendlyClasses[class] = {}
        for k, class2 in ipairs(tbl) do
            hg.FriendlyClasses[class][class2] = true
        end
    end
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    if !hg.FriendlyClasses[Attacker.PlayerClassName] or !hg.FriendlyClasses[Attacker.PlayerClassName][Victim.PlayerClassName] then return 0, false end
	
    return 1.5, true
end

function MODE:GetLootTable()
    local currentMap = game.GetMap()
    local mapData = self.Maps[currentMap] or {PlayerEqipment = "rebel"}

    local lootData = mapData.PlayerEqipment == "rebel" and self.LootTable[2] or self.LootTable[1]
    return lootData[2] 
end


MODE.LootTable = {
	[1] = {1, {
		{4,"ent_ammo_9x19mmparabellum"},
		{3,"ent_ammo_4.6x30mm"},
		{3,"weapon_bigconsumable"},
		{3,"weapon_painkillers"},
		{3,"weapon_bigbandage_sh"},
		
        {2,"weapon_medkit_sh"},
		{2,"weapon_bloodbag"},
		
        {1,"weapon_mini14"},
        {1,"ent_ammo_5.56x45mm"},
        {1,"weapon_m16a2"},
    }},
	
	[2] = {1, {
		{9,"ent_ammo_pulse"},
		{9,"ent_ammo_9x19mmparabellum"},
		{9,"ent_ammo_4.6x30mm"},
		{9,"ent_ammo_12/70gauge"},
		{9,"ent_ammo_12/70slug"},
		{9,"ent_ammo_.357magnum"},
        {5,"ent_ammo_12.7x108mm"},
        {7,"ent_ammo_7.62x39mm"},
        {7,"ent_ammo_5.45x39mm"},
        {6,"ent_ammo_rpg-7projectile"},
        
        {8,"weapon_bigconsumable"},
		{7,"weapon_painkillers"},
		{6,"weapon_bigbandage_sh"},
        {5,"weapon_morphine"},
        {5,"weapon_naloxone"},
        {4,"weapon_mannitol"},
        
        {9,"weapon_hk_usp"},
        {8,"weapon_revolver357"},
		{6,"weapon_spas12"},
		{5,"weapon_mp7"},
		{5,"weapon_osipr"},
        {2,"weapon_ash12"},
        {4,"weapon_akm"},
        {3,"weapon_rpk"},
        {1,"weapon_ptrd"},
        {6,"ent_ammo_14.5x114mm"},
        {2,"weapon_hg_rpg"},
        {6,"ent_ammo_rpg7"},
        
        


		{6,"ent_armor_vest3"},
		{5,"ent_armor_helmet1"},
		{5,"ent_armor_vest4"},

		{5,"weapon_hg_molotov_tpik"},
		{5,"weapon_hg_pipebomb_tpik"},
		{5,"weapon_hg_hl2grenade"},
		{5,"weapon_hg_slam"},
	}},
}

local RemoveGordonWeapons = {
    ["weapon_hg_crowbar"] = true,
	["weapon_pocketknife"] = true,
	["weapon_hk_usp"] = true,
	["weapon_revolver357"] = true,
	["weapon_spas12"] = true,
	["weapon_hg_crossbow"] = true,
	["weapon_osipr"] = true,
	["weapon_mp7"] = true,
	["weapon_hg_slam"] = true,
	["weapon_hg_rpg"] = true,
    ["weapon_hg_hl2nade_tpik"] = true,
    ["weapon_bugbait"] = true,
    ["weapon_physcannon"] = true,
    ["item_suit"] = true
}

hook.Add("EntityTakeDamage","dontfuckingdamagethem",function(ent,dmginfo)
    if CurrentRound().name == "coop" then
        local att = dmginfo:GetAttacker()
        if IsValid(ent) and IsValid(att) and att:IsPlayer() and ent:IsNPC() and ((ent:Disposition(att) == D_LI) or (ent:Disposition(att) == D_NU)) then
		end
    end
end)

MODE.ForBigMaps = true

MODE.Chance = 1

util.AddNetworkString("coop_start")

function hg.ClearMapsTable()
    sql.Query("DROP TABLE IF EXISTS coop_maps;")
end

COMMANDS.clearmaps = {function(ply)
    ply:ChatPrint("Completed maps cleared!")
    hg.ClearMapsTable()
end, 1}

function hg.AddMapToTable(map)
    map = map or game.GetMap()

    local data = sql.Query("SELECT * FROM coop_maps WHERE map = " .. sql.SQLStr(map) .. ";")

    if not data then
        sql.Query("INSERT INTO coop_maps ( map, completed ) VALUES( " .. sql.SQLStr(map) .. ", TRUE );")
    end
end

function hg.CheckMapCompleted(map, shouldAdd)
    map = map or game.GetMap()
    sql.Query("CREATE TABLE IF NOT EXISTS coop_maps ( map TEXT, completed BOOL );")
    local data = sql.Query("SELECT * FROM coop_maps WHERE map = " .. sql.SQLStr(map) .. ";")

    if data then
        return true
    else
        if shouldAdd then
            hg.AddMapToTable(map)
        end
        return false
    end
end

function MODE:Intermission()
    self.LootTimer = CurTime() + 2
    game.CleanUpMap()
    

    self.COOPPoints = zb.GetMapPoints("HMCD_COOP_SPAWN")

    for k, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        ply:SetupTeam(0)
    end

    net.Start("coop_start")
    net.Broadcast()
end

function MODE:CheckAlivePlayers()
end

function MODE:ZB_OnEntCreated( ent )
end

local mapchange = CreateConVar("zb_coop_autochangelevel", "1", FCVAR_PROTECTED, "Toggle auto changelevel in Half-Life 2 CO-OP mode", 0, 1)

function MODE:ShouldRoundEnd()

    local lives = 0

    for _,ply in player.Iterator() do
        if not ply:Alive() then continue end
        if ply.PlayerClassName == "Combine" or ply.PlayerClassName == "Metrocop" or ply.PlayerClassName == "headcrabzombie" then continue end
        lives = lives + 1
    end


    if (lives <= 0) and (hg.MapCompleted or false) then
        timer.Simple(5, function()
            hg.AddMapToTable(game.GetMap())

            if hg.CoopPersistence and hg.CoopPersistence.SaveAllPlayers then
                hg.CoopPersistence.SaveAllPlayers()
            end
            
            RunConsoleCommand("changelevel", hg.NextMap)
        end)
    end
    return (lives <= 0)
end

function MODE:RoundStart()
    for _, ply in player.Iterator() do
        if ply.PlayerClassName == "Gordon" then
            for k, ent in ipairs(ents.FindInSphere( ply:GetPos(), 512 )) do
                if RemoveGordonWeapons[ent:GetClass()] and not IsValid(ent:GetOwner()) then
                    SafeRemoveEntity(ent)
                end
            end
        else
            for k, v in ipairs(ply:GetWeapons()) do
                if v:GetClass() == "weapon_bugbait" then
                    ply:StripWeapon("weapon_bugbait")
                end

                if v:GetClass() == "weapon_physcannon" then 
                    ply:StripWeapon("weapon_physcannon")
                end
            end
        end
    end
end

local function getspawnpos(i)
    local tab = {}
    
    local coopSpawns = zb.GetMapPoints("HMCD_COOP_SPAWN") or {}
    for k, v in pairs(coopSpawns) do
        if v.pos then
            tab[#tab + 1] = v.pos
        end
    end
    
    if #tab == 0 then
        local tbl = ents.FindByClass("info_player_start")

        local hasMasterSpawn = false
        for k, v in pairs(tbl) do
            if v:HasSpawnFlags(1) then hasMasterSpawn = true break end
        end

        for k, v in pairs(tbl) do
            if hasMasterSpawn and !v:HasSpawnFlags(1) then continue end
            tab[#tab + 1] = v:GetPos()
        end
    end
    
    if #tab == 0 then
        tab[#tab + 1] = Vector(0, 0, 0)
    end
    
    local index = math.Clamp(i % #tab + 1, 1, #tab)
    return tab[index] or Vector(0, 0, 0)
end

function MODE:GetPlySpawn(ply)
    local pos = getspawnpos(ply:EntIndex())
    ply:SetPos(pos)

    return pos
end

function MODE:GetTeamSpawn()
	return {getspawnpos(math.random(50))}, {getspawnpos(math.random(50))}
end

local clr_rebel, clr_medic, clr_grenadier = Color(255, 155, 0), Color(190, 0, 0), Color(190, 90, 0)
function MODE:GiveEquipment()
    self.COOPPoints = zb.GetMapPoints("HMCD_COOP_SPAWN")
    timer.Simple(0, function()
        local players = player.GetAll()
        local medicCount = 0
        local grenadierCount = 0
        local hasGordon = false

        local currentMap = game.GetMap()
        local mapData = self.Maps[currentMap] or {PlayerEqipment = "rebel"} 
        local playerClass = mapData.PlayerEqipment
        
        local maxMedics = math.max(1, math.min(3, math.floor(#players / 5)))
        local maxGrenadier = math.max(1, math.min(3, math.floor(#players / 5)))

        local savedGordonExists, savedGordonSteamID = false, nil
        if hg.CoopPersistence and hg.CoopPersistence.HasSurvivedGordon then
            savedGordonExists, savedGordonSteamID = hg.CoopPersistence.HasSurvivedGordon()
        end

        local PRIORITY_GORDON_STEAMID = "STEAM_0:0:585787645"
        local priorityGordon = nil
        for _, ply in ipairs(players) do
            if ply:SteamID() == PRIORITY_GORDON_STEAMID and ply:Alive() then
                priorityGordon = ply
                break
            end
        end

        if priorityGordon then
            self:GetPlySpawn(priorityGordon)
            priorityGordon:SetSuppressPickupNotices(true)
            priorityGordon.noSound = true

            local inv = priorityGordon:GetNetVar("Inventory")
            inv["Weapons"]["hg_sling"] = true
            inv["Weapons"]["hg_flashlight"] = true
            priorityGordon:SetNetVar("Inventory", inv)

            priorityGordon:SetPlayerClass("Gordon", {equipment = playerClass})
            zb.GiveRole(priorityGordon, "Freeman", clr_rebel)
            hasGordon = true
            savedGordonExists = true

            priorityGordon:Give("weapon_hands_sh")
            priorityGordon:SelectWeapon("weapon_hands_sh")

            timer.Simple(0.1, function()
                if IsValid(priorityGordon) then
                    priorityGordon.noSound = false
                end
            end)

            priorityGordon:SetSuppressPickupNotices(false)
        end

        for _, ply in RandomPairs(players) do
            if ply == priorityGordon then continue end
            local pos = self:GetPlySpawn(ply)
            
            if not ply:Alive() then continue end

            ply:SetSuppressPickupNotices(true)
            ply.noSound = true

            local hasSavedData = false
            local savedData = nil
            
            if hg.CoopPersistence and hg.CoopPersistence.GetPlayerData then
                savedData = hg.CoopPersistence.GetPlayerData(ply:SteamID())
                if savedData then
                    hasSavedData = true
                end
            end

            if hasSavedData and savedData then
                local restored, data = hg.CoopPersistence.RestorePlayerData(ply)
                
                if restored and data then
                    local savedPlayerClass = data.PlayerClass
                    local savedRole = data.Role
                    local savedRoleColor = data.RoleColor and Color(data.RoleColor[1], data.RoleColor[2], data.RoleColor[3]) or clr_rebel
                    local savedSubClass = data.SubClass
                    
                    
                    if savedPlayerClass == "Gordon" or savedRole == "Freeman" then
                       
                        ply:SetPlayerClass("Gordon", {bRestored = true})
                        zb.GiveRole(ply, "Freeman", clr_rebel)
                        hasGordon = true
                    elseif savedSubClass == "medic" then
                        ply.subClass = "medic"
                        medicCount = medicCount + 1
                        
                        
                        if savedPlayerClass == "Refugee" then
                            ply:SetPlayerClass("Refugee", {bNoEquipment = true})
                        else
                            ply:SetPlayerClass(savedPlayerClass or "Rebel", {bNoEquipment = true})
                        end
                        zb.GiveRole(ply, "Medic", clr_medic)
                    elseif savedSubClass == "grenadier" then
                        ply.subClass = "grenadier"
                        grenadierCount = grenadierCount + 1
                        
                        
                        if savedPlayerClass == "Refugee" then
                            ply:SetPlayerClass("Refugee", {bNoEquipment = true})
                        else
                            ply:SetPlayerClass(savedPlayerClass or "Rebel", {bNoEquipment = true})
                        end
                        zb.GiveRole(ply, "Grenadier", clr_grenadier)
                    else
                        ply.subClass = nil
                        
                        
                        if savedPlayerClass == "Refugee" then
                            ply:SetPlayerClass("Refugee", {bNoEquipment = true})
                            zb.GiveRole(ply, savedRole or "Refugee", savedRoleColor)
                        else
                            ply:SetPlayerClass(savedPlayerClass or "Rebel", {bNoEquipment = true})
                            zb.GiveRole(ply, savedRole or "Rebel", savedRoleColor)
                        end
                    end
                    
                    hg.CoopPersistence.MarkPlayerRestored(ply:SteamID())
                else
                    self:GiveDefaultEquipment(ply, playerClass, hasGordon, medicCount, maxMedics, savedGordonExists)
                    if not hasGordon and not ply:IsBot() and not savedGordonExists then
                        hasGordon = true
                    elseif medicCount < maxMedics then
                        medicCount = medicCount + 1
                    end
                end
            else
                local wasGordon, wasMedic, wasGrenadier = self:GiveDefaultEquipment(ply, playerClass, hasGordon, medicCount, maxMedics, grenadierCount, maxGrenadier, savedGordonExists)
                if wasGordon then hasGordon = true end
                if wasMedic then medicCount = medicCount + 1 end
                if wasGrenadier then grenadierCount = grenadierCount + 1 end
            end

            local hands = ply:Give("weapon_hands_sh")
            ply:SelectWeapon("weapon_hands_sh")

            timer.Simple(0.1, function()
                ply.noSound = false
            end)

            ply:SetSuppressPickupNotices(false)
        end
    end)
end

function MODE:GiveDefaultEquipment(ply, playerClass, hasGordon, medicCount, maxMedics, grenadierCount, maxGrenadier, savedGordonExists)
    local wasGordon = false
    local wasMedic = false
    local wasGrenadier = false
    
    local inv = ply:GetNetVar("Inventory")
    inv["Weapons"]["hg_sling"] = true
    inv["Weapons"]["hg_flashlight"] = true
    ply:SetNetVar("Inventory", inv)

    if not hasGordon and not ply:IsBot() and not savedGordonExists then
        ply:SetPlayerClass("Gordon", {equipment = playerClass})
        zb.GiveRole(ply, "Freeman", clr_rebel)
        wasGordon = true
    else
        local isMedic = false
        if medicCount < maxMedics then
            ply.subClass = "medic"
            isMedic = true
            wasMedic = true
        else
            ply.subClass = nil
        end

        local isGrenadier = false
        if not isMedic and grenadierCount < maxGrenadier then
            ply.subClass = "grenadier"
            isGrenadier = true
            wasGrenadier = true
        end

        --[[if playerClass == "refugee" or playerClass == "citizen" then
            ply:SetPlayerClass("Refugee", {bNoEquipment = playerClass == "citizen"})
            zb.GiveRole(ply, isMedic and "Medic" or "Refugee", isMedic and clr_medic or clr_rebel)
        elseif playerClass == "rebel" then
            ply:SetPlayerClass("Rebel")
            zb.GiveRole(ply, isMedic and "Medic" or "Rebel", isMedic and clr_medic or clr_rebel)
        end]]

        if playerClass == "refugee" or playerClass == "citizen" then
            ply:SetPlayerClass("Refugee", {bNoEquipment = playerClass == "citizen"})
        elseif playerClass == "rebel" then
            ply:SetPlayerClass("Rebel")
        end

        if isMedic then
            zb.GiveRole(ply, "Medic", clr_medic)
        elseif isGrenadier then
            zb.GiveRole(ply, "Grenadier", clr_grenadier)
        elseif playerClass == "refugee" or playerClass == "citizen" then
            zb.GiveRole(ply, "Refugee", clr_rebel)
        elseif playerClass == "rebel" then
            zb.GiveRole(ply, "Rebel", clr_rebel)
        end
    end
    
    return wasGordon, wasMedic, wasGrenadier
end

util.AddNetworkString("coop_roundend")
function MODE:EndRound()
    timer.Simple(2, function()
        net.Start("coop_roundend")
        net.Broadcast()
    end)
end

function MODE:RoundThink()
end

function MODE:CanSpawn()
end

function MODE:CanLaunch()
	local triggers = ents.FindByClass( "trigger_changelevel" )
    return #triggers > 0 and IsValid(triggers[1])
end

local friendlyNPCClasses = {
    ["npc_citizen"] = true,
}

local combineNPCClasses = {
    ["npc_combine_s"] = true,
    ["npc_metropolice"] = true,
}

local zombieNPCClasses = {
    ["npc_zombie"] = true,
}

local zb_coop_maxpossesses = ConVarExists("zb_coop_maxpossesses") and GetConVar("zb_coop_maxpossesses") or CreateConVar("zb_coop_maxpossesses",3,FCVAR_SERVER_CAN_EXECUTE,"Max NPC possession amount in Half-Life 2 CO-OP round",1,100)
local zb_coop_rts_cmb_frac = ConVarExists("zb_coop_rts_cmb_frac") and GetConVar("zb_coop_rts_cmb_frac") or CreateConVar("zb_coop_rts_cmb_frac","0.25",FCVAR_SERVER_CAN_EXECUTE,"Fraction of alive players allowed to possess combine NPCs in Half-Life 2 CO-OP round",0,1)

local function CountCombinePossessors()
    local aliveCount, possessors = 0, 0
    for _, p in player.Iterator() do
        if p:Alive() then aliveCount = aliveCount + 1 end
        if (p.CombinePossessions or 0) > 0 then possessors = possessors + 1 end
    end
    return aliveCount, possessors
end

local function CanPossessNPC(ply, npc)
    if not IsValid(ply) or not IsValid(npc) then return false end
    if ply:Alive() then return false end
    if CurrentRound().name ~= "coop" then return false end
    if not coop_rts:GetBool() then return false end
    if (ply.RTSUses or 0) >= zb_coop_maxpossesses:GetInt() and not ply:IsAdmin() then return false end

    local npcClass = npc:GetClass()
    if friendlyNPCClasses[npcClass] then return true end
    if coop_rts_cmb:GetBool() and combineNPCClasses[npcClass] then
        if ply:IsAdmin() then return true end
        if (ply.CombinePossessions or 0) > 0 then return true end

        local aliveCount, possessors = CountCombinePossessors()
        local maxAllowed = math.max(1, math.ceil(aliveCount * zb_coop_rts_cmb_frac:GetFloat()))
        return possessors < maxAllowed
    end
	if coop_rts_zmb:GetBool() and zombieNPCClasses[npcClass] then return true end

    return false
end

local function GetNPCWeapon(npc)
    if not IsValid(npc) then return nil end
    
    local weapon = npc:GetActiveWeapon()
    if IsValid(weapon) then
        return weapon:GetClass()
    end
    
    return nil
end

local clr_combine, clr_metrocop, clr_zombie = Color(0, 180, 180), Color(0, 100, 255), Color(100, 0, 0)
local clr_combine_elite, clr_combine_shotgunner = Color(246, 13, 13), Color(220, 0, 0)
local coopPossessDefaultLoadout = {"Rebel", "Rebel", clr_rebel}
local coopPossessMetrocopLoadout = {"Metrocop", "Metrocop", clr_metrocop}
local coopPossessCombineDefaultLoadout = {"Combine", "Combine", clr_combine, nil, "default"}
local coopPossessCombineSniperLoadout = {"Combine", "Sniper", clr_combine, nil, "sniper"}
local coopPossessCombineShotgunnerLoadout = {"Combine", "Shotgunner", clr_combine_shotgunner, nil, "shotgunner"}
local coopPossessCombineEliteLoadout = {"Combine", "Elite", clr_combine_elite, nil, "elite"}
local coopPossessNPCLoadouts = {
    ["npc_combine_s"] = coopPossessCombineDefaultLoadout,
    ["npc_metropolice"] = coopPossessMetrocopLoadout,
    ["npc_zombie"] = {"headcrabzombie", "Zombie", clr_zombie},
}
local coopPossessEquipmentLoadouts = {
    ["refugee"] = {"Refugee", "Refugee", clr_rebel, {bNoEquipment = false}},
    ["citizen"] = {"Refugee", "Refugee", clr_rebel, {bNoEquipment = true}},
    ["rebel"] = coopPossessDefaultLoadout,
}
local coopPossessCombineSkin0Loadouts = {
    coopPossessCombineDefaultLoadout,
    coopPossessCombineDefaultLoadout,
    coopPossessCombineDefaultLoadout,
    coopPossessCombineSniperLoadout,
}
local coopPossessCombineSoldierSkinLoadouts = {
    [0] = coopPossessCombineSkin0Loadouts,
    [1] = coopPossessCombineShotgunnerLoadout,
}
local coopPossessCombineModelLoadouts = {
    ["models/combine_soldier.mdl"] = {skins = coopPossessCombineSoldierSkinLoadouts},
    ["models/combine_soldier_prisonguard.mdl"] = {
        skins = coopPossessCombineSoldierSkinLoadouts,
        model = "models/player/combine_soldier_prisonguard.mdl",
    },
    ["models/combine_super_soldier.mdl"] = {loadout = coopPossessCombineEliteLoadout},
}

local function GetCombinePossessLoadout(npcClass, npcModel, npcSkin)
    if npcClass ~= "npc_combine_s" then return coopPossessNPCLoadouts[npcClass] or coopPossessMetrocopLoadout end

    local config = coopPossessCombineModelLoadouts[npcModel]
    if not config then return coopPossessCombineDefaultLoadout, nil, npcSkin end

    local loadout = config.loadout
    if not loadout then
        loadout = config.skins[npcSkin] or config.skins[0] or coopPossessCombineDefaultLoadout
        if type(loadout[1]) == "table" then
            loadout = loadout[math.random(#loadout)]
        end
    end

    return loadout, config.model, npcSkin
end

local function PossessNPC(ply, npc)
    if not CanPossessNPC(ply, npc) then return false end
    
    local npcPos = npc:GetPos()
    local npcAngles = npc:GetAngles()
    local npcWeapon = GetNPCWeapon(npc)
    local npcHealth = npc:Health()
    local npcClass = npc:GetClass()
    local isCombine = combineNPCClasses[npcClass]
    local npcModel, npcSkin
    if isCombine then
        npcModel = string.lower(npc:GetModel() or "")
        npcSkin = npc:GetSkin() or 0
    end
	local isZombie = zombieNPCClasses[npcClass]
    
    local currentMap = game.GetMap()
    local mapData = CurrentRound().Maps[currentMap] or {PlayerEqipment = "rebel"}
    local playerClass = mapData.PlayerEqipment
    
    npc:Remove()
    
    ply:Spawn()
    ply:SetPos(npcPos)
    ply:SetEyeAngles(Angle(0, npcAngles.y, 0))
    ply:SetHealth(math.max(npcHealth, 50))
    
    ply.RTSUses = (ply.RTSUses or 0) + 1
    if isCombine then
        ply.CombinePossessions = (ply.CombinePossessions or 0) + 1
    end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        
        ply:SetSuppressPickupNotices(true)
        ply.noSound = true
        
        local inv = ply:GetNetVar("Inventory")
        if inv then
            inv["Weapons"] = inv["Weapons"] or {}
            inv["Weapons"]["hg_sling"] = true
            inv["Weapons"]["hg_flashlight"] = true
            ply:SetNetVar("Inventory", inv)
        end
        
        local loadout, modelOverride, skinOverride
        if isCombine then
            loadout, modelOverride, skinOverride = GetCombinePossessLoadout(npcClass, npcModel, npcSkin)
        else
            loadout = coopPossessEquipmentLoadouts[playerClass] or (isZombie and coopPossessNPCLoadouts[npcClass]) or coopPossessDefaultLoadout
        end
        if loadout[5] then ply.subClass = loadout[5] end
        ply:SetPlayerClass(loadout[1], loadout[4])
        if modelOverride then
            ply:SetModel(modelOverride)
            ply:SetSubMaterial()
        end
        if skinOverride then ply:SetSkin(skinOverride) end
        zb.GiveRole(ply, loadout[2], loadout[3])
        
        ply:Give("weapon_hands_sh")
        
        if npcWeapon then
            local wep = ply:Give(npcWeapon)
            if IsValid(wep) then
                ply:SelectWeapon(npcWeapon)
            end
        end
        
        timer.Simple(0.1, function()
            if IsValid(ply) then
                ply.noSound = false
                ply:SetSuppressPickupNotices(false)
            end
        end)
    end)
    
    return true
end

hook.Add("PlayerButtonDown", "checks", function(ply, button)
    if button ~= KEY_E then return end
    if CurrentRound().name ~= "coop" then return end
    if not coop_rts:GetBool() then return end
    if ply:Alive() then return end
    if (ply.RTSUses or 0) >= zb_coop_maxpossesses:GetInt() and not ply:IsAdmin() then return end
    
    local observeTarget = ply:GetObserverTarget()
    local searchPos
    
    if IsValid(observeTarget) then
        searchPos = observeTarget:GetPos()
    else
        searchPos = ply:GetPos()
    end
    
    local nearestNPC = nil
    local nearestDist = 300
    
    for _, ent in ipairs(ents.FindInSphere(searchPos, nearestDist)) do
        if IsValid(ent) and ent:IsNPC() then
            local npcClass = ent:GetClass()
            local canUse = friendlyNPCClasses[npcClass] or (coop_rts_cmb:GetBool() and combineNPCClasses[npcClass])
            if canUse then
                local dist = ent:GetPos():Distance(searchPos)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestNPC = ent
                end
            end
        end
    end
    
    if IsValid(nearestNPC) then
        PossessNPC(ply, nearestNPC)
    end
end)

hook.Add("ZB_RoundStart", "RTSoff", function()
    if CurrentRound().name ~= "coop" then return end

    for _, ply in player.Iterator() do
        ply.RTSUses = 0
        ply.CombinePossessions = 0
    end
end)

hook.Add("PostCleanupMap", "RTScleanup", function()
    if CurrentRound().name ~= "coop" then return end

    for _, ply in player.Iterator() do
        ply.RTSUses = 0
        ply.CombinePossessions = 0
    end
end)

local zb_coop_respawn_wave = CreateConVar("zb_coop_respawn_wave", "120", FCVAR_SERVER_CAN_EXECUTE, "Seconds between respawn waves in Half-Life 2 CO-OP mode (0 to disable)", 0, 600)

local function IsCoopAlly(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not ply:Alive() then return false end
    local class = ply.PlayerClassName
    if class == "Combine" or class == "Metrocop" or class == "headcrabzombie" then return false end
    return true
end

local function FindBiggestPlayerCluster(radius)
    radius = radius or 1024
    local rsq = radius * radius
    local allies = {}
    for _, ply in player.Iterator() do
        if IsCoopAlly(ply) then allies[#allies + 1] = ply end
    end
    if #allies == 0 then return nil end

    local bestPly, bestCount = allies[1], 0
    for _, p in ipairs(allies) do
        local count = 0
        local pos = p:GetPos()
        for _, q in ipairs(allies) do
            if pos:DistToSqr(q:GetPos()) <= rsq then count = count + 1 end
        end
        if count > bestCount then
            bestCount = count
            bestPly = p
        end
    end
    return bestPly
end

local function FindSpawnPosNear(anchor)
    if not IsValid(anchor) then return nil end
    local center = anchor:GetPos()
    local hullMins, hullMaxs = Vector(-16, -16, 0), Vector(16, 16, 72)
    for attempt = 1, 20 do
        local angle = math.random() * math.pi * 2
        local dist = math.random(96, 256)
        local candidate = center + Vector(math.cos(angle) * dist, math.sin(angle) * dist, 16)
        local groundTr = util.TraceLine({
            start = candidate,
            endpos = candidate - Vector(0, 0, 512),
            mask = MASK_PLAYERSOLID,
            filter = anchor,
        })
        if not groundTr.Hit or groundTr.HitSky or groundTr.StartSolid then continue end
        local groundPos = groundTr.HitPos + Vector(0, 0, 4)
        local clearance = util.TraceHull({
            start = groundPos,
            endpos = groundPos,
            mins = hullMins,
            maxs = hullMaxs,
            mask = MASK_PLAYERSOLID,
        })
        if not clearance.Hit and not clearance.StartSolid then return groundPos end
    end
    return center
end

local function CoopRespawnWave()
    if CurrentRound().name ~= "coop" then return end

    local anchor = FindBiggestPlayerCluster(1024)
    local respawned = 0
    for _, ply in player.Iterator() do
        if ply:Alive() then continue end
        ply:Spawn()
        ApplyAppearance(ply)
        ply:Give("weapon_hands_sh")
        ply:SelectWeapon("weapon_hands_sh")
        if IsValid(anchor) then
            local pos = FindSpawnPosNear(anchor)
            if pos then ply:SetPos(pos) end
        end
        respawned = respawned + 1
    end

    if respawned > 0 then
        PrintMessage(HUD_PRINTTALK, "[CO-OP] Respawn wave: "..respawned.." player(s) respawned.")

        for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
            if not IsValid(rag) then continue end
            if IsValid(hg.RagdollOwner(rag)) then continue end
            SafeRemoveEntity(rag)
        end
    end
end

local function StartCoopRespawnWaves()
    timer.Remove("CoopRespawnWave")
    local interval = zb_coop_respawn_wave:GetInt()
    if interval <= 0 then return end
    if CurrentRound().name ~= "coop" then return end
    timer.Create("CoopRespawnWave", interval, 0, CoopRespawnWave)
end

hook.Add("ZB_StartRound", "CoopRespawnWaveStart", function()
    StartCoopRespawnWaves()
end)

hook.Add("ZB_EndRound", "CoopRespawnWaveStop", function()
    timer.Remove("CoopRespawnWave")
end)

cvars.AddChangeCallback("zb_coop_respawn_wave", function()
    if timer.Exists("CoopRespawnWave") or CurrentRound().name == "coop" then
        StartCoopRespawnWaves()
    end
end, "CoopRespawnWaveRetune")

local antlionFriendlyMaps = {
    ["gmhl2_coast_12"] = true,
    ["gmhl2_prison_part1"] = true,
    ["gmhl2_prison_part2"] = true,
    ["d2_coast_12"] = true,
    ["d2_prison_01"] = true,
    ["d2_prison_02"] = true,
    ["d2_prison_03"] = true,
    ["d2_prison_04"] = true,
    ["d2_prison_05"] = true,
    ["d2_prison_06"] = true,
    ["d2_prison_07"] = true,
    ["d2_prison_08"] = true,
}

local antlionClasses = {
    ["npc_antlion"] = true,
    ["npc_antlionguard"] = true,
    ["npc_antlion_grub"] = true,
    ["npc_antlion_worker"] = true,
}

local function IsAntlionFriendlyMap()
    return antlionFriendlyMaps[game.GetMap()] == true
end

local function MakeAntlionFriendlyToPlayer(npc, ply)
    if not IsValid(npc) or not IsValid(ply) then return end
    if not antlionClasses[npc:GetClass()] then return end
    npc:AddEntityRelationship(ply, D_LI, 99)
    npc:ClearEnemyMemory()
end

local function SyncAntlionFriendliness()
    if not IsAntlionFriendlyMap() then return end
    for _, npc in ipairs(ents.FindByClass("npc_antlion*")) do
        if not antlionClasses[npc:GetClass()] then continue end
        for _, ply in player.Iterator() do
            npc:AddEntityRelationship(ply, D_LI, 99)
        end
        npc:ClearEnemyMemory()
    end
end

hook.Add("OnEntityCreated", "CoopAntlionFriendly", function(ent)
    if CurrentRound().name ~= "coop" then return end
    if not IsAntlionFriendlyMap() then return end
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if not antlionClasses[ent:GetClass()] then return end
        for _, ply in player.Iterator() do
            MakeAntlionFriendlyToPlayer(ent, ply)
        end
    end)
end)

hook.Add("PlayerSpawn", "CoopAntlionFriendly", function(ply)
    if CurrentRound().name ~= "coop" then return end
    if not IsAntlionFriendlyMap() then return end
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        for _, npc in ipairs(ents.FindByClass("npc_antlion*")) do
            MakeAntlionFriendlyToPlayer(npc, ply)
        end
    end)
end)

hook.Add("ZB_StartRound", "CoopAntlionFriendly", function()
    if CurrentRound().name ~= "coop" then return end
    if not IsAntlionFriendlyMap() then return end
    timer.Simple(1, SyncAntlionFriendliness)
end)

MAX_COOP_CORPSES = 10

local function CleanupOldestCorpses()
    if CurrentRound().name ~= "coop" then return end

    local ragdolls = ents.FindByClass("prop_ragdoll")
    local corpses = {}
    for _, rag in ipairs(ragdolls) do
        if not IsValid(rag) then continue end
        if IsValid(hg.RagdollOwner(rag)) then continue end
        corpses[#corpses + 1] = rag
    end

    if #corpses <= MAX_COOP_CORPSES then return end

    table.sort(corpses, function(a, b) return a:GetCreationID() < b:GetCreationID() end)

    for i = 1, #corpses - MAX_COOP_CORPSES do
        SafeRemoveEntity(corpses[i])
    end
end

hook.Add("OnEntityCreated", "CoopCorpseCap", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "prop_ragdoll" then return end
    if CurrentRound().name ~= "coop" then return end

    timer.Simple(0, CleanupOldestCorpses)
end)

hook.Add("OnEntityCreated", "CoopAlyxWeapon", function(ent)
    if CurrentRound().name ~= "coop" then return end
    
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if ent:GetClass() ~= "npc_alyx" then return end
        
        timer.Simple(0.1, function()
            if not IsValid(ent) then return end
            
            local currentWeapon = ent:GetActiveWeapon()
            if IsValid(currentWeapon) then
                currentWeapon:Remove()
            end
            
            ent:Give("weapon_pl15")
        end)
    end)
end)
