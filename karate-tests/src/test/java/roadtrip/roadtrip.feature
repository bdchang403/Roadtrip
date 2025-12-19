Feature: Roadtrip Google Maps API Integration

  Background:
    * url googleMapsBaseUrl
    * def apiKey = apiKey
    * if (!apiKey) karate.fail('API Key not found')

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

  Scenario: Fetch Nearby Search (Places API)
    # Testing places search near a location (simulating finding attractions)
    Given path 'place', 'nearbysearch', 'json'
    And param location = '43.6532,-79.3832'
    And param radius = '1000'
    And param key = apiKey
    When method get
    Then status 200
    # Note: If no results, status might be ZERO_RESULTS which is also 200 HTTP but different response status
    And match response.status == '#regex (OK|ZERO_RESULTS)'
