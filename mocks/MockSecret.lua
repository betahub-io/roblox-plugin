local MockSecret = {}

function MockSecret:new(value)
    local secret = {
        _value = value
    }
    setmetatable(secret, self)
    self.__index = self
    self.__tostring = function(s)
        return "Secret(" .. tostring(s._name or "unknown") .. ")"
    end
    return secret
end

function MockSecret:AddPrefix(prefix)
    return MockSecret:new(prefix .. self._value)
end

function MockSecret:AddSuffix(suffix)
    return MockSecret:new(self._value .. suffix)
end

function MockSecret:getValue()
    return self._value
end

return MockSecret