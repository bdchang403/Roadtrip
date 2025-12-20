function fn() {
    var env = karate.env; // get system property 'karate.env'
    karate.log('karate.env system property was:', env);
    if (!env) {
        env = 'dev';
    }

    // Get API key from system property or environment variable
    var apiKey = karate.properties['google.api.key'] || java.lang.System.getenv('REACT_APP_GOOGLE_API_KEY');

    // Get Base URL from system property or environment variable. Default to localhost.
    var baseUrl = karate.properties['app.url'] || java.lang.System.getenv('APP_URL') || 'http://localhost:3000';

    // Get Application Version (injected by CI or local script)
    var appVersion = karate.properties['app.version'] || 'unknown';

    if (!apiKey) {
        karate.log('WARNING: REACT_APP_GOOGLE_API_KEY is not set. Tests may fail.');
    }

    var config = {
        env: env,
        apiKey: apiKey,
        baseUrl: baseUrl,
        baseUrl: baseUrl,
        googleMapsBaseUrl: 'https://maps.googleapis.com/maps/api',
        appVersion: appVersion
    }

    return config;
}
