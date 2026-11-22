include("shared.lua")

--- Degrees per second the minigun turns sideways and up or down, and its turning limits.
local MINIGUN_YAW_RATE = 360
local MINIGUN_PITCH_RATE = 180
local MINIGUN_YAW_MIN, MINIGUN_YAW_MAX = -90, 90
local MINIGUN_PITCH_MIN, MINIGUN_PITCH_MAX = -45, 45

--- Share of the angle between the minigun and its target its goal moves by on every original think.
local MINIGUN_AIM_SHARE = 0.5

--- How fast the head closes in on its aim, the fewest degrees per second it turns by, and its turning limits.
local CANNON_AIM_SPEED = 16
local CANNON_AIM_MIN_RATE = 50
local CANNON_YAW_MIN, CANNON_YAW_MAX = -37.82, 45.34
local CANNON_PITCH_MIN, CANNON_PITCH_MAX = -30.3, 49.8

--- Length of one original think tick in seconds.
local THINK_TICK = 0.1

--- How fast the direction the legs walk in follows the movement, per second, and the slowest speed it still follows at.
local MOVE_YAW_RESPONSE = 8
local MOVE_YAW_MIN_SPEED = 20

--- Box around the entity's origin the model is drawn within: the legs reach far below the body, and the model's origin lies high above it while crouched.
local RENDER_MINS = Vector(-600, -600, -600)
local RENDER_MAXS = Vector(600, 600, 400)

--- Point above the body, relative to the entity, the third person camera orbits.
local THIRDPERSON_PIVOT = Vector(0, 0, 60)

--- Distance of the third person camera from its pivot before the pilot zooms, and how far it rises above the aim as a share of that distance.
local THIRDPERSON_RADIUS = 325
local THIRDPERSON_LIFT = 0.15

--- Share of its distance the third person camera moves back out by per second once a wall no longer blocks it.
local THIRDPERSON_EASE_OUT = 1.5

--- Box the third person camera keeps clear of walls with.
local THIRDPERSON_HULL_MINS = Vector(-4, -4, -4)
local THIRDPERSON_HULL_MAXS = Vector(4, 4, 4)

function ENT:OnSpawn()
    self:SetIK(true)
    self:SetRenderBounds(RENDER_MINS, RENDER_MAXS)
end

--- Places the model as the original's: its origin where the server keeps the original's origin, the stand height above the ground, and its body lowered onto the entity's origin, the middle of the physics body, by the body height pose parameter. The height is worked out from where the entity is on this frame, so that the feet stay on the ground however the body moves.
function ENT:PlaceModel()
    local height = math.Clamp(self.ModelHeight - (self:GetSkeletonZ() - self:LocalToWorld(vector_origin).z), 0, self.ModelHeight)
    local renderOrigin = self:LocalToWorld(Vector(0, 0, self:GetSkeletonOffset(height)))

    self:SetRenderOrigin(renderOrigin)
    self:SetPoseParameter("body_height", height)

    if ( height == self.modelHeight and renderOrigin == self.modelOrigin ) then return end

    self.modelHeight = height
    self.modelOrigin = renderOrigin

    self:InvalidateBoneCache()
end

function ENT:PreDraw(flags)
    self:PlaceModel()

    return true
end

function ENT:PreDrawTranslucent(flags)
    self:PlaceModel()

    return true
end

--- Returns the point the minigun turns to on this client: the local pilot's own crosshair, or the aim the server reports.
---@return Vector|nil aimPos
function ENT:GetClientMinigunAimPos()
    if ( self:GetDriver() == LocalPlayer() ) then return self:GetEyeTrace().HitPos end

    local aimPos = self:GetMinigunAimPos()
    if ( aimPos:IsZero() ) then return nil end

    return aimPos
end

--- Returns the point the cannon turns to on this client while it charges.
---@return Vector aimPos
function ENT:GetClientCannonAimPos()
    if ( self:GetDriver() == LocalPlayer() ) then return self:GetEyeTrace().HitPos end

    return self:GetCannonHitPos()
end

