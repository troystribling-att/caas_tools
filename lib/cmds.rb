#-------------------------------------------------------------------------------------------------
$:.unshift(File.dirname(__FILE__))
require 'ssh'

#----------------------------------------------------------------------------------------------------
# commands
#----------------------------------------------------------------------------------------------------
def uptime(vms)
  send_commands(vms) do |env, vm|
    if vm['os'].eql?('linux')
      result = send_command(env, vm, 'cat /proc/uptime')
      (result[:data] = parse_linux_uptime(result.delete(:data)) ) unless result[:error]
    else 
      result = send_command(env, vm, 'uptime')
      (result[:data] = parse_windows_uptime(result.delete(:data))) unless result[:error] 
    end 
    result          
  end
end

#----------------------------------------------------------------------------------------------------
def selinux_enabled?(vms)
  send_commands(vms) do |env, vm|
    if vm['os'].eql?('linux')
      result = send_command(env, vm, '/usr/sbin/sestatus')            
      (result[:data] =  parse_selinux_enabled(result.delete(:data))) unless result[:error]
      result
    end             
  end
end

#----------------------------------------------------------------------------------------------------
def iptables_running?(vms)
  send_commands(vms) do |env, vm|
    if vm['os'].eql?('linux')
      result = send_command(env, vm, '/sbin/lsmod | grep ip_tables')    
      (result[:data] =  parse_lsmod(result.delete(:data))) unless result[:error]
      result
    end             
  end
end

#----------------------------------------------------------------------------------------------------
def iptables_chkconfig?(vms)
  send_commands(vms) do |env, vm|
    if vm['os'].eql?('linux')
      result = send_command(env, vm, '/sbin/chkconfig --list iptables')    
      (result[:data] =  parse_chkconfig_enabled(result.delete(:data))) unless result[:error]
      result
    end             
  end
end

#----------------------------------------------------------------------------------------------------
def ip6tables_running?(vms)
  send_commands(vms) do |env, vm|
    if vm['os'].eql?('linux')
      result = send_command(env, vm, '/sbin/lsmod | grep ip6_tables')    
      (result[:data] =  parse_lsmod(result.delete(:data))) unless result[:error]
      result
    end             
  end
end

#----------------------------------------------------------------------------------------------------
def ip6tables_chkconfig?(vms)
  send_commands(vms) do |env, vm|
    if vm['os'].eql?('linux')
      result = send_command(env, vm, '/sbin/chkconfig --list ip6tables')    
      (result[:data] =  parse_chkconfig_enabled(result.delete(:data))) unless result[:error]
      result
    end             
  end
end

#----------------------------------------------------------------------------------------------------
# parse results widows
#----------------------------------------------------------------------------------------------------
def parse_windows_uptime(cmd)
  raise(ShellParseError) unless cmd
  comps = cmd.split(',')
  raise(ShellParseError) unless comps.length > 1 
  t1 = comps.first.split('up')
  if t1.include('day')
  end
end

#----------------------------------------------------------------------------------------------------
# parse results linux
#----------------------------------------------------------------------------------------------------
def parse_linux_uptime(cmd)
  raise(ShellParseError) unless cmd
  uptime = cmd.split(' ')
  raise(ShellParseError) unless uptime.length > 1 
  uptime.first.to_i / 3600
end

#----------------------------------------------------------------------------------------------------
def parse_selinux_enabled(cmd)
  raise(ShellParseError) unless cmd
  comps = cmd.split("\n")
  raise(ShellParseError) unless comps.length > 0
  comps.first.include?('enabled') ? 'YES' : 'NO'
end

#----------------------------------------------------------------------------------------------------
def parse_lsmod(cmd)
  raise(ShellParseError) unless cmd
  cmd.empty? ? "NO" : "YES"
end

#----------------------------------------------------------------------------------------------------
def parse_chkconfig_enabled(cmd)
  raise(ShellParseError) unless cmd
  cmd.include?('0:off	1:off	2:off	3:off	4:off	5:off	6:off') ? "NO" : "YES"
end


