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

local PAT_STATIC       = 0
local PAT_MICRO_JIT    = 1
local PAT_JITTER       = 2
local PAT_DELAYED_JIT  = 3
local PAT_RANDOM_JIT   = 4
local PAT_FLICK        = 5
local PAT_FAKE_FLICK   = 6
local PAT_SPIN         = 7
local PAT_DEFENSIVE    = 8
local PAT_HYBRID       = 9

local YAW_BUF_SIZE = 12
local SHOT_BUF_SIZE = 32

local table_pool = {}
local function get_temp_table()
    local t = table_remove(table_pool)
    if not t then t = {} end
    return t
end
local function release_temp_table(t)
    if #table_pool < 100 then
        for k in pairs(t) do t[k] = nil end
        table_insert(table_pool, t)
    end
end

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

local function newShotBuf()
    local b = { idx = 0, count = 0 }
    for i = 1, SHOT_BUF_SIZE do
        b[i] = { target = 0, side = 0, hitgroup = 0, is_hit = false, reason = "" }
    end
    return b
end

local aimbot_data = {}

local function writeShotBuf(buf, target, side, hitgroup, is_hit, reason)
    buf.idx = (buf.idx % SHOT_BUF_SIZE) + 1
    if buf.count < SHOT_BUF_SIZE then buf.count = buf.count + 1 end
    local s  = buf[buf.idx]
    s.target   = target
    s.side     = side
    s.hitgroup = hitgroup
    s.is_hit   = is_hit
    s.reason   = reason
end

local function getHeadHitrate(p)
    local buf = p.shot_buf
    if buf.count == 0 then return 50.0 end
    local hits, total = 0, 0
    for i = 1, math_min(buf.count, SHOT_BUF_SIZE) do
        local s = buf[i]
        if s.target == p.id then
            total = total + 1
            if s.is_hit and s.hitgroup == 1 then hits = hits + 1 end
        end
    end
    return total > 0 and (hits / total * 100) or 50.0
end

local function getBodyHitrate(p)
    local buf = p.shot_buf
    if buf.count == 0 then return 50.0 end
    local hits, total = 0, 0
    for i = 1, math_min(buf.count, SHOT_BUF_SIZE) do
        local s = buf[i]
        if s.target == p.id and s.hitgroup >= 2 and s.hitgroup <= 7 then
            total = total + 1
            if s.is_hit then hits = hits + 1 end
        end
    end
    return total > 0 and (hits / total * 100) or 50.0
end

local function getWeightedSideRate(p, side)
    local buf = p.shot_buf
    local n   = buf.count
    if n == 0 then return 50.0 end

    local w_hits  = 0.0
    local w_total = 0.0
    local idx     = buf.idx
    local age     = 0
    local RECENCY_DECAY = 0.85

    for i = 1, math_min(n, SHOT_BUF_SIZE) do
        local s = buf[idx]
        if s.target == p.id and s.side == side then
            local w = RECENCY_DECAY ^ age
            w_total = w_total + w
            if s.is_hit then w_hits = w_hits + w end
            age = age + 1
        end
        idx = ((idx - 2) % SHOT_BUF_SIZE) + 1
    end

    return w_total > 0 and (w_hits / w_total * 100) or 50.0
end

local function getTargetState(p)
    if not p.on_ground then return "air" end
    if p.exploit_analysis.tickbase_manip or p.exploit_analysis.double_tap then return "exploit" end
    if p.pattern == PAT_DEFENSIVE then return "defensive" end
    if p.speed >= 15 then return "moving" end
    return "standing"
end

