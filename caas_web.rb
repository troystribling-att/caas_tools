require 'rubygems'
require 'rest_client'
require 'json'
require 'logger'

#-------------------------------------------------------------------------------------------------
# CaaS interface
#-------------------------------------------------------------------------------------------------
class CaaS

  ### types
  LOGIN_TYPE    = 'application/vnd.com.sun.cloud.Login+json'
  MESSAGE_TYPE  = 'application/vnd.com.sun.cloud.common.Messages+json'
  ACCOUNT_TYPE  = 'application/vnd.com.sun.cloud.common.Account+json'
  LOCATION_TYPE = 'application/vnd.com.sun.cloud.common.Location+json'
  CLOUD_TYPE    = 'application/vnd.com.sun.cloud.common.Cloud+json'
  VDC_TYPE      = 'application/vnd.com.sun.cloud.common.VDC+json'
  CLUSTER_TYPE  = 'application/vnd.com.sun.cloud.common.Cluster+json'
  VNET_TYPE     = 'application/vnd.com.sun.cloud.common.Vnet+json'
  VM_TYPE       = 'application/vnd.com.sun.cloud.common.Vm+json'
  VERSION_TYPE  = 'application/vnd.com.sun.cloud.Version+json'

  #-------------------------------------------------------------------------------------------------
  attr_reader :session, :site, :uid, :passwd, :logger

  #-------------------------------------------------------------------------------------------------
  def initialize(uid, passwd, site, opts={})
    @uid, @passwd, @site = uid, passwd, site
    @session = nil
    @logger = opts[:logger] || Logger.new(STDOUT)
    RestClient.log = @logger
  end

  #-------------------------------------------------------------------------------------------------
  # version
  #-------------------------------------------------------------------------------------------------
  def get_version
    headers ={:accept=> VERSION_TYPE, :x_cloud_specification_version=>'0.2'}
    json_to_hash(RestClient.get(self.site + '/version', headers))
  end

  #-------------------------------------------------------------------------------------------------
  # account
  #-------------------------------------------------------------------------------------------------
  def login
    @session = json_to_hash(post(:uri          => '/login',
                                 :body         => {:user_id => self.uid,:password => self.passwd},
                                 :accept       => LOGIN_TYPE,
                                 :content_type => LOGIN_TYPE))
  end

  #-------------------------------------------------------------------------------------------------
  def logout
    post(:uri    => '/logout',
         :accept => MESSAGE_TYPE)
  end

  #-------------------------------------------------------------------------------------------------
  def get_account
    json_to_hash(get(:uri    => self.session[:account_uri],
                     :accept => "#{ACCOUNT_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  # cloud
  #-------------------------------------------------------------------------------------------------
  def get_cloud(uri)
     to_caas_object(json_to_hash(get(:uri    => uri,
                                     :accept => "#{CLOUD_TYPE}, #{MESSAGE_TYPE}")))
  end

  #-------------------------------------------------------------------------------------------------
  def list_clouds(args={})
    json_to_hash(get(:uri    => clouds_uri,
                     :accept => "#{CLOUD_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def clouds_uri
     self.session[:account_uri] + '/clouds'
  end

  #-------------------------------------------------------------------------------------------------
  # vdc
  #-------------------------------------------------------------------------------------------------
  def get_vdc(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{VDC_TYPE}, #{MESSAGE_TYPE}")))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_vdcs(cloud)
    get_all(:vdc, cloud)
  end

  #-------------------------------------------------------------------------------------------------
  def list_vdcs(cloud)
    json_to_hash(get(:uri    => vdc_uri(cloud),
                     :accept => "#{VDC_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def vdc_uri(cloud)
     cloud[:uri] + '/vdcs'
  end

  #-------------------------------------------------------------------------------------------------
  # cluster
  #-------------------------------------------------------------------------------------------------
  def get_cluster(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{CLUSTER_TYPE}, #{MESSAGE_TYPE}")))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_clusters(args)
    get_all(:cluster, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_clusters(vdc)
    json_to_hash(get(:uri    => cluster_uri(vdc),
                     :accept => "#{CLUSTER_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def cluster_uri(vdc)
     vdc[:uri] + '/clusters'
  end

  #-------------------------------------------------------------------------------------------------
  # vnets
  #-------------------------------------------------------------------------------------------------
  def get_vnet(uri)
    to_caas_object(json_to_hash(get(:uri    => uri,
                                    :accept => "#{VNET_TYPE}, #{MESSAGE_TYPE}")))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_vnets(args)
    get_all(:vnet, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_vnets(cluster)
    json_to_hash(get(:uri    => vnet_uri(cluster),
                     :accept => "#{VNET_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def vnet_uri(cluster)
     cluster[:uri] + '/vnets'
  end

  #-------------------------------------------------------------------------------------------------
  # utils
  #-------------------------------------------------------------------------------------------------
  def post(args)
    body = args[:body] || {}
    headers = (args[:headers] || {}).update(:accept=>args[:accept],
                                            :x_cloud_specification_version=>'0.2')
    headers.update(:content_type=>args[:content_type]) unless args[:content_type].nil?
    headers.update(:authentication=>'BASIC '+ self.session[:authentication]) unless self.session.nil?
    RestClient.post self.site + args[:uri], self.to_json(body), headers
  end
  
  #-------------------------------------------------------------------------------------------------
  def get(args)
    headers = (args[:headers] || {}).update(:accept=>args[:accept],
                                            :x_cloud_specification_version=>'0.2')
    headers.update(:authentication=>'BASIC '+ self.session[:authentication]) unless self.session.nil?
    RestClient.get self.site + args[:uri], headers
  end

  #-------------------------------------------------------------------------------------------------
  def delete(args)
    headers = (args[:headers] || {}).update(:accept=>args[:accept],
                                            :x_cloud_specification_version=>'0.2',
                                            :authentication=>'BASIC '+ self.session[:authentication])
    RestClient.delete self.site + args[:uri], headers
  end

  #-------------------------------------------------------------------------------------------------
  def put(args)
    body = args[:body] || {}
    headers = (args[:headers] || {}).update(:accept=>args[:accept],
                                            :x_cloud_specification_version=>'0.2',
                                            :authentication=>'BASIC '+ self.session[:authentication])
    headers.update(:content_type=>args[:content_type]) unless args[:content_type].nil?
    RestClient.put self.site + args[:uri], to_json(body), headers
  end

  #-------------------------------------------------------------------------------------------------
  def get_all(obj, args={})
    send(('list_'+obj.to_s+'s').to_sym, args).map{|(u,o)| u.to_s}.inject([]) do |all, uri|
      begin
        all << send(('get_'+obj).to_sym, uri)
      rescue; all; end
    end
  end

  #-------------------------------------------------------------------------------------------------
  def to_json(hash)
    hash.to_json.gsub(/\\\//,'/')
  end

  #-------------------------------------------------------------------------------------------------
  def json_to_hash(json)
    json.empty? ? nil : symbolize_keys(JSON.parse(json))
  end

  #-------------------------------------------------------------------------------------------------
  def symbolize_keys(obj)
    if obj.kind_of?(Hash)
      obj.inject({}){|r,(k,v)| r.update(k.to_sym=>symbolize_keys(v))}
    elsif obj.kind_of?(Array)
      obj.map{|o| symbolize_keys(o)}
    else; obj; end
  end

end #### CaaS
