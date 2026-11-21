-- Builds polarbear.aseprite from the 1x frames polarbear.py writes: one "art" layer, 12fps,
-- one tag per animation. Run through `python3 -I polarbear.py --aseprite`.
--
--   aseprite -b --script-param manifest=<out/manifest.json> --script-param out=<file.aseprite> \
--     --script build-aseprite.lua

local manifestPath, out = app.params.manifest, app.params.out
assert(manifestPath and out, "needs --script-param manifest=... and out=...")
assert(not out:find("/characters/"), "drafts never write into characters/: those files are Kevin's")

local handle = assert(io.open(manifestPath, "r"))
local manifest = json.decode(handle:read("a"))
handle:close()

local sprite = Sprite(27, 18, ColorMode.RGB)
local art = sprite.layers[1]
art.name = "art"

for index, path in ipairs(manifest.frames) do
  if index > #sprite.frames then sprite:newEmptyFrame() end
  local frame = sprite.frames[index]
  frame.duration = 1 / 12
  sprite:newCel(art, frame, Image { fromFile = path }, Point(0, 0))
end

-- Tags after frames: Aseprite stretches a tag over frames added at its end.
for _, tag in ipairs(manifest.tags) do
  local t = sprite:newTag(tag.from + 1, tag.to + 1)
  t.name = tag.name
end

sprite:saveAs(out)
print(out .. ": " .. #sprite.frames .. " frames in " .. #manifest.tags .. " tags")
