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

local function get_taunt_number_from_action(m)
    for i = 1, #tauntTable do
        if tauntTable[i].action == m.action then
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

---@param anim integer|string Either Vanilla or Custom Anim input
---@param loop boolean If the Animation should Loop or only play once
---@param actionFunc boolean|function the Action Update function, True will use generic moving, False will use generic Still
local function add_taunt(name, anim, loop, actionFunc, groupTauntLocal, groupTauntRemote)
    local actionID = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_MOVING)
    table.insert(tauntTable, {
        name = name,
        action = actionID,
        anim = anim,
        actFunc = actionFunc,
        loop = loop,
        groupTauntLocal = groupTauntLocal,
        groupTauntRemote = groupTauntRemote,
    })
    local tauntID = #tauntTable

    ---@param m MarioState
    local function act_taunt(m)
        local tauntData = tauntTable[get_taunt_number_from_action(m)]
        if m.actionState == 0 then
            m.marioObj.header.gfx.animInfo.animID = -1
            if type(anim) == "string" then
                set_mario_animation(m, 0)
                smlua_anim_util_set_animation(m.marioObj, anim)
            elseif type(anim) == "number" then
                set_mario_animation(m, anim)
            end
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
local TAUNT_WAITING = add_taunt("Waiting for You", CHAR_ANIM_STAND_AGAINST_WALL, true, false, TAUNT_STAR, TAUNT_STAR)
local TAUNT_A_POSE = add_taunt("TEST", CHAR_ANIM_A_POSE, true, false)
local TAUNT_COMPANY = add_taunt("Company", EMOTE_ANIM_COMPANY_JIG, true, false)
local TAUNT_BREAKDANCE = add_taunt("Breakdance", CHAR_ANIM_BREAKDANCE, true, true, nil, #tauntTable + 1)

local function mario_update(m)
    if m.action & ACT_FLAG_AIR == 0 then
        if m.controller.buttonDown & L_TRIG ~= 0 then
            local nearest = nearest_mario_state_to_object(m.marioObj)
            local tauntNum = get_taunt_number_from_action(nearest)
            --if not nearest or not tauntData then return end
            if nearest and tauntNum then
                local tauntData = tauntTable[get_taunt_number_from_action(nearest)]
                local yDif = math.abs(m.pos.y - nearest.pos.y)
                local dist = vec3f_dist(m.pos, nearest.pos)
                if yDif < 100 and dist < 1000 and tauntData.groupTauntRemote ~= nil then
                    if tauntData.groupTauntLocal ~= nil then
                        set_mario_taunt(nearest, tauntData.groupTauntLocal)
                        m.pos.x = nearest.pos.x + sins(nearest.faceAngle.y)*250
                        m.pos.z = nearest.pos.z + coss(nearest.faceAngle.y)*250
                        m.faceAngle.y = nearest.faceAngle.y+0x8000
                    else
                        m.marioObj.header.gfx.animInfo.animFrame = nearest.marioObj.header.gfx.animInfo.animFrame
                    end
                    set_mario_taunt(m, tauntData.groupTauntRemote)
                end
            end
        end
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
    end
end

hook_event(HOOK_MARIO_UPDATE, mario_update)


_G.squishyTaunts = {

}