arena = {
	readyTimer = Timer:create(),
	waterCheckTimer = Timer:create(),
	projectileCreationTimer = Timer:create()
}
local waterCraftIDS = {
	[539] = true,
	[460] = true,
	[417] = true,
	[447] = true,
	[472] = true,
	[473] = true,
	[493] = true,
	[595] = true,
	[484] = true,
	[430] = true,
	[453] = true,
	[452] = true,
	[446] = true,
	[454] = true
}
local shootingForbiddenIDs = {
	[425] = true,
}
local disabledAddons = {
	["disable_anti_eat"] = true,
	["scriptloader_keys_forbidden"] = true
}
spectate = {}
enterKey = next(getBoundKeys("enter_exit"))
addEvent("onClientJoinArena", true)
addEvent("onClientLeaveArena", true)
addEvent("onClientPlayerJoinArena", true)
addEvent("onClientPlayerLeaveArena", true)
addEvent("onClientArenaStateChanging", true)
addEvent("onClientArenaMapStarting", true)
addEvent("onClientArenaSpawn", true)
addEvent("onClientArenaWasted", true)
addEvent("onClientArenaGridCountdown", true)
addEvent("onClientArenaNextmapChanged", true)
addEvent("onClientArenaRequestSpectateStart", true)
addEvent("onClientArenaRequestSpectateStop", true)
addEvent("onClientArenaRequestSpectateEnd", true)
addEvent("onClientArenaPlayerStateChange", true)
addEvent("onClientArenaSpawnProtectionStateChange", true)

addEventHandler("onClientJoinArena", resourceRoot,
function(data)
	-- Update synced data
	for i, v in pairs(data) do
		arena[i] = v
	end
	-- Addons
	for addon_index, addon_state in pairs(disabledAddons) do
		setElementData(localPlayer, addon_index, addon_state, false)
	end
	-- Gameplay functions
	setBlurLevel(0)
	setPedCanBeKnockedOffBike(localPlayer, false)
	setShootingEnabled(false)
	exports.core:setGhostmodeEnabled(arena.spawnProtectionEnabled)
	-- Handlers
	addEventHandler("onClientVehicleDamage", root, handleBurnDamage)
	addCommandHandler("suicide", requestKill)
	addCommandHandler("kill", requestKill)
	addEventHandler("onClientPreRender", root, cancelCameraDrop)
	-- Binds
	bindKey(enterKey, "down", "suicide")
	bindKey("b", "down", "manualspectate")
	bindKey("lshift", "down", doJump)
	-- UI stuff
	triggerEvent("radar:setVisible", localPlayer, true)
	triggerEvent("racehud:show", localPlayer, {state = data.state, mapName = data.mapInfo.mapName, nextMapName = data.nextMap, timeIsUpStartTick = getTickCount(), timeIsUpDuration = data.duration})
end)

addEventHandler("onClientLeaveArena", resourceRoot,
function()
	spectate.stop()
	-- Addons element data clear
	for addon_index, addon_state in pairs(disabledAddons) do
		setElementData(localPlayer, addon_index, nil, false)
	end
	-- Reset gameplay functions
	setPedCanBeKnockedOffBike(localPlayer, true)
	arena.waterCheckTimer:killTimer()
	arena.readyTimer:killTimer()
	gridCountdown(false)
	-- Handlers
	removeEventHandler("onClientVehicleDamage", root, handleBurnDamage)
	removeCommandHandler("suicide", requestKill)
	removeCommandHandler("kill", requestKill)
	removeEventHandler("onClientPreRender", root, cancelCameraDrop)
	-- Binds
	unbindKey(enterKey, "down", "suicide")
	unbindKey("b", "down", "manualspectate")
	unbindKey("lshift", "down", doJump)
	-- UI stuff
	triggerEvent("radar:setVisible", localPlayer, false)
	triggerEvent("racehud:hide", localPlayer)
	arena.timeIsUpStartTick = nil
	arena.timeIsUpTick = nil
end)

addEventHandler("onClientArenaStateChanging", resourceRoot,
function(currentState, newState, data)
	arena.state = newState and newState or arena.state
	if arena.state == "running" then
		arena.timeIsUpStartTick = getTickCount()
		arena.timeIsUpTick = arena.timeIsUpStartTick + data.duration
	else
		triggerEvent("onClientProjectionStateChange", localPlayer, false)
	end
end)

