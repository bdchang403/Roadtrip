Feature: Validate Google Maps API Key

  Background:
    * url googleMapsBaseUrl
    * def apiKey = apiKey

  Scenario: Validate API Key with Directions API
    Given path 'directions', 'json'
    And param origin = 'New York, NY'
    And param destination = 'Boston, MA'
    And param key = apiKey
    When method get
    Then status 200
    And match response.status == 'OK'

  Scenario: Validate API Key with Maps JavaScript API
    Given url 'https://maps.googleapis.com/maps/api/js'
    And param key = apiKey
    When method get
    Then status 200
    And match response !contains 'error_message'

  Scenario: Validate API Key with Maps JavaScript API and Referer
    Given url 'https://maps.googleapis.com/maps/api/js'
    And param key = apiKey
    And param libraries = 'places'
    And header Referer = baseUrl + '/'
    When method get
    Then status 200
    And match response !contains 'error_message'

