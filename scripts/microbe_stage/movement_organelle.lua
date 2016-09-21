-- Enables a microbe to move and turn
class 'MovementOrganelle' (Organelle)

-- TODO make this externally configurable for easier balancing
MovementOrganelle.config = {
    flagellum = {force=10, torque=200, mpCost=25},
    cilia = {force=2,torque=1000, mpCost=10}
}

Organelle.mpCosts.flagellum = MovementOrganelle.config.flagellum.mpCost
Organelle.mpCosts.cilia =  MovementOrganelle.config.cilia.mpCost

-- Constructor
--
-- @param force
--  The force this organelle can exert to move a microbe
--
-- @param torque
--  The torque this organelle can exert to turn a microbe
function MovementOrganelle:__init(force, torque)
    Organelle.__init(self)
    self.energyMultiplier = 0.025
    self.force = force
    self.torque = torque
    self.backwards_multiplier = 0
	self.x = 0
	self.y = 0
	self.angle = 0
    self.movingTail = false
end

function MovementOrganelle:onAddedToMicrobe(microbe, q, r, rotation)  
    Organelle.onAddedToMicrobe(self, microbe, q, r, rotation)
end

function MovementOrganelle:load(storage)
    Organelle.load(self, storage)
    self.energyMultiplier = storage:get("energyMultiplier", 0.025)
    self.force = storage:get("force", Vector3(0,0,0))
    self.torque = storage:get("torque", Vector3(0,0,0))
end

function MovementOrganelle:storage()
    local storage = Organelle.storage(self)
    storage:set("energyMultiplier", self.energyMultiplier)
    storage:set("force", self.force)
    storage:set("torque", self.torque)
    return storage
end

function MovementOrganelle:_moveMicrobe(microbe, milliseconds)
    local direction = microbe.microbe.movementDirection
    local forceMagnitude = self.force:dotProduct(direction)
    if forceMagnitude > 0 then
        if direction:isZeroLength() or self.force:isZeroLength()  then
            self.movingTail = false
            self.sceneNode:setAnimationSpeed(0.25)
            return
        end 
        self.movingTail = true
        self.sceneNode:setAnimationSpeed(1.3)
        
        local energy = math.abs(self.energyMultiplier * forceMagnitude * milliseconds / 1000)
        local availableEnergy = microbe:takeCompound(CompoundRegistry.getCompoundId("atp"), energy)
        if availableEnergy < energy then
            forceMagnitude = sign(forceMagnitude) * availableEnergy * 1000 / milliseconds / self.energyMultiplier
            self.movingTail = false
            self.sceneNode:setAnimationSpeed(0.25)
        end
        local impulseMagnitude = microbe.microbe.movementFactor * milliseconds * forceMagnitude / 1000
        local impulse = impulseMagnitude * direction
        local a = microbe.sceneNode.transform.orientation * impulse
        microbe.rigidBody:applyCentralImpulse(
            microbe.sceneNode.transform.orientation * impulse
        )
    else 
        if self.movingTail then
            self.movingTail = false
            self.sceneNode:setAnimationSpeed(0.25)
        end
    end
end


function MovementOrganelle:_turnMicrobe(microbe)
    if self.torque == 0 then
        return
    end
    local transform = microbe.sceneNode.transform
    local targetDirection = microbe.microbe.facingTargetPoint - transform.position
    local localTargetDirection = transform.orientation:Inverse() * targetDirection
    localTargetDirection.z = 0 -- improper fix. facingTargetPoint somehow gets a non-zero z value.
    assert(localTargetDirection.z < 0.01, "Microbes should only move in the 2D plane with z = 0")
    local alpha = math.atan2(
        -localTargetDirection.x,
        localTargetDirection.y
    )
    if math.abs(math.deg(alpha)) > 1 then
        microbe.rigidBody:applyTorque(
            Vector3(0, 0, self.torque * alpha * microbe.microbe.movementFactor)
        )
        microbe.soundSource:playSound("microbe-movement-turn")
    end
end


function MovementOrganelle:update(microbe, logicTime)
    local x, y = axialToCartesian(self.position.q, self.position.r)
    local membraneCoords = microbe.membraneComponent:getExternOrganellePos(x, y)
    local translation = Vector3(membraneCoords[1], membraneCoords[2], 0)
    self.organelleEntity.sceneNode.transform.position = translation - Vector3(x, y, 0)
    self.organelleEntity.sceneNode.transform:touch()

    self:_turnMicrobe(microbe)
    self:_moveMicrobe(microbe, logicTime)
end

-- Calculate the momentum of the movement organelle based on angle towards nucleus
function makeOrganelle(organelleData, config)
    local organelleX, organelleY = axialToCartesian(organelleData.q, organelleData.r)
    local nucleusX, nucleusY = axialToCartesian(0, 0)
    local deltaX = nucleusX - organelleX
    local deltaY = nucleusY - organelleY
    local dist = math.sqrt(deltaX^2 + deltaY^2) -- For normalizing vector
    local momentumX = deltaX / dist * config.force
    local momentumY = deltaY / dist * config.force
    local momentum = Vector3(momentumX, momentumY, 0.0)

    local flagellum = MovementOrganelle(momentum, config.torque)
    flagellum:addHex(0, 0)
    return flagellum
end

-- factory functions
function OrganelleFactory.make_flagellum(data)
    return makeOrganelle(data, MovementOrganelle.config.flagellum)
end

function OrganelleFactory.render_flagellum(data)
	local x, y = axialToCartesian(data.q, data.r)
	local translation = Vector3(-x, -y, 0)
	data.sceneNode[1].meshName = "flagellum.mesh"
	data.sceneNode[1].transform.position = translation
	data.sceneNode[1].transform.orientation = Quaternion(Radian(Degree(-90)), Vector3(0, 0, 1))

	data.sceneNode[2].transform.position = translation
	OrganelleFactory.setColour(data.sceneNode[2], data.colour)
end

function OrganelleFactory.sizeof_flagellum(data)
	return {{q=0, r=0}}
end

function OrganelleFactory.make_cilia(data)
    return makeOrganelle(data, MovementOrganelle.config.cilia)
end

function OrganelleFactory.render_cilia(data)
    OrganelleFactory.render_flagellum(data)
    data.sceneNode[1].transform.scale = Vector3(0.5, 0.5, 0.5)
end

OrganelleFactory.sizeof_cilia = OrganelleFactory.sizeof_flagellum
