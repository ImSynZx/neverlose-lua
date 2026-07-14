local ui = ui
local common = common
local network = network
local json = json
local entity = entity
local utils = utils
local panorama = panorama
local events = events
local vector = vector
local client = client
local globals = globals
local plist = plist

local entity_get_local_player = entity.get_local_player
local entity_get_players = entity.get_players
local entity_get_player_by_index = entity.get_player_by_index
local utils_trace_line = utils.trace_line
local globals_curtime = globals.curtime
local globals_tickinterval = globals.tickinterval

local ffi = ffi
local ffi_cast = ffi and ffi.cast

local plist_cache = {}
local function plist_set(id, key, val)
    if not plist or type(plist) ~= "table" or not plist.set then return end
    if not plist_cache[id] then plist_cache[id] = {} end
    if plist_cache[id][key] == val then return end
    plist_cache[id][key] = val
    pcall(plist.set, id, key, val)
end
local render = render

pcall(ffi.cdef, "typedef struct { float x, y, z; } vec3_t;")
pcall(ffi.cdef, [[
    struct animation_state_t {
        char         _pad0[0x60];
        void*        m_pEntity;
        void*        m_pWeapon;
        void*        m_pLastWeapon;
        float        m_flLastUpdateTime;
        int          m_iLastUpdateFrame;
        float        m_flUpdateDelta;
        float        m_flEyeYaw;
        float        m_flEyePitch;
        float        m_flGoalFeetYaw;
        float        m_flCurrentFeetYaw;
        float        m_flTorsoYaw;
        float        m_flLeanVelocity;
        float        m_flLeanAmount;
        char         _pad1[0x4];
        float        m_flFeetCycle;
        float        m_flFeetYawRate;
        char         _pad2[0x4];
        float        m_flDuckAmount;
        float        m_flLandingDuck;
        char         _pad3[0x4];
        vec3_t       m_vecOrigin;
        vec3_t       m_vecLastOrigin;
        vec3_t       m_vecVelocity;
        char         _pad4[0x4];
        float        m_flSpeed2D;
        float        m_flUpVelocity;
        float        m_flSpeedNormalized;
        float        m_flFeetSpeedForwardsOrSideWays;
        float        m_flFeetSpeedUnknown;
        float        m_flTimeSinceStartedMoving;
        float        m_flTimeSinceStoppedMoving;
        bool         m_bOnGround;
        bool         m_bInHitGroundAnimation;
        char         _pad6[0x2];
        float        m_flJumpToFall;
        float        m_flTimeSinceInAir;
        float        m_flLastOriginZ;
        float        m_flHeadHeight;
        float        m_flStopToFullRunningFraction;
        char         _pad7[0x4];
        float        m_flMagicFraction;
        char         _pad8[0x3C];
        float        m_flWorldForce;
        char         _pad9[0x1CA];
        float        m_flMinBodyYaw;
        float        m_flMaxBodyYaw;
    };
    
    struct animation_layer_t {
        char         _pad0[0x14];
        int          m_nOrder;
        int          m_nSequence;
        float        m_flPrevCycle;
        float        m_flWeight;
        float        m_flWeightDeltaRate;
        float        m_flPlaybackRate;
        float        m_flCycle;
        void*        m_pOwner;
        char         _pad1[0x4];
    };
]])

local ffi_anim_state_t = (function()
    local ok, t = pcall(ffi.typeof, "struct animation_state_t*")
    return ok and t or nil
end)()

local ffi_uintptr_ptr_t = (function()
    local ok, t = pcall(ffi.typeof, "uintptr_t*")
    return ok and t or nil
end)()

local ANIM_STATE_OFFSET = 0x9960

local math_abs   = math.abs
local math_min   = math.min
local math_max   = math.max
local math_floor = math.floor
local math_sqrt  = math.sqrt
local math_pi    = math.pi
local math_atan2 = math.atan2

local table_insert = table.insert
local table_remove = table.remove

local icon_shield   = ui.get_icon("shield")        or ""
local icon_magic    = ui.get_icon("magic")         or ""
local icon_fire     = ui.get_icon("skull")         or ""
local icon_arrow    = ui.get_icon("lock")          or ""
local icon_bullseye = ui.get_icon("crosshairs")     or ""
local icon_logo     = ui.get_icon("eye")           or ""
local icon_user     = ui.get_icon("user")           or ""
local icon_fork     = ui.get_icon("code-fork")      or ""
local icon_link     = ui.get_icon("external-link")  or ""
local icon_info     = ui.get_icon("info-circle")    or ""
ui.color = color

local function register_event(event_name, cb)
    if events[event_name] and type(events[event_name].set) == "function" then
        events[event_name]:set(cb)
    end
end

local GITLAB_REPO = "ntduckien1/neverlose-support"
local GITLAB_RAW = "https://gitlab.com/" .. GITLAB_REPO .. "/-/raw/main"

ui.sidebar("NightSense", "moon")
local ui_info = ui.create("NightSense", icon_info .. "  Information")
local ui_rage = ui.create("NightSense", "Ragebot")

local sw_resolver  = ui_rage:switch(icon_magic   .. "  Resolver Support",  false)
sw_resolver:tooltip("Collects target metrics and feeds evidence-based overrides into the ragebot.")

