#!/bin/bash
set -e

# Source .env file to get the Google API Key (ignore error if file doesn't exist, but we expect it to)
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

if [ -z "$REACT_APP_GOOGLE_API_KEY" ]; then
    echo "Error: REACT_APP_GOOGLE_API_KEY is not set. Please check your .env file."
    exit 1
fi

echo "Building Docker image..."
/usr/bin/docker build --build-arg REACT_APP_GOOGLE_API_KEY="$REACT_APP_GOOGLE_API_KEY" -t roadtrip-app .

echo "Starting Docker container..."
# Run container in detached mode, mapping port 3000 to internal 80 (nginx default)
# Configured Nginx inside container listens on 80
CONTAINER_ID=$(/usr/bin/docker run -d -p 3000:80 roadtrip-app)

echo "Container started with ID: $CONTAINER_ID"
echo "Waiting for application to be ready..."
sleep 5

# Ensure we clean up the container on exit
cleanup() {
    echo "Stopping and removing container..."
    /usr/bin/docker stop "$CONTAINER_ID"
    /usr/bin/docker rm "$CONTAINER_ID"
}
trap cleanup EXIT

echo "Running Karate tests..."
cd karate-tests
# Run tests pointing to localhost:3000 (which maps to the docker container)
# We can also pass the API key to the tests explicitly if needed, but the tests read from env vars or karate-config
# The app itself already has the key baked in from build time.
mvn test -Dapp.url=http://localhost:3000

echo "Tests completed successfully."
