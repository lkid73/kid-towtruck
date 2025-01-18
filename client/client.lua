Config = Config or {}

local isTowing = false
local towingVehicle = nil
local attachedVehicle = nil
local towingVehiclesStatus = {}

function DebugPrint(message)
    if Config.EnableDebug then
        print("[DEBUG] " .. message)
    end
end

function IsTowingVehicle(vehicle)
    local model = GetEntityModel(vehicle)
    DebugPrint("Checking if vehicle is a towing vehicle. Model hash: " .. tostring(model))
    for towingModel, data in pairs(Config.TowingVehicles) do
        if model == GetHashKey(towingModel) then
            DebugPrint("Vehicle is a valid towing vehicle: " .. towingModel)
            return true
        end
    end
    DebugPrint("Vehicle is not a valid towing vehicle.")
    return false
end

function IsVehicleBlacklisted(vehicle)
    local model = GetEntityModel(vehicle)
    DebugPrint("Checking if vehicle is blacklisted. Model hash: " .. tostring(model))

    for towingModel, data in pairs(Config.TowingVehicles) do
        if data.BlacklistedVehicles then
            for _, blacklistedModel in ipairs(data.BlacklistedVehicles) do
                if model == GetHashKey(blacklistedModel) then
                    DebugPrint("Vehicle is blacklisted: " .. blacklistedModel)
                    return true
                end
            end
        end
    end

    DebugPrint("Vehicle is not blacklisted.")
    return false
end

function IsClassBlacklisted(vehicle)
    local class = GetVehicleClass(vehicle)
    DebugPrint("Checking if vehicle class is blacklisted. Class: " .. tostring(class))

    for towingModel, data in pairs(Config.TowingVehicles) do
        if data.BlacklistedClasses then
            for _, blacklistedClass in ipairs(data.BlacklistedClasses) do
                if class == blacklistedClass then
                    DebugPrint("Vehicle is blacklisted: " .. blacklistedClass)
                    return true
                end
            end
        end
    end

    DebugPrint("Vehicle is not blacklisted.")
    return false
end

function IsTowTruckAvailable(towTruck)
    local towTruckId = VehToNet(towTruck)
    DebugPrint("Checking if tow truck is available. Tow truck ID: " .. tostring(towTruckId))

    if towingVehiclesStatus[towTruckId] then
        DebugPrint("Tow truck is already towing another vehicle.")
        return false
    else
        DebugPrint("Tow truck is available.")
        return true
    end
end

function MarkTowTruckAsOccupied(towTruck)
    local towTruckId = VehToNet(towTruck)
    towingVehiclesStatus[towTruckId] = true
    DebugPrint("Marked tow truck ID " .. tostring(towTruckId) .. " as occupied.")
end

function MarkTowTruckAsAvailable(towTruck)
    local towTruckId = VehToNet(towTruck)
    towingVehiclesStatus[towTruckId] = nil
    DebugPrint("Marked tow truck ID " .. tostring(towTruckId) .. " as available.")
end

function FindNearbyTowingVehicle(playerCoords)
    local nearbyVehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, Config.TowingRange, 0, 70)
    DebugPrint("Closest vehicle in range: " .. tostring(nearbyVehicle))
    if nearbyVehicle and IsTowingVehicle(nearbyVehicle) and IsTowTruckAvailable(nearbyVehicle) then
        DebugPrint("Valid and available towing vehicle found nearby.")
        return nearbyVehicle
    end
    DebugPrint("No valid and available towing vehicle found nearby.")
    return nil
end

