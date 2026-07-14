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
sw_resolver:tooltip("Enhances aimbot accuracy against desync by modifying enemy animation state.")

local sw_antidef   = ui_rage:switch(icon_shield  .. "  Anti-Defensive",    false)
sw_antidef:tooltip("Predicts and counters enemy defensive double-tap and pitch manipulation.")

local sw_lethal    = ui_rage:switch(icon_fire    .. "  Lethal BAIM",       false)
sw_lethal:tooltip("Forces body aim on lethal, low health, or hard-to-resolve targets.")

local sw_safepoint = ui_rage:switch(icon_arrow   .. "  Adaptive Safepoint",false)
sw_safepoint:tooltip("Forces safepoint on targets with high acceleration, jittering, or choke.")

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

local native_safe, native_baim, native_mindam, native_hitchance, native_dt

pcall(function() native_safe      = ui.find("Aimbot", "Ragebot", "Safety",    "safe points")      end)
pcall(function() native_baim      = ui.find("Aimbot", "Ragebot", "Safety",    "body aim")         end)
pcall(function() native_mindam    = ui.find("Aimbot", "Ragebot", "Selection", "min. damage")      end)
pcall(function() native_hitchance = ui.find("Aimbot", "Ragebot", "Selection", "hit chance")       end)
pcall(function() native_dt        = ui.find("Aimbot", "Ragebot", "Main",    "double tap")       end)

local last_safe   = nil
local last_baim   = nil
local last_mindam = -1

local function safeAddr(ptr)
    if not ptr then return nil end
    local ok, raw = pcall(ffi.cast, "uintptr_t", ptr)
    if not ok then return nil end
    local addr = tonumber(raw)
    return (addr and addr > 0x1000) and addr or nil
end

local function SafeGetAnimState(ent)
    if not ent or not ent[0] then return nil end
    local ok_addr, ent_addr = pcall(function()
        return tonumber(ffi.cast("uintptr_t", ent[0]))
    end)
    if not ok_addr or not ent_addr or ent_addr <= 0x1000 then return nil end
    if not ffi_uintptr_ptr_t then return nil end
    local ok_ptr, anim_ptr = pcall(ffi.cast, ffi_uintptr_ptr_t, ent_addr + ANIM_STATE_OFFSET)
    if not ok_ptr or not anim_ptr then return nil end
    local ok_deref, anim_addr = pcall(function() return tonumber(anim_ptr[0]) end)
    if not ok_deref or not anim_addr or anim_addr <= 0x1000 then return nil end
    if not ffi_anim_state_t then return nil end
    local ok_cast, anim = pcall(ffi.cast, ffi_anim_state_t, anim_addr)
    if not ok_cast or not anim then return nil end
    local ok_ent, back_ent = pcall(function() return anim.m_pEntity end)
    if not ok_ent then return nil end
    local back_addr = safeAddr(back_ent)
    if not back_addr or back_addr ~= ent_addr then return nil end
    return anim
end

local function SafeGetAnimLayers(ent)
    if not ent or not ent[0] then return nil end
    local ent_addr = tonumber(ffi.cast("uintptr_t", ent[0]))
    if not ent_addr or ent_addr <= 0x1000 then return nil end
    local ptr = ffi.cast("uintptr_t*", ent_addr + 0x2990)
    if not ptr then return nil end
    local addr = tonumber(ptr[0])
    if not addr or addr <= 0x1000 then return nil end
    return ffi.cast("struct animation_layer_t*", addr)
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
    if entity.get_player_by_index then
        return entity.get_player_by_index(idx)
    end
    local players = entity.get_players(true, true)
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

local function getPlayerByUserid(userid)
    if not userid then return nil end
    if entity.get_player_by_userid then
        return entity.get_player_by_userid(userid)
    end
    local players = entity.get_players(true, true)
    if players then
        for i = 1, #players do
            local p = players[i]
            local ok, uid = pcall(function() return p:get_player_info().userid end)
            if ok and uid == userid then
                return p
            end
        end
    end
    return nil
end

local PersistentProfiles = {}

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

local PAT_STATIC          = 0
local PAT_FAKE_FLICK      = 1
local PAT_MICRO_FLICK     = 2
local PAT_DEFENSIVE_FLICK = 3
local PAT_DEFENSIVE_AA    = 4

