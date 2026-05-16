MODE.name = "coop"

local MODE = MODE

net.Receive("coop_start",function()
    surface.PlaySound("hl2mode1.wav")
	zb.RemoveFade()
	hg.DynaMusic:Start("hl_coop")
end)

local teams = {
	[0] = {
		objective = "Go to the end of the map!",
		name = "rebel",
		color1 = Color(155,55,0),
		color2 = Color(129,129,129)
	}
}

surface.CreateFont("ZB_CoopHUDStatus", {
    font = "Bahnschrift",
    size = ScreenScale(14),
    weight = 800,
    antialias = true
})

surface.CreateFont("ZB_CoopHUDTitle", {
    font = "Bahnschrift",
    size = ScreenScale(9),
    weight = 700,
    antialias = true
})

surface.CreateFont("ZB_CoopHUDText", {
    font = "Bahnschrift",
    size = ScreenScale(7),
    weight = 500,
    antialias = true
})

surface.CreateFont("ZB_CoopHUDSmall", {
    font = "Bahnschrift",
    size = ScreenScale(5),
    weight = 500,
    antialias = true
})

local hud = {
    alpha = 0,
    roster = {},
    radar = {},
    marker = {}
}

local gradientRight = Material("vgui/gradient-r")
local statusAlive = Color(92, 220, 138)
local statusDead = Color(235, 80, 72)
local statusSpectator = Color(155, 165, 175)
local statusDown = Color(245, 190, 80)
local hudBg = Color(9, 12, 15)
local hudPanel = Color(19, 24, 28)
local hudPanel2 = Color(30, 38, 43)
local hudText = Color(232, 238, 242)
local hudMuted = Color(142, 153, 160)
local hudLine = Color(255, 160, 70)
local vecUp = Vector(0, 0, 72)
local coopEnemyClasses = {
    Combine = true,
    Metrocop = true,
    headcrabzombie = true
}

local function AlphaColor(col, alpha)
    return Color(col.r, col.g, col.b, math.Clamp(alpha, 0, 255))
end

local function DrawShadowText(text, font, x, y, col, ax, ay)
    draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, col.a or 255), ax, ay)
    draw.SimpleText(text, font, x, y, col, ax, ay)
end

