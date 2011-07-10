module XeroGateway
  
  # Shamelessly based on the Twitter Gem's OAuth implementation by John Nunemaker
  # Thanks!
  # 
  # http://twitter.rubyforge.org/
  # http://github.com/jnunemaker/twitter/
  
  class OAuth
    
    class TokenExpired < StandardError; end
    class TokenInvalid < StandardError; end
    class RateLimitExceeded < StandardError; end
    class UnknownError < StandardError; end
        
    unless defined? XERO_CONSUMER_OPTIONS
      XERO_CONSUMER_OPTIONS = {
        :site               => "https://api.xero.com",
        :request_token_path => "/oauth/RequestToken",
        :access_token_path  => "/oauth/AccessToken",
        :authorize_path     => "/oauth/Authorize"
      }.freeze
    end
    
    extend Forwardable
    def_delegators :access_token, :get, :post, :put, :delete
    
    attr_reader :ctoken, :csecret, :consumer_options, :session_handle, :authorization_expires_at
    
    def initialize(ctoken, csecret, options = {})
      @ctoken, @csecret = ctoken, csecret
      @consumer_options = XERO_CONSUMER_OPTIONS.merge(options)
    end
    
    def consumer
      @consumer ||= ::OAuth::Consumer.new(@ctoken, @csecret, consumer_options)
    end
    
    def request_token(params = {})
      @request_token ||= consumer.get_request_token(params)
    end
    
    def authorize_from_request(rtoken, rsecret, params = {})
      request_token     = ::OAuth::RequestToken.new(consumer, rtoken, rsecret)
      access_token      = request_token.get_access_token(params)
      @atoken, @asecret = access_token.token, access_token.secret
      
      update_attributes_from_token(access_token)
    end
    
    def access_token
      @access_token ||= ::OAuth::AccessToken.new(consumer, @atoken, @asecret)
    end
    
    def authorize_from_access(atoken, asecret)
      @atoken, @asecret = atoken, asecret
    end
  
    # Renewing access tokens only works for Partner applications
    def renew_access_token(access_token = nil, access_secret = nil, session_handle = nil)
      access_token   ||= @atoken
      access_secret  ||= @asecret 
      session_handle ||= @session_handle
      
      old_token = ::OAuth::RequestToken.new(consumer, access_token, access_secret)
      
      access_token = old_token.get_access_token({
        :oauth_session_handle => session_handle,
        :token                => old_token
      })
      
      update_attributes_from_token(access_token)
    end
    
    private
    
      # Update instance variables with those from the AccessToken.
      def update_attributes_from_token(access_token)
        @expires_at               = Time.now + access_token.params[:oauth_expires_in].to_i
        @authorization_expires_at = Time.now + access_token.params[:oauth_authorization_expires_in].to_i
        @session_handle           = access_token.params[:oauth_session_handle]
        @atoken, @asecret         = access_token.token, access_token.secret
        @access_token             = nil
      end
    
  end
end
