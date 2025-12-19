Feature: Frontend Load Validation

  Scenario: Validate App Dashboard Loads
    * configure driver = { type: 'chrome', showDriverLog: true, addOptions: ["--headless=new", "--no-sandbox", "--disable-gpu", "--window-size=1920,1080"] }

    
    Given driver baseUrl
    # Wait for the app to load
    And waitFor('#root')
    # Use a broad check to ensure the "Oops" error text is NOT present on the body
    Then match html('body') !contains 'Oops! Something went wrong'
    # Verify the title
    And match driver.title == 'Roadtrip Planner'
    # Verify the submit button is present (indicating the form loaded)
    And assert exists('button[type=submit]')