addEventHandler("onClientArenaMapStarting", resourceRoot,
function(mapInfo)
	arena.mapInfo = mapInfo
end)

function gridCountdown(countdown)
	if countdown == 0 then
		triggerEvent("racepickups:checkAllPickups", localPlayer)
		local vehicle = arena.vehicle or getPedOccupiedVehicle(localPlayer)
		if isElement(vehicle) then
			setElementFrozen(localPlayer, false)
			setElementFrozen(vehicle, false)
			setVehicleDamageProof(vehicle, false)
			setElementCollisionsEnabled(vehicle, true)
		end
	end
end
addEventHandler("onClientArenaGridCountdown", resourceRoot, gridCountdown)

addEventHandler("onClientArenaNextmapChanged", resourceRoot,
function(nextMap)
	arena.nextMap = nextMap or nil
end)

addEventHandler("onClientArenaSpawn", resourceRoot,
function(vehicle)
	arena.vehicle = vehicle
	spectate.stop()
	setCameraTarget(localPlayer)
	arena.readyTimer:setTimer(function()
		local cameraTarget = getCameraTarget()
		if isElement(cameraTarget) and cameraTarget == localPlayer and isPedInVehicle(localPlayer) then
			triggerServerEvent("onPlayerReady", localPlayer)
			removeVehicleNitro()
			fadeCamera(true)
			arena.readyTimer:killTimer()
		end
	end, 500, 0)
	arena.waterCheckTimer:setTimer(checkWater, 1000, 0)
	removeVehicleNitro()
	fixVehicle(arena.vehicle)
	toggleAllControls(true)
	triggerEvent("racepickups:updateVehicleWeapons", localPlayer)
end)

addEventHandler("onClientArenaWasted", resourceRoot,
function()
	spectate.start()
	arena.readyTimer:killTimer()
	arena.waterCheckTimer:killTimer()
	setShootingEnabled(false)
	triggerEvent("onClientProjectionStateChange", localPlayer, false)
end)

addEventHandler("onClientArenaSpawnProtectionStateChange", resourceRoot,
function(state)
	arena.spawnProtectionEnabled = state
	setShootingEnabled(not state)
	if not arena.spawnProtectionEnabled then
		triggerEvent("onClientProjectionStateChange", localPlayer, true)
	end
	exports.core:setGhostmodeEnabled(state)
end)

function spectate.start(...)
	exports.core:startSpectating(...)
end

addEventHandler("onClientArenaRequestSpectateStart", resourceRoot,
function()
	spectate.start(true)
end)

function spectate.stop(...)
	exports.core:stopSpectating(...)
end
addEventHandler("onClientArenaRequestSpectateStop", resourceRoot, spectate.stop)

addEventHandler("onClientArenaRequestSpectateEnd", resourceRoot,
function()
	exports.core:forcedStopSpectating()
end)

addEventHandler("onClientArenaPlayerStateChange", resourceRoot,
function(player, state)
	if player ~= localPlayer then
		if state == "alive" then
			setPlayerVisible(player, true)
		else
			setPlayerVisible(player, false)
		end
	end
end)

addEventHandler("onClientPlayerJoinArena", resourceRoot,
function(player)
	tableInsert(arena.players, player)
	if player == localPlayer then
		return
	end
	setPlayerVisible(player, false)
end)

addEventHandler("onClientPlayerLeaveArena", resourceRoot,
function(player)
	tableRemove(arena.players, player)
end)

function handleBurnDamage(attacker, weapon)
	if weapon == 37 then
		cancelEvent()
	end
end

function requestKill()
	if arena.state == "running" and not isPlayerDead(localPlayer) then
		triggerServerEvent("onRequestKillPlayer", localPlayer)
	end
end

function checkWater()
	if isElement(arena.vehicle) then
		if not waterCraftIDS[getElementModel(arena.vehicle)] then
			local x, y, z = getElementPosition(localPlayer)
			local waterZ = getWaterLevel(x, y, z)
			if waterZ and z < waterZ - 0.5 and not isPlayerDead(localPlayer) then
				if (isPlayerDead(localPlayer) and not training.stats.active) then
					return
				end
				setElementHealth(localPlayer, 0)
				triggerServerEvent("onRequestKillPlayer", localPlayer)
			end
		end
		if not getVehicleEngineState(arena.vehicle) then
			setVehicleEngineState(arena.vehicle, true)
		end
	end
end

