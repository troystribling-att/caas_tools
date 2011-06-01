####################################################################################################
$:.unshift(File.dirname(__FILE__))
require 'logger'
require 'vcd'

route_with_no_vm = []

####################################################################################################
def get_vms(vcd, org)
  if vdc_info = org[:link][:vdc]
    vdc = vcd.get_vdc(org, vdc_info.keys.first)
    vapps = vdc[:resource_entity][:v_app] || {}
    vapps.keys.inject({}) do |vms, app|
      vapp = vcd.get_vapp(vdc, app)
      if vm = vapp[:vm].first
        if pub_net = vm[:network_connection].find{|n| n[:network].include?('Public')}
          vm_info = {:name => vm[:name], :uri => vm[:href], :ip_address => pub_net[:ip_address],
            :mac_address =>  pub_net[:mac_address], :is_connected => pub_net[:is_connected]} 
          vms.merge(pub_net[:ip_address] => vm_info)
        else; vms; end
      else; vms; end
    end
  else; {}; end
end

####################################################################################################
def duplicate_external_ips(vcd, org)
  ext_ips = {}
  dup_ips = {}
  orgs = vcd.get_orgs
  orgs[:org].keys.each do |org_href|
    org = vcd.get_org(orgs, org_href)
    vms = get_vms(vcd, org)
    $stderr.puts "CHECKING ORG: #{org[:name]}"
    if nets = org[:link][:network]
      nets.keys.each do |n|
        net = vcd.get_network(org, n)
        if net[:name].include?('Public')
          $stderr.puts "CHECKING NET: #{net[:name]}, #{n}"
          net[:nat_service].each do |s|
            if s[:external_port].eql?('22')
              ext_ip = s[:external_ip]
              vm = vms.delete(s[:internal_ip])
              ip_info = if vm
                          {:org => org[:name], :external_ip => ext_ip, :internal_ip => s[:internal_ip],
                           :vm_name => vm[:name], :vm_uri => vm[:uri], :vm_mac_address => vm[:mac_address]}
                        else
                          $stderr.puts "FOUND RULE WITH NO VM: ORG:#{org[:name]}, ext_ip: #{ext_ip}, internal_ip:#{s[:internal_ip]}"
                          {:org => org[:name], :external_ip => ext_ip, :internal_ip => s[:internal_ip],
                           :vm_name => '', :vm_uri => '', :vm_mac_address => ''}
                        end
              if ext_ips[ext_ip]
                $stderr.puts "FOUND DUPLICATE IP: #{ip_info.inspect}"
                (dup_ips[ext_ip] = ext_ips[ext_ip]) unless dup_ips[ext_ip]
                dup_ips[ext_ip] << ip_info              
              else
                ext_ips[ext_ip] = [ip_info]
              end
            end
          end
        end
      end
    end
  end
  dup_ips
end

