-- 2.5x Kerbolar System
-- Redux's galaxy, Drast and Beyl included, at 2.5 times the size, as its own galaxy and campaign pack.
-- Every rescaled body, science region, discoverable set, atmosphere and cloud layer is a copy in the Kerbolar25x
-- layer, so the Redux and Classic galaxies are left exactly as they are.

local LAYER = "Kerbolar25x"
local GALAXY = "GalaxyDefinition_" .. LAYER
local RESCALE = 2.5
-- Atmospheres thicken more slowly than the bodies grow
local ATMOSPHERE_RESCALE = math.log((16.0 / 9.0) + ((2.0 * RESCALE) / 9.0)) / math.log(2.0)

-- The bodies of Redux's galaxy and their original radii, which discoverables are placed against. Only these are
-- copied, so bodies other mods add to the galaxy keep their own data.
local RADII = {
    Beyl = 4595.0091452004035,
    Bop = 65000.0,
    Drast = 1596.259,
    Dres = 138000.0,
    Duna = 320000.0,
    Eeloo = 210000.0,
    Eve = 700000.0,
    Gilly = 13000.0,
    Ike = 130000.0,
    Jool = 6000000.0,
    Kerbin = 600000.0,
    Kerbol = 261600000.0,
    Laythe = 500000.0,
    Minmus = 60000.0,
    Moho = 250000.0,
    Mun = 200000.0,
    Pol = 44000.0,
    Tylo = 600000.0,
    Vall = 300000.0,
}

local ATMOSPHERE_CURVES = {
    "atmospherePressureCurve",
    "BodyAltitudeTemperatureCurve",
    "BodyAltitudeSurfaceFluxCurve",
    "BodyAltitudeRelativeHumidityCurve",
}

local function scaleCurveTimes(curve, factor)
    if curve == nil or curve.fCurve == nil then
        return
    end

    -- Stock bodies keep their keys in m_Curve. Redux's keep them in keys, which Lua reads as the wrapper's Keys
    -- method, and only Redux bodies without atmospheres use that form, so those are left alone.
    local keys = curve.fCurve.m_Curve
    if type(keys) ~= "userdata" then
        return
    end

    for _, key in ipairs(keys) do
        key.time = key.time * factor
    end
end

local function scaleVector(vector, factor)
    vector.x = vector.x * factor
    vector.y = vector.y * factor
    vector.z = vector.z * factor
end

-- Moves a position from the body's center out with the surface, keeping its height above sea level
local function moveOutWithSurface(position, oldRadius, newRadius)
    local length = math.sqrt(position.x * position.x + position.y * position.y + position.z * position.z)
    if length > 0 then
        scaleVector(position, (length - oldRadius + newRadius) / length)
    end
end

-- Bodies
local function rescaleBody(body)
    body.Layer = LAYER

    local oldRadius = body.radius
    if body.radius ~= nil then
        body.radius = body.radius * RESCALE
    end
    -- Terrain grows with the body, so mountains keep their shape rather than flattening into a sphere
    body.TerrainHeightMultiplier = RESCALE
    if body.MinTerrainHeight ~= nil then
        body.MinTerrainHeight = body.MinTerrainHeight * RESCALE
    end
    if body.MaxTerrainHeight ~= nil then
        body.MaxTerrainHeight = body.MaxTerrainHeight * RESCALE
    end
    -- The terrain is built this far below sea level, so it scales with the terrain to keep the shorelines in place
    if body.oceanAltitude ~= nil then
        body.oceanAltitude = body.oceanAltitude * RESCALE
    end
    if body.atmosphereDepth ~= nil then
        body.atmosphereDepth = body.atmosphereDepth * ATMOSPHERE_RESCALE
    end
    if body.ForcedSphereOfInfluence ~= nil then
        body.ForcedSphereOfInfluence = body.ForcedSphereOfInfluence * RESCALE
    end
    if body.inverseRotThresholdAltitude ~= nil then
        body.inverseRotThresholdAltitude = body.inverseRotThresholdAltitude * RESCALE
    end
    if body.StarLuminosity ~= nil then
        body.StarLuminosity = body.StarLuminosity * RESCALE * RESCALE
    end

    -- Objects placed against the body itself, such as the space center, move out with its surface but keep their
    -- height above sea level. The space center campus cannot grow, so scaling its whole position would lift it off
    -- its pad by 1.5 times its altitude.
    if body.LocalSimObjectsData ~= nil and oldRadius ~= nil then
        for _, simObject in ipairs(body.LocalSimObjectsData) do
            if simObject.RelativeTo == nil or simObject.RelativeTo == "" then
                moveOutWithSurface(simObject.LocalPosition, oldRadius, body.radius)
            end
        end
    end

    for _, curveName in ipairs(ATMOSPHERE_CURVES) do
        scaleCurveTimes(body[curveName], ATMOSPHERE_RESCALE)
    end