local sw_antidef   = ui_rage:switch(icon_shield  .. "  Anti-Defensive",    false)
sw_antidef:tooltip("Detects enemy defensive AA and forces body aim or safe points.")

local sw_lethal    = ui_rage:switch(icon_fire    .. "  Lethal BAIM",       false)
sw_lethal:tooltip("Forces body aim dynamically based on resolver confidence and target lethality.")

local sw_safepoint = ui_rage:switch(icon_arrow   .. "  Adaptive Safepoint",false)
sw_safepoint:tooltip("Forces safepoint on targets with low confidence, high choke, or lag instability.")

local sw_priority  = ui_rage:switch(icon_bullseye.. "  Target Priority",   false)
sw_priority:tooltip("Prioritizes threats aiming at you or low HP targets dynamically.")

local user_name = common.get_username() or "Player"
local lbl_welcome = ui_info:label("Welcome back, \aA4E61EFF" .. user_name)
local lbl_dev = ui_info:label(icon_user .. "  Developer: \a7FFF7FFFImSynZx")
local lbl_ver = ui_info:label(icon_fork .. "  Version: \aFFFF7FFF3.0.0 (Premium Release)")
local discord_btn = ui_info:button(icon_link .. "  Open Discord Server")

local function openDiscord(url)
    panorama.SteamOverlayAPI.OpenExternalBrowserURL(url or "https://discord.gg/kg6udfrA3p")
end

discord_btn:set_callback(function()
    openDiscord()
end)

network.get(GITLAB_RAW .. "/info.json", {}, function(response)
    if response and response ~= "" then
        local ok, info = pcall(json.parse, response)
        if ok and type(info) == "table" then
            lbl_dev:name(icon_user .. "  Developer: \a7FFF7FFF" .. (info.developer or "ImSynZx"))
            lbl_ver:name(icon_fork .. "  Version: \aFFFF7FFF" .. (info.version or "3.0.0") .. " (Official)")
            discord_btn:set_callback(function()
                openDiscord(info.discord)
            end)
        end
    end
end)

local native_safe, native_baim, native_mindam, native_hitchance, native_dt, native_delayshot
pcall(function() native_safe      = ui.find("Aimbot", "Ragebot", "Safety",    "safe points")      end)
pcall(function() native_baim      = ui.find("Aimbot", "Ragebot", "Safety",    "body aim")         end)
pcall(function() native_mindam    = ui.find("Aimbot", "Ragebot", "Selection", "min. damage")      end)
pcall(function() native_hitchance = ui.find("Aimbot", "Ragebot", "Selection", "hit chance")       end)
pcall(function() native_dt        = ui.find("Aimbot", "Ragebot", "Main",    "double tap")       end)
pcall(function() native_delayshot = ui.find("Aimbot", "Ragebot", "Selection", "delay shot")       end)

local last_safe   = nil
local last_baim   = nil
local last_mindam = -1
local last_hitchance = nil
local last_delayshot = nil

local function safeAddr(ptr)
    if not ptr then return nil end
    local ok, raw = pcall(ffi_cast, "uintptr_t", ptr)
    if not ok then return nil end
    local addr = tonumber(raw)
    return (addr and addr > 0x1000) and addr or nil
end

local function SafeGetAnimState(ent)
    if not ent or not ent[0] then return nil end
    local ok_addr, ent_addr = pcall(function()
        return tonumber(ffi_cast("uintptr_t", ent[0]))
    end)
    if not ok_addr or not ent_addr or ent_addr <= 0x1000 then return nil end
    if not ffi_uintptr_ptr_t then return nil end
    local ok_ptr, anim_ptr = pcall(ffi_cast, ffi_uintptr_ptr_t, ent_addr + ANIM_STATE_OFFSET)
    if not ok_ptr or not anim_ptr then return nil end
    local ok_deref, anim_addr = pcall(function() return tonumber(anim_ptr[0]) end)
    if not ok_deref or not anim_addr or anim_addr <= 0x1000 then return nil end
    if not ffi_anim_state_t then return nil end
    local ok_cast, anim = pcall(ffi_cast, ffi_anim_state_t, anim_addr)
    if not ok_cast or not anim then return nil end
    local ok_ent, back_ent = pcall(function() return anim.m_pEntity end)
    if not ok_ent then return nil end
    local back_addr = safeAddr(back_ent)
    if not back_addr or back_addr ~= ent_addr then return nil end
    return anim
end

local function SafeGetAnimLayers(ent)
    if not ent or not ent[0] then return nil end
    local ent_addr = tonumber(ffi_cast("uintptr_t", ent[0]))
    if not ent_addr or ent_addr <= 0x1000 then return nil end
    local ptr = ffi_cast("uintptr_t*", ent_addr + 0x2990)
    if not ptr then return nil end
    local addr = tonumber(ptr[0])
    if not addr or addr <= 0x1000 then return nil end
    return ffi_cast("struct animation_layer_t*", addr)
end

local function SafeGetOrigin(ent)
    if not ent then return 0, 0, 0 end
    local ok, x, y, z = pcall(function()
        local o = ent:get_origin()
        return o.x, o.y, o.z
    end)
    if ok and x then return x, y, z end
    return 0, 0, 0
end