function AttachToTowtruck(vehicleToAttach)
    DebugPrint("Attempting to attach vehicle. Vehicle ID: " .. tostring(vehicleToAttach))
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    DebugPrint("Player coordinates: " .. tostring(playerCoords))

    if IsVehicleBlacklisted(vehicleToAttach) then
        DebugPrint("Vehicle is blacklisted. Cannot be towed.")
        Notify("This vehicle cannot be towed!")
        return
    end

    if IsClassBlacklisted(vehicleToAttach) then
        DebugPrint("Vehicle is blacklisted. Cannot be towed.")
        Notify("This vehicle cannot be towed!")
        return
    end

    towingVehicle = FindNearbyTowingVehicle(playerCoords)

    if towingVehicle then
        local towingModel = GetDisplayNameFromVehicleModel(GetEntityModel(towingVehicle)):lower()
        local boneName = Config.TowingVehicles[towingModel] and Config.TowingVehicles[towingModel].AttachToBone
        local boneIndex = GetEntityBoneIndexByName(towingVehicle, boneName)
        DebugPrint("Bone index for " .. boneName .. ": " .. tostring(boneIndex))

        if boneIndex ~= -1 then
            local boneWorldPosition = GetEntityBonePosition_2(towingVehicle, boneIndex)
            DebugPrint("bone world position: " .. tostring(boneWorldPosition))

            local vehiclePosition = GetEntityCoords(vehicleToAttach)
            DebugPrint("Towed vehicle position: " .. tostring(vehiclePosition))

            local offset = vehiclePosition - boneWorldPosition

            local function clamp(value, min, max)
                if value < min then
                    return min
                elseif value > max then
                    return max
                else
                    return value
                end
            end

            offset = vector3(
                clamp(offset.x, -0.1, 0.1),
                clamp(offset.y, -0.1, 0.1),
                clamp(offset.z, -0.1, 0.7)
            )
            DebugPrint("Clamped offset: " .. tostring(offset))

            local boneWorldRotation = GetEntityRotation(towingVehicle, 2)
            DebugPrint("bone world rotation: " .. tostring(boneWorldRotation))

            local vehicleRotation = GetEntityRotation(vehicleToAttach, 2)
            DebugPrint("Towed vehicle rotation: " .. tostring(vehicleRotation))

            local rotationOffset = vector3(
                vehicleRotation.x - boneWorldRotation.x,
                vehicleRotation.y - boneWorldRotation.y,
                vehicleRotation.z - boneWorldRotation.z
            )
            DebugPrint("Calculated rotation offset: " .. tostring(rotationOffset))

            AttachEntityToEntity(
                vehicleToAttach,
                towingVehicle,
                boneIndex,
                offset.x, offset.y, offset.z,
                0.0, 0.0, rotationOffset.z,
                false, false, true, false, 0, true
            )
            isTowing = true
            attachedVehicle = vehicleToAttach
            MarkTowTruckAsOccupied(towingVehicle)
            DebugPrint("Vehicle successfully attached.")
            Notify("Vehicle successfully attached to the tow truck!")
        else
            DebugPrint("Towing vehicle does not have the right bone.")
            Notify("Towing vehicle does not have the right bone, check your config file!")
        end
    else
        DebugPrint("No valid tow truck found within range or it's already occupied.")
        Notify("No valid tow truck found within range or it's already towing another vehicle!")
    end
end

function DetachFromTowtruck()
    DebugPrint("Attempting to detach vehicle.")
    if attachedVehicle and towingVehicle then
        SetEntityCollision(attachedVehicle, false, true)
        DebugPrint("Detaching vehicle ID: " .. tostring(attachedVehicle))
        DetachEntity(attachedVehicle, true, true)
        MarkTowTruckAsAvailable(towingVehicle)
        Wait(100)
        SetEntityCollision(attachedVehicle, true, true)
        attachedVehicle = nil
        towingVehicle = nil
        isTowing = false
        DebugPrint("Vehicle successfully detached.")
        Notify("Vehicle successfully detached from the tow truck!")
    else
        DebugPrint("No vehicle is currently attached.")
        Notify("No vehicle is currently attached!")
    end
end

function Notify(text)
    DebugPrint("Notification: " .. text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
end

function DisplayHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

CreateThread(function()
    while true do
        Wait(10)

        local playerPed = PlayerPedId()
        local playerVehicle = GetVehiclePedIsIn(playerPed, false)
        DebugPrint("Player vehicle ID: " .. tostring(playerVehicle))

        if playerVehicle and IsPedSittingInAnyVehicle(playerPed) and not isTowing and not IsTowingVehicle(playerVehicle) then
            DebugPrint("Player is in a vehicle that is not a tow truck.")
            local playerCoords = GetEntityCoords(playerPed)

            towingVehicle = FindNearbyTowingVehicle(playerCoords)

            if towingVehicle then
                DisplayHelpText("Press ~INPUT_PICKUP~ to attach this vehicle to a tow truck.")
                if IsControlJustPressed(1, 38) then 
                    DebugPrint("E key pressed.")
                    AttachToTowtruck(playerVehicle)
                end
            end
        elseif IsPedSittingInAnyVehicle(playerPed) and not IsTowingVehicle(playerVehicle) and isTowing then
            DebugPrint("Player is towing a vehicle.")
            DisplayHelpText("Press ~INPUT_COVER~ to detach the vehicle from the tow truck.")
            if IsControlJustPressed(1, 44) then
                DebugPrint("Q key pressed.")
                DetachFromTowtruck()
            end
        end
    end
end)
