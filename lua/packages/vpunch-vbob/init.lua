if CLIENT then
  local Punch
  install(gpm.LocatePackage('vpunch-local', 'https://github.com/toxidroma/vpunch-local'), true):Then(function(pkg)
    do
      local _base_0 = pkg:GetResult()
      local _fn_0 = _base_0.Punch
      Punch = function(...)
        return _fn_0(_base_0, ...)
      end
    end
  end)
  local sin, cos, random, Rand
  do
    local _obj_0 = math
    sin, cos, random, Rand = _obj_0.sin, _obj_0.cos, _obj_0.random, _obj_0.Rand
  end
  local Multipliers = { }
  local EnabledTypes = { }
  local _list_0 = {
    'slow',
    'normal',
    'run',
    'idle',
    'dmg',
    'land',
    'jump',
    'crouch',
    'uncrouch'
  }
  for _index_0 = 1, #_list_0 do
    local t = _list_0[_index_0]
    Multipliers[t] = CreateConVar("cl_vpvb_" .. tostring(t) .. "_mult", 1, FCVAR_ARCHIVE)
    EnabledTypes[t] = CreateConVar("cl_vpvb_" .. tostring(t) .. "_enabled", 1, FCVAR_ARCHIVE)
  end
  local Enabled = CreateConVar('cl_vpvb', 1, FCVAR_ARCHIVE, 'Controls whether viewpunch viewbob runs at all.')
  local EnabledSandbox = CreateConVar('cl_vpvb_sbox', 1, FCVAR_ARCHIVE, 'Controls whether viewpunch viewbob is active with the toolgun/physgun/camera equipped.')
  local enabled
  enabled = function(flavor, ply)
    if not (Enabled:GetBool()) then
      return false
    end
    local weapon = ply:GetActiveWeapon()
    if weapon:IsValid() then
      local _exp_0 = weapon:GetClass()
      if 'gmod_tool' == _exp_0 or 'weapon_physgun' == _exp_0 or 'gmod_camera' == _exp_0 then
        if not (EnabledSandbox:GetBool()) then
          return false
        end
      end
    end
    if not (EnabledTypes[flavor]:GetBool()) then
      return false
    end
    if ply:GetMoveType() == MOVETYPE_NOCLIP then
      return false
    end
    return true
  end
  local detectFlavor
  detectFlavor = function(ply)
    local flavor
    do
      local speed = ply:GetMaxSpeed()
      local midpoint_slow = ply:GetWalkSpeed() + ply:GetSlowWalkSpeed()
      local midpoint_fast = ply:GetWalkSpeed() + ply:GetRunSpeed()
      midpoint_slow = midpoint_slow / 2
      midpoint_fast = midpoint_fast / 2
      if speed <= midpoint_slow then
        flavor = 'slow'
      elseif speed >= midpoint_fast then
        flavor = 'run'
      else
        flavor = 'normal'
      end
    end
    return flavor
  end
  local logger = _PKG:GetLogger()
  hook.Add('PlayerFootstep', tostring(_PKG), function(ply, pos, foot, snd, vol, rf, jump)
    if not (ply == LocalPlayer()) then
      return 
    end
    local angle = Angle()
    do
      local flavor = detectFlavor(ply)
      local mult = Multipliers[flavor]:GetFloat()
      local side
      local _exp_0 = foot
      if 0 == _exp_0 then
        side = 1
      elseif 1 == _exp_0 then
        side = -1
      end
      logger:Debug("PlayerFootstep: " .. tostring(speed) .. ", " .. tostring(flavor) .. ", " .. tostring(side) .. ", " .. tostring(mult))
      if ply:KeyDown(IN_FORWARD) then
        angle = angle + Angle(2, side, side)
      end
      if ply:KeyDown(IN_BACK) then
        angle = angle + Angle(-2, side, side)
      end
      if ply:KeyDown(IN_MOVELEFT) then
        angle = angle + Angle(side, side, -2)
      end
      if ply:KeyDown(IN_MOVERIGHT) then
        angle = angle + Angle(side, side, 2)
      end
      angle = angle * (function()
        if enabled(flavor, ply) then
          local _exp_1 = flavor
          if 'slow' == _exp_1 then
            return mult * .2
          elseif 'normal' == _exp_1 then
            return mult * .3
          elseif 'run' == _exp_1 then
            return mult * .5
          end
        else
          return 0
        end
      end)()
      if (ply:KeyPressed(IN_JUMP) or jumped) and enabled('jump', ply) then
        angle = angle + Angle(Multipliers.jump:GetFloat() * -3, 0, 0)
      end
    end
    if not (angle:IsZero()) then
      Punch(angle)
    end
    return nil
  end)
  hook.Add('OnPlayerHitGround', tostring(_PKG), function(ply, inWater, onFloater, speed)
    if not (ply == LocalPlayer()) then
      return 
    end
    if not (enabled('land', ply)) then
      return 
    end
    local mult = Multipliers.land:GetFloat()
    logger:Debug("OnPlayerHitGround: " .. tostring(speed) .. ", " .. tostring(mult))
    local div
    if ply:KeyDown(IN_DUCK) then
      div = 80
    else
      div = 40
    end
    Punch(Angle(speed / div * mult * .5, 0, 0))
    return nil
  end)
  hook.Add('EntityTakeDamage', tostring(_PKG), function(victim, dmginfo)
    if not (victim == LocalPlayer()) then
      return 
    end
    if not (enabled('dmg', victim)) then
      return 
    end
    local mult = Multipliers.dmg:GetFloat() * .5
    logger:Debug("EntityTakeDamage: " .. tostring(mult))
    local sting
    sting = function()
      return random(3, 3) * mult
    end
    Punch(Angle(sting(), sting(), sting()))
    return nil
  end)
  local CrouchWatch = false
  hook.Add('Tick', tostring(_PKG), function()
    local ply = LocalPlayer()
    if not (ply.KeyDown) then
      return 
    end
    if not (ply:OnGround()) then
      return 
    end
    local crouching = ply:Crouching()
    if not (CrouchWatch == crouching) then
      CrouchWatch = crouching
      logger:Debug("Tick (vp-vb crouch): " .. tostring(CrouchWatch) .. ", " .. tostring(crouching) .. ", " .. tostring(mult))
      local mult
      if crouching then
        if not (enabled('crouch', ply)) then
          return 
        end
        mult = Multipliers.crouch:GetFloat()
      else
        if not (enabled('uncrouch', ply)) then
          return 
        end
        mult = -Multipliers.uncrouch:GetFloat()
      end
      Punch(Angle(1 * mult, random(-1, 1) * mult, random(-1, 1) * mult))
    end
    return nil
  end)
  local NextNoise = CurTime()
  local Sway = Angle()
  local SwayLast = Sway
  hook.Add('Think', tostring(_PKG), function()
    local ply = LocalPlayer()
    if ply:InVehicle() then
      return 
    end
    if enabled('idle', ply) then
      local multIdle = Multipliers.idle:GetFloat()
      SwayLast = Sway
      Sway = Angle(cos(CurTime() / .9) / 3 * multIdle, sin(CurTime() / .8) / 3.6 * multIdle, cos(CurTime() / .5) / 3.3 * multIdle)
      local eyeAngs = ply:EyeAngles() - SwayLast
      ply:SetEyeAngles(eyeAngs + Sway)
    end
    if CurTime() >= NextNoise then
      NextNoise = CurTime() + .04242
      local flavor = detectFlavor(ply)
      local multMove = Multipliers[flavor]:GetFloat()
      multMove = multMove * (function()
        if enabled(flavor, ply) then
          local _exp_0 = flavor
          if 'slow' == _exp_0 then
            return .3
          elseif 'normal' == _exp_0 then
            return .5
          elseif 'run' == _exp_0 then
            return .65
          else
            return 0
          end
        end
      end)()
      if not (multMove <= 0) then
        do
          if ply:KeyDown(IN_FORWARD) then
            Punch((Angle(Rand(0, .2), Rand(-.2, .2), 0)) * multMove)
            if ply:KeyDown(IN_SPEED) then
              Punch((Angle(Rand(0, 1.5), Rand(-.2, .2), Rand(-.2, .2))) * multMove)
            end
          end
          if ply:KeyDown(IN_MOVELEFT) then
            Punch((Angle(Rand(0, .2), Rand(-.2, .2), Rand(0, -.3))) * multMove)
            if ply:KeyDown(IN_SPEED) then
              Punch((Angle(Rand(0, .5), Rand(-.2, .2), Rand(0, -.6))) * multMove)
            end
          end
          if ply:KeyDown(IN_MOVERIGHT) then
            Punch((Angle(Rand(0, .2), Rand(-.2, .2), Rand(0, .3))) * multMove)
            if ply:KeyDown(IN_SPEED) then
              Punch((Angle(Rand(0, .5), Rand(-.2, .2), Rand(0, .6))) * multMove)
            end
          end
          if ply:KeyDown(IN_BACK) then
            Punch((Angle(Rand(-.2, .2), Rand(-.2, .2), 0)) * multMove)
            if ply:KeyDown(IN_SPEED) then
              Punch((Angle(Rand(-.5, .5), Rand(-.2, .2), Rand(-.2, .2))) * multMove)
            end
          end
        end
      end
    end
    return nil
  end)
end
return nil
