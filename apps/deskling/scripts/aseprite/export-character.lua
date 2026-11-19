-- Exports a character drawn in Aseprite as Lottie files in Clawd's own format: solid pixel squares,
-- one layer per color, frames switched by hold keyframes on fill opacity. Every visible layer is
-- drawn except those whose name starts with "ref".
--
--   aseprite -b --script-param file=<character.aseprite> --script-param out=<character folder> \
--     --script export-character.lua
--
-- Tags: "walk" (the step loop) and "stand" (one frame) become walking.json and meta.json; "wave"
-- becomes waving.json; "look-up" becomes looking.json, eyes up on frame 0; any other tag becomes
-- <tag>.json, and a tag named after a role (think, type, write, browse, search, delegate, compact,
-- celebrate) plays that role.

local file, out = app.params.file, app.params.out
assert(file and out, "needs --script-param file=... and out=...")

local GRID, OX, OY = 100, 36, 50
local FILE_NAMES = { wave = "waving", ["look-up"] = "looking" }

local sprite = app.open(file)
assert(sprite, "cannot open " .. file)
assert(sprite.width == 27 and sprite.height == 18, "the canvas must be 27 x 18, like new-character.lua makes")
for _, layer in ipairs(sprite.layers) do
  if layer.name:lower():sub(1, 3) == "ref" then layer.isVisible = false end
end

local function tagged(name)
  for _, tag in ipairs(sprite.tags) do
    if tag.name == name then return tag end
  end
end

-- Each frame as rows of same-colored runs: { color = {r,g,b}, x0, x1, y }.
local function runs(frameNumber)
  local image = Image(sprite.spec)
  image:drawSprite(sprite, frameNumber)
  local result = {}
  for y = 0, image.height - 1 do
    local x = 0
    while x < image.width do
      local pixel = image:getPixel(x, y)
      if app.pixelColor.rgbaA(pixel) >= 128 then
        local rgb = pixel & 0xFFFFFF
        local x1 = x
        while x1 + 1 < image.width and (image:getPixel(x1 + 1, y) & 0xFFFFFF) == rgb
          and app.pixelColor.rgbaA(image:getPixel(x1 + 1, y)) >= 128 do
          x1 = x1 + 1
        end
        result[#result + 1] = { rgb = rgb, x0 = x, x1 = x1, y = y }
        x = x1 + 1
      else
        x = x + 1
      end
    end
  end
  return result
end

local function num(value)
  if value == math.floor(value) then return string.format("%d", value) end
  return string.format("%.6f", value)
end

local IDENTITY = '{"o":{"a":0,"k":100},"r":{"a":0,"k":0},"p":{"a":0,"k":[0,0,0]},"a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}}'

-- Writes frames (a list of sprite frame numbers) as one Lottie animation.
local function writeAnimation(path, name, frames)
  local count = #frames
  -- color -> list of { signature, rects, frames = set }
  local colors, colorOrder = {}, {}
  for index, frameNumber in ipairs(frames) do
    local byColor = {}
    for _, run in ipairs(runs(frameNumber)) do
      byColor[run.rgb] = byColor[run.rgb] or {}
      table.insert(byColor[run.rgb], run)
    end
    for rgb, list in pairs(byColor) do
      if not colors[rgb] then
        colors[rgb] = {}
        colorOrder[#colorOrder + 1] = rgb
      end
      local parts = {}
      for _, run in ipairs(list) do parts[#parts + 1] = run.x0 .. "," .. run.x1 .. "," .. run.y end
      local signature = table.concat(parts, ";")
      local group
      for _, existing in ipairs(colors[rgb]) do
        if existing.signature == signature then group = existing end
      end
      if not group then
        group = { signature = signature, rects = list, frames = {} }
        table.insert(colors[rgb], group)
      end
      group.frames[index - 1] = true
    end
  end
  table.sort(colorOrder)

  local layers = {}
  for layerIndex, rgb in ipairs(colorOrder) do
    local r, g, b = (rgb & 0xFF) / 255, ((rgb >> 8) & 0xFF) / 255, ((rgb >> 16) & 0xFF) / 255
    local groups = {}
    for _, group in ipairs(colors[rgb]) do
      local items = {}
      for _, run in ipairs(group.rects) do
        local x0, x1 = OX + run.x0 * GRID, OX + (run.x1 + 1) * GRID
        local y0, y1 = OY + run.y * GRID, OY + (run.y + 1) * GRID
        items[#items + 1] = string.format(
          '{"ty":"sh","ks":{"a":0,"k":{"i":[[0,0],[0,0],[0,0],[0,0]],"o":[[0,0],[0,0],[0,0],[0,0]],"v":[[%d,%d],[%d,%d],[%d,%d],[%d,%d]],"c":true}},"nm":"Rect"}',
          x0, y0, x1, y0, x1, y1, x0, y1)
      end
      local keys = {}
      for t = 0, count - 1 do
        keys[#keys + 1] = string.format('{"t":%d,"s":[%d],"h":1}', t, group.frames[t] and 100 or 0)
      end
      items[#items + 1] = string.format('{"ty":"fl","c":{"a":0,"k":[%s,%s,%s,1]},"o":{"a":1,"k":[%s]},"r":1,"bm":0}',
        num(r), num(g), num(b), table.concat(keys, ","))
      items[#items + 1] = '{"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},"s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}'
      groups[#groups + 1] = '{"ty":"gr","it":[' .. table.concat(items, ",") .. '],"nm":"Frame"}'
    end
    layers[#layers + 1] = string.format(
      '{"ddd":0,"ind":%d,"ty":4,"nm":"color_%06x","sr":1,"ks":%s,"ao":0,"shapes":[%s],"ip":0,"op":%d,"st":0,"bm":0}',
      layerIndex, rgb, IDENTITY, table.concat(groups, ","), count)
  end

  local text = string.format(
    '{"v":"5.7.4","fr":12,"ip":0,"op":%d,"w":2750,"h":1850,"nm":"%s","ddd":0,"assets":[],"layers":[%s]}',
    count, name, table.concat(layers, ","))
  local handle = assert(io.open(path, "w"), "cannot write " .. path)
  handle:write(text)
  handle:close()
end

-- meta.json sits in the character folder; the animations get a folder of their own.
local folder = out
out = folder .. "/animations"
app.fs.makeAllDirectories(out)

local function framesOf(tag)
  local list = {}
  for n = tag.fromFrame.frameNumber, tag.toFrame.frameNumber do list[#list + 1] = n end
  return list
end

local walk, stand = tagged("walk"), tagged("stand")
assert(walk and stand, "needs a \"walk\" tag and a \"stand\" tag")
local walking = framesOf(walk)
local cycleEnd = #walking - 1
walking[#walking + 1] = stand.fromFrame.frameNumber
writeAnimation(out .. "/walking.json", "walking", walking)
local meta = assert(io.open(folder .. "/meta.json", "w"))
meta:write(string.format('{"walkCycle":[0,%d],"standingFrame":%d}\n', cycleEnd, cycleEnd + 1))
meta:close()

local written = { "walking" }
for _, tag in ipairs(sprite.tags) do
  if tag.name ~= "walk" and tag.name ~= "stand" then
    local name = FILE_NAMES[tag.name] or tag.name
    writeAnimation(out .. "/" .. name .. ".json", name, framesOf(tag))
    written[#written + 1] = name
  end
end
print(out .. ": " .. table.concat(written, ", "))
