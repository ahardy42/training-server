# Authentication Mechanisms

This document describes the authentication system used in the Training Server application.

## Overview

The application uses a dual authentication system:
- **Web Interface**: Devise-based session authentication
- **API**: JWT (JSON Web Token) based authentication with access and refresh tokens

## API Authentication (JWT)

The API uses JWT tokens for stateless authentication. The system implements a two-token approach:

### Token Types

1. **Access Token**: Short-lived token (15 minutes) used for API requests
2. **Refresh Token**: Long-lived token (7 days) used to obtain new access tokens

### Authentication Flow

#### 1. Login

**Endpoint**: `POST /api/v1/auth/login`

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response** (200 OK):
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

**Error Response** (401 Unauthorized):
```json
{
  "error": "Invalid email or password"
}
```

#### 2. Using Access Tokens

Include the access token in the `Authorization` header for all authenticated API requests:

```
Authorization: Bearer <access_token>
```

#### 3. Refreshing Tokens

When an access token expires, use the refresh token to obtain a new access token.

**Endpoint**: `POST /api/v1/auth/refresh`

**Request Body**:
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Alternative**: Include refresh token in Authorization header:
```
Authorization: Bearer <refresh_token>
```

**Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 900
}
```

**Error Response** (401 Unauthorized):
```json
{
  "error": "Invalid refresh token"
}
```

#### 4. Get Current User

**Endpoint**: `GET /api/v1/auth/me`

**Headers**:
```
Authorization: Bearer <access_token>
```

**Response** (200 OK):
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

#### 5. Logout

**Endpoint**: `POST /api/v1/auth/logout`

**Headers**:
```
Authorization: Bearer <access_token>
```

**Response** (200 OK):
```json
{
  "message": "Logged out successfully"
}
```

**Note**: Logout invalidates the refresh token by clearing it from the database.

### Token Structure

#### Access Token Payload
```json
{
  "user_id": 1,
  "email": "user@example.com",
  "exp": 1234567890,
  "type": "access"
}
```

#### Refresh Token Payload
```json
{
  "user_id": 1,
  "exp": 1234567890,
  "type": "refresh",
  "jti": "unique-token-identifier"
}
```

### Security Features

1. **Token Expiration**: Access tokens expire after 15 minutes to limit exposure if compromised
2. **Refresh Token Rotation**: New refresh tokens are issued on each refresh
3. **Token Revocation**: Refresh tokens can be revoked by clearing them from the database
4. **Token Validation**: Tokens are signed using HS256 algorithm with the application's secret key
5. **Type Checking**: Tokens include a `type` field to prevent access tokens from being used as refresh tokens and vice versa

### Implementation Details

#### JWT Service

The `JwtService` class (`app/services/jwt_service.rb`) handles all JWT operations:

- `encode_access_token(user)`: Generates a short-lived access token
- `encode_refresh_token(user)`: Generates a long-lived refresh token
- `decode(token)`: Decodes and validates a token
- `current_user_from_token(token)`: Extracts user from an access token

#### Base Controller

The `Api::BaseController` (`app/controllers/api/base_controller.rb`) provides:

- `authenticate_user_from_token!`: Before action that validates JWT tokens
- `current_user`: Returns the authenticated user from the token
- `extract_token_from_header`: Extracts token from Authorization header

### Error Handling

All authentication errors return JSON responses with appropriate HTTP status codes:

- `400 Bad Request`: Missing required parameters
- `401 Unauthorized`: Invalid credentials, expired tokens, or missing authentication
- `404 Not Found`: User not found

### Example Usage

#### cURL Example

```bash
# Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Use access token
curl -X GET http://localhost:3000/api/v1/activities \
  -H "Authorization: Bearer <access_token>"

# Refresh token
curl -X POST http://localhost:3000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<refresh_token>"}'
```

#### JavaScript Example

```javascript
// Login
const loginResponse = await fetch('/api/v1/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'user@example.com', password: 'password123' })
});
const { access_token, refresh_token } = await loginResponse.json();

// Use access token
const activitiesResponse = await fetch('/api/v1/activities', {
  headers: { 'Authorization': `Bearer ${access_token}` }
});

// Refresh token when access token expires
const refreshResponse = await fetch('/api/v1/auth/refresh', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ refresh_token })
});
```

## Web Interface Authentication (Devise)

The web interface uses Devise for session-based authentication. Users can:

- Sign up for new accounts
- Sign in with email and password
- Sign out

### Configuration

Devise is configured in `config/initializers/devise.rb` and uses:
- `database_authenticatable`: Password-based authentication
- `rememberable`: "Remember me" functionality
- `validatable`: Email and password validation

### Routes

- `GET /users/sign_in`: Sign in page
- `POST /users/sign_in`: Sign in action
- `DELETE /users/sign_out`: Sign out action

## Security Best Practices

1. **Always use HTTPS in production** to protect tokens in transit
2. **Store tokens securely** on the client side (e.g., httpOnly cookies or secure storage)
3. **Implement token refresh logic** to automatically refresh expired access tokens
4. **Handle token expiration gracefully** by redirecting to login or refreshing tokens
5. **Never expose refresh tokens** in client-side JavaScript if possible
6. **Rotate refresh tokens** on each use to limit token reuse
7. **Implement rate limiting** on authentication endpoints to prevent brute force attacks

