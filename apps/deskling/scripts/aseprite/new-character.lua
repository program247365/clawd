-- Makes a starter .aseprite file for a new character: one tag per animation the app uses, each
-- with Clawd traced onto a faded "reference" layer at the same size, timing and ground line, and
-- an empty "art" layer on top to draw on. Draw on "art"; the exporter ignores "reference".
--
--   aseprite -b --script-param clawd=<staged animations dir> --script-param out=<file.aseprite> \
--     --script new-character.lua
--
-- One canvas pixel is one of Clawd's body pixels: 100 units of the 2750 x 1850 Lottie canvas,
-- starting at (36, 50), so the 27 x 18 canvas ends exactly at his feet.

local clawdDir = app.params.clawd
local out = app.params.out
assert(clawdDir and out, "needs --script-param clawd=... and out=...")

local GRID, OX, OY, W, H = 100, 36, 50, 27, 18

-- Tag name, Clawd's animation, and the frames of it to trace (nil: all).
local TAGS = {
  { "walk", "walking", 5, 24 },
  { "stand", "walking", 26, 26 },
  { "wave", "waving" },
  { "look-up", "looking", 12, 12 },
  { "think", "thinking" },
  { "type", "laptop" },
  { "write", "notebook" },
  { "browse", "phone" },
  { "search", "lightbulb" },
  { "delegate", "juggling" },
  { "compact", "meditating" },
  { "celebrate", "confetti-happy" },
}

local function readJSON(path)
  local file = assert(io.open(path, "r"), "cannot read " .. path)
  local text = file:read("a")
  file:close()
  return json.decode(text)
end

-- The value of a Lottie property at frame t: static, or the last hold keyframe at or before t.
local function valueAt(property, t)
  if property.a == 0 then
    return type(property.k) == "table" and property.k[1] or property.k
  end
  local value = 0
  for _, key in ipairs(property.k) do
    if key.t <= t then value = key.s[1] end
  end
  return value
end

local function toColor(c)
  return app.pixelColor.rgba(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5), 255)
end

-- Draws frame t of a Clawd animation into image, sampling each canvas pixel at its centre.
local function trace(animation, t, image)
  for index = #animation.layers, 1, -1 do -- Lottie draws its first layer on top
    local layer = animation.layers[index]
    if t >= (layer.ip or 0) and t < (layer.op or math.huge) then
      for _, group in ipairs(layer.shapes or {}) do
        local fill, rects = nil, {}
        for _, item in ipairs(group.it or {}) do
          if item.ty == "fl" then fill = item end
          if item.ty == "sh" then rects[#rects + 1] = item.ks.k.v end
        end
        if fill and valueAt(fill.o, t) > 0 then
          local color = toColor(fill.c.k)
          for _, v in ipairs(rects) do
            local x0, x1 = math.min(v[1][1], v[3][1]), math.max(v[1][1], v[3][1])
            local y0, y1 = math.min(v[1][2], v[3][2]), math.max(v[1][2], v[3][2])
            for row = 0, H - 1 do
              local cy = OY + row * GRID + GRID / 2
              if cy >= y0 and cy < y1 then
                for col = 0, W - 1 do
                  local cx = OX + col * GRID + GRID / 2
                  if cx >= x0 and cx < x1 then image:drawPixel(col, row, color) end
                end
              end
            end
          end
        end
      end
    end
  end
end

local sprite = Sprite(W, H, ColorMode.RGB)
local reference = sprite.layers[1]
reference.name = "reference"
reference.opacity = 70
local art = sprite:newLayer()
art.name = "art"

-- Frames first, tags after: Aseprite stretches a tag over frames added at its end.
local frameNumber, ranges = 1, {}
for _, spec in ipairs(TAGS) do
  local name, source, first, last = spec[1], spec[2], spec[3], spec[4]
  local animation = readJSON(clawdDir .. "/" .. source .. ".json")
  first = first or animation.ip
  last = last or (animation.op - 1)
  local tagStart = frameNumber
  for t = first, last do
    if frameNumber > #sprite.frames then sprite:newEmptyFrame() end
    local frame = sprite.frames[frameNumber]
    frame.duration = 1 / 12
    local image = Image(W, H, ColorMode.RGB)
    trace(animation, t, image)
    sprite:newCel(reference, frame, image, Point(0, 0))
    frameNumber = frameNumber + 1
  end
  ranges[#ranges + 1] = { name, tagStart, frameNumber - 1 }
end
for _, range in ipairs(ranges) do
  local tag = sprite:newTag(range[2], range[3])
  tag.name = range[1]
end

sprite:saveAs(out)
print(out .. ": " .. #sprite.frames .. " frames in " .. #TAGS .. " tags")
