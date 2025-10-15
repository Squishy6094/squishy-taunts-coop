-- name: Squishy Taunts

local tauntTable = {}
local tauntTableRender = {}

gPlayerSyncTable[0].LTrigDown = false

local gExtraStates = {}
for i = 0, MAX_PLAYERS do
    gExtraStates[i] = {
        stickX = 0,
        stickY = 0,
        tauntMenu = false,
        tauntHovered = 0,
        remoteTauntData = nil,

        -- Emulate to look better on clients
        tauntState = 0
    }
end

local function convert_s16(num)
    local min = -32768
    local max = 32767
    while (num < min) do
        num = max + (num - min)
    end
    while (num > max) do
        num = min + (num - max)
    end
    return num
end

local function set_mario_taunt(m, tauntNum)
    set_mario_action(m, tauntTable[tauntNum].action, 0)
end

local function get_mario_taunt(m)
    for i = 1, #tauntTable do
        if tauntTable[i].action == m.action then
            return i
        end
    end
end

---@param m MarioState
---@return MarioState|nil
local function find_closest_mario(m)
    local lowestDist = nil
    local lowestRemote = nil
    for i = 0, MAX_PLAYERS - 1 do
        if (m.playerIndex ~= i) and gNetworkPlayers[i].currAreaSyncValid then
            local remote = gMarioStates[i]
            local dist = vec3f_dist(m.pos, remote.pos)
            if lowestDist == nil or dist < lowestDist then
                lowestDist = dist
                lowestRemote = remote
            end
        end
    end
    return lowestRemote
end

---@param m MarioState
local function stationary_taunt_update(m)
    m.forwardVel = math.lerp(m.forwardVel, 0, 0.2)
    m.vel.x = m.forwardVel*sins(m.faceAngle.y)
    m.vel.z = m.forwardVel*coss(m.faceAngle.y)

    if m.controller.buttonPressed & (A_BUTTON | B_BUTTON) ~= 0 then
        return set_mario_action(m, ACT_FREEFALL_LAND_STOP, 0)
    end

    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end
end

---@param m MarioState
local function moving_taunt_update(m)
    local back = (m.intendedYaw < convert_s16(m.faceAngle.y - 0x4000)) and (m.intendedYaw > convert_s16(m.faceAngle.y + 0x4000))
    m.forwardVel = math.lerp(m.forwardVel, m.controller.stickMag/32*3*(back and -1 or 1), 0.1)
    m.vel.x = m.forwardVel*sins(m.faceAngle.y)
    m.vel.z = m.forwardVel*coss(m.faceAngle.y)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x180, 0x180);

    if m.controller.buttonPressed & (A_BUTTON | B_BUTTON) ~= 0 then
        return set_mario_action(m, ACT_FREEFALL_LAND_STOP, 0)
    end

    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end
end

---@param anim integer|string Either Vanilla or Custom Anim input
---@param loop boolean If the Animation should Loop or only play once
---@param actionFunc boolean|function the Action Update function, True will use generic moving, False will use generic Still
local function add_taunt(name, shown, anim, loop, actionFunc, groupTauntLocal, groupTauntRemote, groupTauntDist)
    if shown == nil then shown = true end
    local actionID = allocate_mario_action(ACT_GROUP_AUTOMATIC | ACT_FLAG_MOVING | ACT_FLAG_ALLOW_FIRST_PERSON)
    table.insert(tauntTable, {
        id = #tauntTable + 1,
        name = name,
        shown = shown,
        action = actionID,
        anim = anim,
        actFunc = actionFunc,
        loop = loop,
        groupTauntLocal = groupTauntLocal,
        groupTauntRemote = groupTauntRemote,
        groupTauntDist = groupTauntDist or 250,
    })
    local tauntID = #tauntTable
    if shown then
        table.insert(tauntTableRender, tauntTable[tauntID])
    end

    ---@param m MarioState
    local function act_taunt(m)
        local e = gExtraStates[m.playerIndex]
        local tauntData = tauntTable[get_mario_taunt(m)]
        if e.tauntState == 0 then
            m.marioObj.header.gfx.animInfo.animID = -1
            if type(anim) == "string" then
                set_mario_animation(m, 0)
                smlua_anim_util_set_animation(m.marioObj, anim)
            elseif type(anim) == "number" then
                set_mario_animation(m, anim)
            end
            e.tauntState = 1
        end

        if type(tauntData.actFunc) == "table" then
            tauntData.actFunc(m)
        elseif tauntData.actFunc then
            moving_taunt_update(m)
        else
            stationary_taunt_update(m)
        end

        if is_anim_at_end(m) ~= 0 then
            if tauntData.loop then
                e.tauntState = 0
            else
                return set_mario_action(m, ACT_FREEFALL_LAND_STOP, 0)
            end
        end
    end

    hook_mario_action(actionID, act_taunt)
    return tauntID
