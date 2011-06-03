#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'lib/duplicate_external_ips'

#-------------------------------------------------------------------------------------------------
CONFIG = File.open(ARGV.first) {|yf| YAML::load(yf)}
vcd = VCD.new(CONFIG_FILE['vcd_user'], CONFIG_FILE['vcd_user_password'], 
              CONFIG_FILE['vcd_url'])
vcd.login
