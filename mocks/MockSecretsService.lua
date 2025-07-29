local MockSecretsService = {}

function MockSecretsService:new(secrets)
    local service = {
        secrets = secrets or {
            BH_PROJECT_ID = "pr-test-project",
            BH_AUTH_TOKEN = "test-token-12345"
        }
    }
    setmetatable(service, self)
    self.__index = self
    return service
end

function MockSecretsService:GetSecret(secretName)
    return self.secrets[secretName]
end

return MockSecretsService