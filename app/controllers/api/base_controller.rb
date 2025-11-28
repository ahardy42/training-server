# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    # Skip CSRF token verification for API requests
    skip_before_action :verify_authenticity_token
    
    # Require authentication for all API endpoints
    before_action :authenticate_user_from_token!
    
    # Set default response format to JSON
    respond_to :json
    
    protected
    
    # Override Devise's authenticate_user! to use JWT tokens
    def authenticate_user_from_token!
      token = extract_token_from_header
      
      unless token
        render_json_error("Missing authentication token", status: :unauthorized)
        return
      end
      
      user = JwtService.current_user_from_token(token)
      
      unless user
        render_json_error("Invalid or expired token", status: :unauthorized)
        return
      end
      
      # Set current_user for the request
      @current_user = user
    end
    
    # Override current_user to use our JWT-authenticated user
    def current_user
      @current_user
    end
    
    def extract_token_from_header
      auth_header = request.headers['Authorization']
      return nil unless auth_header
      
      # Extract token from "Bearer <token>" format
      auth_header.split(' ').last if auth_header.start_with?('Bearer ')
    end
    
    def render_json_error(message, status: :unprocessable_entity)
      render json: { error: message }, status: status
    end
    
    def render_json_validation_errors(record)
      render json: { 
        error: "Validation failed", 
        errors: record.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end
end