end

-- Science situations
local function rescaleRegions(regions)
    regions.Layer = LAYER

    local situations = regions.SituationData
    if situations == nil then
        return
    end

    situations.HighOrbitMaxAltitude = situations.HighOrbitMaxAltitude * RESCALE
    situations.LowOrbitMaxAltutude = situations.LowOrbitMaxAltutude * ATMOSPHERE_RESCALE
    situations.AtmosphereMaxAltutude = situations.AtmosphereMaxAltutude * ATMOSPHERE_RESCALE
end

-- Discoverables keep their height above the surface as the surface moves out
local function rescaleDiscoverables(discoverables)
    discoverables.Layer = LAYER

    local radius = RADII[discoverables.BodyName]
    if radius == nil then
        return
    end

    for _, discoverable in pairs(discoverables) do
        local position = discoverable.Position
        local length = math.sqrt(position.x * position.x + position.y * position.y + position.z * position.z)
        if length > 0 then
            local outward = (radius * RESCALE - radius) / length
            position.x = position.x + position.x * outward
            position.y = position.y + position.y * outward
            position.z = position.z + position.z * outward
        end
        discoverable.Radius = discoverable.Radius * RESCALE
    end
end

-- Kerbol and Jool have no discoverables, so those duplicates match nothing
for bodyName in pairs(RADII) do
    local assetPrefix = string.lower(bodyName) .. "_science_regions"
    PM.Planets:Duplicate(bodyName, bodyName .. "_" .. LAYER):Do(rescaleBody)
    PM.Science:DuplicateRegions(assetPrefix, "{name}_" .. LAYER):Do(rescaleRegions)
    PM.Science:DuplicateDiscoverables(assetPrefix .. "_discoverables", "{name}_" .. LAYER):Do(rescaleDiscoverables)
end

-- Antennas reach 2.5 times as far, so relays cover the wider orbits. Only parts with a transmitter are copied, and
-- every other part keeps its default copy.
local ANTENNA_LAYER = "AntennaRescale"

PM.Parts:Duplicate("*", "{name}_" .. ANTENNA_LAYER)
        :Has("Module_DataTransmitter")
        :Do(function(part)
            part.Layer = ANTENNA_LAYER
            local transmitter = part.Module_DataTransmitter.Data_Transmitter
            transmitter.CommunicationRange = transmitter.CommunicationRange * RESCALE
        end)

-- The galaxy, taken after Redux has added Drast and Beyl
PM.Planets:DuplicateGalaxy("GalaxyDefinition_Default", GALAXY):Do(function(galaxy)
    galaxy.Name = LAYER
    galaxy.LocalizationKey = "Galaxies/" .. GALAXY
    galaxy.DescriptionLocalizationKey = "Galaxies/Description/" .. GALAXY
    for _, entry in ipairs(galaxy.CelestialBodies) do
        entry.Layer = LAYER
        local orbit = entry.OrbitProperties
        if orbit ~= nil and orbit.semiMajorAxis ~= nil then
            orbit.semiMajorAxis = orbit.semiMajorAxis * RESCALE
        end
    end
end)

