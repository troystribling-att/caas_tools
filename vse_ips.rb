#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'yaml'
require 'lib/vcd'

#-------------------------------------------------------------------------------------------------
CONFIG_FILE = File.open(ARGV.first) {|yf| YAML::load(yf)}

#-------------------------------------------------------------------------------------------------
ses = VCD.new(CONFIG_FILE['vcd_user'], CONFIG_FILE['vcd_user_password'], 
              CONFIG_FILE['vcd_url'])
ses.login

#-------------------------------------------------------------------------------------------------
vse_ips = {}
dup_ips = {}

#-------------------------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------------------------
orgs = ses.get_orgs
orgs[:org].keys.each do |org_href|
  org = ses.get_org(orgs, org_href)
  $stderr.puts "CHECKING ORG: #{org[:name]}"
  if nets = org[:link][:network]
p nets    
    nets.keys.each do |n|
      net = ses.get_network(org, n)
      if net[:name].include?('Public')
        $stderr.puts "CHECKING NET: #{net[:name]}, #{n}"
p net.keys
p net        
      end
    end
  end
end

$stderr.puts "VSE IPs"
puts "EXTERNAL IPs"
puts "EXTERNAL IP,ORG,INTERNAL IP, VM NAME, VM URI, VM MAC ADDRESS"
write_rows(vse_ips)

$stderr.puts "DUPLICATE IPs"
puts "DUPLICATE IPs"
puts "EXTERNAL IP,ORG,INTERNAL IP, VM NAME, VM URI, VM MAC ADDRESS"
write_rows(dup_ips)