local TEST_OFFSETS = { 0, 18, 36 }
local HEIGHT_OFFSETS = { 0, -25, -45 }
local temp_branches = { 1, 2, 3, 4, 5 }

local function getDesyncLimit(speed, duck, on_ground)
    if not on_ground then return 58.0 end
    local limit = 58.0
    if speed > 0.1 then
        limit = 58.0 - (58.0 * clamp(speed / 260.0, 0, 1) * 0.8)
    end
    if duck > 0 then
        limit = limit * (1.0 - duck) + 28.0 * duck
    end
    return clamp(limit, 10.0, 58.0)
end

local aimbot_data = {}

local function getTargetState(p)
    if not p.on_ground then return "air" end
    if p.lc_broken or p.sim_shifted or p.fake_movement_burst or p.is_defensive_aa then
        return "exploit"
    end
    if p.speed >= 15 then return "moving" end
    return "standing"
end

local function newSlot(idx)
    local ti = globals.tickinterval
    if type(ti) == "function" then ti = ti() end
    ti = ti or 0.015625

    local ent = getEntity(idx)
    local steamid = getPlayerSteamID(ent) or "unknown"
    
    if not PersistentProfiles[steamid] then
        PersistentProfiles[steamid] = {
            profiles = {
                standing = { best_side = 0, success_rate = 0.0, sample_count = 0, hits = { [-1]=0, [0]=0, [1]=0 }, misses = { [-1]=0, [0]=0, [1]=0 } },
                moving   = { best_side = 0, success_rate = 0.0, sample_count = 0, hits = { [-1]=0, [0]=0, [1]=0 }, misses = { [-1]=0, [0]=0, [1]=0 } },
                air      = { best_side = 0, success_rate = 0.0, sample_count = 0, hits = { [-1]=0, [0]=0, [1]=0 }, misses = { [-1]=0, [0]=0, [1]=0 } },
                exploit  = { best_side = 0, success_rate = 0.0, sample_count = 0, hits = { [-1]=0, [0]=0, [1]=0 }, misses = { [-1]=0, [0]=0, [1]=0 } }
            },
            sig_memory = {},
            archetype = ARC_STATIC,
            observed_successful = {},
            brute_history = {
                { branch = 1, hits = 0, misses = 0 },
                { branch = 2, hits = 0, misses = 0 },
                { branch = 3, hits = 0, misses = 0 },
                { branch = 4, hits = 0, misses = 0 },
                { branch = 5, hits = 0, misses = 0 }
            }
        }
    end
    
    local prof = PersistentProfiles[steamid]

    local p = {
        id            = idx,
        tick_interval = ti,
        steamid       = steamid,
        
        profiles            = prof.profiles,
        sig_memory          = prof.sig_memory,
        brute_history       = prof.brute_history,
        observed_successful = prof.observed_successful,
        
        resolved_side      = 0,
        resolved_delta     = 58,
        consecutive_resolver_misses = 0,
        consecutive_resolver_hits = 0,
        lock_level         = 0,
        
        curr_sim_time  = 0.0,
        prev_feet_yaw  = 0.0,
        
        last_eye_yaw   = 0.0,
        last_yaw_velocity = 0.0,
        last_yaw_acceleration = 0.0,
        yaw_velocity   = 0.0,
        yaw_acceleration = 0.0,
        yaw_jerk       = 0.0,
        flick_history_yaw = nil,
        flick_detected = false,
        pattern        = PAT_STATIC,
        archetype      = prof.archetype,
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
        lc_state       = 0,
        current_sig_hash = 0,
        
        freestand_side = 0,
        last_fs_time   = 0.0,
        last_fs_origin = { x = 0.0, y = 0.0, z = 0.0 },
        
        desync_limit   = 58.0,
        desync_model   = {
            observed_max = 0.0,
            observed_avg = 30.0,
            observed_recent = 30.0
        },
        
        brute_idx = 0,
        speed = 0.0,
        duck = 0.0,
        on_ground = true
    }
    
    return p
end

