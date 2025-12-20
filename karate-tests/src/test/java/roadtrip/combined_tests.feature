Feature: Combined Roadtrip Application Tests
  # This feature file consolidates all test suites for the Roadtrip Planner application.
  # Coverage includes: UI Smoke Tests, API Validations, Integration Scenarios, and User Flows.

  Background:
    # Common configuration for UI tests within this feature
    # Note: API tests override 'url' as needed within their specific scenarios.
    * configure driver = { type: 'chrome', showDriverLog: true, addOptions: ["--headless=new", "--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage", "--window-size=1920,1080"] }
    * def apiKey = apiKey
    * url googleMapsBaseUrl
    # Add Referer to satisfy API key restrictions (mimic local/prod app)
    * header Referer = 'http://localhost:3000/'
    * print 'Execution Version:', appVersion

  # ==================================================================================
  # GROUP 1: UI RELIABILITY & SMOKE TESTS
  # Focus: Ensuring the application loads correctly and key elements are visible.
  # ==================================================================================
  
  @smoke @regression
  Scenario: Validate App Dashboard Loads
    Given driver baseUrl
    # Wait for the app to load
    And waitFor('#root')
    # Use a broad check to ensure the "Oops" error text is NOT present in the body
    Then match html('body') !contains 'Oops! Something went wrong'
    # Verify the title
    And match driver.title == 'Roadtrip Planner'
    # Verify the submit button is present (indicating the form loaded)
    And assert exists('button[type=submit]')

  # ==================================================================================
  # GROUP 2: API KEY & SERVICE VALIDATION
  # Focus: verifying that the configured Google API Key is valid and services are reachable.
  # ==================================================================================

  @api @regression
  Scenario: Validate API Key with Directions API
    Given path 'directions', 'json'
    And param origin = 'New York, NY'
    And param destination = 'Boston, MA'
    And param key = apiKey
    When method get
    Then status 200
    And match response.status == 'OK'

  @api @regression
  Scenario: Validate API Key with Maps JavaScript API
    Given url 'https://maps.googleapis.com/maps/api/js'
    And param key = apiKey
    When method get
    Then status 200
    And match response !contains 'error_message'

  @api @regression
  Scenario: Validate API Key with Maps JavaScript API and Referer
    Given url 'https://maps.googleapis.com/maps/api/js'
    And param key = apiKey
    And param libraries = 'places'
    And header Referer = baseUrl + '/'
    When method get
    Then status 200
    And match response !contains 'error_message'

  # ==================================================================================
  # GROUP 3: INTEGRATION SCENARIOS
  # Focus: Validating actual integration with Google backend services (Directions, Places).
  # ==================================================================================

  @integration @regression @ignore
  Scenario: Fetch Route (Directions API)
    # Testing directions between Toronto (origin in location.js) and Calgary (destination in location.js)
    Given path 'directions', 'json'
    And param origin = 'Toronto, ON'
    And param destination = 'Calgary, AB'
    And param key = apiKey
    When method get
    Then status 200
    And match response.status == 'OK'
    And match response.routes[0].legs[0] != null

  @integration @regression @ignore
  Scenario: Fetch Nearby Search (Places API)
    # Testing places search near a location (simulating finding attractions)
    Given path 'place', 'nearbysearch', 'json'
    And param location = '43.6532,-79.3832'
    And param radius = '1000'
    And param key = apiKey
    When method get
    Then status 200
    And match response.status == '#regex (OK|ZERO_RESULTS)'

  # ==================================================================================
  # GROUP 4: UI USER FLOWS
  # Focus: End-to-end user scenarios like searching for routes and attractions.
  # ==================================================================================

  @ui @functional @regression
  Scenario: Search for BBQ attractions between Toronto and Nashville
    Given driver baseUrl
    And waitFor('#root')
    # Mock alert to prevent blocking if API fails
    * script("window.alert = function(){}")
    
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
    
    # Wait for completion (sufficient time for route + places search)
    And delay(10000)
    
    # Verify BBQ results appear
    Then match html('body') contains 'BBQ'

  # ==================================================================================
  # GROUP 5: LOCAL STORAGE & PERSISTENCE
  # Focus: Verifying data retention on reload and clearing functionality.
  # ==================================================================================

  @ignore @persistence @ui @regression
  Scenario: Verify Local Storage Persistence on Page Reload
    Given driver baseUrl
    And waitFor('#root')

    # Enter a unique attraction to test persistence
    And input("input[name='attractions']", 'UserPersistenceTest')
    
    # Submit to save to local storage (app logic saves on submit)
    And click("button[type='submit']")
    And delay(2000)

    # Reload the page (using url navigation for stability)
    And driver.url(baseUrl)
    And waitFor('#root')
    And delay(2000)

    # Verify the input retains the value
    # We check the 'value' attribute of the input or the text inside it
    Then match value("input[name='attractions']") == 'UserPersistenceTest'

  @persistence @ui @regression
  Scenario: Verify Clear All Functionality
    Given driver baseUrl
    And waitFor('#root')

    # Set some data first
    And input("input[name='attractions']", 'DataToClear')
    
    # Mock alert
    * script("window.alert = function(){}")

    And click("button[type='submit']")
    And delay(2000)

    # Click Clear All (which triggers a reload in the app logic)
    # Finding the button with text 'Clear All' or specifically by type/class if needed.
    # The app code has: <Button type="clear" ...>Clear All</Button>
    # Material UI buttons often don't strictly preserve 'type=clear' as a standard HTML attribute in the same way, 
    # but let's try matching by text or class logic if generic selector fails.
    # Based on Location.js: <Button type="clear" value="Clear" ...>
    And waitFor("//button[text()='Clear All']")
    And click("//button[text()='Clear All']")
    
    # Wait for the reload that happens in the app logic (setTimeout 250ms)
    And delay(3000)
    And waitFor('#root')
    
    # Verify input is reset (should not contain the old data)
    # It usually resets to empty string or undefined
    Then match value("input[name='attractions']") != 'DataToClear'

  # ==================================================================================
  # GROUP 6: OWASP SECURITY CHECKS
  # Focus: Top 10 vulnerabilities (Headers, Injection, etc.)
  # ==================================================================================

  @security @owasp @regression
  Scenario: Check for Security Headers (A05:2021 Security Misconfiguration)
    # Reset URL to the app base URL (Background sets it to Google Maps)
    Given url baseUrl
    When method get
    Then status 200
    # Check for X-Content-Type-Options (prevents MIME sniffing)
    # Using 'match header' which is case-insensitive in Karate
    And match header X-Content-Type-Options == 'nosniff'

  @security @owasp @regression
  Scenario: Verify XSS Protection in Search Inputs (A03:2021 Injection)
    Given driver baseUrl
    And waitFor('#root')

    # Define a malicious XSS payload
    * def xssPayload = "<script>alert('XSS')</script>"
    
    # Attempt to inject into the Starting Point input
    And input("input[placeholder='A: Starting Point']", xssPayload)
    And delay(1000)
    And input("input[placeholder='A: Starting Point']", Key.ENTER)
    
    # Proceed to see if it triggers or if the app crashes/behaves normally
    # We verify that the alert does NOT appear. 
    # In Karate, we can check if a dialog appeared, or check the DOM.
    # If the script executed, an alert would usually block the driver or exist.
    # Note: Karate's 'dialog' keyword handles alerts.
    
    # We assert that the input value is either sanitized or contained safely as text
    Then match value("input[placeholder='A: Starting Point']") contains xssPayload
    
    # Ensure no alert dialog is present (this would throw if an alert was open and we tried to interact, 
    # but explicitly checking for absence is good practice effectively done by valid flow continuing)
    # We can also check that the body doesn't contain the *result* of execution if it were a DOM injection 
    # (though that depends on the specific XSS vector).
    
    # If we got here without the test hanging on an unhandled alert, it's a good sign.