local function newSlot(idx)
    local ti = globals.tickinterval
    if type(ti) == "function" then ti = ti() end
    ti = ti or 0.015625

    local p = {
        id            = idx,
        tick_interval = ti,
        left_hits   = 0, left_misses   = 0,
        right_hits  = 0, right_misses  = 0,
        center_hits = 0, center_misses = 0,
        resolved_side      = 0,
        resolved_delta     = 58,
        best_side          = 0,
        consecutive_misses = 0,
        consecutive_resolver_misses = 0,
        side_lock          = false,
        side_lock_count    = 0,
        pattern    = PAT_STATIC,
        yaw_buf    = {0,0,0,0,0,0,0,0,0,0,0,0},
        yaw_idx    = 0,
        yaw_count  = 0,
        feet_delta = 0.0,
        prev_feet_yaw = 0.0,
        original_feet_yaw = 0.0,
        choke          = 0,
        lc_broken      = false,
        curr_sim_time  = 0,
        def_spikes     = 0,
        def_checks     = 0,
        def_gap_hits   = 0,
        def_anim_resets= 0,
        defensive_freq = 0.0,
        desync_limit = 58.0,
        speed        = 0.0,
        last_speed   = 0.0,
        duck         = 0.0,
        on_ground    = true,
        freestand_side = 0,
        shot_buf = newShotBuf(),
        
        resolver_memory = {
            animation = {
                last_feet_yaw = 0,
                yaw_rate_avg = 0,
                cycle_avg = 0.5,
                confidence = 0.5
            },
            movement = {
                jerk = 0.0,
                accel_spikes = 0,
                confidence = 0.5
            },
            freestand = {
                exposure_left = 0.5,
                exposure_right = 0.5,
                confidence = 0.5
            },
            defensive = {
                frequency = 0.0,
                spikes = 0,
                confidence = 0.5
            },
            exploit = {
                burst_choke = 0,
                confidence = 0.5
            },
            shot_outcome = {
                hits = { [-1] = 0, [0] = 0, [1] = 0 },
                misses = { [-1] = 0, [0] = 0, [1] = 0 },
                confidence = 0.5
            }
        },
        
        confidence = 50,
        fused_side = 0,
        
        pattern_stability = 0,
        pattern_transitions = {},
        
        predictive = {
            next_side = 0,
            next_jitter = 0,
            next_defensive = false
        },
        
        side_learning = {
            standing  = { [-1] = 0.5, [0] = 0.5, [1] = 0.5 },
            moving    = { [-1] = 0.5, [0] = 0.5, [1] = 0.5 },
            air       = { [-1] = 0.5, [0] = 0.5, [1] = 0.5 },
            defensive = { [-1] = 0.5, [0] = 0.5, [1] = 0.5 },
            exploit   = { [-1] = 0.5, [0] = 0.5, [1] = 0.5 }
        },
        
        exploit_analysis = {
            double_tap = false,
            hide_shots = false,
            fake_lag = false,
            tickbase_manip = false,
            recharge = false,
            lc_broken = false,
            exploit_confidence = 0.0
        },
        
        adaptive_desync = {
            estimated_limit = 58.0,
            min_body_yaw = -58.0,
            max_body_yaw = 58.0,
            observed_max_delta = 58.0
        },
        
        resolver_lock = {
            locked = false,
            locked_side = 0,
            lock_ticks = 0
        },
        
        miss_analysis = {
            resolver_misses = 0,
            spread_misses = 0,
            prediction_misses = 0,
            safepoint_misses = 0,
            occlusion_misses = 0
        },
        
        threat_intel = {
            shots_fired = 0,
            hits_on_us = 0,
            accuracy = 50.0,
            aggression = 50.0,
            threat_score = 50.0
        },
        
        markov_prev_side = nil,
        markov_matrix = {
            [-1] = { [-1] = 0, [0] = 0, [1] = 0 },
            [0]  = { [-1] = 0, [0] = 0, [1] = 0 },
            [1]  = { [-1] = 0, [0] = 0, [1] = 0 }
        },
        markov_accuracy = 0.5,
        markov_shots = 0,
        markov_hits = 0,

        jitter_last_side = 0,
        jitter_side_switch_tick = 0,
        jitter_durations = { 2, 2, 2, 2 },
        jitter_durations_idx = 0,
        jitter_accuracy = 0.5,
        jitter_shots = 0,
        jitter_hits = 0,

        mov_layer_accuracy = 0.5,
        mov_layer_shots = 0,
        mov_layer_hits = 0,
        
        anim_accuracy = 0.5,
        anim_shots = 0,
        anim_hits = 0,
        
        fs_accuracy = 0.5,
        fs_shots = 0,
        fs_hits = 0,

        bayesian_inputs = {
            { side = 0, conf = 0 },
            { side = 0, conf = 0 },
            { side = 0, conf = 0 },
            { side = 0, conf = 0 },
            { side = 0, conf = 0 }
        }
    }
    
    local cur_tick = globals.tickcount
    if type(cur_tick) == "function" then cur_tick = cur_tick() end
    p.last_memory_update_tick = cur_tick or 0
    p.last_freestand_tick = 0
    p.jitter_side_switch_tick = cur_tick or 0
    
    return p
end

local function decayMemory(p)
    local cur_tick = globals.tickcount
    if type(cur_tick) == "function" then cur_tick = cur_tick() end
    cur_tick = cur_tick or 0
    local elapsed = cur_tick - (p.last_memory_update_tick or cur_tick)
    p.last_memory_update_tick = cur_tick
    if elapsed > 0 then
        local decay = 0.99 ^ elapsed
        p.resolver_memory.animation.confidence = p.resolver_memory.animation.confidence * decay + 0.5 * (1 - decay)
        p.resolver_memory.movement.confidence  = p.resolver_memory.movement.confidence * decay + 0.5 * (1 - decay)
        p.resolver_memory.freestand.confidence = p.resolver_memory.freestand.confidence * decay + 0.5 * (1 - decay)
        p.resolver_memory.defensive.confidence = p.resolver_memory.defensive.confidence * decay + 0.5 * (1 - decay)
        p.resolver_memory.exploit.confidence   = p.resolver_memory.exploit.confidence * decay + 0.5 * (1 - decay)
        p.resolver_memory.shot_outcome.confidence = p.resolver_memory.shot_outcome.confidence * decay + 0.5 * (1 - decay)
    end
end