local function updatePlayerPhysicsAndExploits(p, ent, sim_time, eye_yaw, feet_yaw, speed, duck, layers)
    local ti = p.tick_interval
    local sim_delta = sim_time - p.curr_sim_time
    
    if p.curr_sim_time > 0 and sim_time > 0 and sim_delta > 0 then
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
        local jerk_yaw = (acc_yaw - p.last_yaw_acceleration) / sim_delta
        
        p.yaw_velocity = vel_yaw
        p.yaw_acceleration = acc_yaw
        p.yaw_jerk = jerk_yaw
        
        p.last_yaw_velocity = vel_yaw
        p.last_yaw_acceleration = acc_yaw
        
        local abs_vel = math_abs(vel_yaw)
        local abs_acc = math_abs(acc_yaw)
        local abs_jerk = math_abs(jerk_yaw)
        
        p.pattern = PAT_STATIC
        p.flick_detected = false
        
        if abs_vel > 1000 then
            p.flick_detected = true
            if p.choke >= 5 or p.sim_shifted then
                p.pattern = PAT_DEFENSIVE_FLICK
            elseif abs_jerk > 500000 then
                if p.flick_history_yaw and math_abs(yawDelta(eye_yaw, p.flick_history_yaw)) < 5 then
                    p.pattern = PAT_FAKE_FLICK
                else
                    p.pattern = PAT_MICRO_FLICK
                end
            end
            p.flick_history_yaw = p.last_eye_yaw
        else
            p.flick_history_yaw = nil
        end
        
        p.last_eye_yaw = eye_yaw
        
        p.lc_state = LC_NORMAL
        if p.sim_shifted then
            p.lc_state = LC_SHIFTED
        elseif p.lc_broken then
            p.lc_state = LC_BROKEN
        elseif p.fake_movement_burst then
            p.lc_state = LC_TELEPORT
        end

        if sw_antidef:get() then
            local defensive_score = 0.0
            if p.choke >= 5 then defensive_score = defensive_score + 0.3 end
            if p.sim_shifted then defensive_score = defensive_score + 0.4 end
            if abs_acc > 50000 then defensive_score = defensive_score + 0.2 end
            if p.lc_broken or p.fake_movement_burst then defensive_score = defensive_score + 0.3 end
            
            if layers then
                local l3 = layers[3]
                local l12 = layers[12]
                if l3 and l3.m_flWeight > 0.9 and speed < 15 then
                    defensive_score = defensive_score + 0.2
                end
                if l12 and (l12.m_flPlaybackRate > 2.0 or l12.m_flWeight > 0.8) then
                    defensive_score = defensive_score + 0.2
                end
            end
            
            p.defensive_confidence = clamp(defensive_score, 0.0, 1.0)
            p.is_defensive_aa = (p.defensive_confidence >= 0.5)
            if p.is_defensive_aa and p.pattern == PAT_STATIC then
                p.pattern = PAT_DEFENSIVE_AA
            end
        else
            p.defensive_confidence = 0.0
            p.is_defensive_aa = false
        end
        
        if p.is_defensive_aa then
            p.archetype = ARC_DEFENSIVE
        elseif p.freestand_side ~= 0 and p.lock_level >= 2 then
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
        
        if p.steamid and PersistentProfiles[p.steamid] then
            PersistentProfiles[p.steamid].archetype = p.archetype
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

local function updateAdvancedFreestand(p, ent)
    local cur_time = globals.curtime
    if type(cur_time) == "function" then cur_time = cur_time() end
    cur_time = cur_time or 0.0
    
    local is_threat = (client.current_threat() == p.id)
    local ox, oy, oz = SafeGetOrigin(ent)
    local dist_sq = (ox - p.last_fs_origin.x)^2 + (oy - p.last_fs_origin.y)^2 + (oz - p.last_fs_origin.z)^2
    local moved_significantly = dist_sq > 256.0 
    
    local elapsed = cur_time - p.last_fs_time
    if elapsed < 0.150 and not moved_significantly and not is_threat then
        return
    end
    
    p.last_fs_time = cur_time
    p.last_fs_origin.x = ox
    p.last_fs_origin.y = oy
    p.last_fs_origin.z = oz
    
    local lp = entity.get_local_player()
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
            
            local tr_l = utils.trace_line(lp_pos, left_pt, lp)
            local tr_r = utils.trace_line(lp_pos, right_pt, lp)
            
            left_exposure = left_exposure + tr_l.fraction
            right_exposure = right_exposure + tr_r.fraction
            total_traces = total_traces + 1
        end
    end
    
    local avg_left_exp = left_exposure / total_traces
    local avg_right_exp = right_exposure / total_traces
    
    local side = 0
    if avg_left_exp < avg_right_exp then
        side = -1
    elseif avg_right_exp < avg_left_exp then
        side = 1
    end
    
    p.freestand_side = side
