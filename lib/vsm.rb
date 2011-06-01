#-------------------------------------------------------------------------------------------------
require 'rubygems'
require 'rest_client'
require 'nokogiri'
require 'logger'

#-------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------
class VSE

  #-------------------------------------------------------------------------------------------------
  attr_accessor :url, :user, :password, :logger, :authorization

  #-------------------------------------------------------------------------------------------------
  def initialize(user, password, url, opts={}) 
    @logger = opts[:logger] || Logger.new(File.join(root, '../log', 'vse.log'), 10, 1024000)
  end

  #-------------------------------------------------------------------------------------------------
  # utils
  #-------------------------------------------------------------------------------------------------
  def authorization_token
    @authorization = Base64.encode64("#{@user}:#{@password}")
  end

  #-------------------------------------------------------------------------------------------------
  def get(args)
    headers = (args[:headers] || {}).update(:accept=>args[:accept],
                                            :x_cloud_specification_version=>'0.2')
    headers.update(:authentication=>'BASIC '+ self.session[:authentication]) unless self.session.nil?
    RestClient.get self.site + args[:uri], headers
  end

#####VSE
end