local function performBehaviorClustering(p)
    if p.yaw_count < 6 then return PAT_STATIC, 1.0 end
    
    local yaws = get_temp_table()
    local n = math_min(p.yaw_count, YAW_BUF_SIZE)
    for i = 1, n do
        yaws[i] = p.yaw_buf[i]
    end
    
    table.sort(yaws)
    
    local clusters = get_temp_table()
    local c_idx = 1
    clusters[1] = { sum = yaws[1], count = 1, min_val = yaws[1], max_val = yaws[1] }
    
    for i = 2, n do
        local val = yaws[i]
        local current = clusters[c_idx]
        if math_abs(val - current.sum / current.count) < 18 then
            current.sum = current.sum + val
            current.count = current.count + 1
            current.max_val = val
        else
            c_idx = c_idx + 1
            clusters[c_idx] = { sum = val, count = 1, min_val = val, max_val = val }
        end
    end
    
    local num_clusters = c_idx
    local pattern = PAT_STATIC
    local conf = 0.5
    
    if num_clusters == 1 then
        local var = clusters[1].max_val - clusters[1].min_val
        if var < 3 then
            pattern = PAT_STATIC
            conf = 0.95
        else
            pattern = PAT_RANDOM_JIT
            conf = 0.6
        end
    elseif num_clusters == 2 then
        local dist = math_abs(clusters[1].sum/clusters[1].count - clusters[2].sum/clusters[2].count)
        pattern = dist > 30 and PAT_JITTER or PAT_MICRO_JIT
        conf = dist > 30 and 0.85 or 0.8
    else
        pattern = PAT_DELAYED_JIT
        conf = 0.75
    end
    
    for idx = 1, num_clusters do
        release_temp_table(clusters[idx])
    end
    release_temp_table(clusters)
    release_temp_table(yaws)
    
    return pattern, conf
end

local function profilerUpdate(p, eye_yaw, feet_yaw, speed, duck, sim_time)
    p.yaw_idx = (p.yaw_idx % YAW_BUF_SIZE) + 1
    p.yaw_buf[p.yaw_idx] = eye_yaw
    if p.yaw_count < YAW_BUF_SIZE then p.yaw_count = p.yaw_count + 1 end
    p.feet_delta = normalizeYaw(eye_yaw - feet_yaw)
    
    local clustered_pat, clustered_conf = performBehaviorClustering(p)
    local last_pattern = p.pattern
    
    local is_defensive = sw_antidef:get() and (p.exploit_analysis.tickbase_manip or (speed < 15 and p.choke >= 5 and math_abs(p.feet_delta) > 35))
    local current_pattern = clustered_pat
    
    if is_defensive then
        current_pattern = PAT_DEFENSIVE
    end
    
    if current_pattern == PAT_JITTER and p.choke >= 5 then
        current_pattern = PAT_HYBRID
    end
    
    p.pattern = current_pattern
    
    if current_pattern == last_pattern then
        p.pattern_stability = p.pattern_stability + 1
    else
        p.pattern_stability = 0
        p.pattern_transitions[last_pattern] = p.pattern_transitions[last_pattern] or {}
        p.pattern_transitions[last_pattern][current_pattern] = (p.pattern_transitions[last_pattern][current_pattern] or 0) + 1
    end
end

local function defensiveUpdate(p, sim_time, speed, feet_yaw, prev_feet_yaw)
    local ti = p.tick_interval
    local det = p.exploit_analysis
    
    p.def_checks = p.def_checks + 1
    local spike = false
    if p.choke >= 5 then spike = true end
    
    local sim_delta = sim_time - p.curr_sim_time
    det.double_tap = false
    det.hide_shots = false
    det.tickbase_manip = false
    det.fake_lag = false
    det.recharge = false
    det.lc_broken = false
    
    if p.curr_sim_time > 0 and sim_time > 0 then
        if sim_delta < -ti * 0.5 or sim_delta > ti * 3 then
            p.def_gap_hits = p.def_gap_hits + 1
            spike = true
            det.tickbase_manip = true
            if sim_delta > 0 then
                det.double_tap = true
            else
                det.hide_shots = true
            end
        end
        
        local ex, ey, ez = SafeGetOrigin(getEntity(p.id))
        local px, py, pz = p.ox, p.oy, p.oz
        local dist = math_sqrt((ex - px)^2 + (ey - py)^2 + (ez - pz)^2)
        if dist > 64 and speed > 15 then
            det.lc_broken = true
        end
        
        if p.choke > 12 then
            det.fake_lag = true
        end
        
        if p.choke == 0 and speed < 5 and p.defensive_freq > 30 then
            det.recharge = true
        end
    end
    
    if speed < 5 and prev_feet_yaw ~= 0 then
        local fyaw_jump = math_abs(yawDelta(feet_yaw, prev_feet_yaw))
        if fyaw_jump > 45 then
            p.def_anim_resets = p.def_anim_resets + 1
            spike = true
        end
    end

    if spike then
        p.def_spikes = p.def_spikes + 1
    end

    p.defensive_freq = p.def_checks > 0
        and (p.def_spikes / p.def_checks * 100)
        or 0.0

    p.resolver_memory.defensive.confidence = clamp(p.defensive_freq / 100, 0.1, 0.9)
    
    local score = 0.0
    if det.double_tap then score = score + 0.5 end
    if det.hide_shots then score = score + 0.4 end
    if det.tickbase_manip then score = score + 0.3 end
    if det.fake_lag then score = score + 0.2 end
    if det.recharge then score = score + 0.3 end
    if det.lc_broken then score = score + 0.4 end
    
    det.exploit_confidence = clamp(score, 0.0, 1.0)
    p.resolver_memory.exploit.confidence = det.exploit_confidence

    p.curr_sim_time = sim_time
