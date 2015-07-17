if SERVER then

local math = math
util.AddNetworkString( "TTT_Radar_Hitman" )

local target_pool = {}
traitor_targets = {}
local traitor_killed_targets = {}
local traitor_killed_civs = {}

CreateConVar("hitman_punishment", 1)

--Set up the initial tables and give each T a target
function InitHitman()
    traitor_targets = {}
    traitor_killed_civs = {}
    for _, ply in pairs(player.GetAll()) do
        if ply:Alive() and not ply:IsSpec() then
            SetPlayerAlive(ply, true)
            SetPlayerHitman(ply, false)
        end
    end
    for _, ply in pairs(GetTraitors()) do
        SetTraitorTarget(ply)
        SetKilledCivs(ply, 0)
        SetKilledTargets(ply, 0)
        SetPlayerHitman(ply, true)
    end
end
hook.Add("TTTBeginRound", "InitHitman", InitHitman)

--Create table with all living innocents
function GetTargetPool()
	local target_pool = {}
	for _, ply in pairs(player.GetAll()) do
		if not ply:IsTraitor() and ply:Alive() and not ply:IsSpec() and GetAssignedHitman(ply) == nil then table.insert(target_pool, ply)	end
	end
	return target_pool
end

function AddToPool(ply)
   table.insert(target_pool, ply)
end

--Select Target and inform player
function SetTraitorTarget(traitor)
	if #GetTargetPool() > 0 then
	    local pick = table.Random(GetTargetPool())
        traitor_targets[traitor:Nick()] = pick:Nick()
        umsg.Start("hitman_newtarget", traitor)
		umsg.String(pick:Nick())
        umsg.End()
    else
	    traitor_targets[traitor:Nick()] = nil
        umsg.Start("hitman_notarget", traitor)
        umsg.End()
    end
end


--Needed for Death- and Disconnectevents
function GetAssignedHitman(target_ply)
    for _, ply in pairs(GetTraitors()) do
        if traitor_targets[ply:Nick()] == target_ply:Nick() then
            return ply
        end
    end
end
--Clean pool, when a player dies or leaves
local function CheckDeadPlayer(victim, weapon, killer)
    --Determining if a hitman needs to be punished
    if killer:IsPlayer() then
	    if killer:Nick() != victim:Nick() then
	        if killer:IsTraitor() then
	    	    if GetAssignedHitman(victim) != nil then
                    if GetAssignedHitman(victim):Nick() == killer:Nick() then AwardHitman(killer)
                    else PunishHitman(killer)
                    end        
                else PunishHitman(killer)
	    	    end
	        end
        end
	end
    --Disabling the TargetText client-side
    SetPlayerAlive(victim, false)
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
        --Check if a Traitor is without a target
		local assigned = false
        for _, v in pairs(GetTraitors()) do
            if !assigned and v:Alive() and traitor_targets[v:Nick()] == nil then
				SetTraitorTarget(v)
				assigned = true
            end
        end
		traitor_targets[ply:Nick()] = nil
        umsg.Start("hitman_notarget", ply)
        umsg.End()
	else
	    if GetAssignedHitman(ply) != nil then
            SetTraitorTarget(GetAssignedHitman(ply))
        end
    end
    -- Give Assigned Hitman a new target
end

function PlayerByName(name)
    for _, ply in pairs(player.GetAll()) do
        if ply:Nick() == name then return ply end
    end
end

function AwardHitman(ply)
    SetKilledTargets(ply, 1 + traitor_killed_targets[ply:Nick()])
end

function PunishHitman(ply)
    SetKilledCivs(ply, 1 + traitor_killed_civs[ply:Nick()])
    
    if traitor_killed_targets[ply:Nick()] < traitor_killed_civs[ply:Nick()] then
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

function SetPlayerAlive(ply, val)
    umsg.Start("hitman_alive", ply)
	umsg.Bool(val)
    umsg.End()
end

function SetPlayerHitman(ply, val)
    umsg.Start("hitman_hitman", ply)
	umsg.Bool(val)
    umsg.End()
end

function SetKilledCivs(ply, score)
    traitor_killed_civs[ply:Nick()] = score
	umsg.Start("hitman_killed_civs", ply)
    umsg.Short(score)
    umsg.End()
end

function SetKilledTargets(ply, score)
    traitor_killed_targets[ply:Nick()] = score
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
function onSleeper(ply)
    SetTraitorTarget(ply)
    SetKilledCivs(ply, 0)
    SetKilledTargets(ply, 0)
    SetPlayerHitman(ply, true)
end
hook.Add("SleeperHitman", "onSleeper", onSleeper)

--For Debugging Purposes, will be removed on release
function PrintTargets()
    print("Targets")
    for _, ply in pairs(GetTraitors()) do
        if ply:Alive() then print(ply:Nick() .. " ; " .. traitor_targets[ply:Nick()]) end
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

local function OverrideRadar()
    concommand.Add("ttt_radar_scan", RadarScan)
end
hook.Add("Initialize", "OverrideRadar", OverrideRadar)

end