local MockRemoteEvent = {}

function MockRemoteEvent:new()
    local event = {
        connections = {},
        clientEvents = {}  -- Store events fired to clients
    }
    setmetatable(event, self)
    self.__index = self
    return event
end

-- Mock the OnServerEvent connection
function MockRemoteEvent:Connect(callback)
    table.insert(self.connections, callback)
    return {
        Disconnect = function() 
            -- Find and remove the callback from connections
            for i, conn in ipairs(self.connections) do
                if conn == callback then
                    table.remove(self.connections, i)
                    break
                end
            end
        end
    }
end

-- Mock firing an event from client to server (for testing)
function MockRemoteEvent:FireServer(player, ...)
    for _, callback in ipairs(self.connections) do
        callback(player, ...)
    end
end

-- Mock firing an event from server to client
function MockRemoteEvent:FireClient(player, ...)
    table.insert(self.clientEvents, {
        player = player,
        args = {...}
    })
end

-- Helper method to get all client events (for testing)
function MockRemoteEvent:getClientEvents()
    return self.clientEvents
end

-- Helper method to clear client events (for testing)
function MockRemoteEvent:clearClientEvents()
    self.clientEvents = {}
end

-- Mock the OnServerEvent property
MockRemoteEvent.OnServerEvent = {
    Connect = function(self, callback)
        return MockRemoteEvent.Connect(self, callback)
    end
}

return MockRemoteEvent