end

local function updateAdvancedFreestand(p, ent)
    local cur_tick = globals.tickcount
    if type(cur_tick) == "function" then cur_tick = cur_tick() end
    cur_tick = cur_tick or 0
    
    local is_threat = (client.current_threat() == p.id)
    if p.last_freestand_tick and (cur_tick - p.last_freestand_tick < 3) and not is_threat then
        return
    end
    p.last_freestand_tick = cur_tick
    
    local lp = entity.get_local_player()
    if not lp then return end
    
    local head_pos = ent:get_eye_position()
    local lp_pos = lp:get_eye_position()
    if not head_pos or not lp_pos then return end
    
    local dir = (head_pos - lp_pos):normalized()
    local left_dir = vector(-dir.y, dir.x, 0)
    local right_dir = vector(dir.y, -dir.x, 0)
    
    local test_offsets = { 0, 18, 36 }
    local height_offsets = { 0, -25, -45 }
    
    local left_exposure = 0
    local right_exposure = 0
    local left_wall_thickness = 0
    local right_wall_thickness = 0
    
    local total_traces = 0
    
    for _, height in ipairs(height_offsets) do
        local enemy_center = head_pos + vector(0, 0, height)
        
        for _, offset in ipairs(test_offsets) do
            local left_pt = enemy_center + left_dir * offset
            local right_pt = enemy_center + right_dir * offset
            
            local tr_l = utils.trace_line(lp_pos, left_pt, lp)
            local tr_r = utils.trace_line(lp_pos, right_pt, lp)
            
            left_exposure = left_exposure + tr_l.fraction
            right_exposure = right_exposure + tr_r.fraction
            
            if tr_l.fraction < 1.0 then
                local back_tr_l = utils.trace_line(left_pt, lp_pos, ent)
                left_wall_thickness = left_wall_thickness + (1.0 - back_tr_l.fraction)
            end
            if tr_r.fraction < 1.0 then
                local back_tr_r = utils.trace_line(right_pt, lp_pos, ent)
                right_wall_thickness = right_wall_thickness + (1.0 - back_tr_r.fraction)
            end
            
            total_traces = total_traces + 1
        end
    end
    
    local avg_left_exp = left_exposure / total_traces
    local avg_right_exp = right_exposure / total_traces
    
    local side = 0
    local conf = 0.5
    if avg_left_exp < avg_right_exp then
        side = -1
        conf = 0.5 + (avg_right_exp - avg_left_exp) * 0.5
    elseif avg_right_exp < avg_left_exp then
        side = 1
        conf = 0.5 + (avg_left_exp - avg_right_exp) * 0.5
    end
    
    p.freestand_side = side
    p.resolver_memory.freestand.confidence = clamp(conf, 0.1, 0.95)
    p.resolver_memory.freestand.exposure_left = avg_left_exp
    p.resolver_memory.freestand.exposure_right = avg_right_exp
end

local function updateDesyncModel(p, ent)
    local anim = SafeGetAnimState(ent)
    if not anim then return end
    
    local min_yaw = anim.m_flMinBodyYaw or -58.0
    local max_yaw = anim.m_flMaxBodyYaw or 58.0
    
    local current_delta = math_abs(p.feet_delta)
    if current_delta > p.adaptive_desync.observed_max_delta then
        p.adaptive_desync.observed_max_delta = clamp(current_delta, 10.0, 58.0)
    end
    
    local base_limit = p.desync_limit
    local estimated = clamp(p.adaptive_desync.observed_max_delta, 15.0, base_limit)
    
    p.adaptive_desync.estimated_limit = estimated
    p.adaptive_desync.min_body_yaw = min_yaw
    p.adaptive_desync.max_body_yaw = max_yaw
end

local function updateMarkovTransitions(p, current_side)
    local prev = p.markov_prev_side
    p.markov_prev_side = current_side
    if not prev then return end
    
    p.markov_matrix[prev] = p.markov_matrix[prev] or { [-1] = 0, [0] = 0, [1] = 0 }
    p.markov_matrix[prev][current_side] = p.markov_matrix[prev][current_side] + 1
end

local function predictMarkovSide(p)
    local cur = p.resolved_side
    local matrix = p.markov_matrix[cur]
    if not matrix then return cur, 0.33 end
    
    local sum = (matrix[-1] or 0) + (matrix[0] or 0) + (matrix[1] or 0)
    if sum == 0 then return cur, 0.33 end
    
    local best_side = cur
    local best_prob = 0
    for _, s in ipairs({-1, 0, 1}) do
        local prob = (matrix[s] or 0) / sum
        if prob > best_prob then
            best_prob = prob
            best_side = s
        end
    end
    
    return best_side, best_prob
end