local function SafeGetHP(ent)
    if not ent then return 100 end
    local ok, hp = pcall(function() return ent.m_iHealth end)
    return (ok and hp and hp > 0) and hp or 100
end

local function normalizeYaw(yaw)
    return (yaw + 180) % 360 - 180
end

local function yawDelta(a, b)
    return ((a - b + 540) % 360) - 180
end

local function clamp(v, lo, hi)
    return (v < lo and lo) or (v > hi and hi) or v
end

local function getEntity(idx)
    if not idx then return nil end
    if entity_get_player_by_index then
        return entity_get_player_by_index(idx)
    end
    local players = entity_get_players(true, true)
    if players then
        for i = 1, #players do
            local p = players[i]
            if p:get_index() == idx then
                return p
            end
        end
    end
    return nil
end

local function getPlayerSteamID(ent)
    if not ent then return nil end
    local ok, info = pcall(function() return ent:get_player_info() end)
    if ok and info then
        if info.steamid and info.steamid ~= "" and info.steamid ~= "BOT" then
            return tostring(info.steamid)
        end
        if info.name and info.name ~= "" then
            return "name_" .. info.name
        end
    end
    return "idx_" .. tostring(ent:get_index())
end

local LC_NORMAL          = 0
local LC_SHIFTED         = 1
local LC_BROKEN          = 2
local LC_TELEPORT        = 3

local ARC_STATIC         = 0
local ARC_JITTER         = 1
local ARC_MICRO_JITTER   = 2
local ARC_DEFENSIVE      = 3
local ARC_RANDOM         = 4
local ARC_FREESTAND      = 5

local TEST_OFFSETS = { 0, 18, 36 }
local HEIGHT_OFFSETS = { 0, -25, -45 }

local aimbot_data = {}
local shot_matrix = {}

local function recordShot(steamid, state, choke, resolver_confidence, defensive_confidence, lc_state, archetype, hitgroup, result)
    if not shot_matrix[steamid] then
        shot_matrix[steamid] = {
            history = {},
            stats = {
                standing = { shots = 0, hits = 0, misses = 0, accuracy = 0.0 },
                moving = { shots = 0, hits = 0, misses = 0, accuracy = 0.0 },
                air = { shots = 0, hits = 0, misses = 0, accuracy = 0.0 },
                exploit = { shots = 0, hits = 0, misses = 0, accuracy = 0.0 }
            }
        }
    end
    
    local entry = {
        state = state,
        choke = choke,
        resolver_confidence = resolver_confidence,
        defensive_confidence = defensive_confidence,
        lc_state = lc_state,
        archetype = archetype,
        hitgroup = hitgroup,
        result = result
    }
    
    local data = shot_matrix[steamid]
    table_insert(data.history, entry)
    if #data.history > 1000 then
        table_remove(data.history, 1)
    end
    
    local stats = data.stats[state]
    if stats then
        stats.shots = stats.shots + 1
        if result == "hit" then
            stats.hits = stats.hits + 1
        else
            stats.misses = stats.misses + 1
        end
        stats.accuracy = stats.hits / stats.shots
    end
end

local function getShotMatrixAccuracy(steamid, state)
    local data = shot_matrix[steamid]
    if not data then return 0.50, 0 end
    local stats = data.stats[state]
    if not stats or stats.shots == 0 then return 0.50, 0 end
    return stats.accuracy, stats.shots
end

local function getTargetState(p)
    if not p.on_ground then return "air" end
    if p.lc_broken or p.sim_shifted or p.fake_movement_burst or p.is_defensive_aa then
        return "exploit"
    end
    if p.speed >= 15 then return "moving" end
    return "standing"
end

local function newSlot(idx)
    local ti = globals_tickinterval
    if type(ti) == "function" then ti = ti() end
    ti = ti or 0.015625

    local ent = getEntity(idx)
    local steamid = getPlayerSteamID(ent) or "unknown"
    
    local p = {
        id            = idx,
        tick_interval = ti,
        steamid       = steamid,
        
        resolver_confidence = 0.50,
        consecutive_resolver_misses = 0,
        consecutive_resolver_hits = 0,
        
        curr_sim_time  = 0.0,
        prev_feet_yaw  = 0.0,
        
        last_eye_yaw   = 0.0,
        last_yaw_velocity = 0.0,
        last_yaw_acceleration = 0.0,
        yaw_velocity   = 0.0,
        yaw_acceleration = 0.0,
        avg_yaw_delta  = 0.0,
        
        last_ox        = 0.0,
        last_oy        = 0.0,
        last_oz        = 0.0,
        last_vx        = 0.0,
        last_vy        = 0.0,
        last_vz        = 0.0,
        
        choke          = 0,
        lc_broken      = false,
        sim_shifted    = false,
        fake_movement_burst = false,
        is_defensive_aa = false,
        defensive_confidence = 0.0,
        lc_confidence  = 1.0,
        lc_state       = 0,
        
        freestand_confidence = 0.0,
        left_exposure = 0.0,
        right_exposure = 0.0,
        visibility_score = 0.0,
        threat_score = 0.0,
        last_fs_time   = 0.0,
        last_fs_origin = { x = 0.0, y = 0.0, z = 0.0 },
        
        archetype      = ARC_STATIC,
        last_confidence_decay_time = nil,
        speed = 0.0,
        duck = 0.0,
        on_ground = true,
        history = {},
        is_accelerating = false,
        predicted_peek_visible = false
    }
    
    return p
