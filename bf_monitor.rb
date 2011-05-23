#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'lib/ssh_cmds'

#-------------------------------------------------------------------------------------------------
CONFIG = File.open(ARGV.first) {|yf| YAML::load(yf)}

#----------------------------------------------------------------------------------------------------
uptimes = get_uptimes(CONFIG['vms'])
p uptimes
selinux_enabled = selinux_enabled(CONFIG['vms'])
p selinux_enabled
iptables_enabled = iptables_enabled(CONFIG['vms'])
p iptables_enabled
