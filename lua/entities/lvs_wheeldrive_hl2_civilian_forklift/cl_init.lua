include("shared.lua")

--- Turns the steering wheel and moves the speedometer needle of the model.
function ENT:UpdatePoseParameters(steer, speed_kmh, engine_rpm, throttle, brake, handbrake, clutch, gear, temperature, fuel, oil, ammeter)
    self:SetPoseParameter("vehicle_steer", steer)
    self:SetPoseParameter("vehicle_guage", speed_kmh * 0.02)
end
