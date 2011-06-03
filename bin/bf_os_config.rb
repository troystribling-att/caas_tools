#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'lib/ssh_cmds'

#-------------------------------------------------------------------------------------------------
CONFIG = File.open(ARGV.first) {|yf| YAML::load(yf)}
EMAIL_CONFIG = File.open(send_email.yml) {|yf| YAML::load(yf)}

#----------------------------------------------------------------------------------------------------
data = {}
data[:uptime_hours] = uptime(CONFIG['vms'])
data[:selinux_enabled] = selinux_enabled?(CONFIG['vms'])
data[:iptables_running] = iptables_running?(CONFIG['vms'])
data[:iptables_chkconfig_enabled] = iptables_chkconfig?(CONFIG['vms'])
data[:ip6tables_running] = ip6tables_running?(CONFIG['vms'])
data[:ip6tables_chkconfig_enabled] = ip6tables_chkconfig?(CONFIG['vms'])

#----------------------------------------------------------------------------------------------------
agg_data = {}
data.each do |(data_type, envs)|
  envs.each do |(env, vms)|
    agg_data[env] ||= {}
    vms.each do |(vm, vm_data)|
      agg_data[env][vm] ||= {}
      agg_data[env][vm][data_type] ||= {:error_msg => vm_data[:error_msg] || 'No Error', :transaction_time_ms => vm_data[:elapsed_time_ms] || 'NA', 
                                        :ip => vm_data[:ip], :data => vm_data[:data] || 'NA'}
    end
  end
end

#----------------------------------------------------------------------------------------------------
headers = ['environment', 'vm', 'ip']
first_env = agg_data.keys.first
first_vm = agg_data[first_env].keys.first
agg_data[first_env][first_vm].each do |data_type, vm_data|
  vm_data.keys.each do |vm_data_type|
    unless vm_data_type.eql?(:ip)
      if vm_data_type.eql?(:data)
        (headers << (data_type.to_s).split('_').join(' ')) 
      else
        (headers << (data_type.to_s + ' ' + vm_data_type.to_s).split('_').join(' ')) 
      end
    end
  end
end

#----------------------------------------------------------------------------------------------------
puts headers.join(',')

#----------------------------------------------------------------------------------------------------
agg_data.each do |(env, vms)|
  vms.each do |(vm, vm_data)|
    data_out = [env, vm]
    data_out << vm_data.first.last[:ip]
    vm_data.each do |(data_types, type_data)|
      type_data.delete(:ip)
      data_out += type_data.values
    end
    puts data_out.join(',')
  end
end