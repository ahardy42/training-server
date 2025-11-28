# frozen_string_literal: true

module Api
  module V1
    class AuthController < Api::BaseController
      # Skip authentication for login/refresh endpoints
      skip_before_action :authenticate_user!, only: [:login, :refresh]
      
      # POST /api/v1/auth/login
      def login
        email = params[:email]
        password = params[:password]
        
        if email.blank? || password.blank?
          return render_json_error("Email and password are required", status: :bad_request)
        end
        
        user = User.find_by(email: email.downcase.strip)
        
        if user&.valid_password?(password)
          access_token = JwtService.encode_access_token(user)
          refresh_token = JwtService.encode_refresh_token(user)
          
          # Store refresh token in database for potential revocation
          user.update(refresh_token: refresh_token) if user.respond_to?(:refresh_token=)
          
          render json: {
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: 'Bearer',
            expires_in: JwtService::ACCESS_TOKEN_EXPIRATION.to_i,
            user: {
              id: user.id,
              email: user.email,
              name: user.name
            }
          }, status: :ok
        else
          render_json_error("Invalid email or password", status: :unauthorized)
        end
      end
      
      # POST /api/v1/auth/refresh
      def refresh
        refresh_token = params[:refresh_token] || extract_token_from_header
        
        if refresh_token.blank?
          return render_json_error("Refresh token is required", status: :bad_request)
        end
        
        payload = JwtService.decode(refresh_token)
        
        unless payload && payload['type'] == 'refresh'
          return render_json_error("Invalid refresh token", status: :unauthorized)
        end
        
        user = User.find_by(id: payload['user_id'])
        
        unless user
          return render_json_error("User not found", status: :unauthorized)
        end
        
        # Optional: Verify refresh token matches stored token (if using database storage)
        if user.respond_to?(:refresh_token) && user.refresh_token.present?
          unless user.refresh_token == refresh_token
            return render_json_error("Refresh token has been revoked", status: :unauthorized)
          end
        end
        
        # Generate new tokens
        new_access_token = JwtService.encode_access_token(user)
        new_refresh_token = JwtService.encode_refresh_token(user)
        
        # Update stored refresh token
        user.update(refresh_token: new_refresh_token) if user.respond_to?(:refresh_token=)
        
        render json: {
          access_token: new_access_token,
          refresh_token: new_refresh_token,
          token_type: 'Bearer',
          expires_in: JwtService::ACCESS_TOKEN_EXPIRATION.to_i
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render_json_error("User not found", status: :unauthorized)
      end
      
      # POST /api/v1/auth/logout
      def logout
        # Optionally revoke refresh token by clearing it from database
        if current_user.respond_to?(:refresh_token=)
          current_user.update(refresh_token: nil)
        end
        
        render json: { message: "Logged out successfully" }, status: :ok
      end
      
      # GET /api/v1/auth/me
      def me
        render json: {
          user: {
            id: current_user.id,
            email: current_user.email,
            name: current_user.name
          }
        }, status: :ok
      end
      
      private
      
      def extract_token_from_header
        auth_header = request.headers['Authorization']
        return nil unless auth_header
        
        # Extract token from "Bearer <token>" format
        auth_header.split(' ').last if auth_header.start_with?('Bearer ')
      end
    end
  end
end

