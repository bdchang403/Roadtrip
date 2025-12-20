Feature: BBQ Route Search

  Scenario: Search for BBQ attractions between Toronto and Nashville
    # Configure driver with headless options including the fix for Docker shared memory
    * configure driver = { type: 'chrome', showDriverLog: true, addOptions: ["--headless=new", "--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage", "--window-size=1920,1080"] }

    Given driver baseUrl
    # Wait for app to load
    And waitFor('#root')
    
    # Enter Starting Point
    And input("input[placeholder='A: Starting Point']", 'Toronto, ON')
    And delay(1000)
    And input("input[placeholder='A: Starting Point']", Key.ENTER)

    # Enter Destination
    And input("input[placeholder='B: Destination']", 'Nashville, TN')
    And delay(1000)
    And input("input[placeholder='B: Destination']", Key.ENTER)

    # Enter Attractions
    And input("input[name='attractions']", 'BBQ')
    
    # Click Submit
    And click("button[type='submit']")
    
    # Wait for results
    # The app displays attractions, likely in a list or markers. 
    # Let's wait for a sufficient time for the Google API to return the route and places.
    And delay(10000)
    
    # Verify BBQ results
    # We expect "BBQ" to appear in the text of the results
    # Adjust this selector based on actual app DOM if this fails
    Then match html('body') contains 'BBQ'