local function updateJitterCycle(p, current_side)
    local cur_tick = globals.tickcount
    if type(cur_tick) == "function" then cur_tick = cur_tick() end
    cur_tick = cur_tick or 0
    
    if current_side ~= p.jitter_last_side then
        local duration = cur_tick - p.jitter_side_switch_tick
        p.jitter_side_switch_tick = cur_tick
        p.jitter_last_side = current_side
        p.jitter_durations_idx = (p.jitter_durations_idx % 4) + 1
        p.jitter_durations[p.jitter_durations_idx] = duration
    end
end

local function predictJitterCycleSide(p)
    local cur_tick = globals.tickcount
    if type(cur_tick) == "function" then cur_tick = cur_tick() end
    cur_tick = cur_tick or 0
    
    local sum = 0
    local count = 0
    for i = 1, 4 do
        local d = p.jitter_durations[i] or 0
        if d > 0 then
            sum = sum + d
            count = count + 1
        end
    end
    
    if count == 0 then return p.resolved_side, 0.5 end
    local avg_period = math_floor(sum / count + 0.5)
    
    local ticks_since_switch = cur_tick - p.jitter_side_switch_tick
    if ticks_since_switch >= avg_period then
        return -p.jitter_last_side, 0.8
    else
        return p.jitter_last_side, 0.7
    end
end

local function resolveMovementLayer(p, layers)
    if not layers then return 0, 0.5 end
    local layer6 = layers[6]
    local l6_weight = layer6.m_flWeight
    local l6_rate = layer6.m_flPlaybackRate
    
    local predicted_speed = l6_rate * 260.0
    local delta = math_abs(predicted_speed - p.speed)
    
    local resolved_side = 0
    local confidence = 0.5
    if delta > 30 then
        resolved_side = p.feet_delta > 0 and -1 or 1
        confidence = clamp(delta / 100, 0.5, 0.9)
    end
    return resolved_side, confidence
end

local function analyzeBalanceAdjust(p, layers)
    if not layers then return 0, 0.5 end
    local layer3 = layers[3]
    local l3_weight = layer3.m_flWeight
    local l3_cycle = layer3.m_flCycle
    
    local resolved_side = 0
    local confidence = 0.5
    if l3_weight > 0.1 then
        resolved_side = p.feet_delta > 0 and -1 or 1
        confidence = clamp(l3_weight * 0.9, 0.5, 0.95)
    end
    return resolved_side, confidence
end

local function predictResolverState(p, layers)
    local pat = p.pattern
    local side = p.resolved_side
    
    p.predictive.next_jitter = 0
    p.predictive.next_defensive = false
    
    local predicted_side = side
    local pred_conf = 0.5
    
    if pat == PAT_JITTER or pat == PAT_MICRO_JIT or pat == PAT_HYBRID then
        local jit_side, jit_conf = predictJitterCycleSide(p)
        predicted_side = jit_side
        pred_conf = jit_conf
    elseif pat == PAT_DELAYED_JIT then
        local jit_side, jit_conf = predictJitterCycleSide(p)
        predicted_side = jit_side
        pred_conf = jit_conf
    elseif pat == PAT_SPIN then
        local rate = p.yaw_count >= 2 and yawDelta(p.yaw_buf[p.yaw_idx], p.yaw_buf[((p.yaw_idx - 2) % YAW_BUF_SIZE) + 1]) or 0
        predicted_side = rate > 0 and 1 or -1
        pred_conf = 0.7
    elseif pat == PAT_DEFENSIVE then
        predicted_side = -side
        pred_conf = 0.8
        p.predictive.next_defensive = true
    else
        local m_side, m_conf = predictMarkovSide(p)
        predicted_side = m_side
        pred_conf = m_conf
    end
    
    p.predictive.next_side = predicted_side
    p.resolver_memory.animation.confidence = clamp(pred_conf, 0.1, 0.95)
end

local function performBayesianFusion(p, layers)
    local sides = { -1, 0, 1 }
    local probs = { [-1] = 0.333, [0] = 0.333, [1] = 0.333 }
    
    local inputs = p.bayesian_inputs
    local n_inputs = 0
    
    local anim_side = p.predictive.next_side
    local anim_conf = p.anim_accuracy
    if anim_side and anim_conf > 0.05 then
        n_inputs = n_inputs + 1
        inputs[n_inputs].side = anim_side
        inputs[n_inputs].conf = anim_conf
    end
    
    local fs_side = p.freestand_side
    local fs_conf = p.fs_accuracy
    if fs_side and fs_conf > 0.05 then
        n_inputs = n_inputs + 1
        inputs[n_inputs].side = fs_side
        inputs[n_inputs].conf = fs_conf
    end
    
    local mv_side, mv_conf = resolveMovementLayer(p, layers)
    local mv_weight = p.mov_layer_accuracy
    if mv_side ~= 0 and mv_conf > 0.05 then
        n_inputs = n_inputs + 1
        inputs[n_inputs].side = mv_side
        inputs[n_inputs].conf = mv_conf * mv_weight
    end

    local bal_side, bal_conf = analyzeBalanceAdjust(p, layers)
    if bal_side ~= 0 and bal_conf > 0.05 then
        n_inputs = n_inputs + 1
        inputs[n_inputs].side = bal_side
        inputs[n_inputs].conf = bal_conf * 0.7
    end
    
    local state = getTargetState(p)
    local state_learning = p.side_learning[state]
    local learn_best_side = 0
    local learn_max_val = 0
    for _, s in ipairs(sides) do
        local rate = state_learning[s] or 0.5
        if rate > learn_max_val then
            learn_max_val = rate
            learn_best_side = s
        end
    end
    if learn_max_val > 0.55 then
        n_inputs = n_inputs + 1
        inputs[n_inputs].side = learn_best_side
        inputs[n_inputs].conf = learn_max_val
    end

    for i = 1, n_inputs do
        local inp = inputs[i]
        local s_pred = inp.side
        local c = clamp(inp.conf, 0.01, 0.99)
        
        local sum = 0
        local temp_probs = get_temp_table()
        for _, s in ipairs(sides) do
            local likelihood = (s == s_pred) and c or ((1 - c) / 2)
            temp_probs[s] = probs[s] * likelihood
            sum = sum + temp_probs[s]
        end
        if sum > 0 then
            for _, s in ipairs(sides) do
                probs[s] = temp_probs[s] / sum
            end
        end
        release_temp_table(temp_probs)
    end
    
    local best_side = 0
    local best_prob = 0
    for _, s in ipairs(sides) do
        if probs[s] > best_prob then
            best_prob = probs[s]
            best_side = s
        end
    end
    
    p.fused_side = best_side
    p.confidence = math_floor(best_prob * 100)
