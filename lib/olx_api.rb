# encoding: UTF-8

require "olx_api/version"
require 'rubygems'
require 'net/http'
require 'net/https'
require 'json'
require 'uri'
require 'yaml'

class OlxApi
    attr_accessor :access_token
    attr_reader :secret, :app_id, :https

    config = YAML.load_file(File.expand_path(File.dirname(__FILE__) + "/config.yml"))
    SDK_VERSION = config["config"]["sdk_version"]
    API_ROOT_URL = config["config"]["api_root_url"]
    AUTH_URL = config["config"]["auth_url"]
    OAUTH_URL = config["config"]["oauth_url"]

    #constructor
    def initialize(app_id = nil, secret = nil, access_token = nil)
        @access_token = access_token
        @app_id = app_id
        @secret = secret
        api_url = URI.parse API_ROOT_URL
        @https = Net::HTTP.new(api_url.host, api_url.port)
        @https.use_ssl = true
        @https.verify_mode = OpenSSL::SSL::VERIFY_PEER
        @https.ssl_version = :TLSv1
    end

    #AUTH METHODS
    def auth_url(redirect_URI, params = {})
        params_full = {:client_id  => @app_id, :response_type => 'code', :redirect_uri => redirect_URI, :scope => 'basic_user_info autoupload'}
        params_full.merge!(params)
        url = "#{AUTH_URL}?#{to_url_params(params_full)}"
    end

    def authorize(code, redirect_URI, params = {})
        
        auth_url = URI.parse OAUTH_URL
        @https_auth = Net::HTTP.new(auth_url.host, auth_url.port)
        @https_auth.use_ssl = true
        @https_auth.verify_mode = OpenSSL::SSL::VERIFY_PEER
        @https_auth.ssl_version = :TLSv1


        params_full = { :grant_type => 'authorization_code', :client_id => @app_id, :client_secret => @secret, :code => code, :redirect_uri => redirect_URI}
        params_full.merge!(params)

        req = Net::HTTP::Post.new(OAUTH_URL)
        req['Accept'] = 'application/json'
        req['User-Agent'] = SDK_VERSION
        req['Content-Type'] = "application/x-www-form-urlencoded"
        req.set_form_data(params_full)
        response = @https_auth.request(req)

        case response
        when Net::HTTPSuccess
            response_info = JSON.parse response.body
            #convert hash keys to symbol
            response_info = Hash[response_info.map{ |k, v| [k.to_sym, v] }]

            @access_token = response_info[:access_token]
            @access_token
        else
            # response code isn't a 200; raise an exception
            response.error!
        end

    end

   

    #REQUEST METHODS
    def execute(req)
        req['Accept'] = 'application/json'
        req['User-Agent'] = SDK_VERSION
        req['Content-Type'] = 'application/json;charset=UTF-8'
        req["Accept-Charset"] = "utf-8"
        response = @https.request(req)
    end

    def post(path, body, params = {})
        uri = make_path(path, params)
        req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
        req.set_form_data(params)
        req.body = body.to_json unless body.nil?
        execute req
    end

    def put(path, body, params = {})
        uri = make_path(path, params)
        req = Net::HTTP::Put.new("#{uri.path}?#{uri.query}")
        req.set_form_data(params)
        req.body = body.to_json unless body.nil?
        execute req
    end

    def insert(body, params = {})
        body.merge!({access_token: @access_token})
        
        put('/autoupload/import', body, params)
    end

    def delete(body, params = {})
        body.merge!({access_token: @access_token})

        put('/autoupload/import', body, params)
    end


    private
        def to_url_params(params)
          URI.escape(params.collect{|k,v| "#{k}=#{v}"}.join('&'))
        end

        def make_path(path, params = {})
            # Making Path and add a leading / if not exist
            unless path =~ /^http/
                path = "/#{path}" unless path =~ /^\//
                path = "#{API_ROOT_URL}#{path}"
            end
            path = "#{path}?#{to_url_params(params)}" if params.keys.size > 0
            uri = URI.parse path
        end


end  #class
