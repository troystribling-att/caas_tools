#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'lib/ssh_cmds'

#-------------------------------------------------------------------------------------------------
CONFIG = File.open(ARGV.first) {|yf| YAML::load(yf)}

#----------------------------------------------------------------------------------------------------
def write_rows(rows)
  rows.each do |(ip,info)|
    $stderr.puts "  EXTERNAL IP: #{ip}"
    info.each do |i|
      $stderr.puts "    ORG: #{i[:org]}, INTERNAL IP: #{i[:internal_ip]}, VM NAME: #{i[:vm_name]}," +
        " VM URI: #{i[:vm_uri]}, VM MAC ADDRESS: #{i[:vm_mac_address]}"
      puts "#{ip},#{i[:org]},#{i[:internal_ip]},#{i[:vm_name]},#{i[:vm_uri]},#{i[:vm_mac_address]}"
    end
  end
end

#----------------------------------------------------------------------------------------------------
data = {}
data[:uptime_days] = get_uptimes(CONFIG['vms'])
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
      agg_data[env][vm][data_type] ||= {:error => vm_data[:error], :error_msg => vm_data[:error_msg] || 'No Error', :tries => vm_data[:tries],
                                        :elapsed_time_ms => vm_data[:elapsed_time_ms], :data => vm_data[:data], :ip => vm_data[:ip]}
    end
  end
end
