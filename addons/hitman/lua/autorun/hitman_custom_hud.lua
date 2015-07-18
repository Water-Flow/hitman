if !SERVER then

local initlang = false
local margin = 10
local dr = draw

-- Round status consts
local ROUND_WAIT   = 1
local ROUND_PREP   = 2
local ROUND_ACTIVE = 3
local ROUND_POST   = 4

local roundstate_string = {
   [ROUND_WAIT]   = "round_wait",
   [ROUND_PREP]   = "round_prep",
   [ROUND_ACTIVE] = "round_active",
   [ROUND_POST]   = "round_post"
};

surface.CreateFont("Hitman",   {font = "Marlett",
                                    size = 24,
                                    weight = 750})        

local function OverrideHUD()
    local hud = {"CHudHealth", "CHudBattery", "CHudAmmo", "CHudSecondaryAmmo", "TTTInfoPanel"}
    initlang = true
    function GAMEMODE:HUDShouldDraw(name)
       for k, v in pairs(hud) do
          if name == v then return false end
       end
       return true
    end
end
hook.Add("Initialize", "OverrideHUD", OverrideHUD)

local function HitmanInfoPaint()
   if !initlang then return end
   local client = LocalPlayer()
   local L = LANG.GetUnsafeLanguageTable()

   local width = 150
   local height = 90

   local x = ScrW() - margin - width
   local y = ScrH() - margin - height

   --DrawBg(x, y, width, height, client)

   local bar_height = 25
   local bar_width = width - (margin*2)

   -- Draw health
   local health = math.max(0, client:Health())
   local health_y = y + margin

   --PaintBar(x + margin, health_y, bar_width, bar_height, health_colors, health/100)

   ShadowedText(SimplisticHealthbar(health), "Hitman", x+margin, health_y, Color(128,128,128), TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT)

   -- Draw ammo
   if client:GetActiveWeapon().Primary then
      local ammo_clip, ammo_max, ammo_inv = GetAmmo(client)
      if ammo_clip != -1 then
         local ammo_y = health_y + bar_height + margin
         --PaintBar(x+margin, ammo_y, bar_width, bar_height, ammo_colors, ammo_clip/ammo_max)
         local text = string.format("%i + %02i", ammo_clip, ammo_inv)

         ShadowedText(ammo_clip, "Hitman", x+margin, ammo_y, Color(128,128,128), TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT)
         ShadowedText(ammo_inv, "Hitman", x+bar_width, ammo_y, Color(128,128,128), TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT)
      end
   end
   if !sb_visible then return end
   -- Draw traitor state
   local color = Color(200,200,200)
   local round_state = GAMEMODE.round_state

   local traitor_y = y - 30
   local text = nil
   if round_state == ROUND_ACTIVE then
      text = L[ client:GetRoleStringRaw() ]
   else
      text = L[ roundstate_string[round_state] ]
   end

   --ShadowedText(text, "TraitorState", x + margin + 73, traitor_y, COLOR_WHITE, TEXT_ALIGN_CENTER)
   dr.SimpleText(text, "TimeLeft", ScrW()/2 - 50, 5, color, TEXT_ALIGN_RIGHT)

   -- Draw round time

   local is_haste = HasteMode() and round_state == ROUND_ACTIVE
   local is_traitor = client:IsActiveTraitor()

   local endtime = GetGlobalFloat("ttt_round_end", 0) - CurTime()

   local text
   local font = "TimeLeft"
   local rx = x + margin + 170
   local ry = traitor_y + 3

   -- Time displays differently depending on whether haste mode is on,
   -- whether the player is traitor or not, and whether it is overtime.
   if is_haste then
      local hastetime = GetGlobalFloat("ttt_haste_end", 0) - CurTime()
      if hastetime < 0 then
         if (not is_traitor) or (math.ceil(CurTime()) % 7 <= 2) then
            -- innocent or blinking "overtime"
            text = L.overtime
            font = "Trebuchet18"

            -- need to hack the position a little because of the font switch
            ry = ry + 5
            rx = rx - 3
         else
            -- traitor and not blinking "overtime" right now, so standard endtime display
            text  = util.SimpleTime(math.max(0, endtime), "%02i:%02i")
            color = COLOR_RED
         end
      else
         -- still in starting period
         local t = hastetime
         if is_traitor and math.ceil(CurTime()) % 6 < 2 then
            t = endtime
            color = COLOR_RED
         end
         text = util.SimpleTime(math.max(0, t), "%02i:%02i")
      end
   else
      -- bog standard time when haste mode is off (or round not active)
      text = util.SimpleTime(math.max(0, endtime), "%02i:%02i")
   end

   --ShadowedText(text, font, rx, ry, color)
   dr.SimpleText(text, font, ScrW()/2, 5, color, TEXT_ALIGN_CENTER)

   if is_haste then
      dr.SimpleText(L.hastemode, "TabLarge", ScrW()/2, 25, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
   end

end
hook.Add("HUDPaint", "HitmanInfoPaint", HitmanInfoPaint)

local function DisplayHitlistHUD()
    client = LocalPlayer()
	draw.RoundedBox(8, 0, 0, ScrW(), ScrH(), Color(0, 0, 10, 200))
    if targetname ~= nil and client:Alive() == true and client:GetRole() == ROLE_TRAITOR then
        --Target announcer
        draw.SimpleText("Kill " .. targetname, "HealthAmmo", ScrW()/2, ScrH() - 20, Color(128, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if sb_visible then
            draw.SimpleText("Killed Targets: " .. targetkills, "HealthAmmo", 5, ScrH() - 40, Color(128, 0, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            draw.SimpleText("Killed Bystanders: " .. civkills, "HealthAmmo", 5, ScrH() - 20, Color(128, 0, 0), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end
hook.Remove("DisplayHitlistHUD")
hook.Add("HUDPaint", "DisplayHitlistHUD", DisplayHitlistHUD)

function SimplisticHealthbar(health)
    maxhealthbars = 25
    local temp = ""
    for i = 1,(health/100)*maxhealthbars do
        temp = temp .. "|"
    end
    return temp
end

function ShadowedText(text, font, x, y, color, xalign, yalign)

   dr.SimpleText(text, font, x+2, y+2, COLOR_BLACK, xalign, yalign)

   dr.SimpleText(text, font, x, y, color, xalign, yalign)
end

function GetAmmo(ply)
   local weap = ply:GetActiveWeapon()
   if not weap or not ply:Alive() then return -1 end

   local ammo_inv = weap:Ammo1() or 0
   local ammo_clip = weap:Clip1() or 0
   local ammo_max = weap.Primary.ClipSize or 0

   return ammo_clip, ammo_max, ammo_inv
end

hook.Add("ScoreboardShow", "sb_visible_true", function() sb_visible = true end)
hook.Add("ScoreboardHide", "sb_visible_false", function() sb_visible = false end)

end