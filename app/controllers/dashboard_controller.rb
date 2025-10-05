class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    # If user is not authenticated, Devise will redirect to login
    # If user is authenticated, show the dashboard
  end
end
