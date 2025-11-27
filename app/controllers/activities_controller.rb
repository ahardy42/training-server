# frozen_string_literal: true

class ActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_activity, only: [:show]

  def index
    @activities = current_user.activities.order(date: :desc, created_at: :desc)
  end

  def show
    @track = @activity.track
    @trackpoints = @track&.trackpoints&.order(:timestamp) || []
  end

  private

  def set_activity
    @activity = current_user.activities.find(params[:id])
  end
end

