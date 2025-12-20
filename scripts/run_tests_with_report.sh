#!/bin/bash
set -e

# Get current git commit short SHA for version tracking
SHA=$(git rev-parse --short HEAD)
echo "Running tests for version: $SHA"

# Navigate to the karate-tests directory (relative to this script)
# Assumes script is in root/scripts/
cd "$(dirname "$0")/../karate-tests"

# Run Maven test with app.version property injected
# "$@" allows passing additional arguments like "-Dkarate.options=..."
mvn test -Dapp.version="${SHA}" "$@"

echo "Test run complete."

# Open the summary report
REPORT_PATH="target/karate-reports/karate-summary.html"
if [ -f "$REPORT_PATH" ]; then
    echo "Opening report: $REPORT_PATH"
    if command -v xdg-open &> /dev/null; then
        xdg-open "$REPORT_PATH"
    elif command -v open &> /dev/null; then
        open "$REPORT_PATH"
    else
        echo "Report available at: $(pwd)/$REPORT_PATH"
    fi
else
    echo "Report file not found at $REPORT_PATH"
fi
