#!/bin/bash

# Exit on any error
set -e

# Run unit tests
echo "Running unit tests..."
dotnet test tests/NetworkImaging.Core.Tests/NetworkImaging.Core.Tests.csproj
dotnet test tests/NetworkImaging.Api.Tests/NetworkImaging.Api.Tests.csproj

# Run integration tests
echo "Running integration tests..."
dotnet test tests/NetworkImaging.Integration.Tests/NetworkImaging.Integration.Tests.csproj

echo "All tests completed successfully!"