local function TrimLastChar(text)
    if string.utf8len and string.utf8sub then
        local ok, len = pcall(string.utf8len, text)
        if ok and len and len > 0 then
            return len > 1 and string.utf8sub(text, 1, len - 1) or ""
        end
    end

    return string.sub(text, 1, #text - 1)
end

local function FitText(text, font, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(maxWidth or 0, 12)
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then return text end

    local shortened = text
    while #shortened > 0 and surface.GetTextSize(shortened .. "...") > maxWidth do
        shortened = TrimLastChar(shortened)
    end

    return shortened ~= "" and (shortened .. "...") or "..."
end

local function DrawPanel(x, y, w, h, alpha)
    draw.RoundedBox(8, x, y, w, h, Color(0, 0, 0, alpha * 0.28))
    draw.RoundedBox(8, x, y, w, h, Color(hudPanel.r, hudPanel.g, hudPanel.b, alpha * 0.86))

    surface.SetMaterial(gradientRight)
    surface.SetDrawColor(hudPanel2.r, hudPanel2.g, hudPanel2.b, alpha * 0.42)
    surface.DrawTexturedRect(x, y, w, h)

    surface.SetDrawColor(hudLine.r, hudLine.g, hudLine.b, alpha * 0.72)
    surface.DrawOutlinedRect(x, y, w, h, 1)
end

local function DrawPill(x, y, w, h, col, alpha)
    draw.RoundedBox(6, x, y, w, h, Color(0, 0, 0, alpha * 0.24))
    draw.RoundedBox(6, x, y, w, h, Color(col.r, col.g, col.b, alpha * 0.24))
    surface.SetDrawColor(col.r, col.g, col.b, alpha * 0.84)
    surface.DrawOutlinedRect(x, y, w, h, 1)
end

local function GetRoleName(ply)
    if not IsValid(ply) then return "Unknown" end

    local roleName = ply:GetNWString("ZB_RoleName", "")
    if roleName == "" and ply == LocalPlayer() and ply.role then
        roleName = ply.role.name or ""
    end

    if roleName == "" then
        roleName = ply.PlayerClassName or team.GetName(ply:Team()) or "Player"
    end

    return roleName
end

local classColors = {
    Gordon = Color(255, 170, 75),
    Rebel = Color(240, 135, 70),
    Refugee = Color(210, 170, 110),
    Combine = Color(70, 190, 210),
    Metrocop = Color(75, 135, 255),
    headcrabzombie = Color(150, 65, 65)
}

local function GetRoleColor(ply)
    if not IsValid(ply) then return hudMuted end

    local r = ply:GetNWInt("ZB_RoleColorR", -1)
    if r >= 0 then
        return Color(r, ply:GetNWInt("ZB_RoleColorG", 255), ply:GetNWInt("ZB_RoleColorB", 255))
    end

    if ply == LocalPlayer() and ply.role and ply.role.color then
        return ply.role.color
    end

    return classColors[ply.PlayerClassName or ""] or ply:GetPlayerColor():ToColor()
end

local function GetPlayerState(ply)
    if not IsValid(ply) then return "Gone", hudMuted end
    if ply:Team() == TEAM_SPECTATOR then return "Spectator", statusSpectator end
    if not ply:Alive() then return "Dead", statusDead end
    if ply.organism and ply.organism.incapacitated then return "Down", statusDown end
    if coopEnemyClasses[ply.PlayerClassName or ""] then return "Possessed", GetRoleColor(ply) end

    return "Alive", statusAlive
end

local function GetSpectateTarget(ply)
    if not IsValid(ply) then return NULL end

    local target = ply:GetNWEntity("spect")
    if IsValid(target) then return target end

    for _, other in player.Iterator() do
        if other:Team() ~= TEAM_SPECTATOR and other:Alive() then
            return other
        end
    end

    return NULL
end

local function BuildPlayerStats()
    local stats = {
        total = 0,
        alive = 0,
        waiting = 0,
        spectators = 0,
        possessed = 0
    }

    for _, ply in player.Iterator() do
        stats.total = stats.total + 1
        if ply:Team() == TEAM_SPECTATOR then
            stats.spectators = stats.spectators + 1
        elseif ply:Alive() then
            stats.alive = stats.alive + 1
            if coopEnemyClasses[ply.PlayerClassName or ""] then
                stats.possessed = stats.possessed + 1
            end
        else
            stats.waiting = stats.waiting + 1
        end
    end

    return stats
end

local function GetRespawnWaveText()
    local interval = GetGlobalInt("zb_coop_respawn_wave_interval", 0)
    local nextWave = GetGlobalFloat("zb_coop_respawn_wave_next", 0)

    if interval <= 0 then
        return "Disabled", 0, 0
    end

    if nextWave <= 0 then
        return "Syncing", 0, interval
    end

    local remaining = math.max(nextWave - CurTime(), 0)
    if remaining <= 0.5 then
        return "Soon", 1, interval
    end

    return string.FormattedTime(remaining, "%02i:%02i"), math.Clamp(1 - remaining / math.max(interval, 1), 0, 1), interval
end

local function DrawStatusBanner(ply, target, stats, alpha)
    local isSpectator = ply:Team() == TEAM_SPECTATOR
    local statusText = isSpectator and "SPECTATOR" or "YOU DIED"
    local statusColor = isSpectator and statusSpectator or statusDead
    local bannerW = math.Clamp(sw * 0.50, 680, 920)
    local bannerH = ScreenScaleH(54)
    local x = sw * 0.5 - bannerW * 0.5
    local y = ScreenScaleH(24) - (1 - alpha / 255) * ScreenScaleH(24)
    local pulse = 0.65 + math.sin(CurTime() * 4) * 0.18

    DrawPanel(x, y, bannerW, bannerH, alpha)

    surface.SetMaterial(gradientRight)
    surface.SetDrawColor(statusColor.r, statusColor.g, statusColor.b, alpha * 0.25 * pulse)
    surface.DrawTexturedRect(x, y, bannerW, bannerH)

    draw.RoundedBox(4, x + ScreenScale(5), y + ScreenScaleH(8), ScreenScale(2), bannerH - ScreenScaleH(16), AlphaColor(statusColor, alpha))

    DrawShadowText(statusText, "ZB_CoopHUDStatus", x + ScreenScale(12), y + ScreenScaleH(9), AlphaColor(statusColor, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local targetText = IsValid(target) and ("Watching " .. target:Name() .. " | " .. GetRoleName(target)) or "No active target"
    local waveText = GetRespawnWaveText()
    local counts = stats.alive .. " alive  " .. stats.waiting .. " waiting  " .. stats.spectators .. " spectators"
    surface.SetFont("ZB_CoopHUDSmall")
    local countsW = surface.GetTextSize(counts)
    local detail = isSpectator and targetText or ("Respawn wave in " .. waveText .. " | " .. targetText)
    local detailMaxW = bannerW - countsW - ScreenScale(44)
    detail = FitText(detail, "ZB_CoopHUDSmall", detailMaxW)

    DrawShadowText(detail, "ZB_CoopHUDSmall", x + ScreenScale(14), y + bannerH - ScreenScaleH(10), AlphaColor(hudText, alpha * 0.88), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    DrawShadowText(counts, "ZB_CoopHUDSmall", x + bannerW - ScreenScale(12), y + bannerH - ScreenScaleH(10), AlphaColor(hudMuted, alpha * 0.95), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end

local function DrawGameStatePanel(stats, alpha)
    local panelW = math.Clamp(sw * 0.24, 430, 540)
    local panelH = ScreenScaleH(112)
    local x = ScreenScale(12) - (1 - alpha / 255) * ScreenScale(18)
    local y = sh - panelH - ScreenScaleH(24)
    local waveText, waveProgress = GetRespawnWaveText()
    local roundLeft = math.max((zb.ROUND_START or CurTime()) + (zb.ROUND_TIME or 0) - CurTime(), 0)

    DrawPanel(x, y, panelW, panelH, alpha)
    DrawShadowText("CO-OP STATE", "ZB_CoopHUDTitle", x + ScreenScale(10), y + ScreenScaleH(8), AlphaColor(hudLine, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DrawShadowText("Round " .. string.FormattedTime(roundLeft, "%02i:%02i:%02i"), "ZB_CoopHUDSmall", x + panelW - ScreenScale(10), y + ScreenScaleH(12), AlphaColor(hudMuted, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    local rowY = y + ScreenScaleH(35)
    local rowH = ScreenScaleH(25)
    local cardW = (panelW - ScreenScale(28)) / 3
    local cards = {
        {stats.alive, "Alive", statusAlive},
        {stats.waiting, "Waiting", statusDead},
        {stats.possessed, "Possessed", Color(75, 190, 215)}
    }

    for i, card in ipairs(cards) do
        local cx = x + ScreenScale(10) + (i - 1) * (cardW + ScreenScale(4))
        DrawPill(cx, rowY, cardW, rowH, card[3], alpha)
        DrawShadowText(tostring(card[1]), "ZB_CoopHUDText", cx + cardW * 0.5, rowY + rowH * 0.36, AlphaColor(hudText, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        DrawShadowText(FitText(card[2], "ZB_CoopHUDSmall", cardW - ScreenScale(8)), "ZB_CoopHUDSmall", cx + cardW * 0.5, rowY + rowH * 0.72, AlphaColor(hudMuted, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local barX = x + ScreenScale(10)
    local barY = y + panelH - ScreenScaleH(27)
    local barW = panelW - ScreenScale(20)
    local barH = ScreenScaleH(6)
    draw.RoundedBox(4, barX, barY, barW, barH, Color(0, 0, 0, alpha * 0.34))
    draw.RoundedBox(4, barX, barY, barW * waveProgress, barH, AlphaColor(hudLine, alpha))

    DrawShadowText("Next respawn wave", "ZB_CoopHUDSmall", barX, barY - ScreenScaleH(5), AlphaColor(hudMuted, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    DrawShadowText(waveText, "ZB_CoopHUDText", barX + barW, barY - ScreenScaleH(5), AlphaColor(hudText, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end

local function DrawRoster(alpha)
    local players = player.GetAll()
    table.sort(players, function(a, b)
        if a:Team() == TEAM_SPECTATOR and b:Team() ~= TEAM_SPECTATOR then return false end
        if b:Team() == TEAM_SPECTATOR and a:Team() ~= TEAM_SPECTATOR then return true end
        if a:Alive() ~= b:Alive() then return a:Alive() end
        return a:Name() < b:Name()
    end)

    local rowH = ScreenScaleH(21)
    local visibleRows = math.min(#players, 8)
    local panelW = math.Clamp(sw * 0.28, 460, 590)
    local panelH = ScreenScaleH(35) + visibleRows * rowH
    local x = sw - panelW - ScreenScale(12) + (1 - alpha / 255) * ScreenScale(22)
    local y = ScreenScaleH(96)

    DrawPanel(x, y, panelW, panelH, alpha)
    DrawShadowText("SQUAD", "ZB_CoopHUDTitle", x + ScreenScale(10), y + ScreenScaleH(8), AlphaColor(hudLine, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DrawShadowText("Role / state", "ZB_CoopHUDSmall", x + panelW - ScreenScale(10), y + ScreenScaleH(12), AlphaColor(hudMuted, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    for i = 1, visibleRows do
        local ply = players[i]
        if not IsValid(ply) then continue end

        local rowTarget = 1
        local key = ply:EntIndex()
        hud.roster[key] = LerpFT(0.14, hud.roster[key] or 0, rowTarget)
        local rowAlpha = alpha * hud.roster[key]
        local rowY = y + ScreenScaleH(31) + (i - 1) * rowH
        local stateText, stateColor = GetPlayerState(ply)
        local roleName = GetRoleName(ply)
        local roleColor = GetRoleColor(ply)

        draw.RoundedBox(4, x + ScreenScale(7), rowY + ScreenScaleH(2), panelW - ScreenScale(14), rowH - ScreenScaleH(4), Color(0, 0, 0, rowAlpha * 0.20))
        draw.RoundedBox(4, x + ScreenScale(7), rowY + ScreenScaleH(2), ScreenScale(3), rowH - ScreenScaleH(4), AlphaColor(roleColor, rowAlpha))

        local innerX = x + ScreenScale(16)
        local innerW = panelW - ScreenScale(28)
        local statusW = math.Clamp(panelW * 0.18, 82, 108)
        local roleW = math.Clamp(panelW * 0.24, 118, 160)
        local gap = ScreenScale(5)
        local nameW = math.max(innerW - statusW - roleW - gap * 2, 90)
        local roleX = innerX + nameW + gap
        local statusX = roleX + roleW + gap
        local nameText = FitText(ply:Name(), "ZB_CoopHUDText", nameW)
        DrawShadowText(nameText, "ZB_CoopHUDText", innerX, rowY + rowH * 0.5, AlphaColor(hudText, rowAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local className = ply.PlayerClassName or "Player"
        local roleText = FitText(roleName .. " / " .. className, "ZB_CoopHUDSmall", roleW)
        DrawShadowText(roleText, "ZB_CoopHUDSmall", roleX + roleW * 0.5, rowY + rowH * 0.5, AlphaColor(roleColor, rowAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        DrawPill(statusX, rowY + ScreenScaleH(4), statusW, rowH - ScreenScaleH(8), stateColor, rowAlpha)
        DrawShadowText(FitText(stateText, "ZB_CoopHUDSmall", statusW - ScreenScale(8)), "ZB_CoopHUDSmall", statusX + statusW * 0.5, rowY + rowH * 0.5, AlphaColor(hudText, rowAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function DrawRadar(target, alpha)
    local size = math.min(ScreenScale(92), sh * 0.25)
    local radius = size * 0.5
    local x = sw - size - ScreenScale(20) + (1 - alpha / 255) * ScreenScale(22)
    local y = sh - size - ScreenScaleH(26)
    local cx = x + radius
    local cy = y + radius
    local anchor = IsValid(target) and target or LocalPlayer()
    local anchorPos = IsValid(anchor) and anchor:GetPos() or vector_origin
    local yaw = EyeAngles().y
    if IsValid(target) then yaw = target:EyeAngles().y end
    local yawRad = math.rad(yaw)
    local cosYaw = math.cos(yawRad)
    local sinYaw = math.sin(yawRad)
    local worldScale = 2200
    local sweep = math.rad((CurTime() * 95) % 360)

    draw.RoundedBox(radius, x, y, size, size, Color(0, 0, 0, alpha * 0.36))
    draw.RoundedBox(radius, x + 1, y + 1, size - 2, size - 2, Color(hudBg.r, hudBg.g, hudBg.b, alpha * 0.82))

    surface.DrawCircle(cx, cy, radius * 0.33, 255, 255, 255, alpha * 0.07)
    surface.DrawCircle(cx, cy, radius * 0.66, 255, 255, 255, alpha * 0.07)
    surface.DrawCircle(cx, cy, radius - 2, 255, 255, 255, alpha * 0.07)
    surface.SetDrawColor(255, 255, 255, alpha * 0.07)
    surface.DrawLine(cx - radius + 8, cy, cx + radius - 8, cy)
    surface.DrawLine(cx, cy - radius + 8, cx, cy + radius - 8)

    surface.SetDrawColor(hudLine.r, hudLine.g, hudLine.b, alpha * 0.36)
    surface.DrawLine(cx, cy, cx + math.cos(sweep) * (radius - 6), cy + math.sin(sweep) * (radius - 6))

    DrawShadowText("N", "ZB_CoopHUDSmall", cx, y + ScreenScaleH(8), AlphaColor(hudMuted, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        if not ply:Alive() then continue end

        local rel = ply:GetPos() - anchorPos
        local forward = (rel.x * cosYaw + rel.y * sinYaw) / worldScale
        local right = (-rel.x * sinYaw + rel.y * cosYaw) / worldScale
        local px = right * radius
        local py = -forward * radius
        local dist = math.sqrt(px * px + py * py)
        local maxDist = radius - ScreenScale(5)

        if dist > maxDist then
            px = px / dist * maxDist
            py = py / dist * maxDist
        end

        local key = ply:EntIndex()
        hud.radar[key] = hud.radar[key] or {x = px, y = py}
        hud.radar[key].x = LerpFT(0.18, hud.radar[key].x, px)
        hud.radar[key].y = LerpFT(0.18, hud.radar[key].y, py)

        local roleColor = GetRoleColor(ply)
        local blipSize = ply == target and ScreenScale(7) or ScreenScale(5)
        local bx = cx + hud.radar[key].x
        local by = cy + hud.radar[key].y

        draw.RoundedBox(blipSize, bx - blipSize, by - blipSize, blipSize * 2, blipSize * 2, Color(0, 0, 0, alpha * 0.55))
        draw.RoundedBox(blipSize, bx - blipSize + 1, by - blipSize + 1, blipSize * 2 - 2, blipSize * 2 - 2, AlphaColor(roleColor, alpha))

        if ply == target then
            surface.DrawCircle(bx, by, blipSize + 4, roleColor.r, roleColor.g, roleColor.b, alpha * 0.85)
        end
    end
end

local function DrawWorldMarkers(target, alpha)
    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        if not ply:Alive() then continue end

        local screen = (ply:EyePos() + vecUp * 0.12):ToScreen()
        if not screen.visible then continue end

        local dist = IsValid(target) and target:GetPos():Distance(ply:GetPos()) or LocalPlayer():GetPos():Distance(ply:GetPos())
        local fade = math.Clamp(1 - dist / 9000, 0.34, 0.95)
        local markerAlpha = alpha * fade
        local key = ply:EntIndex()
        hud.marker[key] = LerpFT(0.16, hud.marker[key] or 0, markerAlpha)

        local roleColor = GetRoleColor(ply)
        local stateText = GetPlayerState(ply)
        local label = FitText(ply:Name() .. " | " .. GetRoleName(ply), "ZB_CoopHUDSmall", math.Clamp(sw * 0.15, 180, 280))
        local w = 0
        surface.SetFont("ZB_CoopHUDSmall")
        w = surface.GetTextSize(label)
        w = math.max(w + ScreenScale(18), ScreenScale(74))

        local x = screen.x - w * 0.5
        local y = screen.y - ScreenScaleH(12)
        DrawPill(x, y, w, ScreenScaleH(17), roleColor, hud.marker[key])
        DrawShadowText(label, "ZB_CoopHUDSmall", screen.x, y + ScreenScaleH(8), AlphaColor(hudText, hud.marker[key]), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.RoundedBox(8, screen.x - 3, y + ScreenScaleH(22), 6, 6, AlphaColor(roleColor, hud.marker[key]))
        if ply == target then
            DrawShadowText("TARGET", "ZB_CoopHUDSmall", screen.x, y - ScreenScaleH(4), AlphaColor(hudLine, hud.marker[key]), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        elseif stateText ~= "Alive" then
            DrawShadowText(stateText, "ZB_CoopHUDSmall", screen.x, y - ScreenScaleH(4), AlphaColor(hudMuted, hud.marker[key]), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
    end
end

local function DrawCoopSpectatorHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local active = zb.ROUND_STATE == 1 and (not ply:Alive() or ply:Team() == TEAM_SPECTATOR)
    hud.alpha = LerpFT(0.12, hud.alpha or 0, active and 255 or 0)
    if hud.alpha <= 1 then return end

    local alpha = hud.alpha
    local target = GetSpectateTarget(ply)
    local stats = BuildPlayerStats()

    surface.SetDrawColor(0, 0, 0, alpha * 0.14)
    surface.DrawRect(0, 0, sw, sh)

    DrawWorldMarkers(target, alpha)
    DrawStatusBanner(ply, target, stats, alpha)
    DrawGameStatePanel(stats, alpha)
    DrawRoster(alpha)
    DrawRadar(target, alpha)
end

function MODE:RenderScreenspaceEffects()
    if zb.ROUND_START + 7.5 < CurTime() then return end
    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(),0,1)

    surface.SetDrawColor(0,0,0,255 * fade)
    surface.DrawRect(-1,-1,ScrW() + 1,ScrH() + 1)
end

function MODE:HUDPaint()
    DrawCoopSpectatorHUD()

    if zb.ROUND_START + 8.5 < CurTime() then return end

	if not lply:Alive() then return end
	zb.RemoveFade()
    local fade = math.Clamp(zb.ROUND_START + 8 - CurTime(),0,1)
    draw.SimpleText("Homicide | CO-OP", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0,162,255, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    local Rolename = (lply.role and lply.role.name) or "Unknown"
    local ColorRole = Color(teams[0].color1.r, teams[0].color1.g, teams[0].color1.b, 255 * fade)
    draw.SimpleText("You are " .. Rolename, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local Objective = lply.PlayerClassName == "Gordon" and "Lead the resistance to victory!" or "Follow the Gordon!"
    local ColorObj = Color(teams[0].color2.r, teams[0].color2.g, teams[0].color2.b, 255 * fade)
    draw.SimpleText( Objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local CreateEndMenu

net.Receive("coop_roundend",function()
    CreateEndMenu()
end)

local colGray = Color(85,85,85,255)
local colRed = Color(130,10,10)
local colRedUp = Color(160,30,30)

local colBlue = Color(10,10,160)
local colBlueUp = Color(40,40,160)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(255,255,255)

local colorBG = Color(55,55,55,255)
local colorBGBlacky = Color(40,40,40,255)

local blurMat = Material("pp/blurscreen")
local Dynamic = 0

BlurBackground = BlurBackground or hg.DrawBlur

if IsValid(hmcdEndMenu) then
    hmcdEndMenu:Remove()
    hmcdEndMenu = nil
end

CreateEndMenu = function()
	if IsValid(hmcdEndMenu) then
		hmcdEndMenu:Remove()
		hmcdEndMenu = nil
	end
	Dynamic = 0
	hmcdEndMenu = vgui.Create("ZFrame")

    surface.PlaySound("ambient/alarms/warningbell1.wav")

	local sizeX,sizeY = ScrW() / 2.5 ,ScrH() / 1.2
	local posX,posY = ScrW() / 1.3 - sizeX / 2,ScrH() / 2 - sizeY / 2

	hmcdEndMenu:SetPos(posX,posY)
	hmcdEndMenu:SetSize(sizeX,sizeY)
	--hmcdEndMenu:SetBackgroundColor(colGray)
	hmcdEndMenu:MakePopup()
	hmcdEndMenu:SetKeyboardInputEnabled(false)
	hmcdEndMenu:ShowCloseButton(false)

	local closebutton = vgui.Create("DButton",hmcdEndMenu)
	closebutton:SetPos(5,5)
	closebutton:SetSize(ScrW() / 20,ScrH() / 30)
	closebutton:SetText("")
	
	closebutton.DoClick = function()
		if IsValid(hmcdEndMenu) then
			hmcdEndMenu:Close()
			hmcdEndMenu = nil
		end
	end

	closebutton.Paint = function(self,w,h)
		surface.SetDrawColor( 122, 122, 122, 255)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
		surface.SetFont( "ZB_InterfaceMedium" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Close")
		surface.SetTextPos( lengthX - lengthX/1.1, 4)
		surface.DrawText("Close")
	end

    hmcdEndMenu.PaintOver = function(self,w,h)

		surface.SetFont( "ZB_InterfaceMediumLarge" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Players:")
		surface.SetTextPos(w / 2 - lengthX/2,20)
		surface.DrawText("Players:")

	end
	-- PLAYERS
	local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
	DScrollPanel:SetPos(10, 80)
	DScrollPanel:SetSize(sizeX - 20, sizeY - 90)
	function DScrollPanel:Paint( w, h )

		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end

	for i, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		local but = vgui.Create("DButton",DScrollPanel)
		but:SetSize(100,50)
		but:Dock(TOP)
		but:DockMargin( 8, 6, 8, -1 )
		but:SetText("")
		but.Paint = function(self,w,h)
			if !IsValid(ply) then return end
            local col1 = (ply:Alive() and colRed) or colGray
            local col2 = (ply:Alive() and colRedUp) or colSpect1
			surface.SetDrawColor(col1.r,col1.g,col1.b,col1.a)
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor(col2.r,col2.g,col2.b,col2.a)
			surface.DrawRect(0,h/2,w,h/2)

            local col = ply:GetPlayerColor():ToColor()
			surface.SetFont( "ZB_InterfaceMediumLarge" )
			local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
			
			surface.SetTextColor(0,0,0,255)
			surface.SetTextPos(w / 2 + 1,h/2 - lengthY/2 + 1)
			surface.DrawText(ply:GetPlayerName() or "He quited...")

			surface.SetTextColor(col.r,col.g,col.b,col.a)
			surface.SetTextPos(w / 2,h/2 - lengthY/2)
			surface.DrawText(ply:GetPlayerName() or "He quited...")

            
			local col = colSpect2
			surface.SetFont( "ZB_InterfaceMediumLarge" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
			surface.SetTextPos(15,h/2 - lengthY/2)
			surface.DrawText((ply:Name() .. (not ply:Alive() and " - died" or "")) or "He quited...")

			surface.SetFont( "ZB_InterfaceMediumLarge" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize( ply:Frags() or "He quited..." )
			surface.SetTextPos(w - lengthX -15,h/2 - lengthY/2)
			surface.DrawText(ply:Frags() or "He quited...")
		end

		function but:DoClick()
			if ply:IsBot() then chat.AddText(Color(255,0,0), "no, you can't") return end
			gui.OpenURL("https://steamcommunity.com/profiles/"..ply:SteamID64())
		end

		DScrollPanel:AddItem(but)
	end

	return true
end

function MODE:RoundStart()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end
