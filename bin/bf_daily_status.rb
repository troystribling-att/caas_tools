#-------------------------------------------------------------------------------------------------
this_dir = File.expand_path(File.dirname(__FILE__))
$:.unshift(this_dir)
require 'yaml'
require "#{this_dir}/../lib/cmds"
require "#{this_dir}/../lib/send_email"

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
unreachable_count = 0
unreachable = agg_response.inject({}) do |unreach, (env, vms)|
                unreach_vms = vms.select{|vm| vms[vm][:error]}
                unreachable_count += unreach_vms.size             
                unreach[env] = unreach_vms               
                unreach
              end
              
#----------------------------------------------------------------------------------------------------
reachable_count = 0
reachable   = agg_response.inject({}) do |reach, (env, vms)|
                reach_vms = vms.select{|vm| !vms[vm][:error]}
                reachable_count += reach_vms.size             
                reach[env] = reach_vms              
                reach
              end
         
#----------------------------------------------------------------------------------------------------
if unreachable_count > 0
  unreachable_msg = "#{unreachable_count} SERVERS ARE NOT ACCESSIBLE\n" +
                    "ENVIRONMENT     SERVER                                IP                ERROR\n" +
                    "--------------------------------------------------------------------------------------------------------------\n"
  unreachable_msg = unreachable.inject(unreachable_msg) do |msg, (env, vms)| 
           vms.each do |(vm, data)|
             msg += sprintf("%-15.15s | %-35.35s | %-15s | %-38.38s\n", env, vm, data[:ip], data[:error_msg])
           end; msg
         end 
else
  unreachable_msg = "THERE WERE NO ERRORS IN ACCESSING SERVERS\n"
end         

#----------------------------------------------------------------------------------------------------
if reachable_count > 0
  reachable_msg = "#{reachable_count} SERVERS ARE ACCESSIBLE\n" + 
                  "ENVIRONMENT     SERVER                                IP                TRIES   TRANSACTION(MS)    UPTIME(HRS)\n" +
                  "--------------------------------------------------------------------------------------------------------------\n"
  reachable_msg = reachable.inject(reachable_msg) do |msg, (env, vms)| 
                    vms.each do |(vm, data)|
                      msg += sprintf("%-15.15s | %-35.35s | %-15s | %-5s | %-16s | %-11s\n", env, vm, data[:ip], data[:tries], data[:elapsed_time_ms], data[:data])
                    end; msg
                  end
else
  reachable_msg = "NO SERVERS ACCESSIBLE\n"
end                  

#----------------------------------------------------------------------------------------------------
msg = "\n" + unreachable_msg + "\n\n\n" + reachable_msg
send_email(EMAIL_CONFIG['msg']['to'].join(', '), EMAIL_CONFIG['msg']['subject'], msg, EMAIL_CONFIG['server'])
