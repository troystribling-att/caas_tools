#-------------------------------------------------------------------------------------------------
require 'net/ssh'
require 'yaml'
require 'logger'

#-------------------------------------------------------------------------------------------------
class SSHError < Exception; end
class ShellParseError < Exception; end

#----------------------------------------------------------------------------------------------------
module SshConfig
  SLEEP_RETRY = 60
  MAX_RETRIES = 2
  APP_PATH = File.expand_path(File.dirname(__FILE__))
  @logger = Logger.new(File.join(APP_PATH, '../log', 'monitor.log'), 10, 1024000)
  def logger; @logger; end
  module_function :logger
end

#----------------------------------------------------------------------------------------------------
def log_error(msg, env, vm)
  SshConfig.logger.error "#{msg}"
  SshConfig.logger.error "#{env}, #{vm['name']}, #{vm['ip']}"
  {:error => true, :error_msg => msg, :ip => vm['ip']}
end

#----------------------------------------------------------------------------------------------------
def send_commands(vms)
  results = {}
  vms.each do |(env, vms)|
    results[env] = {}
    vms.each do |vm|
      results[env][vm['name']] = begin
                                   yield(env, vm)
                                 rescue ShellParseError
                                   log_error("COMMAND PARSE ERROR", env, vm)
                                 end
    end
  end
  results
end

#----------------------------------------------------------------------------------------------------
def send_command(env, vm, cmd)
  response, try_count = '', 0
  error = false
  SshConfig.logger.info "CONNECTING TO:   #{env}, #{vm['name']}, #{vm['ip']}"
  SshConfig.logger.info "SENDING COMMAND: #{cmd}"
  begin
    try_count += 1
    exe_time = Time.now.to_f
    Net::SSH.start(vm['ip'], vm['uid'], :password => vm['password']) do |ssh|
      ssh.open_channel do |channel|
        channel.exec(cmd) do |ch, success|
          raise(SSHError) unless success
          channel.on_data do |ch, data|
            response = data
          end
        end 
      end
    end
    SshConfig.logger.info "COMMAND SUCCEEDED IN #{exe_time}ms"
    SshConfig.logger.info "RECEIVED RESPONSE #{response}"
    {:data => response, :tries => try_count, :error => false, :ip => vm['ip'], :elapsed_time_ms => (1000*(Time.now.to_f - exe_time)).to_i}
  rescue Errno::EHOSTUNREACH
    unless try_count == SshConfig::MAX_RETRIES
      log_error("HOST CONNECTION FAILD, RETRYING: #{try_count}", env, vm)
      sleep(SshConfig::SLEEP_RETRY)
      retry 
    else
      log_error("HOST UNREACHABLE AFTER #{try_count} TRIES", env, vm)
    end
  rescue Errno::ETIMEDOUT
    unless try_count == SshConfig::MAX_RETRIES
      log_error("CONNECTION TIMEOUT, RETRYING: #{try_count}", env, vm)
      sleep(SshConfig::SLEEP_RETRY)
      retry 
    else
      log_error("CONNECTION TIMEOUT AFTER #{try_count} TRIES", env, vm)
    end
  rescue Errno::ECONNREFUSED
    log_error("CONNECTION REFUSED", env, vm)
  rescue Net::SSH::AuthenticationFailed
    log_error("AUTHENTICATION FAILED", env, vm)
  rescue SSHError
    log_error("SSH COMMAND ERROR", env, vm)
  end
end

#----------------------------------------------------------------------------------------------------
# send commands
#----------------------------------------------------------------------------------------------------
def get_uptimes(vms)
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
# parse results widows
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

