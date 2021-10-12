Feature: Special feature to help monitor the network performance of the test environment.
  The steps could be refactored to avoid repetition, but the output is clearer not doing so.

  Scenario: Network soak
    # Batch 1
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 2
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 3
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 4
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 5
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 6
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 7
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 8
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 9
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

    # Batch 10
    When I run "NetworkSoakScenario"
    And I process a batch of 60 logs
    And I wait to receive a log
    And the log payload field "averageElapsed" is less than 1000
    And the log payload field "maxElapsed" is less than 2000
    And I discard the oldest log