end

local function updateResolverLock(p)
    local lock = p.resolver_lock
    if lock.locked then
        if p.confidence < 45 then
            lock.locked = false
            lock.lock_ticks = 0
        else
            lock.lock_ticks = lock.lock_ticks - 1
            if lock.lock_ticks <= 0 then
                lock.locked = false
            end
        end
    else
        if p.confidence >= 80 then
            lock.locked = true
            lock.locked_side = p.fused_side
            
            local base_duration = 3
            if p.pattern == PAT_STATIC then
                base_duration = 8
            elseif p.pattern == PAT_DELAYED_JIT then
                base_duration = 5
            elseif p.pattern == PAT_JITTER then
                base_duration = 2
            end
            lock.lock_ticks = base_duration + clamp(math_floor(p.pattern_stability / 5), 0, 4)
        end
    end
end

local function updateThreatIntel(p, ent)
    local lp = entity.get_local_player()
    if not lp then return end
    
    local lx, ly, lz = SafeGetOrigin(lp)
    local ex, ey, ez = SafeGetOrigin(ent)
    local dist = math_sqrt((lx - ex)^2 + (ly - ey)^2 + (lz - ez)^2) * 0.0254
    
    local dist_factor = clamp((150 - dist) / 1.5, 0, 100)
    local fire_factor = (p.threat_intel.shots_fired > 0) and 30 or 0
    p.threat_intel.aggression = dist_factor * 0.7 + fire_factor * 0.3
    
    local acc = 50.0
    if p.threat_intel.shots_fired > 0 then
        acc = (p.threat_intel.hits_on_us / p.threat_intel.shots_fired) * 100
    end
    p.threat_intel.accuracy = acc
    
    local hp = SafeGetHP(ent)
    p.threat_intel.threat_score = (100 - hp) * 0.20
                                + p.threat_intel.aggression * 0.30
                                + p.threat_intel.accuracy * 0.30
                                + p.exploit_analysis.exploit_confidence * 20
end

local function computeBrute(p, eye_yaw, layers)
    decayMemory(p)
    predictResolverState(p, layers)
    performBayesianFusion(p, layers)
    updateResolverLock(p)
    
    local final_side = 0
    local final_delta = p.adaptive_desync.estimated_limit
    
    if p.resolver_lock.locked then
        final_side = p.resolver_lock.locked_side
    else
        final_side = p.fused_side
    end
    
    local cm = p.consecutive_resolver_misses
    if cm > 0 then
        p.resolver_lock.locked = false
        local step = cm % 3
        if step == 1 then
            final_side = -final_side
        elseif step == 2 then
            final_side = 0
        end
        final_delta = final_delta * 0.75
    end
    
    p.resolved_side = final_side
    p.resolved_delta = clamp(final_delta, 10.0, p.desync_limit)
end

local function updatePlayer(p, ent)
    local ok_alive, alive = pcall(function() return ent:is_alive()   end)
    if not ok_alive or not alive then return end
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
    
    local new_tick = (sim_time > p.curr_sim_time)
    if new_tick then
        p.original_feet_yaw = feet_yaw
        p.last_speed = p.speed
    end

    if p.original_feet_yaw == 0.0 then
        p.original_feet_yaw = feet_yaw
    end
    
    if p.curr_sim_time > 0 and sim_time > 0 then
        local ti = p.tick_interval
        local dt = sim_time - p.curr_sim_time
        p.choke = dt > 0 and clamp(math_floor(dt / ti + 0.5) - 1, 0, 16) or 0
        p.lc_broken = (dt > ti * 2) and (speed > 15)
    end
    
    p.speed      = speed
    p.duck       = duck
    p.on_ground  = on_ground
    p.desync_limit = getDesyncLimit(speed, duck, on_ground)

    local layers = SafeGetAnimLayers(ent)

    updateAdvancedFreestand(p, ent)
    updateDesyncModel(p, ent)
    
    profilerUpdate(p, eye_yaw, p.original_feet_yaw, speed, duck, sim_time)
    defensiveUpdate(p, sim_time, speed, p.original_feet_yaw, p.prev_feet_yaw)
    
    updateMarkovTransitions(p, p.resolved_side)
    updateJitterCycle(p, p.resolved_side)
    updateThreatIntel(p, ent)
    
    p.prev_feet_yaw = p.original_feet_yaw
    
    computeBrute(p, eye_yaw, layers)
    
    local resolved_y = normalizeYaw(eye_yaw + p.resolved_side * p.resolved_delta)
    anim.m_flGoalFeetYaw    = resolved_y
    anim.m_flCurrentFeetYaw = resolved_y
