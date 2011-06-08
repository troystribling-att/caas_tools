#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'apigee_shell'

#----------------------------------------------------------------------------------------------------
# commands
#----------------------------------------------------------------------------------------------------
def apigee_uptime(vms)
  send_commands(vms) do |env, vm|
      cmd = <<CMD_TEXT
#!/usr/bin/expect -f
#
set timeout -1
spawn ssh admin@206.17.23.66
match_max 100000
expect "Password: "
send -- "secret\r"
expect "localhost > "
send -- "show system status\r"
expect "localhost > "
send -- "exit\r"
expect eof
CMD_TEXT
      result = send_apigee_shell_command(env, vm, cmd) 
      (result[:data] =  parse_apigee_uptime(result.delete(:data))) unless result[:error]
      result
  end             
end

#----------------------------------------------------------------------------------------------------
# parse results apigee
#----------------------------------------------------------------------------------------------------
def parse_apigee_uptime(cmd)
  raise(ShellParseError) unless cmd
  'NA'  
end
