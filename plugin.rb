# name: discourse-directoryopus
# about: Plugin specific to the GPSoftware Directory Opus support forum.
# version: 0.1
# authors: Leo Davidson
# url: https://www.gpsoft.com.au

enabled_site_setting :directoryopus_enabled

register_asset 'stylesheets/directoryopus.scss'

after_initialize do

  # We have two modules as we want to have URLs in two different places on the site.

  module ::DiscourseOpusLinkLanding
    class Engine < ::Rails::Engine
      engine_name "opuslinklanding"
      isolate_namespace DiscourseOpusLinkLanding
    end
  end

  module ::DiscourseOpusLink
    class Engine < ::Rails::Engine
      engine_name "opuslink"
      isolate_namespace DiscourseOpusLink
    end
  end

  require_dependency 'application_controller'

  # Server side of the landing component does nothing. We just want the client-side URL to work so it can show
  # some fairly static pages or redirect people to things, based on login state. For whatever reason, that
  # requires setting up a dummy server-side route as well.
  class DiscourseOpusLinkLanding::OpuslinklandingController < ::ApplicationController
    # No point even checking if the plugin is enabled for this one -- before_action :ensure_plugin_enabled
    def index
      render nothing: true
    end
  end

  # Server side of the link component allows refreshing and updating of account linking information.
  class DiscourseOpusLink::OpuslinkController < ::ApplicationController
    # User must be logged in to use any of our server-side APIs, since they set or get info about the logged-in account.
    # For admins only, info can be obtained about other accounts, but that also requires the admin be logged in.
    
    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in

    def ensure_plugin_enabled
      raise Discourse::InvalidAccess.new('Directory Opus plugin is not enabled') if !SiteSetting.directoryopus_enabled
    end

    def index

      # We'll be called via "/user/<username>/link-opus.json?user_id=<user_id>"
      # That gives us both the name and id. The name is only there so the non-json URL in the browser is nicer.
      # Since we'll always be given both, we'll use the user_id as it's faster. That said, this code also works:
      #   if params.has_key?(:username)
      #     user_record = User.find_by_username(params[:username])
      #   end

      user_record = nil

      if params.has_key?(:user_id)
        user_record = User.find_by_id(params[:user_id].to_i)
        if (user_record.blank? && current_user.admin?)
          return render_json_error("Invalid user_id \"#{params[:user_id]}\"")
        end
      elsif current_user.admin?
        return render_json_error("No user_id param")
      end

      if user_record.blank? || (user_record.id != current_user.id && !current_user.admin?)
        return render_json_error("You may only manage account-linking information about your own account")
      end

      return render json: {
        forum_username: user_record.username,
        reg_status: "linked",
        reg_edition: "pro",
        reg_version: "12"
      }

    end
  end

  DiscourseOpusLinkLanding::Engine.routes.draw do
    get '/' => 'opuslinklanding#index'
  end

  DiscourseOpusLink::Engine.routes.draw do
    get '/' => 'opuslink#index'
  end

  require_dependency "config/routes" # for USERNAME_ROUTE_FORMAT.
  Discourse::Application.routes.append do
    mount ::DiscourseOpusLink::Engine, at: "/users/:username/link-opus(.:format)", constraints: {username: USERNAME_ROUTE_FORMAT}
    mount ::DiscourseOpusLinkLanding::Engine, at: "/link-opus"
  end
end
