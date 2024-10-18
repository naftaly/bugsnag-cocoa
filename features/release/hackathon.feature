Feature: App and Device attributes present

  Background:
    Given I clear all persistent data

  Scenario: App and Device info is as expected when overridden via config
    When I run "AppAndDeviceAttributesConfigOverrideScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the error "Bugsnag-API-Key" header equals "12312312312312312312312312312312"

    And the error payload field "events.0.app.type" equals "iLeet"
    And the error payload field "events.0.app.bundleVersion" equals "12345"
    And the error payload field "events.0.context" equals "myContext"
    And the error payload field "events.0.app.releaseStage" equals "secondStage"

    # Additional checks from the hackathon
    And the last event is available via the data access api
    And the pipeline event payload field "app.type" equals "iLeet"
    And the pipeline event payload field "app.versionCode" equals 12345
    And the pipeline event payload field "context" equals "myContext"
    And the pipeline event payload field "app.releaseStage" equals "secondStage"
