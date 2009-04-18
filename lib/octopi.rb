require 'rubygems'
require 'httparty'
require 'pp'

module Octopi
  def connect(login, token, &block)
    yield Api.new(login, token)
  end
  
  class Api
    include HTTParty
    base_uri "https://github.com/api/v2"
  
    attr_accessor :format
  
    def initialize(login, token, format = "yaml")
      self.class.default_params :login => login, :token => token
      @format = format
    end
  
    %w[keys emails].each do |action|
      define_method("#{action}") do
        get("/user/#{action}")
      end
    end
  
    def user(username = self.class.default_params[:login])
      user_data = get("/user/show/#{username}")

      raise "Unexpected response for user command" unless user_data and user_data['user']

      User.new(self, user_data['user'])
    end
    
    def save(resource_path, data)
      self.class.default_params.each_pair do |k,v|
        resource_path.gsub!(":#{k.to_s}", v)
      end
      #still can't figure out on what format values are expected
      self.class.post("#{resource_path}", { :query => data })
    end
  
    private
    def get(uri)
      self.class.get("/#{format}#{uri}")
    end
  end
  
  class Base
    def initialize(api, hash)
      @api = api
      @keys = []
      
      raise "Missing data for #{self.class.name}" unless hash
      
      hash.each_pair do |k,v|
        @keys << k
        instance_variable_set("@#{k}", v)
        
        self.class.send :define_method, "#{k}=" do |v|
          instance_variable_set("@#{k}", v)
        end

        self.class.send :define_method, k do
          instance_variable_get("@#{k}")
        end
      end
    end
    
    def self.resource_path(path)
      @@res = path
    end
    
    def save
      hash = {}
      @keys.each { |k| hash[k] = send(k) }
      @api.save(@@res, hash)
    end
  end
  
  class User < Base
    resource_path "/user/:login"
  end
end