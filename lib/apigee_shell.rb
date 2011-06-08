#-------------------------------------------------------------------------------------------------
require 'logger'
require 'tempfile'

#-------------------------------------------------------------------------------------------------
class ApiGeeSSHError < Exception; end
class ApiGeeShellParseError < Exception; end

#----------------------------------------------------------------------------------------------------
module ApiGeeConfig
  SLEEP_RETRY = 60
  MAX_RETRIES = 2
  APP_PATH = File.expand_path(File.dirname(__FILE__))
  @logger = Logger.new(File.join(APP_PATH, '../log', 'apigee.log'), 10, 1024000)
  def logger; @logger; end
  module_function :logger
end

#----------------------------------------------------------------------------------------------------
def log_apigee_error(msg, env, vm)
  SshConfig.logger.error "#{msg}"
  SshConfig.logger.error "#{env}, #{vm['name']}, #{vm['ip']}"
  {:error => true, :error_msg => msg, :ip => vm['ip']}
end

#----------------------------------------------------------------------------------------------------
def send_apigee_shell_commands(vms)
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
def send_apigee_shell_command(env, vm, cmd)
  response, try_count = '', 0
  error = false
  ApiGeeConfig.logger.info "CONNECTING TO:   #{env}, #{vm['name']}, #{vm['ip']}"
  ApiGeeConfig.logger.info "SENDING COMMAND: #{cmd}"
  begin
    try_count += 1
    exe_time = Time.now.to_f
    cmd_file = File.new("apigee_cmd", "w")
    cmd_file.chmod(0744)
    cmd_file << cmd
    elapsed_time = (1000*(Time.now.to_f - exe_time)).to_i
    ApiGeeConfig.logger.info "COMMAND SUCCEEDED IN #{elapsed_time}ms"
    ApiGeeConfig.logger.info "RECEIVED RESPONSE #{response}"
    {:data => 'NA', :tries => try_count, :error => false, :ip => vm['ip'], :elapsed_time_ms =>elapsed_time}
  rescue 
    log_apigee_error("APIGEE COMMAND ERROR", env, vm)
  end
end
