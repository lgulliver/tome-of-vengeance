local _, ns = ...

local Attribution = {}
Attribution.__index = Attribution

function Attribution.new(window)
  return setmetatable({ window = window or 12, hits = {} }, Attribution)
end

local function prune(self, clock)
  for i = #self.hits, 1, -1 do
    if clock - self.hits[i].clock > self.window then
      table.remove(self.hits, i)
    end
  end
end

function Attribution:note(clock, guid, name)
  prune(self, clock)
  self.hits[#self.hits + 1] = { clock = clock, guid = guid, name = name }
end

function Attribution:killer(clock)
  prune(self, clock)
  local hit = self.hits[#self.hits]
  if hit then return hit.guid, hit.name end
end

function Attribution:drop(name)
  for i = #self.hits, 1, -1 do
    if self.hits[i].name == name then table.remove(self.hits, i) end
  end
end

function Attribution:reset()
  self.hits = {}
end

ns.Attribution = Attribution
