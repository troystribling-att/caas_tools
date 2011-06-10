#-------------------------------------------------------------------------------------------------
require 'logger'
require 'tempfile'

#-------------------------------------------------------------------------------------------------
class ApiGeeSSHError < Exception; end
class ApiGeeShellParseError < Exception; end
class ApiGeeShellTimeout < Exception; end
class ApiGeeShellConnectionRefused < Exception; end
class ApiGeeShellAuthenitcationFailed < Exception; end

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
#----------------------------------------------------------------------------------------------------
class APIGeeShell
  
  #--------------------------------------------------------------------------------------------------
  class << self

    #----------------------------------------------------------------------------------------------------
    def log_error(msg, env, vm)
      SshConfig.logger.error "#{msg}"
      SshConfig.logger.error "#{env}, #{vm['name']}, #{vm['ip']}"
      {:error => true, :error_msg => msg, :ip => vm['ip']}
    end

    #----------------------------------------------------------------------------------------------------
    def commands(vms)
      results = {}
      vms.each do |(env, vms)|
        results[env] = {}
        vms.each do |vm|
          results[env][vm['name']] = begin
                                       yield(env, vm)
                                     rescue ApiGeeShellParseError
                                       log_ssh_error("COMMAND PARSE ERROR", env, vm)
                                     end
        end
      end
      results
    end

    #----------------------------------------------------------------------------------------------------
    def command(env, vm, cmd)
      response, try_count = '', 0
      error = false
      ApiGeeConfig.logger.info "CONNECTING TO:   #{env}, #{vm['name']}, #{vm['ip']}"
      ApiGeeConfig.logger.info "SENDING COMMAND: #{cmd}"
      begin
        try_count += 1
        exe_time = Time.now.to_f
        cmd_file = Tempfile.new("apigee_cmd:#{vm['ip']}")
        cmd_file.chmod(0744)
        cmd_file << cmd
        cmd_file.close
        response = `#{cmd_file.path}`
        raise(ApiGeeShellTimeout) if response.include?('timed out')
        raise(ApiGeeShellConnectionRefused) if response.include?('Connection refused')
        raise(ApiGeeShellAuthenitcationFailed) if response.include?("\r\n\r\nPassword: \r\nPassword: \r\n")
        cmd_file.delete
        elapsed_time = (1000*(Time.now.to_f - exe_time)).to_i
        ApiGeeConfig.logger.info "COMMAND SUCCEEDED IN #{elapsed_time}ms"
        ApiGeeConfig.logger.info "RECEIVED RESPONSE #{response}"
        {:data => response, :tries => try_count, :error => false, :ip => vm['ip'], :elapsed_time_ms =>elapsed_time}
      rescue ApiGeeShellAuthenitcationFailed
        log_error("AUTHENTICATION FAILED", env, vm)
      rescue ApiGeeShellTimeout
        log_error("CONNECTION TIMED OUT", env, vm)
      rescue ApiGeeShellConnectionRefused
        log_error("CONNECTION REFUSED", env, vm)
      end
    end

  #### self
  end

####  APIGeeCmds
end
