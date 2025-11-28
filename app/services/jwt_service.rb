# frozen_string_literal: true

class JwtService
  # Access token expiration (15 minutes)
  ACCESS_TOKEN_EXPIRATION = 15.minutes
  
  # Refresh token expiration (7 days)
  REFRESH_TOKEN_EXPIRATION = 7.days
  
  class << self
    # Get secret key for signing tokens
    def secret_key
      @secret_key ||= begin
        if Rails.application.credentials.respond_to?(:secret_key_base) && Rails.application.credentials.secret_key_base.present?
          Rails.application.credentials.secret_key_base
        else
          Rails.application.secret_key_base
        end
      end
    end
    
    # Generate access token (short-lived)
    def encode_access_token(user)
      payload = {
        user_id: user.id,
        email: user.email,
        exp: ACCESS_TOKEN_EXPIRATION.from_now.to_i,
        type: 'access'
      }
      encode(payload)
    end
    
    # Generate refresh token (long-lived)
    def encode_refresh_token(user)
      payload = {
        user_id: user.id,
        exp: REFRESH_TOKEN_EXPIRATION.from_now.to_i,
        type: 'refresh',
        jti: SecureRandom.uuid # Unique token identifier for revocation
      }
      encode(payload)
    end
    
    # Decode and verify token
    def decode(token)
      decoded = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      decoded[0] # Return payload
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
      nil
    end
    
    # Extract user from access token
    def current_user_from_token(token)
      payload = decode(token)
      return nil unless payload
      return nil unless payload['type'] == 'access'
      
      User.find_by(id: payload['user_id'])
    rescue ActiveRecord::RecordNotFound
      nil
    end
    
    private
    
    def encode(payload)
      JWT.encode(payload, secret_key, 'HS256')
    end
  end
end