end

local function updateDesyncModel(p, ent)
    local anim = SafeGetAnimState(ent)
    if not anim then return end
    
    local feet_yaw = anim.m_flGoalFeetYaw
    local fy_vel = 0.0
    if p.prev_feet_yaw ~= 0.0 and p.curr_sim_time > 0 then
        local sim_delta = anim.m_flLastUpdateTime - p.curr_sim_time
        if sim_delta > 0 then
            fy_vel = math_abs(yawDelta(feet_yaw, p.prev_feet_yaw)) / sim_delta
        end
    end
    
    local eye_yaw = anim.m_flEyeYaw
    local observed_delta = math_abs(normalizeYaw(eye_yaw - feet_yaw))
    
    local model = p.desync_model
    model.observed_max = math_max(model.observed_max, observed_delta)
    model.observed_recent = observed_delta
    model.observed_avg = model.observed_avg * 0.95 + observed_delta * 0.05
    
    local base_limit = p.desync_limit
    local estimated_limit = base_limit
    
    local state = getTargetState(p)
    local successful_delta = p.observed_successful[state]
    if successful_delta and successful_delta > 0.0 then
        estimated_limit = math_min(base_limit, successful_delta + 5.0)
    elseif p.on_ground then
        local observed_cap = math_max(model.observed_recent, model.observed_avg)
        estimated_limit = math_min(base_limit, math_max(15.0, observed_cap))
        if fy_vel > 100.0 then
            estimated_limit = math_min(base_limit, estimated_limit + 10.0)
        end
    else
        estimated_limit = 58.0
    end
    
    p.resolved_delta = clamp(estimated_limit, 10.0, base_limit)
end

local function computeBrute(p, ent, layers)
    local state = getTargetState(p)
    local limit = p.resolved_delta or p.desync_limit
    
    -- 1. Apply Adaptive Lock overrides (HARD and MEDIUM lock levels)
    if p.lock_level == 3 and p.locked_side then
        p.resolved_side = p.locked_side
        p.resolved_delta = clamp(p.locked_delta or limit, 0.0, p.desync_limit)
        return
    elseif p.lock_level == 2 and p.locked_side then
        p.resolved_side = p.locked_side
        p.resolved_delta = clamp(limit, 0.0, p.desync_limit)
        return
    end

    -- 2. Fake Flick modifications (invalidate locks / signature confidence)
    local use_signature_memory = not p.flick_detected
    if p.flick_detected then
        p.lock_level = 0
        p.brute_idx = p.brute_idx + 1
    end

    -- 3. LC state and Defensive AA modifications
    if p.lc_state == LC_BROKEN or p.lc_state == LC_TELEPORT then
        limit = limit * 0.7
    elseif p.lc_state == LC_SHIFTED or p.defensive_confidence > 0.5 then
        p.lock_level = math_min(p.lock_level, 1)
        limit = p.desync_limit -- Expand brute search range
    end

    if p.lc_state == LC_TELEPORT then
        p.resolved_side = 0
        p.resolved_delta = 0.0
        return
    end

    -- 4. Find Best Side from Signature or State Profile
    local best_side = 0
    local sig = use_signature_memory and p.sig_memory[p.current_sig_hash]
    if sig then
        local max_score = -9999
        for _, s in ipairs({-1, 1, 0}) do
            local hits = sig.hits[s] or 0
            local misses = sig.misses[s] or 0
            local score = hits - misses
            if score > max_score and (hits > 0 or misses > 0) then
                max_score = score
                best_side = s
            end
        end
    end
    
    if best_side == 0 then
        local profile = p.profiles[state]
        if profile and profile.sample_count > 0 then
            local max_score = -9999
            for _, s in ipairs({-1, 1, 0}) do
                local hits = profile.hits[s] or 0
                local misses = profile.misses[s] or 0
                local score = hits - misses
                if score > max_score and (hits > 0 or misses > 0) then
                    max_score = score
                    best_side = s
                end
            end
        end
    end

    -- 5. Brute Tree branch selection with Dynamic Reordering
    -- Sort local temp_branches based on brute history branch success rates
    temp_branches[1] = 1
    temp_branches[2] = 2
    temp_branches[3] = 3
    temp_branches[4] = 4
    temp_branches[5] = 5

    table.sort(temp_branches, function(a, b)
        local ha, ma = p.brute_history[a].hits, p.brute_history[a].misses
        local hb, mb = p.brute_history[b].hits, p.brute_history[b].misses
        local ra = (ha + 1) / (ha + ma + 2)
        local rb = (hb + 1) / (hb + mb + 2)
        return ra > rb
    end)

    local idx = p.brute_idx or 0
    local step = (idx % 5) + 1
    local branch_choice = temp_branches[step]

    -- Defensive AA adjustments: override choice to prioritize Half Left/Right
    if p.defensive_confidence > 0.5 and (branch_choice == 1 or branch_choice == 2) then
        branch_choice = 4 -- Force Half Left fallback
    end

    -- Map branch choice to side and delta
    local side = best_side
    if side == 0 then
        side = p.freestand_side ~= 0 and p.freestand_side or 1
    end

    local final_side = 0
    local final_delta = limit

    if branch_choice == 1 then
        final_side = side
        final_delta = limit
    elseif branch_choice == 2 then
        final_side = -side
        final_delta = limit
    elseif branch_choice == 3 then
        final_side = 0
        final_delta = 0.0
    elseif branch_choice == 4 then
        final_side = -1
        final_delta = limit * 0.5
    else -- branch_choice == 5
        final_side = 1
        final_delta = limit * 0.5
    end

    p.resolved_side = final_side
    p.resolved_delta = clamp(final_delta, 0.0, p.desync_limit)