end

local function shouldForceBAIM(p, hp)
    if not sw_lethal:get() then return false end
    if not p then return false end

    local conf = p.confidence or 100
    local cm   = p.consecutive_resolver_misses

    local is_lethal = hp <= 35 or (hp <= 65 and cm >= 1)
    local low_reliability = (conf < 35) or (cm >= 2)
    
    if is_lethal then return true end
    if low_reliability then return true end
    if p.pattern == PAT_SPIN or p.pattern == PAT_DEFENSIVE or p.pattern == PAT_HYBRID then return true end
    
    return false
end

local function shouldPreferSafe(p)
    if not sw_safepoint:get() then return false end
    if not p then return false end

    local conf = p.confidence or 100
    local cm   = p.consecutive_resolver_misses
    local active_exploit = p.exploit_analysis.exploit_confidence > 0.4
    
    if cm >= 1 then return true end
    if conf < 65 then return true end
    if p.choke > 6 or active_exploit then return true end
    if p.pattern == PAT_JITTER or p.pattern == PAT_DELAYED_JIT or p.pattern == PAT_HYBRID then return true end
    
    local accel = math_abs(p.speed - (p.last_speed or p.speed))
    if accel > 45 then return true end

    return false
end

local function getThreatScore(ent, lp_x, lp_y, lp_z)
    local ex, ey, ez = SafeGetOrigin(ent)
    local dist = math_sqrt((lp_x-ex)^2 + (lp_y-ey)^2 + (lp_z-ez)^2) * 0.0254
    local ok_vis, vis = pcall(function() return ent:is_visible() end)
    local dist_score  = clamp(100 - dist, 0, 100)
    return dist_score * 0.7 + ((ok_vis and vis) and 30 or 0) * 0.3
end

local function getFovToLocalPlayer(ent, lp_pos)
    local ent_pos = ent:get_eye_position()
    if not ent_pos or not lp_pos then return 180 end
    
    local anim = SafeGetAnimState(ent)
    if not anim then return 180 end
    
    local eye_yaw = anim.m_flEyeYaw
    
    local dx_val = lp_pos.x - ent_pos.x
    local dy_val = lp_pos.y - ent_pos.y
    local yaw_to_lp = math_atan2(dy_val, dx_val) * (180 / math_pi)
    
    local delta_yaw = math_abs(yawDelta(eye_yaw, yaw_to_lp))
    return delta_yaw
end

local function getBestTarget(enemies)
    if not sw_priority:get() then
        for i = 1, #enemies do
            local e = enemies[i]
            local ok_a, a = pcall(function() return e:is_alive()   end)
            local ok_d, d = pcall(function() return e:is_dormant() end)
            if ok_a and a and ok_d and not d then return e end
        end
        return nil
    end

    local lp = entity.get_local_player()
    if not lp then return nil end
    local lx, ly, lz = SafeGetOrigin(lp)

    local best_ent, best_score = nil, -math.huge

    for i = 1, #enemies do
        local e = enemies[i]
        local ok_a, a = pcall(function() return e:is_alive()   end)
        local ok_d, d = pcall(function() return e:is_dormant() end)
        if ok_a and a and ok_d and not d then
            local ok_id, eid = pcall(function() return e:get_index() end)
            if ok_id then
                local p  = EnemyRecords[eid]
                local score = p and p.threat_intel.threat_score or getThreatScore(e, lx, ly, lz)

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

local function updatePredictorAccuracy(p, shot_side, was_hit, shot)
    if was_hit then
        if shot.pred_anim == shot_side then p.anim_accuracy = clamp(p.anim_accuracy * 0.92 + 0.08, 0.1, 0.95) end
        if shot.pred_fs == shot_side then p.fs_accuracy = clamp(p.fs_accuracy * 0.92 + 0.08, 0.1, 0.95) end
        if shot.pred_markov == shot_side then p.markov_accuracy = clamp(p.markov_accuracy * 0.92 + 0.08, 0.1, 0.95) end
        if shot.pred_jitter == shot_side then p.jitter_accuracy = clamp(p.jitter_accuracy * 0.92 + 0.08, 0.1, 0.95) end
        if shot.pred_mov_layer == shot_side then p.mov_layer_accuracy = clamp(p.mov_layer_accuracy * 0.92 + 0.08, 0.1, 0.95) end
    else
        if shot.pred_anim == shot_side then p.anim_accuracy = clamp(p.anim_accuracy * 0.92, 0.1, 0.95) end
        if shot.pred_fs == shot_side then p.fs_accuracy = clamp(p.fs_accuracy * 0.92, 0.1, 0.95) end
        if shot.pred_markov == shot_side then p.markov_accuracy = clamp(p.markov_accuracy * 0.92, 0.1, 0.95) end
        if shot.pred_jitter == shot_side then p.jitter_accuracy = clamp(p.jitter_accuracy * 0.92, 0.1, 0.95) end
        if shot.pred_mov_layer == shot_side then p.mov_layer_accuracy = clamp(p.mov_layer_accuracy * 0.92, 0.1, 0.95) end
    end