end

local TAUNT_STAR = add_taunt("Star Dance", true, CHAR_ANIM_STAR_DANCE, false, false)
--local TAUNT_WAITING = add_taunt("Waiting for You", true, CHAR_ANIM_STAND_AGAINST_WALL, true, false, TAUNT_STAR, TAUNT_STAR)
local TAUNT_A_POSE = add_taunt("TEST", true, CHAR_ANIM_A_POSE, true, false)
local TAUNT_COMPANY = add_taunt("Company", true, EMOTE_ANIM_COMPANY_JIG, true, false)
local TAUNT_BREAKDANCE = add_taunt("Breakdance", true, CHAR_ANIM_BREAKDANCE, true, true, nil, #tauntTable + 1)
local TAUNT_HUG = add_taunt("Hug", false, CHAR_ANIM_IDLE_WITH_LIGHT_OBJ, true, false, nil, nil)
local TAUNT_HUG_ASK = add_taunt("Hug Me", true, CHAR_ANIM_IDLE_HEAVY_OBJ, true, false, TAUNT_HUG, TAUNT_HUG, 30)


local function nullify_inputs(m)
    local c = m.controller
    c.buttonDown = 0
    c.buttonPressed = 0
    c.extStickX = 0
    c.extStickY = 0
    c.rawStickX = 0
    c.rawStickY = 0
    c.stickMag = 0
    c.stickX = 0
    c.stickY = 0
end

local function before_mario_update(m)
    local e = gExtraStates[m.playerIndex]
    e.remoteTauntData = nil

    if not gNetworkPlayers[m.playerIndex].connected then return end

    -- Get the nearest player and check if you can taunt with them
    local nearest = find_closest_mario(m)
    local tauntNum = nearest and get_mario_taunt(nearest) or nil
    if nearest and tauntNum then
        local tauntData = tauntTable[tauntNum]
        local yDif = math.abs(m.pos.y - nearest.pos.y)
        local dist = vec3f_dist(m.pos, nearest.pos)
        if yDif < 100 and dist < 300 and tauntData.groupTauntRemote ~= nil then
            e.remoteTauntData = tauntData
        end
    end

    if m.playerIndex == 0 then
        gPlayerSyncTable[0].LTrigDown = m.controller.buttonDown & L_TRIG ~= 0
    end

    djui_chat_message_create(tostring(m.playerIndex) .. " - " .. tostring(gPlayerSyncTable[m.playerIndex].LTrigDown))
    if gPlayerSyncTable[m.playerIndex].LTrigDown then
        e.tauntMenu = true
        e.stickX = math.lerp(e.stickX, m.controller.stickX/64*80, 0.3)
        e.stickY = math.lerp(e.stickY, -m.controller.stickY/64*80, 0.3)

        local lowestDist = 20
        e.tauntHovered = -1
        for i = 1, #tauntTableRender do
            local angle = -0x10000*((i - 1)/#tauntTableRender) + 0x8000
            local x = sins(angle)*80
            local y = coss(angle)*80

            local dist = math.sqrt((e.stickX - x)^2 + (e.stickY - y)^2)
            if dist < lowestDist then
                lowestDist = dist
                e.tauntHovered = tauntTableRender[i].id
            end
        end

        nullify_inputs(m)
        --[[
        if m.controller.buttonPressed & U_JPAD ~= 0 then
            set_mario_taunt(m, TAUNT_STAR)
        end
        if m.controller.buttonPressed & L_JPAD ~= 0 then
            set_mario_taunt(m, TAUNT_A_POSE)
        end
        if m.controller.buttonPressed & D_JPAD ~= 0 then
            set_mario_taunt(m, TAUNT_COMPANY)
        end
        if m.controller.buttonPressed & R_JPAD ~= 0 then
            set_mario_taunt(m, TAUNT_BREAKDANCE)
        end
        ]]
    else
        e.tauntMenu = false

        if m.action & ACT_FLAG_ALLOW_FIRST_PERSON ~= 0 and not e.tauntMenu then
            if e.tauntHovered > 0 then
                e.tauntState = 0
                set_mario_taunt(m, e.tauntHovered)
            elseif e.tauntHovered ~= 0 and e.remoteTauntData and nearest then
                if e.remoteTauntData.groupTauntLocal ~= nil then
                    set_mario_taunt(nearest, e.remoteTauntData.groupTauntLocal)
                    m.pos.x = nearest.pos.x + sins(nearest.faceAngle.y)*e.remoteTauntData.groupTauntDist
                    m.pos.z = nearest.pos.z + coss(nearest.faceAngle.y)*e.remoteTauntData.groupTauntDist
                    m.faceAngle.y = nearest.faceAngle.y+0x8000
                else
                    m.marioObj.header.gfx.animInfo.animFrame = nearest.marioObj.header.gfx.animInfo.animFrame
                end
                set_mario_taunt(m, e.remoteTauntData.groupTauntRemote)
            end
            e.tauntHovered = 0
        end
    end
end

local function hud_render()
    local e = gExtraStates[0]

    if e.tauntMenu then
        djui_hud_set_resolution(RESOLUTION_N64)
        local screenWidth = djui_hud_get_screen_width()
        local screenHeight = 240
        djui_hud_set_color(0, 0, 0, 100)
        djui_hud_render_rect(0, 0, screenWidth, screenHeight)
        for i = 1, #tauntTableRender do
            local angle = -0x10000*((i - 1)/#tauntTableRender) + 0x8000
            if i == e.tauntHovered then
                djui_hud_set_color(200, 200, 255, 255)
            else
                djui_hud_set_color(100, 100, 255, 255)
            end
            local x = sins(angle)*80
            local y = coss(angle)*80
            djui_hud_render_rect(screenWidth*0.5 - 8 + x, screenHeight*0.5 - 8 + y, 16, 16)
        end

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_render_rect(screenWidth*0.5 - 8 + e.stickX, screenHeight*0.5 - 8 + e.stickY, 16, 16)
        djui_hud_set_font(FONT_RECOLOR_HUD)
        local tauntText = ""
        if tauntTable[e.tauntHovered] ~= nil then
            tauntText = tauntTable[e.tauntHovered].name
        elseif e.remoteTauntData then
            tauntText = "Join " .. tauntTable[e.remoteTauntData.groupTauntRemote].name
        end
        djui_hud_print_text(tauntText, screenWidth*0.5 - djui_hud_measure_text(tauntText)*0.5, screenHeight*0.5 - 8, 1)
    end
end

local function before_mario_action(m, nextAct)
    if nextAct ~= m.action then
        gExtraStates[m.playerIndex].tauntState = 0
    end
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_ON_HUD_RENDER, hud_render)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_mario_action)

_G.squishyTaunts = {

}