local MockPlayer = {}

function MockPlayer:new(name)
    local player = {
        Name = name or "TestPlayer"
    }
    setmetatable(player, self)
    self.__index = self
    return player
end

return MockPlayer