--- Turns the minigun on every frame as the server does on its think, from CStriderMinigun::AimAtPoint.
---@param anim table Client animation state.
---@param deltatime number
function ENT:AnimMinigun(anim, deltatime)
    local aimPos = self:GetClientMinigunAimPos()
    local base = self:GetStriderAttachment("MiniGunBase")

    if ( aimPos and base ) then
        local localAngles = WorldToLocal(aimPos, angle_zero, base.Pos, base.Ang):Angle()
        local share = 1 - (1 - MINIGUN_AIM_SHARE) ^ (deltatime / THINK_TICK)

        anim.minigunPitchGoal = math.Clamp(anim.minigunPitchGoal + share * math.NormalizeAngle(localAngles.p), MINIGUN_PITCH_MIN, MINIGUN_PITCH_MAX)
        anim.minigunYawGoal = math.Clamp(anim.minigunYawGoal - share * math.NormalizeAngle(localAngles.y), MINIGUN_YAW_MIN, MINIGUN_YAW_MAX)
    end

    anim.minigunYaw = math.Approach(anim.minigunYaw, anim.minigunYawGoal, MINIGUN_YAW_RATE * deltatime)
    anim.minigunPitch = math.Approach(anim.minigunPitch, anim.minigunPitchGoal, MINIGUN_PITCH_RATE * deltatime)
end

--- Turns the head towards the cannon's aim on every frame while it charges, from CNPC_Strider::AimCannonAt.
---@param anim table Client animation state.
---@param deltatime number
function ENT:AnimCannon(anim, deltatime)
    if ( !self:GetCannonCharging() ) then
        anim.bCannonCharging = false

        return
    end

    if ( !anim.bCannonCharging ) then
        anim.bCannonCharging = true
        anim.cannonYaw = 0
        anim.cannonPitch = 0
    end

    local gun = self:GetStriderAttachment("BigGun")
    if ( !gun ) then return end

    local localAngles = WorldToLocal(self:GetClientCannonAimPos(), angle_zero, gun.Pos, gun.Ang):Angle()
    local yawDiff = math.NormalizeAngle(localAngles.y)
    local pitchDiff = math.NormalizeAngle(localAngles.p)
    local yawStep = math.max(math.abs(CANNON_AIM_SPEED * yawDiff), CANNON_AIM_MIN_RATE) * deltatime
    local pitchStep = math.max(math.abs(CANNON_AIM_SPEED * pitchDiff), CANNON_AIM_MIN_RATE) * deltatime

    anim.cannonYaw = math.Clamp(math.Approach(anim.cannonYaw, anim.cannonYaw + yawDiff, yawStep), CANNON_YAW_MIN, CANNON_YAW_MAX)
    anim.cannonPitch = math.Clamp(math.Approach(anim.cannonPitch, anim.cannonPitch + pitchDiff, pitchStep), CANNON_PITCH_MIN, CANNON_PITCH_MAX)
end

--- Lets the legs walk in the direction the strider moves.
---@param anim table Client animation state.
---@param deltatime number
function ENT:AnimMoveYaw(anim, deltatime)
    local velocity = self:GetVelocity()
    velocity.z = 0

    if ( velocity:LengthSqr() < MOVE_YAW_MIN_SPEED * MOVE_YAW_MIN_SPEED ) then return end

    local localVelocity = WorldToLocal(velocity, angle_zero, vector_origin, Angle(0, self:GetAngles().y, 0))
    local moveYaw = math.deg(math.atan2(localVelocity.y, localVelocity.x))

    anim.moveYaw = math.ApproachAngle(anim.moveYaw, moveYaw, math.abs(math.AngleDifference(moveYaw, anim.moveYaw)) * math.min(MOVE_YAW_RESPONSE * deltatime, 1))
end

--- Places the model and animates the minigun, the head and the legs' walking direction on every frame, so that they move smoothly instead of in the steps of the server's think and the network.
function ENT:AnimateStrider()
    local deltatime = RealFrameTime()
    local anim = self.striderAnim

    if ( !anim ) then
        anim = {
            minigunYaw = 0,
            minigunPitch = 0,
            minigunYawGoal = 0,
            minigunPitchGoal = 0,
            cannonYaw = 0,
            cannonPitch = 0,
            moveYaw = 0,
        }

        self.striderAnim = anim
    end

    self:PlaceModel()
    self:ApplyAnimPoses(anim)
    self:AnimMinigun(anim, deltatime)
    self:AnimCannon(anim, deltatime)
    self:AnimMoveYaw(anim, deltatime)
    self:ApplyAnimPoses(anim)
end

--- Sets the pose parameters the client animates and rebuilds the bones from them. The server networks its own values of the same pose parameters, which overwrite the client's between frames, so the client puts its own back before it reads an attachment to aim from.
---@param anim table Client animation state.
function ENT:ApplyAnimPoses(anim)
    self:SetPoseParameter("minigunYaw", anim.minigunYaw)
    self:SetPoseParameter("minigunPitch", anim.minigunPitch)
    self:SetPoseParameter("yaw", anim.cannonYaw)
    self:SetPoseParameter("pitch", anim.cannonPitch)
    self:SetPoseParameter("move_yaw", anim.moveYaw)
    self:InvalidateBoneCache()
