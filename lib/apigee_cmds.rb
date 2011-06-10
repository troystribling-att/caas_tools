#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'apigee_shell'

#----------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------
class APIGeeCmds
  
  #--------------------------------------------------------------------------------------------------
  class << self
    
    #----------------------------------------------------------------------------------------------------
    # commands
    #----------------------------------------------------------------------------------------------------
    def uptime(vms)
      APIGeeShell.commands(vms) do |env, vm|
          cmd = <<CMD_TEXT
#!/usr/bin/expect -f
#
set timeout -1
spawn ssh  #{vm['uid']}@#{vm['ip']}
match_max 100000
expect "Password: "
send -- "#{vm['password']}\r\r\r\r\r\r\r\r"
expect " > " {
  send -- "show system status\r"
  expect " > "
  send -- "exit\r"
} "Password: " {
  send -- \003
}
expect eof
CMD_TEXT
          result = APIGeeShell.command(env, vm, cmd) 
          (result[:data] = parse_uptime(result.delete(:data))) unless result[:error]
          result
      end             
    end

    #----------------------------------------------------------------------------------------------------
    # parse results apigee
    #----------------------------------------------------------------------------------------------------
    def parse_uptime(cmd)
      raise(ApiGeeShellParseError) unless cmd
      system_uptime = cmd.split("\n").select{|c| c.include?('System Uptime')}.first
      raise(ApiGeeShellParseError) unless system_uptime
      days = /.*(.\d)d.*/.match(system_uptime).to_a.last || '0'
      hours = /.*(.\d)h.*/.match(system_uptime).to_a.last || '0' 
      24*days.to_i + hours.to_i
    end

  #### self
  end

####  APIGeeCmds
end