-- Atmospheres, sized in kilometres
local ATMOSPHERES = {
    kerbin = { radius = 600, depth = 60, absorptionMin = 10, absorptionMax = 66.37167 },
    jool = { radius = 6000, depth = 200, absorptionMin = 10, absorptionMax = 40 },
    laythe = { radius = 500, depth = 30, absorptionMin = 10, absorptionMax = 40 },
    eve = { radius = 700, depth = 82, absorptionMin = 0, absorptionMax = 80 },
    duna = { radius = 320, depth = 22, absorptionMin = 0, absorptionMax = 19.69695 },
}

for bodyName, atmosphere in pairs(ATMOSPHERES) do
    PM.Planets:CreateAtmosphereOverride(bodyName, function(atmosphereOverride)
        atmosphereOverride.Layer = LAYER
        atmosphereOverride.BottomRadius = atmosphere.radius * RESCALE
        atmosphereOverride.AtmosphereHeight = atmosphere.depth * ATMOSPHERE_RESCALE
        atmosphereOverride.AbsorptionHeightMinMax = {
            x = atmosphere.absorptionMin * ATMOSPHERE_RESCALE,
            y = atmosphere.absorptionMax * ATMOSPHERE_RESCALE,
        }
    end)
end

-- Cloud layers, sized in metres
local CLOUD_PLANET_RADII = {
    kerbin = 600000,
    eve = 700000,
    jool = 6000000,
    laythe = 500000,
    duna = 320000,
}

local function scaleCloudLayer(cloudLayer)
    if cloudLayer.bakedCloudHeight ~= nil then
        cloudLayer.bakedCloudHeight = cloudLayer.bakedCloudHeight * ATMOSPHERE_RESCALE
    end
    local range = cloudLayer.cloudHeightRange
    if range ~= nil then
        range.x = range.x * ATMOSPHERE_RESCALE
        range.y = range.y * ATMOSPHERE_RESCALE
    end
end

-- Redux already tunes Kerbin's, Eve's and Jool's cloud layers, so the 2.5x layer copies those and lifts them
for _, bodyName in ipairs({ "kerbin", "eve", "jool" }) do
    PM.Planets:DuplicateCloudOverride("volume_cloud_override_" .. bodyName, "{name}_" .. LAYER):Do(function(cloudOverride)
        cloudOverride.Layer = LAYER
        cloudOverride.planetRadius = CLOUD_PLANET_RADII[bodyName] * RESCALE
        for _, cloudLayer in pairs(cloudOverride.cumulusList) do
            scaleCloudLayer(cloudLayer)
        end
    end)
end

-- Laythe's and Duna's clouds are stock, so their stock layer heights are lifted
local STOCK_CLOUDS = {
    laythe = {
        Cloud = { height = 3000, minHeight = 2500, maxHeight = 3500 },
    },
    duna = {
        ["Fluffy Clouds"] = { height = 2257, minHeight = 1810.811, maxHeight = 2705.112 },
    },
}

for bodyName, cloudLayers in pairs(STOCK_CLOUDS) do
    PM.Planets:CreateCloudOverride(bodyName, function(cloudOverride)
        cloudOverride.Layer = LAYER
        cloudOverride.planetRadius = CLOUD_PLANET_RADII[bodyName] * RESCALE
        for layerName, cloudLayer in pairs(cloudLayers) do
            cloudOverride.cumulusList:Append({
                layerName = layerName,
                bakedCloudHeight = cloudLayer.height * ATMOSPHERE_RESCALE,
                cloudHeightRange = {
                    x = cloudLayer.minHeight * ATMOSPHERE_RESCALE,
                    y = cloudLayer.maxHeight * ATMOSPHERE_RESCALE,
                },
            })
        end
    end)
end

-- The campaign pack: the rescaled galaxy with Redux's tech tree, missions and parts, and the rescaled antennas on top
PM.CampaignPacks:CreateCampaignPack(LAYER, function(campaignPack)
    campaignPack.Galaxy = GALAXY
    campaignPack.PartLayers = { "Default", ANTENNA_LAYER }
    campaignPack.CampaignPackDescriptionLocalizationKey = "CampaignPacks/Description/" .. LAYER
end)
