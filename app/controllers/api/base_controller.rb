# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    # Skip CSRF token verification for API requests
    skip_before_action :verify_authenticity_token
    
    # Require authentication for all API endpoints
    before_action :authenticate_user!
    
    # Set default response format to JSON
    respond_to :json
    
    protected
    
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

