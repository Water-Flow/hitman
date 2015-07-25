if SERVER then
local commsrange = 1024
local loc_voice

local function inrange(p1, p2)
    return (not loc_voice:GetBool()) or (p2:GetPos():DistToSqr(p1:GetPos()) <= commsrange*commsrange)
end

local function RadioCommand(ply, cmd, args)
   if IsValid(ply) and ply:IsTerror() and #args == 2 then
      local msg_name = args[1]
      local msg_target = args[2]

      local name = ""
      local rag_name = nil

      if tonumber(msg_target) then
         -- player or corpse ent idx
         local ent = Entity(tonumber(msg_target))
         if IsValid(ent) then
            if ent:IsPlayer() then
               name = ent:Nick()
            elseif ent:GetClass() == "prop_ragdoll" then
               name = LANG.NameParam("quick_corpse_id")
               rag_name = CORPSE.GetPlayerNick(ent, "A Terrorist")
            end
         end

         msg_target = ent
      else
         -- lang string
         name = LANG.NameParam(msg_target)
      end

      if hook.Call("TTTPlayerRadioCommand", GAMEMODE, ply, msg_name, msg_target) then
         return
      end

      net.Start("TTT_RadioMsg")
         net.WriteEntity(ply)
         net.WriteString(msg_name)
         net.WriteString(name)
         if rag_name then
            net.WriteString(rag_name)
         end

	  local receivers = {}
	  for _,v in pairs(player.GetAll()) do if inrange(ply, v) then table.insert(receivers, v) end end
      net.Send(receivers)
   end
end

local function OverrideComms()
    loc_voice = GetConVar( "ttt_locational_voice" ) 
	concommand.Add("_ttt_radio_send", RadioCommand)
    function GAMEMODE:PlayerCanSeePlayersChat(text, team_only, listener, speaker)
        if (not IsValid(listener)) then return false end
    	if (not IsValid(speaker)) then
    		if isentity(s) then
    			return true
    		else
    			return false
    		end
    	end
    
    	local sTeam = speaker:Team() == TEAM_SPEC
    	local lTeam = listener:Team() == TEAM_SPEC
    
    	if (GetRoundState() != ROUND_ACTIVE) or   -- Round isn't active
    	(not GetConVar("ttt_limit_spectator_chat"):GetBool()) or   -- Spectators can chat freely
    	(not DetectiveMode()) or   -- Mumbling
    	(not sTeam and ((team_only and not speaker:IsSpecial()) or (not team_only and (speaker:GetRole() == ROLE_DETECTIVE or inrange(listener,speaker) )))) or   -- If someone alive talks (and not a special role in teamchat's case)
    	(not sTeam and team_only and speaker:GetRole() == listener:GetRole()) or
    	(sTeam and lTeam) then   -- If the speaker and listener are spectators
    	   return true
    	end
    
    	return false
    end
    
    function GAMEMODE:PlayerCanHearPlayersVoice(listener, speaker)
       -- Enforced silence
       if mute_all then
          return false, false
       end
    
       if (not IsValid(speaker)) or (not IsValid(listener)) or (listener == speaker) then
          return false, false
       end
    
       -- limited if specific convar is on, or we're in detective mode
       local limit = DetectiveMode() or GetConVar("ttt_limit_spectator_voice"):GetBool()
    
       -- Spectators should not be heard by living players during round
       if speaker:IsSpec() and (not listener:IsSpec()) and limit and GetRoundState() == ROUND_ACTIVE then
          return false, false
       end
    
       -- Specific mute
       if listener:IsSpec() and listener.mute_team == speaker:Team() then
          return false, false
       end
    
       -- Specs should not hear each other locationally
       if speaker:IsSpec() and listener:IsSpec() then
          return true, false
       end
    
       -- Traitors "team"chat by default, non-locationally
       if speaker:IsActiveTraitor() and !speaker.traitor_gvoice then
          return listener:IsActiveTraitor(), false
       end
    
       return inrange(listener,speaker), (loc_voice:GetBool() and GetRoundState() != ROUND_POST)
    end

end
hook.Add("Initialize", "OverrideComms", OverrideComms)

end