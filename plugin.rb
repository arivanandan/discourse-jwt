# frozen_string_literal: true
# name: discourse-jwt
# about: JSON Web Tokens Auth Provider
# version: 0.1
# author: Robin Ward

require_dependency 'auth/oauth2_authenticator'

gem "discourse-omniauth-jwt", "0.0.2", require: false

require 'omniauth/jwt'

class JWTAuthenticator < ::Auth::OAuth2Authenticator
  def register_middleware(omniauth)
    omniauth.provider :jwt,
                      name: 'jwt',
                      uid_claim: 'id',
                      required_claims: ['id', 'email', 'name'],
                      setup: lambda { |env|
                        opts = env['omniauth.strategy'].options
                        opts[:secret] = SiteSetting.jwt_secret
                        opts[:auth_url] = SiteSetting.jwt_auth_url
                      }
  end

  def enabled?
    # Check the global setting for backwards-compatibility.
    # When this plugin used only global settings, there was no separate enable setting
    SiteSetting.jwt_enabled || GlobalSetting.try(:jwt_auth_url)
  end

  def after_authenticate(auth)
    result = Auth::Result.new

    uid = auth[:uid]
    result.name = auth[:info].name
    result.username = uid
    result.email = auth[:info].email
    result.email_valid = true

    current_info = ::PluginStore.get("jwt", "jwt_user_#{uid}")
    if current_info
      result.user = User.where(id: current_info[:user_id]).first
    end
    result.extra_data = { jwt_user_id: uid }
    result
  end

  def after_create_account(user, auth)
    ::PluginStore.set("jwt", "jwt_user_#{auth[:extra_data][:jwt_user_id]}", user_id: user.id)
  end

end

auth_provider authenticator: JWTAuthenticator.new('jwt')
