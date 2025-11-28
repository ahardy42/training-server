# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Add plotly-rails-js gem assets to the load path
plotly_gem_path = Bundler.rubygems.find_name("plotly-rails-js").first&.full_gem_path
if plotly_gem_path
  Rails.application.config.assets.paths << File.join(plotly_gem_path, "vendor", "assets", "javascripts")
end
