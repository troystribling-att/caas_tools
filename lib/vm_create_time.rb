require './caas_web'
require 'net/ssh'

#-------------------------------------------------------------------------------------------------
class SSHError < Exception; end

#-------------------------------------------------------------------------------------------------
module VMCreateTime
  SLEEP_RETRY = 10
  MAX_RETRIES = 100
  UBUNTU          = "/vAppTemplate/vappTemplate-1796597075"
  WINDOWS_2008    = "/vAppTemplate/vappTemplate-855535336"
  RHEL55          = "/vAppTemplate/vappTemplate-1222801342"
  SUSE            = "/vAppTemplate/vappTemplate-1453857859"
  CENTOS          = "/vAppTemplate/vappTemplate-375943477"
  SOLARIS         = "/vAppTemplate/vappTemplate-528701478"
  @logger = Logger.new(File.join(root, '../log', 'vm_create_time.log'), 10, 1024000)
  def logger; @logger; end
  module_function :logger
end

#----------------------------------------------------------------------------------------------------
def vm_create_time(ses, nvms=5, vmtemplate = VMCreateTime::UBUNTU)
 
  ### account params
  VMCreateTime.logger.info "STARTING CREATE VM TEST"
  VMCreateTime.logger.info "USER: #{ses[:caas].uid}"
  VMCreateTime.logger.info "PASSWORD: #{ses[:caas].passwd}"
  VMCreateTime.logger.info "SITE: #{ses[:caas].site}"

  ### session data
  caas = ses[:caas]
  cluster = ses[:cluster]
  vnets = ses[:vnets]
  location = ses[:location]
  results = []
  
  ### create vms
  nvms.times do |vm_number|
    vm_name = "vm-#{vm_number}"
    start_time = Time.now().to_i
    VMCreateTime.logger.info "CREATING VM: #{vm_name}"
    new_vm = CaaS.retry_until{caas.create_vm(:name       => vm_name, 
                                             :vmtemplate => vmtemplate, 
                                             :cluster    => cluster, 
                                             :vnets      => vnets, 
                                             :location   => location)}
    vm_uri = /#{caas.site}(.*)/.match(new_vm.headers[:location]).captures.first
    CaaS.retry_until{caas.get_vm(vm_uri)[:run_state].eql?('STARTED')}
    vm = CaaS.retry_until{caas.get_vm(vm_uri)}
    VMCreateTime.logger.info "CREATED VM: #{vm_uri}"
    VMCreateTime.logger.info "CUSTOMIZE VM: #{vm_name}"
    begin
      CaaS.retry_until{caas.control_vm(vm, :customize, {:note=>'note', :description=>'description'})}
    rescue RestClient::BadRequest
      retry
    end
    public_ip = CaaS.retry_until{caas.get_vm(vm_uri)[:interfaces].first[:public_address]}
    if public_ip
      VMCreateTime.logger.info "PUBLIC IP: #{public_ip}"
    else
      VMCreateTime.logger.error "CUSTOMIZE FAILED: #{vm_name}"
    end
    vm = CaaS.retry_until{caas.get_vm(vm_uri)}
    if connection_test = test_vm_connection(vm)      
      VMCreateTime.logger.info "CONNECTION TEST SUCCEEDED"
    else
      VMCreateTime.logger.error "CONNECTION TEST FAILED"
    end
    time_to_create = Time.now().to_i - start_time
    VMCreateTime.logger.info "CREATE TIME: #{time_to_create}"    
    results << {:vm => vm, :time => time_to_create, :connection_test => connection_test}
  end
  results
end

#----------------------------------------------------------------------------------------------------
def delete_vms_time(ses, vms)
  caas = ses[:caas]
  times = []
  vms.each do |vm|
    start_time = Time.now().to_i
    VMCreateTime.logger.info "DELETING VM: #{vm[:name]}"
    CaaS.retry_until{caas.delete_vm(vm)}
    VMCreateTime.logger.info "DELETED VM: #{vm[:name]}"
    time_to_delete = Time.now().to_i - start_time
    VMCreateTime.logger.info "DELETE TIME: #{time_to_delete}"
    times << time_to_delete
    sleep(60)
  end 
  times
end

#----------------------------------------------------------------------------------------------------
def test_vm_connection(vm)
  host = vm[:interfaces].first[:public_address]
  passwd = vm[:password]
  VMCreateTime.logger.info "CONNECTING TO HOST: #{host}"
  VMCreateTime.logger.info "USING PASSWORD: #{passwd}"
  result, try_count = false, 0
  begin
    try_count += 1
    Net::SSH.start(host, 'root', :password => passwd) do |ssh|
      ssh.open_channel do |channel|
        channel.exec('whoami') do |ch, success|
          raise(SSHError) unless success
          channel.on_data do |ch, data|
            result = data.chomp.eql?('root')
          end
        end 
      end
    end
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    VMCreateTime.logger.info "CONNECTION ERROR"
    sleep(VMCreateTime::SLEEP_RETRY)
    retry unless try_count > VMCreateTime::MAX_RETRIES
  rescue Net::SSH::AuthenticationFailed
  rescue SSHError
    VMCreateTime.logger.info "SSH ERROR"
    sleep(VMCreateTime::SLEEP_RETRY)
    retry unless try_count > VMCreateTime::MAX_RETRIES
  end
  result
end