function removeVehicleNitro()
	if isElement(arena.vehicle) then
		removeVehicleUpgrade(arena.vehicle, 1010)
	end
end

function setPlayerVisible(player, visible)
	if isElement(player) then
		local vehicle = getPedOccupiedVehicle(player)
		local visibleDimension = getElementDimension(localPlayer)
		if visible then
			setElementDimension(player, visibleDimension)
			if isElement(vehicle) then
				setElementDimension(vehicle, visibleDimension)
			end
		else
			visibleDimension = visibleDimension + 1
			setElementDimension(player, visibleDimension)
			if isElement(vehicle) then
				setElementDimension(vehicle, visibleDimension)
			end
		end
	end
end

function doShoot()
	if arena.projectileCreationTimer:isActive() then
		return
	end
	if isElement(arena.vehicle) and not shootingForbiddenIDs[getElementModel(arena.vehicle)] then
		local x, y, z = getElementPosition(arena.vehicle)
		local groundZ = getGroundPosition(x, y, z)
		local rX, rY, rZ = getElementRotation(arena.vehicle)
		if 1 > math.abs(groundZ - z) then
			z = groundZ + 1
		end
		x = x + 4 * math.cos(math.rad(rZ + 90))
		y = y + 4 * math.sin(math.rad(rZ + 90))
		createProjectile(arena.vehicle, 19, x, y, z, 1, nil)
		triggerEvent("onClientProjectionStateChange", localPlayer, false)
		arena.projectileCreationTimer:setTimer(function() triggerEvent("onClientProjectionStateChange", localPlayer, true) end, 3000, 1)
	end
end

function setShootingEnabled(enabled)
	arena.shootingEnabled = enabled and true or false
	if arena.shootingEnabled then
		if arena.boundKeys then
			for i, key in pairs(arena.boundKeys) do
				unbindKey(key[1], key[2], doShoot)
			end
		end
		arena.boundKeys = {}
		local vehicleFireKeys = getBoundKeys("vehicle_fire")
		local vehicleSecondaryFireKeys = getBoundKeys("vehicle_secondary_fire")
		if vehicleFireKeys then
			for key, state in pairs(vehicleFireKeys) do
				bindKey(key, "down", doShoot)
				table.insert(arena.boundKeys, {key, "down"})
			end
		end
		if vehicleSecondaryFireKeys then
			for key, state in pairs(vehicleSecondaryFireKeys) do
				bindKey(key, "down", doShoot)
				table.insert(arena.boundKeys, {key, "down"})
			end
		end
		if not vehicleFireKeys and vehicleSecondaryFireKeys then
			bindKey("lctrl", "down", doShoot)
			table.insert(arena.boundKeys, {"lctrl", "down"})
			bindKey("rctrl", "down", doShoot)
			table.insert(arena.boundKeys, {"rctrl", "down"})
			bindKey("mouse1", "down", doShoot)
			table.insert(arena.boundKeys, {"mouse1", "down"})
		end
	else
		arena.projectileCreationTimer:killTimer()
		if arena.boundKeys then
			for i, key in pairs(arena.boundKeys) do
				unbindKey(key[1], key[2], doShoot)
			end
		end
	end
end

function doJump()
	if arena.state ~= "running" or arena.spawnProtectionEnabled or getElementData(localPlayer, "state") ~= "alive" or not isElement(arena.vehicle) then
		return
	end
	if isVehicleOnGround(arena.vehicle) then
		local velX, velY, velZ = getElementVelocity(arena.vehicle)
		setElementVelocity(arena.vehicle, velX, velY, velZ + 0.3)
	end
end

function isPlayerDead(player)
	return not getElementHealth(player) or getElementHealth(player) < 1e-45 or isPedDead(player)
end

function getTimePassed()
	if arena.timeIsUpStartTick and arena.timeIsUpTick then
		return math.max(getTickCount() - arena.timeIsUpStartTick, 0)
	end
	return nil
end

function getTimeLeft()
	if arena.timeIsUpStartTick and arena.timeIsUpTick then
		return math.max(arena.timeIsUpTick - getTickCount(), 0)
	end
	return nil
end

function cancelCameraDrop()
	if isPlayerDead(localPlayer) then
		setCameraMatrix(getCameraMatrix())
	end
end

_getCameraTarget = getCameraTarget
function getCameraTarget()
	local target = _getCameraTarget()
	if isElement(target) and getElementType(target) == "vehicle" then
		target = getVehicleOccupant(target)
	end
	return target
end