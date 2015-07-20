if SERVER then
local commsrange = 1024
local loc_voice

local function inrange(p1, p2)
    return (not loc_voice:GetBool()) or (p2:GetPos():DistToSqr(p1:GetPos()) <= commsrange*commsrange)
end

local function OverrideComms()
    loc_voice = GetConVar( "ttt_locational_voice" ) 
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
       if speaker:IsActiveTraitor() then
          if speaker.traitor_gvoice then
             return true, loc_voice:GetBool()
          elseif listener:IsActiveTraitor() then
             return true, false
          else
             -- unless traitor_gvoice is true, normal innos can't hear speaker
             return false, false
          end
       end
    
       return inrange(listener,speaker), (loc_voice:GetBool() and GetRoundState() != ROUND_POST)
    end

end
hook.Add("Initialize", "OverrideComms", OverrideComms)

end