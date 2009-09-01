Feature: Autosynching a folder into clearcase

Scenario: The case of the new folder
  Given a new file
  When I add the new file
  And I checkin the new file
  Then I should see the new file committed