end

local function updateAdvancedFreestand(p, ent)
    local cur_time = globals_curtime
    if type(cur_time) == "function" then cur_time = cur_time() end
    cur_time = cur_time or 0.0
    
    local is_threat = (client.current_threat() == p.id)
    local ox, oy, oz = SafeGetOrigin(ent)
    local dist_sq = (ox - p.last_fs_origin.x)^2 + (oy - p.last_fs_origin.y)^2 + (oz - p.last_fs_origin.z)^2
    local moved_significantly = dist_sq > 256.0 
    
    local elapsed = cur_time - p.last_fs_time
    local throttle_interval = is_threat and 0.100 or 0.300
    if elapsed < throttle_interval and not moved_significantly then
        return
    end
    
    p.last_fs_time = cur_time
    p.last_fs_origin.x = ox
    p.last_fs_origin.y = oy
    p.last_fs_origin.z = oz
    
    local lp = entity_get_local_player()
    if not lp then return end
    
    local head_pos = ent:get_eye_position()
    local lp_pos = lp:get_eye_position()
    if not head_pos or not lp_pos then return end
    
    local dir = (head_pos - lp_pos):normalized()
    local left_dir = vector(-dir.y, dir.x, 0)
    local right_dir = vector(dir.y, -dir.x, 0)
    
    local left_exposure = 0
    local right_exposure = 0
    local total_traces = 0
    
    for i = 1, #HEIGHT_OFFSETS do
        local height = HEIGHT_OFFSETS[i]
        local enemy_center = head_pos + vector(0, 0, height)
        
        for j = 1, #TEST_OFFSETS do
            local offset = TEST_OFFSETS[j]
            local left_pt = enemy_center + left_dir * offset
            local right_pt = enemy_center + right_dir * offset
            
            local tr_l = utils_trace_line(lp_pos, left_pt, lp)
            local tr_r = utils_trace_line(lp_pos, right_pt, lp)
            
            left_exposure = left_exposure + tr_l.fraction
            right_exposure = right_exposure + tr_r.fraction
            total_traces = total_traces + 1
        end
    end
    
    local avg_left_exp = left_exposure / total_traces
    local avg_right_exp = right_exposure / total_traces
    
    p.left_exposure = avg_left_exp
    p.right_exposure = avg_right_exp
    p.visibility_score = clamp((avg_left_exp + avg_right_exp) * 0.5, 0.0, 1.0)
    
    local lp_x, lp_y, lp_z = SafeGetOrigin(lp)
    local dist = math_sqrt((lp_x - ox)^2 + (lp_y - oy)^2 + (lp_z - oz)^2) * 0.0254
    p.threat_score = clamp((1.0 - (dist / 100.0)) * 0.5 + (is_threat and 0.5 or 0.0), 0.0, 1.0)
    
    local exp_diff = math_abs(avg_left_exp - avg_right_exp)
    p.freestand_confidence = clamp(exp_diff * 2.0, 0.0, 1.0)
end