end

register_event("aim_fire", function(e)
    if not e then return end
    local p = EnemyRecords[e.target]
    if not p then return end
    
    local layers = SafeGetAnimLayers(getEntity(e.target))
    local mv_side, _ = resolveMovementLayer(p, layers)
    local m_side, _ = predictMarkovSide(p)
    local j_side, _ = predictJitterCycleSide(p)
    
    aimbot_data[e.id] = {
        target   = e.target,
        side     = p and p.resolved_side or 0,
        hitgroup = e.hitgroup,
        pred_anim = p and p.predictive.next_side or 0,
        pred_fs = p and p.freestand_side or 0,
        pred_markov = m_side,
        pred_jitter = j_side,
        pred_mov_layer = mv_side
    }
end)

register_event("aim_ack", function(e)
    if not e then return end
    local shot = aimbot_data[e.id]
    if not shot then return end
    aimbot_data[e.id] = nil

    local p = EnemyRecords[shot.target]
    if not p then return end

    p.consecutive_misses = 0
    p.consecutive_resolver_misses = 0

    if shot.side == p.resolved_side then
        p.side_lock_count = p.side_lock_count + 1
        if p.side_lock_count >= 3 then p.side_lock = true end
    else
        p.side_lock_count = 1
        p.side_lock = false
    end

    local side = shot.side
    if side == -1 then
        p.left_hits = p.left_hits + 1
    elseif side == 1 then
        p.right_hits = p.right_hits + 1
    else
        p.center_hits = p.center_hits + 1
    end

    local state = getTargetState(p)
    p.side_learning[state][side] = clamp(p.side_learning[state][side] * 0.85 + 0.15, 0.05, 0.95)
    
    p.resolver_memory.shot_outcome.hits[side] = (p.resolver_memory.shot_outcome.hits[side] or 0) + 1
    p.resolver_memory.shot_outcome.confidence = clamp(p.resolver_memory.shot_outcome.confidence * 0.9 + 0.1, 0.5, 0.99)
    
    updatePredictorAccuracy(p, side, true, shot)

    writeShotBuf(p.shot_buf, shot.target, side, e.hitgroup, true, "")
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
        p.miss_analysis.resolver_misses = p.miss_analysis.resolver_misses + 1
        p.consecutive_resolver_misses = p.consecutive_resolver_misses + 1
        p.side_lock       = false
        p.side_lock_count = 0
        
        local state = getTargetState(p)
        local side = shot.side
        p.side_learning[state][side] = clamp(p.side_learning[state][side] * 0.85, 0.05, 0.95)
        
        updatePredictorAccuracy(p, side, false, shot)
    elseif reason == "spread" then
        p.miss_analysis.spread_misses = p.miss_analysis.spread_misses + 1
    elseif reason == "prediction" or reason == "prediction error" then
        p.miss_analysis.prediction_misses = p.miss_analysis.prediction_misses + 1
    elseif reason == "occlusion" or reason == "wall" then
        p.miss_analysis.occlusion_misses = p.miss_analysis.occlusion_misses + 1
    end
    
    p.consecutive_misses = p.consecutive_misses + 1

    local side = shot.side
    if side == -1 then
        p.left_misses = p.left_misses + 1
    elseif side == 1 then
        p.right_misses = p.right_misses + 1
    else
        p.center_misses = p.center_misses + 1
    end

    p.resolver_memory.shot_outcome.misses[side] = (p.resolver_memory.shot_outcome.misses[side] or 0) + 1
    
    writeShotBuf(p.shot_buf, shot.target, side, shot.hitgroup, false, reason)
end)

register_event("player_hurt", function(e)
    if not e then return end
    local lp = entity.get_local_player()
    if not lp then return end
    local lp_idx = lp:get_index()
    
    local victim_ent = getPlayerByUserid(e.userid)
    local attacker_ent = getPlayerByUserid(e.attacker)
    
    if victim_ent and victim_ent:get_index() == lp_idx and attacker_ent then
        local attacker_idx = attacker_ent:get_index()
        local p = EnemyRecords[attacker_idx]
        if p then
            p.threat_intel.hits_on_us = p.threat_intel.hits_on_us + 1
        end
    end
end)

register_event("weapon_fire", function(e)
    if not e then return end
    local shooter_ent = getPlayerByUserid(e.userid)
    if shooter_ent then
        local shooter_idx = shooter_ent:get_index()
        local p = EnemyRecords[shooter_idx]
        if p then
            p.threat_intel.shots_fired = p.threat_intel.shots_fired + 1
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
