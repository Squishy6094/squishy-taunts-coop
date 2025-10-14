-- name: Squishy Taunts

local tauntTable = {
    
}

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

local function get_taunt_number_from_action(m, action)
    for i = 1, #tauntTable do
        if tauntTable[i].action == action then
            return i
        end
    end
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
    m.forwardVel = math.lerp(m.forwardVel, m.controller.stickMag/32*5, 0.1)
    m.vel.x = m.forwardVel*sins(m.faceAngle.y)
    m.vel.z = m.forwardVel*coss(m.faceAngle.y)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, 0x100, 0x100);

    if m.controller.buttonPressed & (A_BUTTON | B_BUTTON) ~= 0 then
        return set_mario_action(m, ACT_FREEFALL_LAND_STOP, 0)
    end

    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end
end

---@param anim integer|string
---@param loop boolean
---@param actionFunc boolean|function
local function add_taunt(name, anim, loop, actionFunc)
    local actionID = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_MOVING)
    table.insert(tauntTable, {
        name = name,
        action = actionID,
        anim = anim,
        actFunc = actionFunc,
        loop = loop,
    })
    local tauntID = #tauntTable

    local function act_taunt(m)
        local tauntData = tauntTable[get_taunt_number_from_action(m, m.action)]
        if m.actionState == 0 then
            m.marioObj.header.gfx.animInfo.animID = -1
            if type(anim) == "string" then
                set_mario_animation(m, 0)
                smlua_anim_util_set_animation(m.marioObj, anim)
            elseif type(anim) == "number" then
                set_mario_animation(m, anim)
            end
            djui_chat_message_create("loop")
            m.actionState = 1
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
                m.actionState = 0
            else
                return set_mario_action(m, ACT_FREEFALL_LAND_STOP, 0)
            end
        end
    end

    hook_mario_action(actionID, act_taunt)
    return tauntID
end

local function set_mario_taunt(m, tauntNum)
    set_mario_action(m, tauntTable[tauntNum].action, 0)
end

local TAUNT_STAR = add_taunt("Star Dance", CHAR_ANIM_STAR_DANCE, false, false)
local TAUNT_A_POSE = add_taunt("Star Dance", CHAR_ANIM_A_POSE, true, false)
local TAUNT_COMPANY = add_taunt("Company", EMOTE_ANIM_COMPANY_JIG, true, false)

local function mario_update(m)
    if m.action & ACT_FLAG_AIR == 0 then
        if m.controller.buttonPressed & U_JPAD ~= 0 then
            set_mario_taunt(m, TAUNT_STAR)
        end
        if m.controller.buttonPressed & L_JPAD ~= 0 then
            set_mario_taunt(m, TAUNT_A_POSE)
        end
        if m.controller.buttonPressed & D_JPAD ~= 0 then
            set_mario_taunt(m, TAUNT_COMPANY)
        end
    end
end

hook_event(HOOK_MARIO_UPDATE, mario_update)


_G.squishyTaunts = {

}