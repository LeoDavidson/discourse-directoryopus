# name: discourse-directoryopus
# about: Plugin specific to the GPSoftware Directory Opus support forum.
# version: 0.1
# authors: Leo Davidson
# url: https://www.gpsoft.com.au

enabled_site_setting :directoryopus_enabled

# If separate stylesheets for desktop/mobile are desired, it's done like this:
# register_asset "stylesheets/desktop/directoryopus.scss", :desktop
# register_asset "stylesheets/mobile/directoryopus.scss", :mobile
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
      render json: success_json
    end
  end

  # Server side of the link component allows refreshing and updating of account linking information.
  class DiscourseOpusLink::OpuslinkController < ::ApplicationController
    # User must be logged in to use any of our server-side APIs, since they set or get info about the logged-in account.
    # For admins only, info can be obtained about other accounts, but that also requires the admin be logged in.
    
    before_action :ensure_plugin_enabled
    before_action :ensure_logged_in

    MAX_REGCODE_FAILS = 10

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

    def callRemoteLinkingServer(action, params)
      begin
        paramsAug = params.clone
        paramsAug[:action] = action
        paramsAug[SiteSetting.directoryopus_account_link_code_name.to_sym] = SiteSetting.directoryopus_account_link_code_code

        checkCodeUri = URI(SiteSetting.directoryopus_account_link_url)
        checkCodeUri.query = URI.encode_www_form(paramsAug)

        # At least in the Discourse development and Docker environments, Net::HTTP.get with a HTTPS:// URL will automatically
        # check most aspects of the certificate and fail if it is bad. This part of Ruby has improved over the years.
        res = Net::HTTP.get(checkCodeUri)
        return JSON.parse(res, { :symbolize_names=>true })
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
      return false if (link_status.blank? || !(link_status.is_a? String))
      statusLower = link_status.downcase
      if (statusLower.blank? || statusLower == "invalid")
        # Must delete the values. Not sure setting them to nil etc. works. Deleting is better anyway.
        u.custom_fields.delete("directoryopus_link_last_refreshed")
        u.custom_fields.delete("directoryopus_link_version")
        u.custom_fields.delete("directoryopus_link_edition")
        u.custom_fields.delete("directoryopus_link_id")
      elsif (statusLower == "linked" && !link_id.blank?)
        u.custom_fields["directoryopus_link_last_refreshed"] = Time.now.utc
        u.custom_fields["directoryopus_link_version"] = link_version
        u.custom_fields["directoryopus_link_edition"] = link_edition
        u.custom_fields["directoryopus_link_id"] = link_id
        u.custom_fields.delete("directoryopus_link_failures") # If they succeed, clean up any recorded failures from the database.
      else
        return false
      end
      if (!u.save_custom_fields)
        return false
      end
      return true
    end

    def addUserFailureCode(user, invalidCode)
      if (user.is_a? Numeric)
        u = User.find_by_id(user)
      else
        u = user
      end
      return false if u.blank?
      failString = u.custom_fields["directoryopus_link_failures"]
      if (!(failString.blank?) && (failString.is_a? String))
        failMap = JSON.parse(failString)
      else
        failMap = Hash.new
      end
      oldMapSize = failMap.size
      failMap[invalidCode] = true
      if (oldMapSize >= failMap.size)
        return false
      end
      u.custom_fields["directoryopus_link_failures"] = JSON.generate(failMap)
      if (!u.save_custom_fields)
        return false
      end
      actingUserForLog = current_user
      if current_user.id == u.id
        actingUserForLog = -1 # Mark it as the system user if it's (presumably) not an admin changing someone else, since it's an admin action log not a user action log.
      end
      logDetails = "RegCode: #{invalidCode.gsub(/^([A-Z0-9]{5}-){3}(.+)$/, '...-\2')}"
      logAdminAction(actingUserForLog, u, "linkopus_badcode", nil, nil, logDetails)
      if (failMap.size >= MAX_REGCODE_FAILS)
        logDetails = "MaxAttempts: #{MAX_REGCODE_FAILS}"
        logAdminAction(actingUserForLog, u, "linkopus_block", nil, nil, logDetails)
      end
      return true
    end

    def clearUserFailureCodes(user)
      if (user.is_a? Numeric)
        u = User.find_by_id(user)
      else
        u = user
      end
      return false if u.blank?
      u.custom_fields.delete("directoryopus_link_failures")
      if (!u.save_custom_fields)
        return false
      end
      return true
    end

    def getUserLinkData(user)
      return false if user.blank?
      if (user.is_a? Numeric)
        user_id = user
      else
        user_id = user.id
      end

      # Calling userObject.custom_fields["x"] is easier, but turns into a SQL request per lookup.
      # Getting them out in a batch is more efficient:
      #    User.custom_fields_for_ids(user_id, ["directoryopus_link_id", "directoryopus_link_last_refreshed", "directoryopus_link_version", "directoryopus_link_edition"])
      #       If user_id=3 => {3=>{"directoryopus_link_last_refreshed"=>"2017-02-22 23:28:41 UTC", "directoryopus_link_version"=>"12", "directoryopus_link_edition"=>"light", "directoryopus_link_id"=>"xxxxxxxxxxxxxxxx_leo"}}
      #       Or {} if nothing found at all.
      fieldsMap = User.custom_fields_for_ids(user_id, ["directoryopus_link_id", "directoryopus_link_last_refreshed", "directoryopus_link_version", "directoryopus_link_edition", "directoryopus_link_failures"])[user_id]
      if (fieldsMap.blank?)
        return {
          :link_status => false
        }
      elsif (fieldsMap["directoryopus_link_id"].blank?)
        return {
          :link_status => false,
          :link_failures => fieldsMap["directoryopus_link_failures"]
        }
      else
        refresh_time_distance = ""
        timeThenUTC = fieldsMap["directoryopus_link_last_refreshed"]
        if !timeThenUTC.blank?
          refresh_time_distance = view_context.distance_of_time_in_words(
            Time.now.utc, timeThenUTC,
            { :scope => :'datetime.distance_in_words_verbose' })
        end
        return {
          :link_status => true,
          :link_id => fieldsMap["directoryopus_link_id"],
          :link_last_refreshed => refresh_time_distance,
          :link_version => fieldsMap["directoryopus_link_version"],
          :link_edition => fieldsMap["directoryopus_link_edition"]
        }
      end
    end

    def logAdminAction(actingUser, targetUser, actionName, oldValue, newValue, details)

      if (actingUser.is_a? Numeric)
        au = User.find_by_id(actingUser)
      else
        au = actingUser
      end

      if (targetUser.is_a? Numeric)
        tu = User.find_by_id(targetUser)
      else
        tu = targetUser
      end

      user_url_path = "/users/#{tu.username}/link-opus"

      # based on log_custom: https://github.com/discourse/discourse/blob/master/app/services/staff_action_logger.rb
      attrs = {}
      attrs[:action] = UserHistory.actions[:custom_staff]
      attrs[:custom_type] = actionName
      attrs[:acting_user_id] = au.id
      attrs[:target_user_id] = tu.id
      attrs[:context] = user_url_path
      attrs[:previous_value] = oldValue if (!(oldValue.blank?))
      attrs[:new_value] = newValue if (!(newValue.blank?))
      attrs[:details] = details
    # attrs[:details] = details.map {|r| "#{r[0]}: #{r[1]}"}.join("\n")
      UserHistory.create(attrs)
    end

    def makeLinkContextLine(opusVersion, opusEdition)
      if (opusVersion.blank? && opusEdition.blank?)
        return "Not linked"
      else
        opusVersion = "<unknown version>" if (opusVersion.blank?)
        opusEdition = "<unknown edition>" if (opusEdition.blank?)
        return "Linked v#{opusVersion} #{opusEdition}"
      end      
    end

    def index
      res = indexMain(params)
      if (res.is_a? String)
        return render_json_error(res)
      elsif (res.is_a? Hash)
        res.delete(:link_id) if !current_user.admin? # The link_id is not really secret but there is no reason to send it to the client.
        res.delete(:link_failures) if !current_user.admin? || res[:link_failures].blank?
        return render json: res
      end
      return render_json_error("Unexpected result type. Please notify an admin via private message.")
    end

    def indexMain(params)

      # We'll be called via "/user/<username>/link-opus.json?user_id=<user_id>"
      # That gives us both the name and id. The name is only there so the non-json URL in the browser is nicer.
      # Since we'll always be given both, we'll use the user_id as it's faster. That said, this code also works:
      #   if params.has_key?(:username)
      #     user_record = User.find_by_username(params[:username])
      #   end

      operationQuery = false
      operationLink = false
      operationRefresh = false
      operationClearLocal = false
      operationClearFailures = false

      if params.has_key?(:operation)
        operation = params[:operation]
        if !operation.is_a? String
          return "Invalid operation."
        end
        opLower = operation.downcase
        if opLower == "link"
          operationLink = true
        elsif opLower == "refresh"
          operationRefresh = true
        elsif opLower == "clearlocal"
          operationClearLocal = true
        elsif opLower == "clearfailures"
          clearUserFailureCodes = true
        elsif opLower != "query"
          # operationQuery is set later on, not here.
          return "Invalid operation."
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
        return "Invalid user_id"
      end

      if (operationClearLocal || clearUserFailureCodes)
        if (!current_user.admin?)
          return "You can't do that."
        end
      elsif (operationLink || operationRefresh)
        if (user_record.id != current_user.id && !current_user.admin?)
          return "You may only manage account-linking information for your own account."
        end
      else
        operationQuery = true
      end

      # Get our own local idea of the account's current state.
      userLinkDetails = getUserLinkData(user_record)
      if (userLinkDetails.blank?)
        return "Error obtaining account linking details. Please notify an admin via private message."
      end

      if (operationClearLocal)
          oldContext = makeLinkContextLine(userLinkDetails[:link_version], userLinkDetails[:link_edition])
          newContext = makeLinkContextLine(nil, nil)
          logAdminAction(current_user, user_record, "linkopus_unlink", oldContext, newContext, nil)
          setUserLinkData(user_record, "invalid", nil, nil, nil)
          userLinkDetails = getUserLinkData(user_record)
          return userLinkDetails
      end

      if (clearUserFailureCodes)
          logAdminAction(current_user, user_record, "linkopus_clearfail", nil, nil, nil)
          clearUserFailureCodes(user_record)
          userLinkDetails = getUserLinkData(user_record)
          return userLinkDetails
      end

      # If we are just querying things, we can return the state immediately.
      if operationQuery
        return userLinkDetails
      end

      # If the forum is in read-only mode then we can't change anything.
      if Discourse.readonly_mode?
        userLinkDetails[:remote_error] = I18n.t('read_only_mode_enabled')
        return userLinkDetails
      end

      jsonRemoteResult = nil
      remoteStatusLower = nil
      link_id = userLinkDetails[:link_id]

      if operationRefresh

        if (link_id.blank?)
          # If we are refreshing, and there is no link_id, then we're done as the details are unchanged.
          return userLinkDetails
        end

        jsonRemoteResult = callRemoteLinkingServer("check", { :linkId => link_id } )

        if (jsonRemoteResult.blank? || jsonRemoteResult[:status].blank? || (!(jsonRemoteResult[:status].is_a? String)))
          remoteStatusLower = "error"
        else
          remoteStatusLower = jsonRemoteResult[:status].downcase
        end

      elsif operationLink

        if (!link_id.blank?)
          # If we are linking, there can't already be linked. Either the UI is confused or someone's sending bogus requests.
          userLinkDetails[:remote_error] = "Account is already linked. Please notify an admin via private message."
          return userLinkDetails
        end

        failString = userLinkDetails[:link_failures]
        if (!(failString.blank?) && (failString.is_a? String))
          failMap = JSON.parse(failString)
          if (failMap.size >= MAX_REGCODE_FAILS)
            userLinkDetails[:remote_error] = "Too many invalid attempts. Please contact an admin via private message."
            return userLinkDetails
          end
        end

        regCode = params[:reg_code]
        # The client should have processed the reg code into the correct case and format, so our regex is strict here.
        if (regCode.blank? || (!(regCode.is_a? String)) || regCode !~ /^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/)
          userLinkDetails[:remote_error] = "RC param invalid. Please notify an admin via private message."
          return userLinkDetails
        end

        takeOwnership = false
        takeOwnershipDoneOnce = false
        loop do

          jsonRemoteResult = callRemoteLinkingServer("link", { :reg => regCode, :link => user_record.username, :force => (takeOwnership ? 1 : 0) } )

          if takeOwnership
            takeOwnership = false
            takeOwnershipDoneOnce = true
          end

          if (jsonRemoteResult.blank? || jsonRemoteResult[:status].blank? || (!(jsonRemoteResult[:status].is_a? String)))
            remoteStatusLower = "error"
          else
            remoteStatusLower = jsonRemoteResult[:status].downcase
          end

          if remoteStatusLower == "invalid"
            addUserFailureCode(user_record, regCode)
            userLinkDetails = getUserLinkData(user_record) # This is mainly for admin users, so they see the failed code immediately.
            if (userLinkDetails.blank?)
              return "Error re-obtaining account linking details. Please notify an admin via private message."
            end
            userLinkDetails[:remote_error] = "Invalid registration code."
            return userLinkDetails
          elsif remoteStatusLower == "used"
            # Handle situation where account is already linked, and it looks like it was linked to this account
            # but we failed to record the fact on our side. e.g. Read-only mode, power failure, transaction failure after
            # we already told the remote system to create the link. It'll think we're linked but we won't know.
            # No other account should have the same linkId already. (So if a linked account is renamed, and remains
            # linked, someone cannot then create an account with the old name and take over their reg code.
            # Unlikely, but not impossible (people publicly post their codes sometimes), and simple to check.)
            # If we *already* tried to take ownership once, give up, else we could loop forever.
            remoteUserName = jsonRemoteResult[:link]   # What the remote database thinks is the forum username.
            remoteLinkId   = jsonRemoteResult[:linkId] # Unique ID representing the link / row in the remote database.
            if (!takeOwnershipDoneOnce &&
                !(remoteUserName.blank?) && (remoteUserName.is_a? String)  &&
                !(remoteLinkId.blank?)   && (remoteLinkId.is_a? String)    &&
                (remoteUserName.downcase == user_record.username.downcase) &&
                (UserCustomField.find_by(name: "directoryopus_link_id", value: remoteLinkId).blank?))
              takeOwnership = true
            end
            
            if !takeOwnership
              # OK, it is used for real, so return a simple error.
              userLinkDetails[:remote_error] = "That registration code is already linked to another account."
              return userLinkDetails
            end
          end
          
          break if !takeOwnership
        end

      end

      if remoteStatusLower == "error"
        userLinkDetails[:remote_error] = "Request failed. Please try later. If the problem persists, please notify an admin via private message."
        return userLinkDetails
      end

      resultBad = false

      if remoteStatusLower == "linked"
        if jsonRemoteResult[:linkId].blank?       || (!(jsonRemoteResult[:linkId].is_a? String)) ||
           jsonRemoteResult[:type].blank?         || (!(jsonRemoteResult[:type].is_a? String))   ||
           (!jsonRemoteResult.has_key?(:version)) || (!(jsonRemoteResult[:version].is_a? Numeric))
          resultBad = true
        end
      elsif remoteStatusLower != "invalid"
        resultBad = true
      end

      if resultBad
        userLinkDetails[:remote_error] = "Invalid result from server. Please notify an admin via private message."
        return userLinkDetails
      end

      # Test read-only mode a second time, as the request to the remote server could have taken a while.
      # This could mean we have linked the account on the remote server but now not recorded the fact.
      # The user will have to retry, but we'll handle that situation.
      # We have to handle that situation anyway as there are other ways it can happen, not just read-only turning on.
      if Discourse.readonly_mode?
        userLinkDetails[:remote_error] = I18n.t('read_only_mode_enabled')
        return userLinkDetails
      end

      # Save our version of the new data.
      if ((jsonRemoteResult[:version].to_i != userLinkDetails[:link_version].to_i) || (jsonRemoteResult[:type] != userLinkDetails[:link_edition]))
        oldContext = makeLinkContextLine(userLinkDetails[:link_version], userLinkDetails[:link_edition])
        newContext = makeLinkContextLine(jsonRemoteResult[:version], jsonRemoteResult[:type])
        actingUserForLog = current_user
        if current_user.id == user_record.id
          actingUserForLog = -1 # Mark it as the system user if it's (presumably) not an admin changing someone else, since it's an admin action log not a user action log.
        end
        logAdminAction(actingUserForLog, user_record, "linkopus_change", oldContext, newContext, nil)
      end
      if (!setUserLinkData(user_record, remoteStatusLower, jsonRemoteResult[:version], jsonRemoteResult[:type], jsonRemoteResult[:linkId]))
        userLinkDetails[:remote_error] = "Failed to update database. Please notify an admin via private message."
        return userLinkDetails
      end

      # Get our view of the new data back out again, rather than update the object we had.
      # Doing it this way is easier, and will show problems sooner if the round-trip didn't actually work.
      userLinkDetails = getUserLinkData(user_record)
      if (userLinkDetails.blank?)
        return "Error re-obtaining account linking details. Please notify an admin via private message."
      end

      # Augment the returned data if we have some extras from the server.
      if remoteStatusLower == "linked"
        if !jsonRemoteResult[:regcodeRedacted].blank?
         userLinkDetails[:link_reg_code_redacted] = jsonRemoteResult[:regcodeRedacted]
        end
        if !jsonRemoteResult[:regDate].blank?
         userLinkDetails[:link_reg_date] = jsonRemoteResult[:regDate]
        end
      end

      return userLinkDetails

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
