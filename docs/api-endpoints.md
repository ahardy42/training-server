# API Endpoints

This document describes all available API endpoints in the Training Server application.

## Base URL

All API endpoints are prefixed with `/api/v1`.

## Authentication

All API endpoints (except authentication endpoints) require a valid JWT access token in the `Authorization` header:

```
Authorization: Bearer <access_token>
```

For details on authentication, see [Authentication Mechanisms](./authentication.md).

## Response Format

### Success Responses

Successful responses return JSON with the requested data and appropriate HTTP status codes (200, 201, etc.).

### Error Responses

Error responses follow this format:

```json
{
  "error": "Error message here"
}
```

Validation errors include additional details:

```json
{
  "error": "Validation failed",
  "errors": ["Field can't be blank", "Another error message"]
}
```

## Endpoints

### Authentication

#### Login
- **Endpoint**: `POST /api/v1/auth/login`
- **Authentication**: Not required
- **Request Body**:
  ```json
  {
    "email": "user@example.com",
    "password": "password123"
  }
  ```
- **Response** (200 OK):
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "Bearer",
    "expires_in": 900,
    "user": {
      "id": 1,
      "email": "user@example.com",
      "name": "John Doe"
    }
  }
  ```

#### Refresh Token
- **Endpoint**: `POST /api/v1/auth/refresh`
- **Authentication**: Not required
- **Request Body**:
  ```json
  {
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
  ```
- **Response** (200 OK):
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "Bearer",
    "expires_in": 900
  }
  ```

#### Get Current User
- **Endpoint**: `GET /api/v1/auth/me`
- **Authentication**: Required
- **Response** (200 OK):
  ```json
  {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "name": "John Doe"
    }
  }
  ```

#### Logout
- **Endpoint**: `POST /api/v1/auth/logout`
- **Authentication**: Required
- **Response** (200 OK):
  ```json
  {
    "message": "Logged out successfully"
  }
  ```

### Activities

#### List Activities
- **Endpoint**: `GET /api/v1/activities`
- **Authentication**: Required
- **Query Parameters**:
  - `page` (optional): Page number for pagination (default: 1)
  - `per_page` (optional): Number of items per page (default: 10)
- **Response** (200 OK):
  ```json
  {
    "activities": [
      {
        "id": 1,
        "activity_type": "cycling",
        "date": "2024-01-15",
        "title": "Morning Ride",
        "description": "A nice morning ride",
        "distance": 25.5,
        "duration": 3600,
        "elevation": 450.0,
        "average_power": 180.0,
        "average_hr": 145.0,
        "created_at": "2024-01-15T10:00:00Z",
        "updated_at": "2024-01-15T10:00:00Z",
        "track": {
          "id": 1,
          "start_date": "2024-01-15T08:00:00Z",
          "end_date": "2024-01-15T09:00:00Z"
        }
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 10,
      "total_pages": 5,
      "total_count": 50,
      "next_page": 2,
      "prev_page": null
    }
  }
  ```

#### Get Activity
- **Endpoint**: `GET /api/v1/activities/:id`
- **Authentication**: Required
- **Response** (200 OK):
  ```json
  {
    "id": 1,
    "activity_type": "cycling",
    "date": "2024-01-15",
    "title": "Morning Ride",
    "description": "A nice morning ride",
    "distance": 25.5,
    "duration": 3600,
    "elevation": 450.0,
    "average_power": 180.0,
    "average_hr": 145.0,
    "created_at": "2024-01-15T10:00:00Z",
    "updated_at": "2024-01-15T10:00:00Z",
    "track": {
      "id": 1,
      "start_date": "2024-01-15T08:00:00Z",
      "end_date": "2024-01-15T09:00:00Z",
      "trackpoints": [
        {
          "id": 1,
          "timestamp": "2024-01-15T08:00:00Z",
          "latitude": 37.7749,
          "longitude": -122.4194,
          "heartrate": 140.0,
          "power": 175.0,
          "cadence": 85.0,
          "elevation": 100.0
        }
      ]
    }
  }
  ```
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Activity not found"
  }
  ```

#### Create Activity
- **Endpoint**: `POST /api/v1/activities`
- **Authentication**: Required
- **Request Body**:
  ```json
  {
    "activity": {
      "activity_type": "cycling",
      "date": "2024-01-15",
      "title": "Morning Ride",
      "description": "A nice morning ride",
      "distance": 25.5,
      "duration": 3600,
      "elevation": 450.0,
      "average_power": 180.0,
      "average_hr": 145.0,
      "track": {
        "start_date": "2024-01-15T08:00:00Z",
        "end_date": "2024-01-15T09:00:00Z"
      },
      "trackpoints": [
        {
          "timestamp": "2024-01-15T08:00:00Z",
          "latitude": 37.7749,
          "longitude": -122.4194,
          "heartrate": 140.0,
          "power": 175.0,
          "cadence": 85.0,
          "elevation": 100.0
        }
      ]
    }
  }
  ```
- **Response** (201 Created): Same format as Get Activity
- **Error Response** (422 Unprocessable Entity):
  ```json
  {
    "error": "Validation failed",
    "errors": ["Date can't be blank", "Activity type can't be blank"]
  }
  ```

#### Update Activity
- **Endpoint**: `PATCH /api/v1/activities/:id` or `PUT /api/v1/activities/:id`
- **Authentication**: Required
- **Request Body**: Same format as Create Activity (all fields optional)
- **Response** (200 OK): Same format as Get Activity
- **Error Response** (404 Not Found):
  ```json
  {
    "error": "Activity not found"
  }
  ```

## Activity Data Model

### Activity Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `activity_type` | String | Yes | Type of activity (e.g., "cycling", "running", "hiking") |
| `date` | Date | Yes | Date of the activity (ISO 8601 format: YYYY-MM-DD) |
| `title` | String | No | Title of the activity |
| `description` | String | No | Description of the activity |
| `distance` | Float | No | Distance in kilometers |
| `duration` | Integer | No | Duration in seconds |
| `elevation` | Float | No | Elevation gain in meters |
| `average_power` | Float | No | Average power in watts |
| `average_hr` | Float | No | Average heart rate in BPM |

### Track Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `start_date` | DateTime | No | Start time of the track (ISO 8601 format) |
| `end_date` | DateTime | No | End time of the track (ISO 8601 format) |

### Trackpoint Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `timestamp` | DateTime | No | Timestamp of the trackpoint (ISO 8601 format) |
| `latitude` | Float | No | Latitude coordinate |
| `longitude` | Float | No | Longitude coordinate |
| `heartrate` | Float | No | Heart rate in BPM |
| `power` | Float | No | Power in watts |
| `cadence` | Float | No | Cadence in RPM |
| `elevation` | Float | No | Elevation in meters |

## Pagination

List endpoints support pagination using the `page` and `per_page` query parameters. The response includes pagination metadata:

```json
{
  "pagination": {
    "current_page": 1,
    "per_page": 10,
    "total_pages": 5,
    "total_count": 50,
    "next_page": 2,
    "prev_page": null
  }
}
```

## Error Codes

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (missing or invalid parameters) |
| 401 | Unauthorized (missing or invalid authentication) |
| 404 | Not Found (resource doesn't exist) |
| 422 | Unprocessable Entity (validation errors) |
| 500 | Internal Server Error |

## Example Usage

### Complete Workflow

```bash
# 1. Login
TOKEN_RESPONSE=$(curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}')

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

# 2. List activities
curl -X GET http://localhost:3000/api/v1/activities \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# 3. Create activity
curl -X POST http://localhost:3000/api/v1/activities \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "activity": {
      "activity_type": "cycling",
      "date": "2024-01-15",
      "title": "Morning Ride",
      "distance": 25.5,
      "duration": 3600
    }
  }'

# 4. Get specific activity
curl -X GET http://localhost:3000/api/v1/activities/1 \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# 5. Update activity
curl -X PATCH http://localhost:3000/api/v1/activities/1 \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "activity": {
      "title": "Updated Title"
    }
  }'
```

## Rate Limiting

Currently, there are no rate limits implemented. Consider implementing rate limiting in production to prevent abuse.

## Versioning

The API is versioned using URL path prefixes (`/api/v1/`). Future versions will use `/api/v2/`, etc. The current version is v1.

