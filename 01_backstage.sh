#!/usr/bin/env bash

set -eo pipefail

echo "======================================"
echo "Starting Backstage"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -d "backstage" ]; then
    echo "Error: backstage directory not found."
    echo "Please run this script from the project root directory."
    exit 1
fi

cd backstage

echo "Installing dependencies..."
yarn install

echo ""
echo "Starting Backstage..."
echo "Backstage will be available at: http://localhost:3000"
echo "Backend API will be available at: http://localhost:7007"
echo ""

yarn start