local function predictTargetMovement(p, ent)
    local lp = entity_get_local_player()
    if not lp then return end
    
    local ox, oy, oz = SafeGetOrigin(ent)
    local vx, vy, vz = 0, 0, 0
    local vel = ent.m_vecVelocity
    if vel then
        vx, vy, vz = vel.x, vel.y, vel.z
    end
    
    table_insert(p.history, {
        pos = { x = ox, y = oy, z = oz },
        vel = { x = vx, y = vy, z = vz }
    })
    if #p.history > 16 then
        table_remove(p.history, 1)
    end
    
    if #p.history < 2 then
        p.is_accelerating = false
        p.predicted_peek_visible = false
        return
    end
    
    local cur = p.history[#p.history]
    local prev = p.history[#p.history - 1]
    
    local cur_vel_len = math_sqrt(cur.vel.x^2 + cur.vel.y^2)
    local prev_vel_len = math_sqrt(prev.vel.x^2 + prev.vel.y^2)
    p.is_accelerating = (cur_vel_len - prev_vel_len) > 25.0
    
    local lp_pos = lp:get_eye_position()
    if not lp_pos then return end
    
    local ti = p.tick_interval or 0.015625
    local time_step = 6 * ti
    
    local pred_x = cur.pos.x + cur.vel.x * time_step
    local pred_y = cur.pos.y + cur.vel.y * time_step
    local pred_z = cur.pos.z + cur.vel.z * time_step + 64
    
    local frac, trace_ent = utils_trace_line(lp_pos, vector(pred_x, pred_y, pred_z), lp)
    p.predicted_peek_visible = (frac > 0.97)
end

local function updatePlayer(p, ent)
    local ok_alive, alive = pcall(function() return ent:is_alive()   end)
    local ok_dorm,  dorm  = pcall(function() return ent:is_dormant() end)
    if not ok_dorm or dorm then return end

    if not sw_resolver:get() and not sw_antidef:get() then
        return
    end

    local anim = SafeGetAnimState(ent)
    if not anim then return end

    local ok_ey,  eye_yaw   = pcall(function() return anim.m_flEyeYaw      end)
    local ok_fy,  feet_yaw  = pcall(function() return anim.m_flGoalFeetYaw end)
    local ok_sp,  speed     = pcall(function() return anim.m_flSpeed2D     end)
    local ok_gd,  on_ground = pcall(function() return anim.m_bOnGround     end)
    local ok_dk,  duck      = pcall(function() return anim.m_flDuckAmount  end)
    local ok_sim, sim_time  = pcall(function() return ent.m_flSimulationTime end)

    if not ok_ey or not eye_yaw then return end

    feet_yaw  = (ok_fy  and feet_yaw)  or 0
    speed     = (ok_sp  and speed)     or 0
    on_ground = (ok_gd  and on_ground) or true
    duck      = (ok_dk  and duck)      or 0
    sim_time  = (ok_sim and sim_time)  or 0
    
    local layers = nil
    if sw_resolver:get() or sw_antidef:get() then
        layers = SafeGetAnimLayers(ent)
    end

    local sim_delta = sim_time - p.curr_sim_time
    if p.curr_sim_time > 0 and sim_time > 0 and sim_delta > 0 then
        local ti = p.tick_interval or 0.015625
        p.choke = clamp(math_floor(sim_delta / ti + 0.5) - 1, 0, 16)
        
        local ox, oy, oz = SafeGetOrigin(ent)
        local vx, vy, vz = 0, 0, 0
        local vel = ent.m_vecVelocity
        if vel then
            vx, vy, vz = vel.x, vel.y, vel.z
        end
        
        if p.last_ox ~= 0.0 or p.last_oy ~= 0.0 then
            local origin_delta = math_sqrt((ox - p.last_ox)^2 + (oy - p.last_oy)^2 + (oz - p.last_oz)^2)
            local velocity_delta = math_sqrt((vx - p.last_vx)^2 + (vy - p.last_vy)^2 + (vz - p.last_vz)^2)
            local last_speed_val = math_sqrt(p.last_vx^2 + p.last_vy^2 + p.last_vz^2)
            local expected_dist = last_speed_val * sim_delta
            local teleport_dist = math_abs(origin_delta - expected_dist)
            
            p.lc_broken = (sim_delta > ti * 2) or (origin_delta > 64 and speed > 15)
            p.sim_shifted = (sim_delta < -ti * 0.5) or (sim_delta > ti * 3)
            p.fake_movement_burst = (velocity_delta > 150) and (teleport_dist > 32)
        end
        
        p.last_ox, p.last_oy, p.last_oz = ox, oy, oz
        p.last_vx, p.last_vy, p.last_vz = vx, vy, vz
        
        local yaw_delta = yawDelta(eye_yaw, p.last_eye_yaw)
        local abs_yaw_delta = math_abs(yaw_delta)
        p.avg_yaw_delta = (p.avg_yaw_delta or 0.0) * 0.9 + abs_yaw_delta * 0.1
        
        local vel_yaw = yaw_delta / sim_delta
        local acc_yaw = (vel_yaw - p.last_yaw_velocity) / sim_delta
        
        p.yaw_velocity = vel_yaw
        p.yaw_acceleration = acc_yaw
        
        p.last_yaw_velocity = vel_yaw
        p.last_yaw_acceleration = acc_yaw
        
        local abs_acc = math_abs(acc_yaw)
        
        p.lc_state = LC_NORMAL
        local lc_penalty = 0.0
        if p.sim_shifted then
            p.lc_state = LC_SHIFTED
            lc_penalty = lc_penalty + 0.3
        elseif p.lc_broken then
            p.lc_state = LC_BROKEN
            lc_penalty = lc_penalty + 0.5
        elseif p.fake_movement_burst then
            p.lc_state = LC_TELEPORT
            lc_penalty = lc_penalty + 0.8
        end
        
        if p.choke > 6 then
            lc_penalty = lc_penalty + (p.choke - 6) * 0.05
        end
        p.lc_confidence = clamp(1.0 - lc_penalty, 0.1, 1.0)

        if sw_antidef:get() then
            local indicators = 0
            
            if p.choke >= 10 then
                indicators = indicators + 1
            end
            
            if p.sim_shifted then
                indicators = indicators + 1
            end
            
            if p.lc_broken or p.fake_movement_burst then
                indicators = indicators + 1
            end
            
            local has_anim_anomaly = false
            if layers then
                local l3 = layers[3]
                local l12 = layers[12]
                if l3 and l3.m_flWeight > 0.9 and speed < 15 then
                    has_anim_anomaly = true
                end
                if l12 and (l12.m_flPlaybackRate > 2.0 or l12.m_flWeight > 0.8) then
                    has_anim_anomaly = true
                end
            end
            if has_anim_anomaly then
                indicators = indicators + 1
            end
            
            if indicators >= 2 then
                p.defensive_confidence = clamp(indicators * 0.25, 0.0, 1.0)
                p.is_defensive_aa = true
            else
                p.defensive_confidence = clamp(indicators * 0.15, 0.0, 1.0)
                p.is_defensive_aa = false
            end
        else
            p.defensive_confidence = 0.0
            p.is_defensive_aa = false
        end
        
        local is_fake_walking = false
        if layers then
            local l6 = layers[6]
            if l6 and speed > 1.0 and speed < 100.0 then
                if l6.m_flWeight > 0.8 and l6.m_flPlaybackRate < 0.15 then
                    is_fake_walking = true
                end
            end
        end

        if p.is_defensive_aa then
            p.archetype = ARC_DEFENSIVE
        elseif is_fake_walking then
            p.archetype = ARC_FREESTAND
        else
            local avg_d = p.avg_yaw_delta or 0.0
            if avg_d < 1.0 then
                p.archetype = ARC_STATIC
            elseif avg_d > 25.0 then
                p.archetype = ARC_RANDOM
            elseif avg_d > 10.0 then
                p.archetype = ARC_JITTER
            else
                p.archetype = ARC_MICRO_JITTER
            end
        end
        
        if sw_resolver:get() then
            p.is_fakewalk = is_fake_walking
            p.original_feet_yaw = feet_yaw
            
            updateAdvancedFreestand(p, ent)
            predictTargetMovement(p, ent)
        else
            p.is_fakewalk = false
            p.is_accelerating = false
            p.predicted_peek_visible = false
        end
        
        p.curr_sim_time = sim_time
    elseif p.curr_sim_time == 0.0 and sim_time > 0 then
        p.curr_sim_time = sim_time
        p.last_eye_yaw = eye_yaw
        local ox, oy, oz = SafeGetOrigin(ent)
        p.last_ox, p.last_oy, p.last_oz = ox, oy, oz
        local vel = ent.m_vecVelocity
        if vel then
            p.last_vx, p.last_vy, p.last_vz = vel.x, vel.y, vel.z
        end
    end
    
    p.speed = speed
    p.duck = duck
end

local function getThreatScore(ent, lp_x, lp_y, lp_z)
    local ex, ey, ez = SafeGetOrigin(ent)
    local dist = math_sqrt((lp_x-ex)^2 + (lp_y-ey)^2 + (lp_z-ez)^2) * 0.0254
    local ok_vis, vis = pcall(function() return ent:is_visible() end)
    local hp = SafeGetHP(ent)
    local score = (100 - hp) * 0.3 + ((ok_vis and vis) and 40 or 0) + clamp(100 - dist, 0, 100) * 0.3
    return score
end

local function getBestTarget(enemies)
    local lp = entity_get_local_player()
    if not lp then return nil end
    
    if not sw_priority:get() then
        for i = 1, #enemies do
            local e = enemies[i]
            local ok_a, a = pcall(function() return e:is_alive()   end)
            local ok_d, d = pcall(function() return e:is_dormant() end)
            if ok_a and a and ok_d and not d and e ~= lp then return e end
        end
        return nil
    end

    local lx, ly, lz = SafeGetOrigin(lp)
    local best_ent, best_score = nil, -math.huge

    for i = 1, #enemies do
        local e = enemies[i]
        if e ~= lp then
            local ok_a, a = pcall(function() return e:is_alive()   end)
            local ok_d, d = pcall(function() return e:is_dormant() end)
            if ok_a and a and ok_d and not d then
                local id = e:get_index()
                local p = EnemyRecords[id]
                
                local threat_score = getThreatScore(e, lx, ly, lz)
                local resolver_confidence = p and p.resolver_confidence or 0.50
                local defensive_score = p and (1.0 - p.defensive_confidence) or 1.0
                local visibility_score = p and p.visibility_score or 0.0
                
                local hp = SafeGetHP(e)
                local lethality_score = (hp <= 35) and 1.0 or (hp <= 65 and 0.5 or 0.0)
                
                local norm_threat = threat_score / 170.0
                local priority_score = norm_threat + resolver_confidence + defensive_score + visibility_score + lethality_score
                
                if priority_score > best_score then
                    best_score = priority_score
                    best_ent   = e
                end
            end
        end
    end

    return best_ent
end

local function restorePlayerPlist(id)
    plist_set(id, "Override prefer body aim", "-")
    plist_set(id, "Override prefer safe point", "-")
    plist_cache[id] = nil
end

EnemyRecords = {}

register_event("net_update_start", function()
    if not sw_resolver:get() and not sw_antidef:get() then return end

    local lp      = entity_get_local_player()
    if not lp then return end
    local enemies = entity_get_players(true, false)
    if not enemies then return end

    for i = 1, #enemies do
        local ent = enemies[i]
        if ent ~= lp then
            local ok_id, id = pcall(function() return ent:get_index() end)
            if ok_id and id then
                local ok_a, a = pcall(function() return ent:is_alive()   end)
                local ok_d, d = pcall(function() return ent:is_dormant() end)

                if (ok_a and a) and not (ok_d and d) then
                    if not EnemyRecords[id] then
                        EnemyRecords[id] = newSlot(id)
                    end
                    pcall(updatePlayer, EnemyRecords[id], ent)
                else
                    if EnemyRecords[id] then
                        restorePlayerPlist(id)
                        EnemyRecords[id] = nil
                    end
                end
            end
        end
    end
end)

register_event("aim_fire", function(e)
    if not e then return end
    local p = EnemyRecords[e.target]
    if not p then return end
    
    aimbot_data[e.id] = {
        target = e.target,
        hitgroup = e.hitgroup,
        state = getTargetState(p),
        choke = p.choke,
        resolver_confidence = p.resolver_confidence,
        defensive_confidence = p.defensive_confidence,
        lc_state = p.lc_state,
        archetype = p.archetype
    }
end)

register_event("aim_ack", function(e)
    if not e then return end
    local shot = aimbot_data[e.id]
    if not shot then return end
    aimbot_data[e.id] = nil
    
    local p = EnemyRecords[shot.target]
    if not p then return end
    
    p.consecutive_resolver_hits = p.consecutive_resolver_hits + 1
    p.consecutive_resolver_misses = 0
    
    local is_moving = (shot.state == "moving")
    local is_defensive = (shot.defensive_confidence > 0.49)
    local is_exploit = (shot.state == "exploit" or shot.lc_state > 0)
    local is_high_choke = (shot.choke >= 5)
    
    local confidence_gain = 0.01
    if is_moving or is_defensive or is_exploit or is_high_choke then
        confidence_gain = 0.15
    end
    
    p.resolver_confidence = clamp(p.resolver_confidence + confidence_gain, 0.1, 1.0)
    recordShot(p.steamid, shot.state, shot.choke, shot.resolver_confidence, shot.defensive_confidence, shot.lc_state, shot.archetype, shot.hitgroup, "hit")
end)

register_event("aim_miss", function(e)
    if not e then return end
    local shot = aimbot_data[e.id]
    if not shot then return end
    aimbot_data[e.id] = nil
    
    local p = EnemyRecords[shot.target]
    if not p then return end
    
    local reason = (type(e.reason) == "string") and e.reason:lower() or "unknown"
    
    if reason == "resolver" or reason == "correction" then
        p.consecutive_resolver_hits = 0
        p.consecutive_resolver_misses = p.consecutive_resolver_misses + 1
        p.resolver_confidence = clamp(p.resolver_confidence - 0.20, 0.1, 1.0)
        recordShot(p.steamid, shot.state, shot.choke, shot.resolver_confidence, shot.defensive_confidence, shot.lc_state, shot.archetype, shot.hitgroup, "miss")
    end
end)

register_event("createmove", function(cmd)
    if not sw_resolver:get() and not sw_antidef:get() then
        if last_baim   ~= nil then if native_baim   then native_baim:override()   end; last_baim   = nil  end
        if last_safe   ~= nil then if native_safe   then native_safe:override()   end; last_safe   = nil  end
        if last_mindam ~= -1  then if native_mindam then native_mindam:override() end; last_mindam = -1   end
        return
    end

    local lp = entity_get_local_player()
    if not lp then return end
    local ok_lp_alive, lp_alive = pcall(function() return lp:is_alive() end)
    if not ok_lp_alive or not lp_alive then return end

    local enemies = entity_get_players(true, false)
    if not enemies or #enemies == 0 then
        if last_baim   ~= nil then if native_baim   then native_baim:override()   end; last_baim   = nil end
        if last_safe   ~= nil then if native_safe   then native_safe:override()   end; last_safe   = nil end
        if last_mindam ~= -1  then if native_mindam then native_mindam:override() end; last_mindam = -1  end
        return
    end

    local best = getBestTarget(enemies)
    if not best then
        if last_baim   ~= nil then if native_baim   then native_baim:override()   end; last_baim   = nil end
        if last_safe   ~= nil then if native_safe   then native_safe:override()   end; last_safe   = nil end
        if last_mindam ~= -1  then if native_mindam then native_mindam:override() end; last_mindam = -1  end
        return
    end

    local ok_bid, bid = pcall(function() return best:get_index() end)
    if not ok_bid then return end

    local p  = EnemyRecords[bid]
    if not p then
        if last_baim   ~= nil then if native_baim   then native_baim:override()   end; last_baim   = nil end
        if last_safe   ~= nil then if native_safe   then native_safe:override()   end; last_safe   = nil end
        if last_mindam ~= -1  then if native_mindam then native_mindam:override() end; last_mindam = -1  end
        return
    end

    local hp = SafeGetHP(best)

    local want_baim = false
    if sw_lethal:get() then
        local state = getTargetState(p)
        local state_accuracy, state_shots = getShotMatrixAccuracy(p.steamid, state)
        
        local is_lethal = hp <= 40
        
        local is_defensive = p.defensive_confidence > 0.70
        
        local low_confidence_and_accuracy = (p.resolver_confidence < 0.40) and (state_shots >= 3 and state_accuracy < 0.50)
        
        local is_exploit_state = (state == "exploit")
        local exploit_unreliable = is_exploit_state and (p.lc_confidence < 0.50 or (state_shots >= 3 and state_accuracy < 0.50))
        
        local not_head_peeking = p.visibility_score > 0.30
        
        if (is_lethal or is_defensive or low_confidence_and_accuracy or exploit_unreliable) and not_head_peeking then
            want_baim = true
        end
    end

    if want_baim then
        plist_set(bid, "Override prefer body aim", "On")
        if last_baim ~= "force" then
            if native_baim then native_baim:override("force") end
            last_baim = "force"
        end
    else
        plist_set(bid, "Override prefer body aim", "-")
        if last_baim ~= nil then
            if native_baim then native_baim:override() end
            last_baim = nil
        end
    end

    local want_safe = false
    if sw_safepoint:get() then
        local state = getTargetState(p)
        local state_accuracy, state_shots = getShotMatrixAccuracy(p.steamid, state)
        
        local high_defensive = (p.defensive_confidence > 0.60)
        local unstable_lc = (p.lc_confidence < 0.60)
        local low_accuracy = (state_shots >= 3 and state_accuracy < 0.50)
        
        local is_unstable_angle = (p.archetype == ARC_JITTER or p.archetype == ARC_RANDOM) and (p.resolver_confidence < 0.45)
        
        local is_wall_peeking = (p.visibility_score < 0.60 and p.freestand_confidence > 0.50)
        local is_peeking = p.predicted_peek_visible
        
        if high_defensive or unstable_lc or low_accuracy or is_unstable_angle or is_wall_peeking or is_peeking then
            want_safe = true
        end
    end

    if want_safe then
        plist_set(bid, "Override prefer safe point", "On")
        local mode = (p.consecutive_resolver_misses >= 2) and "force" or "prefer"
        if last_safe ~= mode then
            if native_safe then native_safe:override(mode) end
            last_safe = mode
        end
    else
        plist_set(bid, "Override prefer safe point", "-")
        if last_safe ~= nil then
            if native_safe then native_safe:override() end
            last_safe = nil
        end
    end

    local target_md = -1
    local ok_vis, vis = pcall(function() return best:is_visible() end)
    if sw_lethal:get() and ok_vis and vis and hp < 50 then
        target_md = math_min(hp + 1, 100)
        if native_dt then
            local ok_dt, dt_on = pcall(function() return native_dt:get() end)
            if ok_dt and dt_on then
                local ok_md, base_md = pcall(function() return native_mindam:get() end)
                if ok_md and base_md then
                    target_md = math_max(1, math_floor(base_md * 0.6))
                end
            end
        end
    elseif p.resolver_confidence < 0.5 then
        local ok_md, base_md = pcall(function() return native_mindam:get() end)
        if ok_md and base_md then
            local reduction_factor = clamp(p.resolver_confidence * 1.5, 0.4, 0.95)
            target_md = math_max(1, math_floor(base_md * reduction_factor))
        end
    end

    if target_md ~= -1 then
        if last_mindam ~= target_md then
            if native_mindam then native_mindam:override(target_md) end
            last_mindam = target_md
        end
    else
        if last_mindam ~= -1 then
            if native_mindam then native_mindam:override() end
            last_mindam = -1
        end
    end

    local target_hc = -1
    if native_hitchance then
        local ok_hc, base_hc = pcall(function() return native_hitchance:get() end)
        if ok_hc and base_hc then
            local adjusted_hc = base_hc
            local conf = p.resolver_confidence
            
            if conf > 0.85 then
                adjusted_hc = math_floor(base_hc * 0.95)
            elseif conf < 0.50 then
                adjusted_hc = math_floor(base_hc * 1.10)
            end
            
            if p.is_defensive_aa or p.lc_state == LC_BROKEN or p.lc_state == LC_TELEPORT or p.predicted_peek_visible or p.is_accelerating then
                adjusted_hc = math_floor(adjusted_hc * 1.15)
            end
            
            local safe_floor = math_max(35, math_min(base_hc, 35))
            target_hc = math_max(safe_floor, math_min(adjusted_hc, 100))
        end
    end

    if target_hc ~= -1 then
        if last_hitchance ~= target_hc then
            if native_hitchance then native_hitchance:override(target_hc) end
            last_hitchance = target_hc
        end
    else
        if last_hitchance ~= nil then
            if native_hitchance then native_hitchance:override() end
            last_hitchance = nil
        end
    end

    local want_delayshot = false
    if native_delayshot then
        local unstable_lc = (p.lc_confidence < 0.60)
        local is_volatile = p.is_defensive_aa or p.predicted_peek_visible or p.is_accelerating or unstable_lc
        if is_volatile then
            want_delayshot = true
        end
    end

    if want_delayshot then
        if last_delayshot ~= true then
            if native_delayshot then native_delayshot:override(true) end
            last_delayshot = true
        end
    else
        if last_delayshot ~= nil then
            if native_delayshot then native_delayshot:override() end
            last_delayshot = nil
        end
    end
end)

register_event("round_start", function()
    EnemyRecords = {}
    aimbot_data  = {}
    plist_cache  = {}
    last_baim    = nil
    last_safe    = nil
    last_mindam  = -1
    last_hitchance = nil
    last_delayshot = nil
    if native_baim   then pcall(function() native_baim:override()   end) end
    if native_safe   then pcall(function() native_safe:override()   end) end
    if native_mindam then pcall(function() native_mindam:override() end) end
    if native_hitchance then pcall(function() native_hitchance:override() end) end
    if native_delayshot then pcall(function() native_delayshot:override() end) end
end)

register_event("shutdown", function()
    if native_baim      then pcall(function() native_baim:override()      end) end
    if native_safe      then pcall(function() native_safe:override()      end) end
    if native_mindam    then pcall(function() native_mindam:override()    end) end
    if native_hitchance then pcall(function() native_hitchance:override() end) end
    if native_delayshot then pcall(function() native_delayshot:override() end) end
    for id, _ in pairs(EnemyRecords) do
        restorePlayerPlist(id)
    end
    EnemyRecords = {}
    aimbot_data  = {}
    plist_cache  = {}
end)
