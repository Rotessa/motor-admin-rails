# frozen_string_literal: true

module Motor
  class ApplicationController < ActionController::Base
    include Motor::CurrentUserMethod
    include Motor::CurrentAbility

    before_action :check_confirm_two_factor_authentication

    private

    def check_confirm_two_factor_authentication
      return unless current_user&.two_factor_authentication == true
      session[:two_factor_authentication] == true ? nil : redirect_to(user_two_factor_authentication_path)
    end
  end
end
