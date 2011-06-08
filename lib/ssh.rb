#-------------------------------------------------------------------------------------------------
require 'net/ssh'
require 'logger'

#-------------------------------------------------------------------------------------------------
class SSHError < Exception; end
class ShellParseError < Exception; end

#----------------------------------------------------------------------------------------------------
module SshConfig
  SLEEP_RETRY = 60
  MAX_RETRIES = 2
  APP_PATH = File.expand_path(File.dirname(__FILE__))
  @logger = Logger.new(File.join(APP_PATH, '../log', 'ssh_cmds.log'), 10, 1024000)
  def logger; @logger; end
  module_function :logger
end

#----------------------------------------------------------------------------------------------------
def log_ssh_error(msg, env, vm)
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
                                   log_ssh_error("COMMAND PARSE ERROR", env, vm)
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
    elapsed_time = (1000*(Time.now.to_f - exe_time)).to_i
    SshConfig.logger.info "COMMAND SUCCEEDED IN #{elapsed_time}ms"
    SshConfig.logger.info "RECEIVED RESPONSE #{response}"
    {:data => response, :tries => try_count, :error => false, :ip => vm['ip'], :elapsed_time_ms =>elapsed_time}
  rescue Errno::EHOSTUNREACH
    unless try_count == SshConfig::MAX_RETRIES
      log_ssh_error("HOST CONNECTION FAILD, RETRYING: #{try_count}", env, vm)
      sleep(SshConfig::SLEEP_RETRY)
      retry 
    else
      log_ssh_error("HOST UNREACHABLE AFTER #{try_count} TRIES", env, vm)
    end
  rescue Errno::ETIMEDOUT
    unless try_count == SshConfig::MAX_RETRIES
      log_ssh_error("CONNECTION TIMEOUT, RETRYING: #{try_count}", env, vm)
      sleep(SshConfig::SLEEP_RETRY)
      retry 
    else
      log_ssh_error("CONNECTION TIMEOUT AFTER #{try_count} TRIES", env, vm)
    end
  rescue Errno::ECONNREFUSED
    log_ssh_error("CONNECTION REFUSED", env, vm)
  rescue Net::SSH::AuthenticationFailed
    log_ssh_error("AUTHENTICATION FAILED", env, vm)
  rescue SSHError
    log_ssh_error("SSH COMMAND ERROR", env, vm)
  end
end