end

local function updatePlayer(p, ent)
    local ok_alive, alive = pcall(function() return ent:is_alive()   end)
    local ok_dorm,  dorm  = pcall(function() return ent:is_dormant() end)
    if not ok_dorm  or dorm  then return end

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
    
    local layers = SafeGetAnimLayers(ent)
    
    updatePlayerPhysicsAndExploits(p, ent, sim_time, eye_yaw, feet_yaw, speed, duck, layers)
    
    p.original_feet_yaw = feet_yaw
    p.desync_limit = getDesyncLimit(speed, duck, on_ground)
    
    updateAdvancedFreestand(p, ent)
    
    updateDesyncModel(p, ent)
    
    local sig_hash = 0
    if layers then
        local l3 = layers[3]
        local l6 = layers[6]
        local l12 = layers[12]
        
        local l3_w = math_floor(l3.m_flWeight * 10 + 0.5)
        local l6_w = math_floor(l6.m_flWeight * 10 + 0.5)
        local l6_r = math_floor(clamp(l6.m_flPlaybackRate, 0, 5) * 4 + 0.5)
        local spd = math_floor(clamp(speed, 0, 300) / 30)
        local choke_val = clamp(p.choke, 0, 16)
        
        sig_hash = l3_w + l6_w * 16 + l6_r * 256 + spd * 8192 + choke_val * 131072
    end
    p.current_sig_hash = sig_hash
    
    p.prev_feet_yaw = feet_yaw
    
    computeBrute(p, ent, layers)
    
    local resolved_y = normalizeYaw(eye_yaw + p.resolved_side * p.resolved_delta)
    anim.m_flGoalFeetYaw    = resolved_y
    anim.m_flCurrentFeetYaw = resolved_y
end

local function shouldForceBAIM(p, hp)
    if not sw_lethal:get() then return false end
    if not p then return false end

    local cm = p.consecutive_resolver_misses

    local is_lethal = hp <= 35 or (hp <= 65 and cm >= 1)
    local low_reliability = (cm >= 2)
    
    if is_lethal then return true end
    if low_reliability then return true end
    if p.pattern == PAT_DEFENSIVE_FLICK or p.pattern == PAT_DEFENSIVE_AA then return true end
    
    return false
end

local function shouldPreferSafe(p)
    if not sw_safepoint:get() then return false end
    if not p then return false end

    local cm = p.consecutive_resolver_misses
    local active_exploit = p.lc_broken or p.sim_shifted or p.fake_movement_burst or p.is_defensive_aa
    
    if cm >= 1 then return true end
    if p.choke > 6 or active_exploit then return true end
    if p.pattern == PAT_FAKE_FLICK or p.pattern == PAT_MICRO_FLICK or p.pattern == PAT_DEFENSIVE_FLICK then return true end
    
    return false
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
    local lp = entity.get_local_player()
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
                local score = getThreatScore(e, lx, ly, lz)
                if score > best_score then
                    best_score = score
                    best_ent   = e
                end
            end
        end
    end

    return best_ent
