import \Punch from install 'packages/vpunch-local', 'https://github.com/toxidroma/vpunch-local'
if CLIENT
    import sin, cos, random, Rand from math
    Multipliers     = {}
    EnabledTypes    = {}
    for t in *{'slow', 'normal', 'run', 
            'idle', 'dmg', 'land',
            'jump', 'crouch', 'uncrouch'}
        Multipliers[t] = CreateConVar "cl_vpvb_#{t}_mult", 1, FCVAR_ARCHIVE
        EnabledTypes[t] = CreateConVar "cl_vpvb_#{t}_enabled", 1, FCVAR_ARCHIVE
    Enabled = CreateConVar 'cl_vpvb', 1, FCVAR_ARCHIVE, 'Controls whether viewpunch viewbob runs at all.'
    EnabledSandbox = CreateConVar 'cl_vpvb_sbox', 1, FCVAR_ARCHIVE, 'Controls whether viewpunch viewbob is active with the toolgun/physgun/camera equipped.'

    enabled = (flavor, ply) ->
        return false if ply\GetMoveType! == MOVETYPE_NOCLIP
        return false unless Enabled\GetBool!
        weapon = ply\GetActiveWeapon!
        if weapon\IsValid!
            switch weapon\GetClass!
                when 'gmod_tool', 'weapon_physgun', 'gmod_camera'
                    return false unless EnabledSandbox\GetBool!
        return false unless EnabledTypes[flavor]\GetBool!
        true

    detectFlavor = (ply) ->
        local flavor
        with ply
            speed = \GetMaxSpeed!

            midpoint_slow = \GetWalkSpeed! + \GetSlowWalkSpeed!
            midpoint_fast = \GetWalkSpeed! + \GetRunSpeed!
            midpoint_slow /= 2
            midpoint_fast /= 2

            flavor = if speed <= midpoint_slow
                'slow'
            elseif speed >= midpoint_fast
                'run'
            else
                'normal'
        flavor

    logger = _PKG\GetLogger!

    hook.Add 'PlayerFootstep', tostring(_PKG), (ply, pos, foot, snd, vol, rf, jump) ->
        return unless ply == LocalPlayer!
        angle = Angle!
        with ply
            flavor  = detectFlavor ply

            mult    = Multipliers[flavor]\GetFloat!

            side = switch foot
                when 0 --left
                    1
                when 1 --right
                    -1

            logger\Debug "PlayerFootstep: #{speed}, #{flavor}, #{side}, #{mult}"

            angle += Angle 2, side, side if \KeyDown IN_FORWARD
            angle += Angle -2, side, side if \KeyDown IN_BACK
            angle += Angle side, side, -2 if \KeyDown IN_MOVELEFT
            angle += Angle side, side, 2 if \KeyDown IN_MOVERIGHT
            
            angle *= if enabled flavor, ply
                switch flavor
                    when 'slow'
                        mult * .2
                    when 'normal'
                        mult * .3
                    when 'run'
                        mult * .5
            else
                0

            if (\KeyPressed(IN_JUMP) or jumped) and enabled('jump', ply)
                angle += Angle Multipliers.jump\GetFloat!*-3, 0, 0
            
        Punch angle unless angle\IsZero!
        nil --preventing .moon's implicit return from making a busted hook

    hook.Add 'OnPlayerHitGround', tostring(_PKG), (ply, inWater, onFloater, speed) ->
        return unless ply == LocalPlayer!
        return unless enabled 'land', ply

        mult = Multipliers.land\GetFloat!

        logger\Debug "OnPlayerHitGround: #{speed}, #{mult}"

        div = if ply\KeyDown IN_DUCK
            80
        else
            40

        Punch Angle speed / div * mult * .5, 0, 0
        nil --preventing moon's implicit return from making a busted hook, again

    hook.Add 'EntityTakeDamage', tostring(_PKG), (victim, dmginfo) ->
        return unless victim == LocalPlayer!
        return unless enabled 'dmg', victim

        mult = Multipliers.dmg\GetFloat! * .5

        logger\Debug "EntityTakeDamage: #{mult}"

        sting = -> random(3,3)*mult
        Punch Angle sting!, sting!, sting!
        nil --you get it by now

    CrouchWatch       = false --say that three times fast
    --TODO: extension package that includes a hook which runs after detecting someone has 'crouched'
        --for those people who STILL use source's default crouch behavior, with the midair exploit bullshit
            --because a Tick hook for any potential situation you'd wanna check when someone crouches is godawful
    hook.Add 'Tick', tostring(_PKG), ->
        ply = LocalPlayer!
        return unless ply.KeyDown
        --so because crouch jumping exists at all, it's possible the below can run while you're in the air
            --as you might expect, this is stupid as hell and it looks horrible
            --even worse that you can alternate between crouched and not crouched INSTANTLY between ticks in midair
            --there are no words for how much i hate this, nor for how much i hate that the next line has to be written
        return unless ply\OnGround!
        crouching = ply\Crouching!
        unless CrouchWatch == crouching
            CrouchWatch = crouching
            logger\Debug "Tick (vp-vb crouch): #{CrouchWatch}, #{crouching}, #{mult}"

            mult = if crouching
                return unless enabled 'crouch', ply
                Multipliers.crouch\GetFloat!
            else
                return unless enabled 'uncrouch', ply
                -Multipliers.uncrouch\GetFloat! --negative pitch looks upward
            
            Punch Angle 1 * mult, random(-1,1)*mult, random(-1,1)*mult
        nil

    NextNoise   = CurTime!
    Sway        = Angle!
    SwayLast    = Sway
    hook.Add 'Think', tostring(_PKG), ->
        ply = LocalPlayer!
        return if ply\InVehicle!

        if enabled 'idle', ply
            multIdle = Multipliers.idle\GetFloat!

            SwayLast = Sway
            Sway = Angle cos(CurTime!/.9) / 3 * multIdle,
                sin(CurTime!/.8) / 3.6 * multIdle,
                cos(CurTime!/.5) / 3.3 * multIdle

            eyeAngs = ply\EyeAngles! - SwayLast
            ply\SetEyeAngles eyeAngs + Sway

        if CurTime! >= NextNoise
            NextNoise = CurTime! + .04242
        
            flavor = detectFlavor ply
            multMove = Multipliers[flavor]\GetFloat!
            multMove *= if enabled flavor, ply
                switch flavor
                    when 'slow'
                        .3
                    when 'normal'
                        .5
                    when 'run'
                        .65
            else
                0

            unless multMove <= 0
                with ply
                    if \KeyDown IN_FORWARD
                        Punch (Angle Rand(0, .2), Rand(-.2, .2), 0)*multMove
                        Punch (Angle Rand(0, 1.5), Rand(-.2, .2), Rand(-.2, .2))*multMove if \KeyDown IN_SPEED
                    if \KeyDown IN_MOVELEFT
                        Punch (Angle Rand(0, .2), Rand(-.2, .2), Rand(0, -.3))*multMove
                        Punch (Angle Rand(0, .5), Rand(-.2, .2), Rand(0, -.6))*multMove if \KeyDown IN_SPEED
                    if \KeyDown IN_MOVERIGHT
                        Punch (Angle Rand(0, .2), Rand(-.2, .2), Rand(0, .3))*multMove
                        Punch (Angle Rand(0, .5), Rand(-.2, .2), Rand(0, .6))*multMove if \KeyDown IN_SPEED
                    if \KeyDown IN_BACK
                        Punch (Angle Rand(-.2, .2), Rand(-.2, .2), 0)*multMove
                        Punch (Angle Rand(-.5, .5), Rand(-.2, .2), Rand(-.2, .2))*multMove if \KeyDown IN_SPEED
        nil

    --TODO: singleplayer compatibility by abusing the net library
        --which is gonna mean porting the UPLINK class from eclipse
nil