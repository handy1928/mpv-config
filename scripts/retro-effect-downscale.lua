-- retro-effect-downscale.lua
-- Downscales video to create a vintage/retro effect.

-------------------------------------------------------------------------------
-- CONFIGURATION
-------------------------------------------------------------------------------
-- Upscale method used to display the low-res video on your screen:
-- "keep"     : Keeps your normal mpv scaler (e.g. spline36) -> smooth, natural low-res look (no sharp blocks)
-- "bilinear" : Soft, slightly blurry vintage look (authentic early YouTube / CRT feel)
-- "bicubic"  : Balanced, slightly sharper vintage smoothing
-- "nearest"  : Sharp, chunky pixel-art blocks (if you ever want the Minecraft look back)
local UPSCALE_FILTER = "keep"

-- Algorithm used to downsample the video frames:
-- "area"     : Averages pixels smoothly (clean downsampling, no crawling edges)
-- "bilinear" : Fast bilinear downscaling
local DOWNSCALE_ALGO = "bilinear"

-- Available retro height presets (720p, 480p, 360p)
local PRESETS = {
    { label = "Disabled",          height = 0   },
    { label = "480p (DVD / CRT)",  height = 480 },
    { label = "360p (Early Web)",  height = 360 },
    { label = "600p",              height = 600 },
    { label = "720p (2000s HD)",   height = 720 },
}

-------------------------------------------------------------------------------
-- STATE
-------------------------------------------------------------------------------
local current_idx = 1
local last_active_idx = 3   -- Default when toggling on (480p)
local saved_scale = nil
local saved_cscale = nil

-------------------------------------------------------------------------------
-- CORE LOGIC
-------------------------------------------------------------------------------
local function apply_state()
    local preset = PRESETS[current_idx]

    if preset.height == 0 then
        -- Remove the downscaling filter
        mp.commandv("vf", "remove", "@retro")

        -- Restore original upscaler if we modified it
        if saved_scale then
            mp.set_property("scale", saved_scale)
            mp.set_property("cscale", saved_cscale)
            saved_scale = nil
            saved_cscale = nil
        end

        mp.osd_message("Retro Effect: Disabled", 2)
    else
        -- Adjust upscaler only if not set to "keep"
        if UPSCALE_FILTER ~= "keep" then
            if not saved_scale then
                saved_scale = mp.get_property("scale") or "bilinear"
                saved_cscale = mp.get_property("cscale") or "bilinear"
            end
            mp.set_property("scale", UPSCALE_FILTER)
            mp.set_property("cscale", UPSCALE_FILTER)
        end

        -- Replace/apply the downscale filter
        mp.commandv("vf", "remove", "@retro")
        local filter_str = string.format("@retro:lavfi=[scale=-2:%d:flags=%s]", preset.height, DOWNSCALE_ALGO)
        mp.commandv("vf", "add", filter_str)

        last_active_idx = current_idx
        mp.osd_message(string.format("Retro Effect: %s (%dp)", preset.label, preset.height), 2)
    end
end

local function toggle_retro()
    if current_idx == 1 then
        current_idx = last_active_idx
    else
        current_idx = 1
    end
    apply_state()
end

local function cycle_retro()
    current_idx = current_idx + 1
    if current_idx > #PRESETS then
        current_idx = 1
    end
    apply_state()
end

local function cycle_retro_prev()
    current_idx = current_idx - 1
    if current_idx < 1 then
        current_idx = #PRESETS
    end
    apply_state()
end

local function retro_up()
    if current_idx > 1 then
        current_idx = current_idx - 1
        apply_state()
    else
        mp.osd_message("Retro Effect: Maximum quality (Disabled)", 1.5)
    end
end

local function retro_down()
    if current_idx < #PRESETS then
        current_idx = current_idx + 1
        apply_state()
    else
        mp.osd_message("Retro Effect: Minimum quality (360p)", 1.5)
    end
end

local function set_retro_height(h)
    local height = tonumber(h)
    if not height or height <= 0 then
        current_idx = 1
    else
        local found = false
        for i, p in ipairs(PRESETS) do
            if p.height == height then
                current_idx = i
                found = true
                break
            end
        end
        if not found then
            PRESETS[#PRESETS + 1] = { label = "Custom", height = height }
            current_idx = #PRESETS
        end
    end
    apply_state()
end

-------------------------------------------------------------------------------
-- SCRIPT MESSAGES
-------------------------------------------------------------------------------
mp.register_script_message("toggle-retro", toggle_retro)
mp.register_script_message("cycle-retro", cycle_retro)
mp.register_script_message("cycle-retro-prev", cycle_retro_prev)
mp.register_script_message("retro-up", retro_up)
mp.register_script_message("retro-down", retro_down)
mp.register_script_message("set-retro-height", set_retro_height)