end

function ENT:OnFrame()
    self:AnimateStrider()
end

--- Returns whether the third person camera may pass through an entity: it stops only at the world and solid map entities, as the LVS camera does.
---@param ent Entity
---@return boolean bCollide
local function ThirdPersonCameraFilter(ent)
    local class = ent:GetClass()

    return !class:StartWith("prop_physics") and !class:StartWith("prop_dynamic") and !class:StartWith("prop_ragdoll") and !ent:IsVehicle() and !class:StartWith("gmod_") and !class:StartWith("lvs_") and !class:StartWith("player") and !ent.LVS
end

--- Rides on the minigun in first person, looking down its barrel from just above it.
---@param ply Player
---@param pos Vector
---@param fov number
---@return table view
function ENT:CalcViewFirstPerson(ply, pos, fov)
    local angles = ply:EyeAngles()
    local base = self:GetStriderAttachment("MiniGunBase")

    return {
        origin = base and self:GetMinigunViewPos(base.Pos, angles) or pos,
        angles = angles,
        fov = fov,
        drawviewer = false,
    }
end

--- Orbits a point above the strider's body in third person, high enough to see over it and close enough to keep it large on screen. A wall pulls the camera in at once and lets it ease back out, so that it does not jump back and forth while the strider walks past buildings.
---@param ply Player
---@param fov number
---@param pod Entity
---@return table view
function ENT:CalcViewThirdPerson(ply, fov, pod)
    local angles = ply:EyeAngles()
    local pivot = self:LocalToWorld(THIRDPERSON_PIVOT)
    local radius = THIRDPERSON_RADIUS * (1 + pod:GetCameraDistance())
    local targetPos = pivot - angles:Forward() * radius + angles:Up() * radius * (THIRDPERSON_LIFT + pod:GetCameraHeight())

    local trace = util.TraceHull({
        start = pivot,
        endpos = targetPos,
        filter = ThirdPersonCameraFilter,
        mins = THIRDPERSON_HULL_MINS,
        maxs = THIRDPERSON_HULL_MAXS,
    })

    local fraction = trace.StartSolid and 1 or trace.Fraction
    local eased = self.thirdPersonFraction or fraction

    if ( fraction < eased ) then
        eased = fraction
    else
        eased = math.Approach(eased, fraction, THIRDPERSON_EASE_OUT * RealFrameTime())
    end

    self.thirdPersonFraction = eased

    return {
        origin = LerpVector(eased, pivot, targetPos),
        angles = angles,
        fov = fov,
        drawviewer = true,
    }
end

--- Rides on the minigun in first person and orbits the strider in third person.
function ENT:CalcViewDriver(ply, pos, angles, fov, pod)
    if ( !pod:GetThirdPersonMode() ) then
        self.thirdPersonFraction = nil

        return self:CalcViewFirstPerson(ply, pos, fov)
    end

    return self:CalcViewThirdPerson(ply, fov, pod)
end

--- Draws a square crosshair with a shadow.
---@param pos2D table Screen position.
---@param color Color|nil
function ENT:PaintCrosshairSquare(pos2D, color)
    local size = 20

    for pass = 1, 2 do
        local x = pos2D.x + (pass == 1 and 1 or 0)
        local y = pos2D.y + (pass == 1 and 1 or 0)

        if ( pass == 1 ) then
            surface.SetDrawColor(0, 0, 0, 80)
        elseif ( color ) then
            surface.SetDrawColor(color.r, color.g, color.b, color.a)
        else
            surface.SetDrawColor(255, 255, 255, 255)
        end

        surface.DrawLine(x - size, y + size, x - size * 0.5, y + size)
        surface.DrawLine(x + size, y + size, x + size * 0.5, y + size)
        surface.DrawLine(x - size, y + size, x - size, y + size * 0.5)
        surface.DrawLine(x - size, y - size, x - size, y - size * 0.5)
        surface.DrawLine(x + size, y + size, x + size, y + size * 0.5)
        surface.DrawLine(x + size, y - size, x + size, y - size * 0.5)
        surface.DrawLine(x - size, y - size, x - size * 0.5, y - size)
        surface.DrawLine(x + size, y - size, x + size * 0.5, y - size)
    end

    self:PaintCrosshairCenter(pos2D, color)
end
