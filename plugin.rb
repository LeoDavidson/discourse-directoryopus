# name: discourse-directoryopus
# about: Plugin specific to the GPSoftware Directory Opus support forum.
# version: 0.1
# authors: Leo Davidson
# url: https://www.gpsoft.com.au

enabled_site_setting :directoryopus_enabled

register_asset 'stylesheets/directoryopus.scss'

require 'net/http'
require 'json'

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
      # This should never be called, but once in dev I saw errors when going to the client side URL
      # typed by hand, when this returned "render nothing: true", so I've made it return success instead.
      
      puts "------------------------------------------------- Opuslinklanding INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslinklanding INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslinklanding INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslinklanding INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslinklanding INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslinklanding INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslinklanding INDEX CALLED -------------------------------------------------"
      
      render json: success_json
    end
  end

  # Server side of the link component allows refreshing and updating of account linking information.
  class DiscourseOpusLink::OpuslinkController < ::ApplicationController
    # User must be logged in to use any of our server-side APIs, since they set or get info about the logged-in account.
    # For admins only, info can be obtained about other accounts, but that also requires the admin be logged in.
    
    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in

    def ensure_plugin_enabled
      if !SiteSetting.directoryopus_enabled
        raise Discourse::InvalidAccess.new('Directory Opus plugin is not enabled')
      end
      if (SiteSetting.directoryopus_account_link_url.blank? || SiteSetting.directoryopus_account_link_code_name.blank? || SiteSetting.directoryopus_account_link_code_code.blank?)
        raise Discourse::InvalidAccess.new('Directory Opus plugin is not configured')
      end
      if !SiteSetting.directoryopus_account_link_url.downcase.start_with?("https://")
        raise Discourse::InvalidAccess.new('Directory Opus plugin is misconfigured')
      end
    end

    # callRemoteLinkingServer("echo", { :hello => "moo Hello", :there => "cow" } )
    def callRemoteLinkingServer(action, params)
      begin
        paramsAug = params.clone
        paramsAug[:action] = action
        paramsAug[SiteSetting.directoryopus_account_link_code_name.to_sym] = SiteSetting.directoryopus_account_link_code_code
        checkCodeUri = URI(SiteSetting.directoryopus_account_link_url)
        checkCodeUri.query = URI.encode_www_form(checkCodeParams)
        # TODO: Find out if we need to do extra to verify the server's certificate is signed by a valid CA here.
        #       I've checked that this makes sure the certificate matches the server, but that on its own isn't
        #       enough to prevent a fake server with a fake cert that is self-signed or signed by a bogus CA.
        res = Net::HTTP.get(checkCodeuri)
        return JSON.parse(res)
      rescue
        return false
      end
    end

    def setUserLinkData(user, link_status, link_version, link_edition, link_id)
      if (user.is_a? Numeric)
        u = User.find_by_id(user)
      else
        u = user
      end
      return false if u.blank?
      statusLower = link_status.downcase
      if (statusLower.blank? || statusLower == "invalid")
        u.custom_fields["directoryopus_link_status"] = false
        u.custom_fields["directoryopus_link_version"] = nil
        u.custom_fields["directoryopus_link_edition"] = nil
        u.custom_fields["directoryopus_link_id"] = nil
      elsif (statusLower == "linked" && !link_id.blank?)
        u.custom_fields["directoryopus_link_status"] = true
        u.custom_fields["directoryopus_link_version"] = link_version
        u.custom_fields["directoryopus_link_edition"] = link_edition
        u.custom_fields["directoryopus_link_id"] = link_id
      else
        return false
      end
      if (!u.save)
        return false
      end
      return true
    end

    def getUserLinkData(user)
      if (user.is_a? Numeric)
        u = User.find_by_id(user)
      else
        u = user
      end
      return false if u.blank?
      link_status = u.custom_fields["directoryopus_link_status"]
      if (link_status.blank?)
        return {
          :link_status => false
        }
      else
        return {
          :link_status => true,
          :link_version => u.custom_fields["directoryopus_link_version"],
          :link_edition => u.custom_fields["directoryopus_link_edition"],
          :link_id => u.custom_fields["directoryopus_link_id"],
        }
      end
    end

    def index

      # REMINDER: What do we need to do to respect read-only mode in Discourse, if anything?
      puts "------------------------------------------------- Opuslink INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslink INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslink INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslink INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslink INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslink INDEX CALLED -------------------------------------------------"
      puts "------------------------------------------------- Opuslink INDEX CALLED -------------------------------------------------"

      # We'll be called via "/user/<username>/link-opus.json?user_id=<user_id>"
      # That gives us both the name and id. The name is only there so the non-json URL in the browser is nicer.
      # Since we'll always be given both, we'll use the user_id as it's faster. That said, this code also works:
      #   if params.has_key?(:username)
      #     user_record = User.find_by_username(params[:username])
      #   end

      operationQuery = false
      operationLink = false
      operationRefresh = false

      if params.has_key?(:operation)
        operation = params[:operation]
        if !operation.is_a? String
          return render_json_error("Invalid operation")
        end
        oplower = operation.downcase
        if oplower == "link"
          operationLink = true
        elsif opLower == "refresh"
          operationRefresh = true
        elsif opLower != "query"
          # operationQuery is set later on, not here.
          return render_json_error("Invalid operation")
        end
      end

      user_record = nil

      if params.has_key?(:user_id)
        user_id = params[:user_id]
        if user_id.is_a? String
          user_record = User.find_by_id(user_id.to_i)
        end
      end

      if user_record.blank?
        return render_json_error("Invalid user_id")
      end

      if (operationLink || operationRefresh)
        if (user_record.id != current_user.id && !current_user.admin?)
          return render_json_error("You may only manage account-linking information for your own account")
        end
      else
        operationQuery = true
      end

      # Get our own local idea of the account's current state.
      userLinkDetails = getUserLinkData(user_record)
      if (userLinkDetails.blank?)
        return render_json_error("Error obtaining account linking details")
      end

      # If we are just querying things, we can return the state immediately.
      if operationQuery
        return render json: userLinkDetails
      end

      jsonRemoteResult = nil

      if operationRefresh
        link_id = userLinkDetails[:link_id]
        if (link_id.blank?)
          # If we are refreshing, and there is no link_id, then we're done as the details are unchanged.
          return render json: userLinkDetails
        end
        jsonRemoteResult = callRemoteLinkingServer("FailOnPurpose_check", { :linkId => link_id } )
        if (jsonRemoteResult.blank?)
          userLinkDetails[:remote_error] = "Error refreshing account linking details"
          return userLinkDetails
        end
      elsif operationLink
        link_id = userLinkDetails[:link_id]
        if (!link_id.blank?)
          # If we are linking, they can't already be linked. Either the UI is confused or someone's sending bogus requests.
          userLinkDetails[:remote_error] = "Account was already linked"
          return render json: userLinkDetails
        end

        # TODO: Throttle the requests so they can't brute-force a reg code.
        #       After too many failures, block them from being able to link at all and notify all admins.
        #       But: If current_user.admin, allow the block to be bypassed (but not the throttle?)
        userLinkDetails[:remote_error] = "Linking not implemented yet"
        return render json: userLinkDetails
      end

      # TODO: Update the user record based on what came out.      

      return render json: userLinkDetails

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
