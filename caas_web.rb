require 'rubygems'
require 'rest_client'
require 'json'
require 'logger'

#-------------------------------------------------------------------------------------------------
class CaaSError < Exception; end

#-------------------------------------------------------------------------------------------------
# CaaS interface
#-------------------------------------------------------------------------------------------------
class CaaS

  ### types
  LOGIN_TYPE           = 'application/vnd.com.sun.cloud.Login+json'
  MESSAGE_TYPE         = 'application/vnd.com.sun.cloud.common.Messages+json'
  ACCOUNT_TYPE         = 'application/vnd.com.sun.cloud.Account+json'
  LOCATION_TYPE        = 'application/vnd.com.sun.cloud..Location+json'
  VMTEMPLATE_TYPE      = 'application/vnd.com.sun.cloud.VMTemplate+json'
  CLOUD_TYPE           = 'application/vnd.com.sun.cloud.Cloud+json'
  VDC_TYPE             = 'application/vnd.com.sun.cloud.VDC+json'
  CLUSTER_TYPE         = 'application/vnd.com.sun.cloud.Cluster+json'
  VNET_TYPE            = 'application/vnd.com.sun.cloud.Vnet+json'
  VOLUME_TYPE          = 'application/vnd.com.sun.cloud.Volume+json'
  VM_TYPE              = 'application/vnd.com.sun.cloud.Vm+json'
  FW_TYPE              = 'application/vnd.com.sun.cloud.Fw+json'
  FWRULE_TYPE          = 'application/vnd.com.sun.cloud.FwRule+json'
  LBPOOL_TYPE          = 'application/vnd.com.sun.cloud.LbPool+json'
  LBPOOL_MEMBER_TYPE   = 'application/vnd.com.sun.cloud.LbPoolMember+json'
  LB_TYPE              = 'application/vnd.com.sun.cloud.Lb+json'
  VERSION_TYPE         = 'application/vnd.com.sun.cloud.Version+json'

  #-------------------------------------------------------------------------------------------------
  MAX_RETRIES     = 120
  SLEEP_RETRY     = 10

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
  # locations
  #-------------------------------------------------------------------------------------------------
  def get_location(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{LOCATION_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_locations
    get_all(:location)
  end

  #-------------------------------------------------------------------------------------------------
  def list_locations(args={})
    json_to_hash(get(:uri    => locations_uri,
                     :accept => "#{LOCATION_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def locations_uri
     '/locations'
  end

  #-------------------------------------------------------------------------------------------------
  # vm templates
  #-------------------------------------------------------------------------------------------------
  def get_vmtemplate(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{VMTEMPLATE_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_vmtemplates
    get_all(:vmtemplate)
  end

  #-------------------------------------------------------------------------------------------------
  def list_vmtemplates(args={})
    json_to_hash(get(:uri    => vmtemplates_uri,
                     :accept => "#{VMTEMPLATE_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def vmtemplates_uri
     '/vmtemplates'
  end

  #-------------------------------------------------------------------------------------------------
  # cloud
  #-------------------------------------------------------------------------------------------------
  def get_cloud(uri)
     json_to_hash(get(:uri    => uri,
                      :accept => "#{CLOUD_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def list_clouds(arg={})
    json_to_hash(get(:uri    => clouds_uri,
                     :accept => "#{CLOUD_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_clouds
    get_all(:cloud)
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
                     :accept => "#{VDC_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_vdcs(cloud)
    get_all(:vdc, cloud)
  end

  #-------------------------------------------------------------------------------------------------
  def list_vdcs(cloud)
    json_to_hash(get(:uri    => vdcs_uri(cloud),
                     :accept => "#{VDC_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def vdcs_uri(cloud)
     cloud[:cloud_uri] + '/vdcs'
  end

  #-------------------------------------------------------------------------------------------------
  # cluster
  #-------------------------------------------------------------------------------------------------
  def get_cluster(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{CLUSTER_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_clusters(args)
    get_all(:cluster, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_clusters(vdc)
    json_to_hash(get(:uri    => clusters_uri(vdc),
                     :accept => "#{CLUSTER_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def clusters_uri(vdc)
     vdc[:uri] + '/clusters'
  end

  #-------------------------------------------------------------------------------------------------
  # vnets
  #-------------------------------------------------------------------------------------------------
  def get_vnet(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{VNET_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_vnets(args)
    get_all(:vnet, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_vnets(cluster)
    json_to_hash(get(:uri    => vnets_uri(cluster),
                     :accept => "#{VNET_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def vnets_uri(cluster)
     cluster[:uri] + '/vnets'
  end

  #-------------------------------------------------------------------------------------------------
  # volumes
  #-------------------------------------------------------------------------------------------------
  def get_volume(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{VOLUME_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_volumes(vdc)
    get_all(:volume, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_volumes(vdc)
    json_to_hash(get(:uri    => volumes_uri(vdc),
                     :accept => "#{VOLUME_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def volumes_uri(vdc)
     vdc[:uri] + '/volumes'
  end

  #-------------------------------------------------------------------------------------------------
  # vms
  #-------------------------------------------------------------------------------------------------
  def create_vm(args)
    validate([:name, :vmtemplate, :vnets, :cluster, :location], args)
    vnets = args[:vnets].map do |n| 
      n.kind_of?(String) ? n : n[:uri]
    end
    template_uri = args[:vmtemplate].kind_of?(String) ?  args[:vmtemplate] : args[:vmtemplate][:uri]
    location_uri =  args[:location].kind_of?(String) ?  args[:location] : args[:location][:uri]
    body = {:name           => args[:name],
            :description    => args[:description] || '',
            :vmtemplate_uri => template_uri,
            :locations_uri  => location_uri,
            :vnets          => vnets}
    res = post(:uri          => vms_uri(args[:cluster]),
               :body         => body,
               :accept       => MESSAGE_TYPE,
               :content_type => VM_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def get_vm(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{VM_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_vms(args)
    get_all(:vm, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_vms(cluster)
    json_to_hash(get(:uri    => vms_uri(cluster),
                     :accept => "#{VM_TYPE}, #{MESSAGE_TYPE}"))
   end

  #-------------------------------------------------------------------------------------------------
  def delete_vm(vm)
     delete(:uri    => vm[:uri],
            :accept => MESSAGE_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def update_vm(vm, body)
    validate([:name], body)
    put(:uri          => vm[:uri],
        :body         => body,
        :accept       => "#{VM_TYPE}, #{MESSAGE_TYPE}",
        :content_type => VM_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def control_vm(vm, control, body={})
    validate([:note, :description], body)
    control_uri = case control
                  when :clone then 
                    validate([:name], body)
                    vm[:controllers][:clone]
                  when :customize then  
                    body.update(:name => 'customize')
                    vm[:uri] + '/customize'
                  else
                    (ctl = vm[:controllers][control]) ? ctl : raise(ArgumentError, "'#{control}' is invalid")
                  end
    post(:uri          => control_uri,
         :body         => body,
         :accept       => "#{VM_TYPE}, #{MESSAGE_TYPE}",
         :content_type => VM_TYPE)
  end

  #-------------------------------------------------------------------------------------------------
  def vms_uri(cluster)
     cluster[:uri] + '/vms'
  end

  #-------------------------------------------------------------------------------------------------
  # firewall
  #-------------------------------------------------------------------------------------------------
  def get_fw(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{FW_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_fws(args)
    get_all(:fw, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_fws(vnet)
    json_to_hash(get(:uri    => fws_uri(vnet),
                     :accept => "#{FW_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def update_fw(fw, body)
    validate([:name], body)
    put(:uri          => fw[:uri],
        :body         => body,
        :accept       => "#{FW_TYPE}, #{MESSAGE_TYPE}",
        :content_type => FW_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def control_fws(fw, body)
    validate([:note, :description], body)
    control_uri = (ctl = fw[:controllers][control]) ? ctl : raise(ArgumentError, "'#{control}' is invalid")
    post(:uri          => control_uri,
         :body         => body,
         :accept       => MESSAGE_TYPE,
         :content_type => FW_TYPE)
  end

  #-------------------------------------------------------------------------------------------------
  def fws_uri(vnet)
     vnet[:uri] + '/fws'
  end

  #-------------------------------------------------------------------------------------------------
  # firewall rules
  #-------------------------------------------------------------------------------------------------
  def create_fwrule(fw, body)
    validate([:name, :description, :policy, :protocol, :ip, :port], body)
    post(:uri          => fwrules_uri,
         :body         => body,
         :accept       => MESSAGE_TYPE,
         :content_type => FWRULE_TYPE)
  end

  #-------------------------------------------------------------------------------------------------
  def get_fwrule(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{FWRULE_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_fwrules(args)
    get_all(:fwrule, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_fwrules(fw)
    json_to_hash(get(:uri    => fwrules_uri(fe),
                     :accept => "#{FWRULE_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def delete_fwrule(fwrule)
     delete(:uri    => fwrule[:uri],
            :accept => MESSAGE_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def update_fwrule(fwrule, body)
    validate([:name], body)
    put(:uri          => fw[:uri],
        :body         => body,
        :accept       => MESSAGE_TYPE,
        :content_type => FW_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def fwrules_uri(fw)
     fw[:uri] + '/fwrules'
  end

  #-------------------------------------------------------------------------------------------------
  # load balancer
  #------------------------------------------------------------------------------------------------
  def create_lb(vdc, body)
    validate([:name, :description], body)
    post(:uri          => lbs_uri(vdc),
         :body         => body,
         :accept       => MESSAGE_TYPE,
         :content_type => LB_TYPE)
  end

  #-------------------------------------------------------------------------------------------------
  def get_lb(uri)
    json_to_hash(get(:uri    => uri,
                     :accept => "#{LB_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_lbs(args)
    get_all(:lb, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_lbs(vdc)
    json_to_hash(get(:uri    => lbs_uri(vdc),
                     :accept => "#{LB_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def update_lb(lb, body)
    validate([:name], body)
    put(:uri          => lb[:uri],
        :body         => body,
        :accept       => "#{LB_TYPE}, #{MESSAGE_TYPE}",
        :content_type => LB_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def delete_lb(lb)
     delete(:uri          => lb[:uri],
            :accept       => MESSAGE_TYPE,
            :content_type => LB_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def lbs_uri(vdc)
     vdc[:uri] + '/lbs'
  end

  #-------------------------------------------------------------------------------------------------
  # load balancer pool
  #------------------------------------------------------------------------------------------------
  def create_lbpool(lb, body)
    validate([:name, :description], body)
    post(:uri          => lbpools_uri(vdc),
         :body         => body,
         :accept       => MESSAGE_TYPE,
         :content_type => LBPOOL_TYPE)
  end

  #-------------------------------------------------------------------------------------------------
  def get_lbpool(uri)
    json_to_hash(get(:uri          => uri,
                     :accept       => "#{LBPOOL_TYPE}, #{MESSAGE_TYPE}",
                     :content_type => LBPOOL_TYPE))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_lbpools(args)
    get_all(:lbpool, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_lbpools(lb)
    json_to_hash(get(:uri    => lbpools_uri(lb),
                     :accept => "#{LBPOOL_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def update_lbpool(lbpool, body)
    validate([:description], body)
    put(:uri          => lbpool[:uri],
        :body         => body,
        :accept       => "#{LBPOOL_TYPE}, #{MESSAGE_TYPE}",
        :content_type => LBPOOL_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def delete_lbpool(lbpool)
     delete(:uri          => lb[:uri],
            :accept       => MESSAGE_TYPE,
            :content_type => LBPOOL_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def lbpools_uri(lb)
     lb[:uri] + '/pools'
  end

  #-------------------------------------------------------------------------------------------------
  # load balancer pool member
  #------------------------------------------------------------------------------------------------
  def create_lbpool_member(lbpool, body)
    validate([:name, :description, :ip, :port], body)
    post(:uri          => lbpool_members_uri(vdc),
         :body         => body,
         :accept       => MESSAGE_TYPE,
         :content_type => LBPOOL_MEMBER_TYPE)
  end

  #-------------------------------------------------------------------------------------------------
  def get_lbpool_member(uri)
    json_to_hash(get(:uri          => uri,
                     :accept       => "#{LBPOOL_MEMBER_TYPE}, #{MESSAGE_TYPE}",
                     :content_type => LBPOOL_MEMBER_TYPE))
  end

  #-------------------------------------------------------------------------------------------------
  def get_all_lbpool_members(args)
    get_all(:lbpool_member, args)
  end

  #-------------------------------------------------------------------------------------------------
  def list_lbpool_members(lbpool)
    json_to_hash(get(:uri    => lbpool_members_uri(lb),
                     :accept => "#{LBPOOL_MEMBER_TYPE}, #{MESSAGE_TYPE}"))
  end

  #-------------------------------------------------------------------------------------------------
  def update_lbpool_member(lbpool_member, body)
    validate([:name], body)
    put(:uri          => lbpool_member[:uri],
        :body         => body,
        :accept       => "#{LBPOOL_MEMBER_TYPE}, #{MESSAGE_TYPE}",
        :content_type => LBPOOL_MEMBER_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def delete_lbpool_member(lbpool)
     delete(:uri          => lb[:uri],
            :accept       => MESSAGE_TYPE)
   end

  #-------------------------------------------------------------------------------------------------
  def lbpool_members_uri(lbpool)
     lbpool[:uri] + '/members'
  end

  #-------------------------------------------------------------------------------------------------
  # utils
  #------------------------------------------------------------------------------------------------
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
    send(('list_' + obj.to_s + 's').to_sym, args).map{|(u,o)| u.to_s}.inject([]) do |all, uri|
      begin
        all << send(('get_' + obj.to_s).to_sym, uri)
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

  #-------------------------------------------------------------------------------------------------
  def validate(expect, given)
    given_args = given.keys
    expect.each{|e| raise(ArgumentError, "#{e} missing") unless given_args.include?(e)}
  end

  #-------------------------------------------------------------------------------------------------
  def self.retry_until
    try_count = 0
    begin
      try_count += 1
      result = yield
      raise(CaaSError) unless result
      result
    rescue RestClient::ResourceNotFound, Errno::ECONNREFUSED, RestClient::ServerBrokeConnection
      sleep(SLEEP_RETRY)
      try_count < MAX_RETRIES ? retry : raise
    rescue RestClient::RequestFailed => exp
      if exp.http_code.eql?(409)
        sleep(SLEEP_RETRY)
        try_count < MAX_RETRIES ? retry : raise
      else; raise; end
    rescue CaaSError
      sleep(SLEEP_RETRY)
      try_count < MAX_RETRIES ? retry : raise
    end
  end

end #### CaaS
