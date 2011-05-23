#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'lib/caas_web'
require 'create_session'

#----------------------------------------------------------------------------------------------------
def create_vm(ses, vm_name, template)
  caas = ses[:caas]
  cluster = ses[:cluster]
  vnets = ses[:vnets]
  location = ses[:location]
  puts ">>>>> CREATING VM using TEMPLATE: #{template}"
  new_vm = CaaS.retry_until{caas.create_vm(:name       => vm_name, 
                                           :vmtemplate => template, 
                                           :cluster    => cluster, 
                                           :vnets      => vnets, 
                                           :location   => location)}
   vm_uri = /#{caas.site}(.*)/.match(new_vm.headers[:location]).captures.first
   CaaS.retry_until{caas.get_vm(vm_uri)[:run_state].eql?('STARTED')}
   vm = CaaS.retry_until{caas.get_vm(vm_uri)}
   puts ">>>>> CREATED VM: #{vm_uri}"
   puts ">>>>> CUSTOMIZING VM: #{vm_name}"
   begin
     CaaS.retry_until{caas.control_vm(vm, :customize, {:note=>'note', :description=>'description'})}
   rescue RestClient::BadRequest
     retry
   end
   puts ">>>>> VM CUSTOMIZED: #{vm_name}"
   vm = CaaS.retry_until{caas.get_vm(vm_uri)}
   puts ">>>>> CREATED VM with IP: #{vm[:interfaces].first[:public_address]} and PASSWORD: #{vm[:password]}"
end