end

EnemyRecords = {}

register_event("net_update_start", function()
    if not sw_resolver:get() then return end

    local lp      = entity.get_local_player()
    if not lp then return end
    local enemies = entity.get_players(true, false)
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
                    EnemyRecords[id] = nil
                end
            end
        end
    end
end)

register_event("pre_render", function()
    if not sw_resolver:get() then return end

    local lp      = entity.get_local_player()
    local enemies = entity.get_players(true, false)
    if not enemies then return end

    for i = 1, #enemies do
        local ent = enemies[i]
        if ent ~= lp then
            local ok_id, id = pcall(function() return ent:get_index() end)
            if ok_id then
                local p = EnemyRecords[id]
                if p then
                    pcall(function()
                        local ok_a, a = pcall(function() return ent:is_alive()   end)
                        local ok_d, d = pcall(function() return ent:is_dormant() end)
                        if (ok_a and a) and not (ok_d and d) then
                            local anim = SafeGetAnimState(ent)
                            if anim then
                                local ok_ey, eye_yaw = pcall(function() return anim.m_flEyeYaw end)
                                if ok_ey and eye_yaw then
                                    local resolved = normalizeYaw(eye_yaw + p.resolved_side * p.resolved_delta)
                                    anim.m_flGoalFeetYaw    = resolved
                                    anim.m_flCurrentFeetYaw = resolved
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
end)

local function getEvidenceWeight(state, hitgroup, choke, lock_level)
    local weight = 1.0
    local is_head = (hitgroup == 1)
    
    if state == "standing" then
        weight = is_head and 2.0 or 1.0
    elseif state == "moving" then
        weight = is_head and 1.5 or 0.5
    end
    
    if choke >= 5 then
        weight = weight + 0.5
    end
    
    if lock_level <= 1 then
        weight = weight + 0.3
    end
    
    return weight
end

register_event("aim_fire", function(e)
    if not e then return end
    local p = EnemyRecords[e.target]
    if not p then return end
    
    local idx = p.brute_idx or 0
    local step = (idx % 5) + 1
    local branch_choice = temp_branches[step]
    
    aimbot_data[e.id] = {
        target = e.target,
        side = p.resolved_side,
        delta = p.resolved_delta,
        hitgroup = e.hitgroup,
        sig_hash = p.current_sig_hash,
        state = getTargetState(p),
        lock_level = p.lock_level,
        choke = p.choke,
        branch_choice = branch_choice
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
    p.brute_idx = 0
    
    if p.consecutive_resolver_hits >= 3 then
        p.lock_level = 3
    elseif p.consecutive_resolver_hits == 2 then
        p.lock_level = 2
    else
        p.lock_level = 1
    end
    
    p.locked_side = shot.side
    p.locked_delta = shot.delta
    p.observed_successful[shot.state] = shot.delta
    
    local side = shot.side
    local state = shot.state
    local sig_hash = shot.sig_hash
    local branch_choice = shot.branch_choice
    
    local w = getEvidenceWeight(state, shot.hitgroup, shot.choke, shot.lock_level)
    
    if sig_hash ~= 0 then
        p.sig_memory[sig_hash] = p.sig_memory[sig_hash] or {
            hits = { [-1] = 0, [0] = 0, [1] = 0 },
            misses = { [-1] = 0, [0] = 0, [1] = 0 }
        }
        p.sig_memory[sig_hash].hits[side] = (p.sig_memory[sig_hash].hits[side] or 0) + w
    end
    
    local profile = p.profiles[state]
    if profile then
        profile.hits[side] = (profile.hits[side] or 0) + w
        profile.sample_count = profile.sample_count + w
        
        local total_hits = profile.hits[-1] + profile.hits[1] + profile.hits[0]
        local total_misses = profile.misses[-1] + profile.misses[1] + profile.misses[0]
        profile.success_rate = total_hits / (total_hits + total_misses + 1)
    end
    
    if branch_choice and p.brute_history[branch_choice] then
        p.brute_history[branch_choice].hits = p.brute_history[branch_choice].hits + w
    end
end)

register_event("aim_miss", function(e)
    if not e then return end
    local shot = aimbot_data[e.id]
    if not shot then return end
    aimbot_data[e.id] = nil
    
    local p = EnemyRecords[shot.target]
    if not p then return end
    
    local reason = (type(e.reason) == "string") and e.reason:lower() or "unknown"
    local side = shot.side
    local state = shot.state
    local sig_hash = shot.sig_hash
    local branch_choice = shot.branch_choice
    
    if reason == "resolver" or reason == "correction" then
        p.consecutive_resolver_hits = 0
        p.consecutive_resolver_misses = p.consecutive_resolver_misses + 1
        p.brute_idx = p.brute_idx + 1
        p.lock_level = math_max(0, p.lock_level - 1)
        
        local w = getEvidenceWeight(state, shot.hitgroup, shot.choke, shot.lock_level)
        
        if sig_hash ~= 0 then
            p.sig_memory[sig_hash] = p.sig_memory[sig_hash] or {
                hits = { [-1] = 0, [0] = 0, [1] = 0 },
                misses = { [-1] = 0, [0] = 0, [1] = 0 }
            }
            p.sig_memory[sig_hash].misses[side] = (p.sig_memory[sig_hash].misses[side] or 0) + w
        end
        
        local profile = p.profiles[state]
        if profile then
            profile.misses[side] = (profile.misses[side] or 0) + w
            profile.sample_count = profile.sample_count + w
            
            local total_hits = profile.hits[-1] + profile.hits[1] + profile.hits[0]
            local total_misses = profile.misses[-1] + profile.misses[1] + profile.misses[0]
            profile.success_rate = total_hits / (total_hits + total_misses + 1)
        end
        
        if branch_choice and p.brute_history[branch_choice] then
            p.brute_history[branch_choice].misses = p.brute_history[branch_choice].misses + w
        end
    end
end)

register_event("createmove", function(cmd)
    if not sw_resolver:get() then
        if last_baim   ~= nil then if native_baim   then native_baim:override()   end; last_baim   = nil  end
        if last_safe   ~= nil then if native_safe   then native_safe:override()   end; last_safe   = nil  end
        if last_mindam ~= -1  then if native_mindam then native_mindam:override() end; last_mindam = -1   end
        return
    end

    local lp = entity.get_local_player()
    if not lp then return end
    local ok_lp_alive, lp_alive = pcall(function() return lp:is_alive() end)
    if not ok_lp_alive or not lp_alive then return end

    local enemies = entity.get_players(true, false)
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

    local want_baim = shouldForceBAIM(p, hp)
    if want_baim then
        if last_baim ~= "force" then
            if native_baim then native_baim:override("force") end
            last_baim = "force"
        end
    else
        if last_baim ~= nil then
            if native_baim then native_baim:override() end
            last_baim = nil
        end
    end

    local want_safe = shouldPreferSafe(p)
    if want_safe then
        local mode = (p.consecutive_resolver_misses >= 2) and "force" or "prefer"
        if last_safe ~= mode then
            if native_safe then native_safe:override(mode) end
            last_safe = mode
        end
    else
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
    elseif p.consecutive_resolver_misses >= 1 then
        local ok_md, base_md = pcall(function() return native_mindam:get() end)
        if ok_md and base_md then
            local factor = math_max(0.4, 1.0 - (p.consecutive_resolver_misses * 0.15))
            target_md = math_max(1, math_floor(base_md * factor))
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
end)

register_event("round_start", function()
    EnemyRecords = {}
    aimbot_data  = {}
    last_baim    = nil
    last_safe    = nil
    last_mindam  = -1
    if native_baim   then pcall(function() native_baim:override()   end) end
    if native_safe   then pcall(function() native_safe:override()   end) end
    if native_mindam then pcall(function() native_mindam:override() end) end
end)

register_event("shutdown", function()
    if native_baim      then pcall(function() native_baim:override()      end) end
    if native_safe      then pcall(function() native_safe:override()      end) end
    if native_mindam    then pcall(function() native_mindam:override()    end) end
    if native_hitchance then pcall(function() native_hitchance:override() end) end
    EnemyRecords = {}
    aimbot_data  = {}
end)
