#-------------------------------------------------------------------------------------------------
this_dir = File.expand_path(File.dirname(__FILE__))
$:.unshift(this_dir)
require 'yaml'
require "#{this_dir}/../lib/cmds"

#-------------------------------------------------------------------------------------------------
CONFIG = File.open(ARGV.first){|yf| YAML::load(yf)}
EMAIL_CONFIG = File.open('send_email.yml') {|yf| YAML::load(yf)}

#----------------------------------------------------------------------------------------------------
bash_response = uptime(CONFIG['bash_vms'])
apigee_response = apigee_shell(CONFIG['apigee_vms'])

#----------------------------------------------------------------------------------------------------
envs = bash_response.keys
agg_response = envs.inject({}) do |agg, env|
                 agg[env] = bash_response[env].merge(apigee_response[env]); agg
               end

#----------------------------------------------------------------------------------------------------
errors = agg_response.inject({}) do |err, (env, vms)|
           err[env] = vms.select{|(vm, data)| data[:error]}
         end
         
#----------------------------------------------------------------------------------------------------
agg_response.inject("ENVIRONMENT        ERROR MESSAGE           TRANSACTION(MS)         UPTIME") do |s, (env, vms)| 
end 
