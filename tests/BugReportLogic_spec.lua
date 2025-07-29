-- Add the project root to the package path so we can require our modules
package.path = package.path .. ";./?.lua;./mocks/?.lua;./Server/?.lua"

local BugReportLogic = require("Server.BugReportLogic")
local MockHttpService = require("MockHttpService")
local MockRemoteEvent = require("MockRemoteEvent")
local MockPlayer = require("MockPlayer")
local MockSecret = require("MockSecret")

describe("BugReportLogic", function()
    
    describe("validateIssueDescription", function()
        it("should reject nil input", function()
            local isValid, error = BugReportLogic.validateIssueDescription(nil)
            assert.is_false(isValid)
            assert.equals("Issue description must be a string", error)
        end)
        
        it("should reject non-string input", function()
            local isValid, error = BugReportLogic.validateIssueDescription(123)
            assert.is_false(isValid)
            assert.equals("Issue description must be a string", error)
        end)
        
        it("should reject descriptions shorter than 40 characters", function()
            local shortDescription = "This is too short"
            local isValid, error = BugReportLogic.validateIssueDescription(shortDescription)
            assert.is_false(isValid)
            assert.equals("Bug description must be at least 40 characters.", error)
        end)
        
        it("should accept descriptions with exactly 40 characters", function()
            local exactDescription = "1234567890123456789012345678901234567890" -- exactly 40 chars
            local isValid, error = BugReportLogic.validateIssueDescription(exactDescription)
            assert.is_true(isValid)
            assert.is_nil(error)
        end)
        
        it("should accept descriptions longer than 40 characters", function()
            local longDescription = "This is a much longer description that definitely exceeds the minimum character requirement"
            local isValid, error = BugReportLogic.validateIssueDescription(longDescription)
            assert.is_true(isValid)
            assert.is_nil(error)
        end)
    end)
    
    describe("formatLogs", function()
        it("should return empty string for nil logs", function()
            local result = BugReportLogic.formatLogs(nil)
            assert.equals("", result)
        end)
        
        it("should return empty string for non-table logs", function()
            local result = BugReportLogic.formatLogs("not a table")
            assert.equals("", result)
        end)
        
        it("should format logs correctly", function()
            local logs = {
                {
                    timestamp = 1640995200, -- Jan 1, 2022 00:00:00 UTC
                    messageType = "INFO",
                    message = "Test log message"
                },
                {
                    timestamp = 1640995260, -- Jan 1, 2022 00:01:00 UTC
                    messageType = "ERROR",
                    message = "Test error message"
                }
            }
            
            local result = BugReportLogic.formatLogs(logs)
            assert.matches("%[%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%] %(INFO%): Test log message", result)
            assert.matches("%[%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%] %(ERROR%): Test error message", result)
        end)
        
        it("should skip incomplete log entries", function()
            local logs = {
                {
                    timestamp = 1640995200,
                    messageType = "INFO",
                    message = "Complete log"
                },
                {
                    timestamp = 1640995260,
                    -- missing messageType
                    message = "Incomplete log"
                }
            }
            
            local result = BugReportLogic.formatLogs(logs)
            assert.matches("Complete log", result)
            assert.does_not_match("Incomplete log", result)
        end)
    end)
    
    describe("createRequestData", function()
        it("should create proper request structure", function()
            local issue = "This is a test issue description that is long enough"
            local steps = "Step 1: Do this\nStep 2: Do that"
            local logs = {
                {
                    timestamp = 1640995200,
                    messageType = "INFO", 
                    message = "Test log"
                }
            }
            
            local data = BugReportLogic.createRequestData(issue, steps, logs)
            
            assert.equals(issue, data.issue.description)
            assert.equals(steps, data.issue.unformatted_steps_to_reproduce)
            assert.matches("Test log", data.issue.logs)
        end)
    end)
    
    describe("createHttpRequest", function()
        it("should create proper HTTP request structure", function()
            local mockHttpService = MockHttpService:new()
            local data = { test = "data" }
            local testProjectId = "pr-test-project"
            local testAuthToken = "test-token-12345"
            
            local request = BugReportLogic.createHttpRequest(data, mockHttpService, testProjectId, testAuthToken)
            
            assert.equals("https://app.betahub.io/projects/pr-test-project/issues", request.Url)
            assert.equals("POST", request.Method)
            assert.equals("application/json", request.Headers["Content-Type"])
            assert.equals("application/json", request.Headers["Accept"])
            assert.equals("FormUser test-token-12345", request.Headers["Authorization"])
            assert.is_not_nil(request.Body)
        end)
        
        it("should handle Secret objects by using AddPrefix/AddSuffix methods", function()
            local mockHttpService = MockHttpService:new()
            local data = { test = "data" }
            local secretProjectId = MockSecret:new("pr-secret-project")
            local secretAuthToken = MockSecret:new("secret-token-67890")
            
            local request = BugReportLogic.createHttpRequest(data, mockHttpService, secretProjectId, secretAuthToken)
            
            -- URL should be a Secret object with the expected value
            assert.equals("https://app.betahub.io/projects/pr-secret-project/issues", request.Url:getValue())
            assert.equals("POST", request.Method)
            assert.equals("application/json", request.Headers["Content-Type"])
            assert.equals("application/json", request.Headers["Accept"])
            -- Authorization should be the Secret object directly
            assert.equals("FormUser secret-token-67890", request.Headers["Authorization"]:getValue())
            assert.is_not_nil(request.Body)
        end)
    end)
    
    describe("parseErrorResponse", function()
        it("should parse JSON error response", function()
            local mockHttpService = MockHttpService:new()
            local response = {
                Body = '{"error":"Custom error message"}'
            }
            
            local errorMessage = BugReportLogic.parseErrorResponse(response, mockHttpService)
            assert.equals("Custom error message", errorMessage)
        end)
        
        it("should handle invalid JSON in error response", function()
            local mockHttpService = MockHttpService:new()
            local response = {
                Body = "Invalid JSON",
                StatusCode = 400
            }
            
            local errorMessage = BugReportLogic.parseErrorResponse(response, mockHttpService)
            assert.equals("Failed to submit report. Error Code: 400", errorMessage)
        end)
        
        it("should handle missing StatusCode", function()
            local mockHttpService = MockHttpService:new()
            local response = {
                Body = "Invalid JSON"
            }
            
            local errorMessage = BugReportLogic.parseErrorResponse(response, mockHttpService)
            assert.equals("Failed to submit report. Error Code: unknown", errorMessage)
        end)
    end)
    
    describe("processBugReport", function()
        local mockPlayer, mockHttpService, mockRemoteEvent
        
        before_each(function()
            mockPlayer = MockPlayer:new("TestPlayer")
            mockHttpService = MockHttpService:new()
            mockRemoteEvent = MockRemoteEvent:new()
        end)
        
        local testProjectId = "pr-test-project"
        local testAuthToken = "test-token-12345"
        
        it("should reject invalid issue description", function()
            local success, message = BugReportLogic.processBugReport(
                mockPlayer, 
                "Too short", -- invalid description
                "Steps to reproduce",
                {},
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            assert.is_false(success)
            assert.equals("Bug description must be at least 40 characters.", message)
            
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("error", clientEvents[1].args[1])
        end)
        
        it("should successfully submit valid bug report", function()
            mockHttpService.shouldSucceed = true
            
            local success, message = BugReportLogic.processBugReport(
                mockPlayer,
                "This is a valid bug description that is definitely long enough to pass validation",
                "Steps to reproduce the bug",
                {
                    {
                        timestamp = 1640995200,
                        messageType = "INFO",
                        message = "Test log entry"
                    }
                },
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            assert.is_true(success)
            assert.equals("Bug report submitted successfully!", message)
            
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("success", clientEvents[1].args[1])
        end)
        
        it("should handle HTTP request failure", function()
            mockHttpService.shouldSucceed = false
            mockHttpService.responseBody = '{"error":"Server error"}'
            
            local success, message = BugReportLogic.processBugReport(
                mockPlayer,
                "This is a valid bug description that is definitely long enough to pass validation",
                "Steps to reproduce",
                {},
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            assert.is_false(success)
            assert.equals("Server error", message)
            
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("error", clientEvents[1].args[1])
            assert.equals("Server error", clientEvents[1].args[2])
        end)
    end)
end)