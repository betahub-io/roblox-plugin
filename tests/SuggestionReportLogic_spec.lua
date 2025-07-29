-- Add the project root to the package path so we can require our modules
package.path = package.path .. ";./?.lua;./mocks/?.lua;./Server/?.lua"

local SuggestionReportLogic = require("Server.SuggestionReportLogic")
local MockHttpService = require("MockHttpService")
local MockRemoteEvent = require("MockRemoteEvent")
local MockPlayer = require("MockPlayer")

describe("SuggestionReportLogic", function()
    
    describe("validateSuggestionDescription", function()
        it("should reject nil input", function()
            local isValid, error = SuggestionReportLogic.validateSuggestionDescription(nil)
            assert.is_false(isValid)
            assert.equals("Suggestion description must be a string", error)
        end)
        
        it("should reject non-string input", function()
            local isValid, error = SuggestionReportLogic.validateSuggestionDescription(123)
            assert.is_false(isValid)
            assert.equals("Suggestion description must be a string", error)
        end)
        
        it("should reject descriptions shorter than 80 characters", function()
            local shortDescription = "This suggestion is too short for the minimum requirement"
            assert.is_true(#shortDescription < 80, "Test setup: description should be less than 80 chars")
            local isValid, error = SuggestionReportLogic.validateSuggestionDescription(shortDescription)
            assert.is_false(isValid)
            assert.equals("Suggestion description must be at least 80 characters.", error)
        end)
        
        it("should accept descriptions with exactly 80 characters", function()
            local exactDescription = "12345678901234567890123456789012345678901234567890123456789012345678901234567890" -- exactly 80 chars
            assert.equals(80, #exactDescription, "Test setup: description should be exactly 80 chars")
            local isValid, error = SuggestionReportLogic.validateSuggestionDescription(exactDescription)
            assert.is_true(isValid)
            assert.is_nil(error)
        end)
        
        it("should accept descriptions longer than 80 characters", function()
            local longDescription = "This is a much longer suggestion description that definitely exceeds the minimum character requirement for feature request suggestions which is 80 characters long"
            assert.is_true(#longDescription > 80, "Test setup: description should be more than 80 chars")
            local isValid, error = SuggestionReportLogic.validateSuggestionDescription(longDescription)
            assert.is_true(isValid)
            assert.is_nil(error)
        end)
    end)
    
    describe("createRequestData", function()
        it("should create proper request structure", function()
            local description = "This is a comprehensive test suggestion description that meets the minimum length requirements for feature requests in the system"
            local steps = "Step 1: Open the application\nStep 2: Navigate to suggestions\nStep 3: Submit new suggestion"
            
            local data = SuggestionReportLogic.createRequestData(description, steps)
            
            assert.equals(description, data.feature_request.description)
            assert.equals(steps, data.feature_request.unformatted_steps_to_reproduce)
        end)
        
        it("should handle nil steps parameter", function()
            local description = "This is a valid suggestion description that meets all the minimum length requirements for submission"
            local steps = nil
            
            local data = SuggestionReportLogic.createRequestData(description, steps)
            
            assert.equals(description, data.feature_request.description)
            assert.is_nil(data.feature_request.unformatted_steps_to_reproduce)
        end)
        
        it("should handle empty string steps parameter", function()
            local description = "This is another valid suggestion description that meets all the minimum length requirements for proper submission"
            local steps = ""
            
            local data = SuggestionReportLogic.createRequestData(description, steps)
            
            assert.equals(description, data.feature_request.description)
            assert.equals("", data.feature_request.unformatted_steps_to_reproduce)
        end)
    end)
    
    describe("createHttpRequest", function()
        it("should create proper HTTP request structure", function()
            local mockHttpService = MockHttpService:new()
            local data = { feature_request = { description = "test suggestion", unformatted_steps_to_reproduce = "test steps" } }
            local testProjectId = "pr-test-project"
            local testAuthToken = "FormUser test-token-12345"
            
            local request = SuggestionReportLogic.createHttpRequest(data, mockHttpService, testProjectId, testAuthToken)
            
            assert.equals("https://app.betahub.io/projects/pr-test-project/feature_requests", request.Url)
            assert.equals("POST", request.Method)
            assert.equals("application/json", request.Headers["Content-Type"])
            assert.equals("application/json", request.Headers["Accept"])
            assert.equals("FormUser test-token-12345", request.Headers["Authorization"])
            assert.is_not_nil(request.Body)
        end)
        
        it("should properly encode request data in body", function()
            local mockHttpService = MockHttpService:new()
            local testDescription = "Test suggestion with proper length requirements to meet the minimum validation criteria"
            local testSteps = "Test steps for reproduction"
            local data = SuggestionReportLogic.createRequestData(testDescription, testSteps)
            local testProjectId = "pr-test-project"
            local testAuthToken = "FormUser test-token-12345"
            
            local request = SuggestionReportLogic.createHttpRequest(data, mockHttpService, testProjectId, testAuthToken)
            
            -- Decode the JSON body to verify it contains our data
            local decodedBody = mockHttpService:JSONDecode(request.Body)
            assert.equals(testDescription, decodedBody.feature_request.description)
            assert.equals(testSteps, decodedBody.feature_request.unformatted_steps_to_reproduce)
        end)
    end)
    
    describe("parseErrorResponse", function()
        it("should parse JSON error response", function()
            local mockHttpService = MockHttpService:new()
            local response = {
                Body = '{"error":"Custom error message for suggestion submission"}'
            }
            
            local errorMessage = SuggestionReportLogic.parseErrorResponse(response, mockHttpService)
            assert.equals("Custom error message for suggestion submission", errorMessage)
        end)
        
        it("should handle invalid JSON in error response", function()
            local mockHttpService = MockHttpService:new()
            local response = {
                Body = "Invalid JSON response from server",
                StatusCode = 422
            }
            
            local errorMessage = SuggestionReportLogic.parseErrorResponse(response, mockHttpService)
            assert.equals("Failed to submit suggestion. Error Code: 422", errorMessage)
        end)
        
        it("should handle missing StatusCode", function()
            local mockHttpService = MockHttpService:new()
            local response = {
                Body = "Invalid JSON without status code"
            }
            
            local errorMessage = SuggestionReportLogic.parseErrorResponse(response, mockHttpService)
            assert.equals("Failed to submit suggestion. Error Code: unknown", errorMessage)
        end)
        
        it("should handle nested error structures", function()
            local mockHttpService = MockHttpService:new()
            local response = {
                Body = '{"errors":{"description":["is too short"]},"message":"Validation failed"}'
            }
            
            local errorMessage = SuggestionReportLogic.parseErrorResponse(response, mockHttpService)
            assert.equals("Failed to submit suggestion. Error Code: unknown", errorMessage)
        end)
    end)
    
    describe("processSuggestionReport", function()
        local mockPlayer, mockHttpService, mockRemoteEvent
        
        before_each(function()
            mockPlayer = MockPlayer:new("TestPlayer")
            mockHttpService = MockHttpService:new()
            mockRemoteEvent = MockRemoteEvent:new()
        end)
        
        local testProjectId = "pr-test-project"
        local testAuthToken = "FormUser test-token-12345"
        
        it("should reject invalid suggestion description", function()
            local success, message = SuggestionReportLogic.processSuggestionReport(
                mockPlayer, 
                "Too short for suggestion", -- invalid description (less than 80 chars)
                "Steps to implement the suggestion",
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            assert.is_false(success)
            assert.equals("Suggestion description must be at least 80 characters.", message)
            
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("error", clientEvents[1].args[1])
            assert.equals("Suggestion description must be at least 80 characters.", clientEvents[1].args[2])
        end)
        
        it("should successfully submit valid suggestion report", function()
            mockHttpService.shouldSucceed = true
            
            local success, message = SuggestionReportLogic.processSuggestionReport(
                mockPlayer,
                "This is a comprehensive and valid suggestion description that definitely meets all the minimum character requirements for feature request submissions in the system",
                "Step 1: Implement the new feature\nStep 2: Test the functionality\nStep 3: Deploy to users",
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            assert.is_true(success)
            assert.equals("Suggestion submitted successfully!", message)
            
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("success", clientEvents[1].args[1])
        end)
        
        it("should handle HTTP request failure with JSON error", function()
            mockHttpService.shouldSucceed = false
            mockHttpService.responseBody = '{"error":"Feature request validation failed: description already exists"}'
            
            local success, message = SuggestionReportLogic.processSuggestionReport(
                mockPlayer,
                "This is a valid suggestion description that meets all minimum length requirements but will trigger a server error response",
                "Implementation steps for the suggestion",
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            assert.is_false(success)
            assert.equals("Feature request validation failed: description already exists", message)
            
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("error", clientEvents[1].args[1])
            assert.equals("Feature request validation failed: description already exists", clientEvents[1].args[2])
        end)
        
        it("should handle HTTP request failure with non-JSON error", function()
            mockHttpService.shouldSucceed = false
            mockHttpService.responseBody = "Internal Server Error"
            mockHttpService.responseCode = 500
            
            local success, message = SuggestionReportLogic.processSuggestionReport(
                mockPlayer,
                "This is another valid suggestion description that meets all the minimum length requirements for submission but will receive server error",
                "Steps to reproduce or implement the suggestion",
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            assert.is_false(success)
            assert.matches("Failed to submit suggestion. Error Code:", message)
            
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("error", clientEvents[1].args[1])
        end)
        
        it("should handle nil steps parameter gracefully", function()
            mockHttpService.shouldSucceed = true
            
            local success, message = SuggestionReportLogic.processSuggestionReport(
                mockPlayer,
                "This is a valid suggestion description that meets all length requirements and should be submitted successfully without reproduction steps",
                nil, -- nil steps
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            assert.is_true(success)
            assert.equals("Suggestion submitted successfully!", message)
            
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("success", clientEvents[1].args[1])
        end)
        
        it("should properly format request data for API", function()
            mockHttpService.shouldSucceed = true
            local testDescription = "This comprehensive suggestion description provides detailed information about a new feature that would greatly benefit users and meets all validation requirements"
            local testSteps = "Step 1: Design the UI\nStep 2: Implement backend logic\nStep 3: Add user feedback mechanisms"
            
            SuggestionReportLogic.processSuggestionReport(
                mockPlayer,
                testDescription,
                testSteps,
                mockHttpService,
                mockRemoteEvent,
                testProjectId,
                testAuthToken
            )
            
            -- Verify the request was made with proper structure
            -- Note: In a real scenario, we'd need to capture the actual request made
            -- For now, we just verify the process completed successfully
            local clientEvents = mockRemoteEvent:getClientEvents()
            assert.equals(1, #clientEvents)
            assert.equals("success", clientEvents[1].args[1])
        end)
    end)
end)