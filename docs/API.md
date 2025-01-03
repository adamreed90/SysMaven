# API Documentation

## Overview

This document provides an overview of the API endpoints available in the Network Imaging System. The API allows for managing image creation, restoration, network boot configuration, and system status retrieval.

## Endpoints

### ImageController

#### Create Image

- **Endpoint**: `POST /api/image/create`
- **Description**: Creates an image from the specified source device and saves it to the destination path.
- **Request Body**:
  ```json
  {
    "name": "string",
    "size": "number",
    "metadata": "string"
  }
  ```
- **Query Parameters**:
  - `sourceDevice` (string): The source device to create the image from.
  - `destinationPath` (string): The path to save the created image.
- **Response**:
  - `200 OK`: Image created successfully.
  - `400 Bad Request`: Invalid input parameters.
  - `500 Internal Server Error`: An error occurred during image creation.

#### Restore Image

- **Endpoint**: `POST /api/image/restore`
- **Description**: Restores an image from the specified image path to the target device.
- **Request Body**:
  ```json
  {
    "name": "string",
    "size": "number",
    "metadata": "string"
  }
  ```
- **Query Parameters**:
  - `imagePath` (string): The path of the image to restore.
  - `targetDevice` (string): The target device to restore the image to.
- **Response**:
  - `200 OK`: Image restored successfully.
  - `400 Bad Request`: Invalid input parameters.
  - `500 Internal Server Error`: An error occurred during image restoration.

### NetworkBootController

#### Configure Network Boot

- **Endpoint**: `POST /api/networkboot/configure`
- **Description**: Configures network boot settings.
- **Request Body**:
  ```json
  {
    "ipAddress": "string",
    "subnetMask": "string",
    "gateway": "string"
  }
  ```
- **Response**:
  - `200 OK`: Network boot configured successfully.
  - `400 Bad Request`: Invalid input parameters.
  - `500 Internal Server Error`: An error occurred during network boot configuration.

### SystemController

#### Get System Status

- **Endpoint**: `GET /api/system/status`
- **Description**: Retrieves the current system status, including CPU usage, memory usage, and disk space.
- **Response**:
  - `200 OK`: Returns the system status.
  - `500 Internal Server Error`: An error occurred while retrieving the system status.
  ```json
  {
    "cpuUsage": "number",
    "memoryUsage": "number",
    "diskSpace": "number"
  }
  ```

## Authentication

The API uses JWT (JSON Web Token) for authentication. Include the token in the `Authorization` header of each request.

## Logging

All API requests and responses are logged using `syslog-ng`.

## Error Handling

The API returns standard HTTP status codes to indicate the success or failure of a request. The response body may contain additional information about the error.

## Examples

### Create Image Example

**Request**:
```bash
curl -X POST "http://localhost:5000/api/image/create?sourceDevice=/dev/sda&destinationPath=/images/image1.img" -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{
  "name": "Image1",
  "size": 1024,
  "metadata": "Sample image"
}'
```

**Response**:
```json
{
  "message": "Image created successfully."
}
```

### Restore Image Example

**Request**:
```bash
curl -X POST "http://localhost:5000/api/image/restore?imagePath=/images/image1.img&targetDevice=/dev/sda" -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{
  "name": "Image1",
  "size": 1024,
  "metadata": "Sample image"
}'
```

**Response**:
```json
{
  "message": "Image restored successfully."
}
```

### Configure Network Boot Example

**Request**:
```bash
curl -X POST "http://localhost:5000/api/networkboot/configure" -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{
  "ipAddress": "192.168.1.100",
  "subnetMask": "255.255.255.0",
  "gateway": "192.168.1.1"
}'
```

**Response**:
```json
{
  "message": "Network boot configured successfully."
}
```

### Get System Status Example

**Request**:
```bash
curl -X GET "http://localhost:5000/api/system/status" -H "Authorization: Bearer <token>"
```

**Response**:
```json
{
  "cpuUsage": 10.5,
  "memoryUsage": 2048,
  "diskSpace": 50000
}
```
