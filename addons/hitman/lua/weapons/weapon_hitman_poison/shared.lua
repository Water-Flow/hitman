if SERVER then
   AddCSLuaFile( "shared.lua" )
   resource.AddFile("materials/hitman/icon_hitman_poison.png")
end
 
SWEP.HoldType           = "pistol"
 
if CLIENT then
   SWEP.PrintName           = "Poison Dart"
   SWEP.Author              = "TTT"
   SWEP.Slot                = 6
   SWEP.SlotPos         = 0
 
   SWEP.EquipMenuData = {
      type="Weapon",
      --model="models/weapons/w_pist_usp.mdl",
      desc="After 10 seconds a poison slowly kills the target.\nClose Range only."
   };
 
   SWEP.Icon = "hitman/icon_hitman_poison.png"
end
 
SWEP.Base = "weapon_tttbase"
SWEP.Primary.Recoil = 1
SWEP.Primary.Damage = 1
SWEP.Primary.Delay = 0.3
SWEP.Primary.Cone = 0.0
SWEP.Primary.ClipSize = 2
SWEP.Primary.Automatic = true
SWEP.Primary.DefaultClip = 1
SWEP.Primary.ClipMax = 1
SWEP.Primary.Ammo = "" --"Pistol"
SWEP.Primary.Range = 200
SWEP.AdminSpawnable = true
 
SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR} -- only traitors can buy
--SWEP.WeaponID = AMMO_SIPISTOL
 
SWEP.AmmoEnt = "" --"item_ammo_pistol_ttt"
 
SWEP.IsSilent = true
SWEP.LimitedStock = false
 
SWEP.ViewModel          = "models/weapons/v_crossbow.mdl"
SWEP.WorldModel         = "models/weapons/w_pist_usp.mdl"
 
SWEP.Primary.Sound = nil
SWEP.IronSightsPos = Vector( 4.48, -4.34, 2.75)
SWEP.IronSightsAng = Vector(-0.5, 0, 0)

 
function SWEP:Deploy()
   self.Weapon:SendWeaponAnim(ACT_VM_DRAW_SILENCED)
   return true
end
 
--[[-- We were bought as special equipment, and we have an extra to give
function SWEP:WasBought(buyer)
   if IsValid(buyer) then -- probably already self.Owner
      buyer:GiveAmmo( 16, "Pistol" )
   end
end]]
function SWEP:PrimaryAttack(worldsnd)
   local owner = self.Owner
   local weapon = self.Weapon
 
   self.Weapon:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
   self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
 
   if not self:CanPrimaryAttack() then return end
    
   if not worldsnd then
      --self.Weapon:EmitSound( self.Primary.Sound , 50, 100)
   else
      --WorldSound(self.Primary.Sound, self:GetPos(), 50, 100)
   end
 
 
   --self:ShootBullet( self.Primary.Damage, self.Primary.Recoil, self.Primary.NumShots, self.Primary.Cone, self.Doors, self.Force, self.TracerName )
   if SERVER then
       if owner:GetEyeTrace().HitNonWorld and owner:GetEyeTrace().Entity:IsPlayer() and (owner:GetEyeTrace().Entity:GetPos()-owner:GetPos()):LengthSqr() < 200*200 then
      
            local en = self.Owner:GetEyeTrace().Entity
            local uni = en:UniqueID()
            --en:EmitSound("ambient/voices/citizen_beaten" .. math.random(1,5) .. ".wav",500,100)
            timer.Create(uni .. "poisondart_delay", 10, 1, function()
                timer.Create(uni .. "poisondart", 5, 0, function()
                    if IsValid(en) and en:IsTerror() then
                        if IsValid(owner) then
                           en:TakeDamage(10,owner,weapon)
                        else
                           en:TakeDamage(10,weapon,weapon)
                        end
                    else
                    timer.Destroy(uni .. "poisondart")
                    end
                end)
            end)
			self:TakePrimaryAmmo( 1 )
       end
   end
    
   if not IsValid(owner) or owner:IsNPC() or (not owner.ViewPunch) then return end
    
   --self.Owner:ViewPunch( Angle( math.Rand(-0.2,-0.1) * self.Primary.Recoil, math.Rand(-0.1,0.1) *self.Primary.Recoil, 0 ) )
    
   if ( (game.SinglePlayer() and SERVER) or CLIENT ) then
      self.Weapon:SetNetworkedFloat( "LastShootTime", CurTime() )
   end
 
end

function SWEP:SecondaryAttack() return end

function resetpoison()
    for _,v in pairs(player.GetAll()) do
	    timer.Destroy(v:UniqueID() .. "poisondart")
	    timer.Destroy(v:UniqueID() .. "poisondart_delay")
	end
end
hook.Add("TTTPrepareRound", "resetpoison", resetpoison)