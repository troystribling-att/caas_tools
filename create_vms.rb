require './caas_web'

#----------------------------------------------------------------------------------------------------
def run_create_create_vm_test_forever(user, password, nthreads=2, nvms=5, site = 'https://206.17.20.10/CirrusServices/resources')
  nrun = 1
  while true
    puts "RUN NUMBER: #{nrun}"
    ses = create_test_session(user, password, site)
    spawn_create_vm_test_threads(ses, nthreads, nvms)
  end
end

#----------------------------------------------------------------------------------------------------
def spawn_create_vm_test_threads(sessions, nthreads=2, nvms=5)
  threads = []
  sessions = [sessions].flatten
  sessions.each do |ses|
    nthreads.times do |n|
      threads << Thread.new do
                   puts "SPAWNING CREATE VM TEST THREAD: #{n}"
                   create_vm_test(ses, nvms)
                 end
    end
  end
  threads.each{|t| j.join}
  puts "TEST COMPLETED"
end

#----------------------------------------------------------------------------------------------------
def create_test_session(user, password, site = 'https://206.17.20.10/CirrusServices/resources')
  user = [user].flatten
  password = [password].flatten
  sessions = []
  user.each_index do |i|
    puts "CREATING SESSION"
    puts "  USER: #{user[i]}"
    puts "  PASSWORD: #{password[i]}"
    puts "  SITE: #{site}"
    session = {}
    session[:caas]     = CaaS.new(user[i], password[i], site)
    CaaS.retry_until{session[:caas].login}
    session[:cloud]    = CaaS.retry_until{session[:caas].get_all_clouds.first}
    session[:vdc]      = CaaS.retry_until{session[:caas].get_all_vdcs(session[:cloud]).first}
    session[:cluster]  = CaaS.retry_until{session[:caas].get_all_clusters(session[:vdc]).first}
    session[:location] = CaaS.retry_until{session[:caas].get_all_locations[1]}
    session[:vnets]    = CaaS.retry_until{session[:caas].get_all_vnets(session[:cluster])}
    sessions << session
  end
  sessions
end

#----------------------------------------------------------------------------------------------------
def create_vm_test(ses, nvms=5)
 
  ### account params
  puts "STARTING CREATE VM TEST"
  puts "  USER: #{ses[:caas][:uid]}"
  puts "  PASSWORD: #{ses[:cass][:passwd]}"
  puts "  SITE: #{ses[:caas][:site]}"

  ### session data
  caas = ses[:caas]
  cluster = ses[:cluster]
  vnets = ses[:vnets]
  location = ses[:location]
  vms = []
  
  ### create vms
  nvms.times do |vm_number|
    vm_name = "vm-#{vm_number}"
    puts ">>>>> CREATING VM: #{vm_name}"
    new_vm = CaaS.retry_until{caas.create_vm(:name       => vm_name, 
                                             :vmtemplate => "/vAppTemplate/vappTemplate-1796597075", 
                                             :cluster    => cluster, 
                                             :vnets      => vnets, 
                                             :location   => location)}
    vm_uri = /#{caas.site}(.*)/.match(new_vm.headers[:location]).captures.first
    CaaS.retry_until{caas.get_vm(vm_uri)[:run_state].eql?('STARTED')}
    vm = CaaS.retry_until{caas.get_vm(vm_uri)}
    puts ">>>>> CREATED VM: #{vm_uri}"
    p vm
    puts ">>>>> CUSTOMIZE VM: #{vm_name}"
    begin
      CaaS.retry_until{caas.control_vm(vm, :customize, {:note=>'this sucks', :description=>'why do I have to do this'})}
    rescue RestClient::BadRequest
      retry
    end
    public_ip = CaaS.retry_until{caas.get_vm(vm_uri)[:interfaces].first[:public_address]}
    if public_ip
      puts ">>>>> PUBLIC IP: #{public_ip}"
    else
      puts ">>>>> CUSTOMIZE FAILED: #{vm_name}"
    end
    vms << CaaS.retry_until{caas.get_vm(vm_uri)}    
  end 


  ### delete vms
  vms.each do |vm|
    puts ">>>>> DELETING VM: #{vm[:name]}"
    CaaS.retry_until{caas.delete_vm(vm)}
    puts ">>>>> DELETED VM: #{vm[:name]}"
  end 

end







