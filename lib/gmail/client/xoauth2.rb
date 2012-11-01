require 'gmail_xoauth'

module Gmail
  module Client
    class XOAuth2 < Base
      attr_reader :oauth2_token

      def initialize(username, options={})
        @oauth2_token    = options.delete(:oauth2_token)
        super(username, options)
      end

      def login(raise_errors=false)
        @imap and @logged_in = (@imap.authenticate('XOAUTH2', username, oauth2_token)) && login.name == 'OK'
      rescue
        raise_errors and raise AuthorizationError, "Couldn't login to given GMail account: #{username}"
      end

      def smtp_settings
        [:smtp, {
           :address => GMAIL_SMTP_HOST,
           :port => GMAIL_SMTP_PORT,
           :domain => mail_domain,
           :user_name => username,
           :password => {
             :token => oauth2_token
           },
           :authentication => :xoauth2,
           :enable_starttls_auto => true
         }]
      end
    end # XOAuth

    register :xoauth2, XOAuth2
  end # Client
end # Gmail


