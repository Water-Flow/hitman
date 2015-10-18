if SERVER then

    local math = math
    util.AddNetworkString( "TTT_Radar_Hitman" )

    hitman_target_pool = {}
    hitman_targets = {}
    hitman_killed_targets = {}
    hitman_killed_civs = {}

    CreateConVar("hitman_punishment", 1)

    --Set up the initial tables and give each T a target
    function InitHitman()
        hitman_targets = {}
        hitman_killed_civs = {}
        for _, ply in pairs(GetTraitors()) do
            SetPlayerHitman(ply)
        end
    end
    hook.Add("TTTBeginRound", "InitHitman", InitHitman)

    --Create table with all living innocents
    function GetTargetPool()
        local hitman_target_pool = {}
        for _, ply in pairs(player.GetAll()) do
            if not ply:IsTraitor() and ply:Alive() and not ply:IsSpec() and not GetAssignedHitman(ply) then table.insert(hitman_target_pool, ply) end
        end
        return hitman_target_pool
    end

    --Select Target and inform player
    function SetTraitorTarget(traitor)
        if #GetTargetPool() > 0 then
            local pick = table.Random(GetTargetPool())
            hitman_targets[traitor:Nick()] = pick:Nick()
            umsg.Start("hitman_newtarget", traitor)
            umsg.String(pick:Nick())
            umsg.End()
        else
            hitman_targets[traitor:Nick()] = nil
            umsg.Start("hitman_notarget", traitor)
            umsg.End()
        end
    end


    --Needed for Death- and Disconnectevents
    function GetAssignedHitman(target_ply)
        for _, ply in pairs(GetTraitors()) do
            if hitman_targets[ply:Nick()] == target_ply:Nick() then
                return ply
            end
        end
    end
    --Clean pool, when a player dies or leaves
    local function CheckDeadPlayer(victim, weapon, killer)
        --Determining if a hitman needs to be punished
        if killer:IsPlayer() then
            if killer:Nick() != victim:Nick() and killer:IsTraitor() then
                if GetAssignedHitman(victim) then
                    if GetAssignedHitman(victim):Nick() == killer:Nick() then AwardHitman(killer)
                    else PunishHitman(killer)
                    end
                else PunishHitman(killer)
                end
            end
        end
        --Disabling the TargetText client-side
        ReassignTarget(victim)
    end
    hook.Add( "PlayerDeath", "CheckDeadPlayer", CheckDeadPlayer)

    local function CheckDisconnectedPlayer(ply)
        ReassignTarget(ply)
    end
    hook.Add("PlayerDisconnected", "CheckDisconnectedPlayer", CheckDisconnectedPlayer)

    function ReassignTarget(ply)
        --Add Target back to pool
        if ply:IsTraitor() then
            hitman_targets[ply:Nick()] = nil
            umsg.Start("hitman_notarget", ply)
            umsg.End()
            --Check if a Traitor is without a target
            local assigned = false
            for _, v in pairs(GetTraitors()) do
                if !assigned and v:Alive() and ply != v and not hitman_targets[v:Nick()] then
                    SetTraitorTarget(v)
                    assigned = true
                end
            end
        else
            if GetAssignedHitman(ply) then
                SetTraitorTarget(GetAssignedHitman(ply))
            end
        end
    end

    function AwardHitman(ply)
        SetKilledTargets(ply, 1 + hitman_killed_targets[ply:Nick()])
    end

    function PunishHitman(ply)
        SetKilledCivs(ply, 1 + hitman_killed_civs[ply:Nick()])

        if hitman_killed_targets[ply:Nick()] < hitman_killed_civs[ply:Nick()] then
            local punishment = GetConVar("hitman_punishment"):GetInt()
            if punishment == 1 then
                PunishReveal(ply)
            elseif punishment == 2 then
                ply:Kill()
            end
            umsg.Start("hitman_disappointed", ply)
            umsg.Short(punishment)
            umsg.End()
        end
    end

    function PunishReveal(ply)
        for _, v in pairs(player.GetAll()) do
            if v:Nick() ~= ply:Nick() then
                umsg.Start("hitman_reveal", v)
                umsg.String(ply:Nick())
                umsg.End()
            end
        end
    end

    function SetPlayerHitman(ply)
        SetTraitorTarget(ply)
        SetKilledCivs(ply, 0)
        SetKilledTargets(ply, 0)
        umsg.Start("hitman_hitman", ply)
        umsg.End()
    end

    function SetKilledCivs(ply, score)
        hitman_killed_civs[ply:Nick()] = score
        umsg.Start("hitman_killed_civs", ply)
        umsg.Short(score)
        umsg.End()
    end

    function SetKilledTargets(ply, score)
        hitman_killed_targets[ply:Nick()] = score
        umsg.Start("hitman_killed_targets", ply)
        umsg.Short(score)
        umsg.End()
    end

    function DisableAllTargets()
        umsg.Start("hitman_notarget")
        umsg.End()
    end
    hook.Add("TTTPrepareRound", "Reset1", DisableAllTargets)
    hook.Add("TTTEndRound", "Reset2", DisableAllTargets)
    --Sleeper Hitman Hook
    hook.Add("SleeperHitman", "onSleeper", function(ply) SetPlayerHitman(ply) end)

    --For Debugging Purposes, will be removed on release
    function PrintTargets()
        print("Targets")
        for _, ply in pairs(GetTraitors()) do
            if hitman_targets[ply:Nick()] then print(ply:Nick() .. " ; " .. hitman_targets[ply:Nick()]) end
        end
    end
    concommand.Add("hitman_print_targets", PrintTargets)

    function PrintPool()
        print("Potential Targets")
        for _, ply in pairs(GetTargetPool()) do
            print(ply:Nick())
        end
    end
    concommand.Add("hitman_print_pool", PrintPool)

    local chargetime = 30

    function RadarScan(ply, cmd, args)
       if IsValid(ply) and ply:IsTerror() then
          if ply:HasEquipmentItem(EQUIP_RADAR) then

             if ply.radar_charge > CurTime() then
                LANG.Msg(ply, "radar_charging")
                return
             end

             if ply:IsTraitor() then
                 chargetime = 1
             else
                 chargetime = 30
             end

             ply.radar_charge =  CurTime() + chargetime

             local scan_ents = player.GetAll()
             table.Add(scan_ents, ents.FindByClass("ttt_decoy"))

             local targets = {}
             for k, p in pairs(scan_ents) do
                if ply:IsTraitor() then
                    if GetAssignedHitman(p) != nil then
                       if GetAssignedHitman(p):Nick() != ply:Nick() then continue end
                    else continue
                    end
                end

                if ply == p or (not IsValid(p)) then continue end

                if p:IsPlayer() then
                   if not p:IsTerror() then continue end
                   if p:GetNWBool("disguised", false) and (not ply:IsTraitor()) then continue end
                end

                local pos = p:LocalToWorld(p:OBBCenter())

                -- Round off, easier to send and inaccuracy does not matter
                pos.x = math.Round(pos.x)
                pos.y = math.Round(pos.y)
                pos.z = math.Round(pos.z)

                local role = p:IsPlayer() and p:GetRole() or -1

                if not p:IsPlayer() then
                   -- Decoys appear as innocents for non-traitors
                   if not ply:IsTraitor() then
                      role = ROLE_INNOCENT
                   end
                elseif role != ROLE_INNOCENT and role != ply:GetRole() then
                   -- Detectives/Traitors can see who has their role, but not who
                   -- has the opposite role.
                   role = ROLE_INNOCENT
                end

                table.insert(targets, {role=role, pos=pos})
             end

             net.Start("TTT_Radar_Hitman")
                net.WriteUInt(#targets, 8)
                net.WriteBit(ply:IsTraitor())
                for k, tgt in pairs(targets) do
                   net.WriteUInt(tgt.role, 2)

                   net.WriteInt(tgt.pos.x, 32)
                   net.WriteInt(tgt.pos.y, 32)
                   net.WriteInt(tgt.pos.z, 32)
                end
             net.Send(ply)

          else
             LANG.Msg(ply, "radar_not_owned")
          end
       end
    end

    hook.Add("Initialize", "OverrideRadar", function() concommand.Add("ttt_radar_scan", RadarScan) end)

else -- Client

    hitman_targetname = ""
    hitman_targetkills = 0
    hitman_civkills = 0

    local revealed = false

    --for painting
    local x = 270
    local y = ScrH() - 130

    local w = 250
    local h = 120

    usermessage.Hook( "hitman_newtarget", function(um) hitman_targetname = um:ReadString() end)
    usermessage.Hook( "hitman_notarget", function(um) hitman_targetname = nil end)

    local function DisplayHitlistHUD()
        if hitman_targetname and LocalPlayer():Alive() and LocalPlayer():IsTraitor() then
            --basic box
            draw.RoundedBox(8, x, y, w, h, Color(0, 0, 10, 200))
            draw.RoundedBox(8, x, y, w, 30, Color(200, 25, 25, 200))

            --Didn't mind using BadKings ShadowedText. For some reason stuff doesn't properly import. Got to clean up the bloody code at some point anyway.
            -- 26th June 2015: Still haven't, should get my lazy ass to do it some day
            -- 18th October 2015: lmao I'll never do this part properly, will I? Well doesn't matter really, atleast the rest of the code gets de-garbaged

            --Target announcer
            draw.SimpleText(hitman_targetname, "TraitorState", x + 12, y+2, Color(0, 0, 0, 255))
            draw.SimpleText(hitman_targetname, "TraitorState", x + 10, y, Color(255, 255, 255, 255))
            --Stats
            draw.SimpleText("Killed Targets: " .. hitman_targetkills, "HealthAmmo", x + 12, y +42, Color(0, 0, 0, 255))
            draw.SimpleText("Killed Targets: " .. hitman_targetkills, "HealthAmmo", x + 10, y +40, Color(255, 255, 255, 255))

            draw.SimpleText("Killed Civilians: " .. hitman_civkills, "HealthAmmo", x + 12, y + 62, Color(0, 0, 0, 255))
            draw.SimpleText("Killed Civilians: " .. hitman_civkills, "HealthAmmo", x + 10, y + 60, Color(255, 255, 255, 255))
        end
    end
    hook.Add("HUDPaint", "DisplayHitlistHUD", DisplayHitlistHUD);
    --Fetch stats
    usermessage.Hook( "hitman_killed_targets", function(um) hitman_targetkills = um:ReadShort() end)
    usermessage.Hook( "hitman_killed_civs", function(um) hitman_civkills = um:ReadShort() end)

    local function SetTraitor(um)
        if um:ReadBool() then chat.AddText(Color(255, 0, 0), "You are a hitman, hired by a mysterious employer who wants a range of people dead. Avoid killing anyone other than the target or your employer will be ... unsatisfied.") end
        revealed = false
    end
    usermessage.Hook( "hitman_hitman", SetTraitor )

    local function Disappointed(um)
        local punishment = um:ReadShort()
        if punishment == 2 then
            chat.AddText(Color(255, 0, 0), "Your employer is very disappointed of your work and decided to activate the killswitch")
        elseif punishment == 1 and !revealed then
            chat.AddText(Color(255, 0, 0), "As a result of breaking the contract with your employer he decided to blow your cover with an anonymous phone call.")
        end
        revealed = true
    end
    usermessage.Hook( "hitman_disappointed", Disappointed )

    local function RevealHitman(um)
        chat.AddText(Color(0, 255, 0), "You receive a phonecall from an unknown number. As you accept the call you hear an old man saying: \"", Color(255, 0, 0), um:ReadString(), Color(0, 255, 0), " is a hired killer! Kill him before he has the chance to murder someone innocent!\" ")
    end
    usermessage.Hook( "hitman_reveal", RevealHitman )

    local function ReceiveRadarScan()
       local num_targets = net.ReadUInt(8)
       local hitmanscan = net.ReadBit() == 1

       if hitmanscan then
          RADAR.duration = 1
       else
          RADAR.duration = 30
       end

       RADAR.targets = {}
       for i=1, num_targets do
          local r = net.ReadUInt(2)

          local pos = Vector()
          pos.x = net.ReadInt(32)
          pos.y = net.ReadInt(32)
          pos.z = net.ReadInt(32)

          table.insert(RADAR.targets, {role=r, pos=pos})
       end

       RADAR.enable = true
       RADAR.endtime = CurTime() + RADAR.duration

       timer.Create("radartimeout", RADAR.duration + 1, 1,
                    function() RADAR:Timeout() end)
    end
    net.Receive("TTT_Radar_Hitman", ReceiveRadarScan)

end