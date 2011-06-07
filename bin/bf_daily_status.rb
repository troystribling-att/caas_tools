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
  short_msg = "#{unreachable_count} SERVERS ARE NOT ACCESSIBLE"
  msg = "#{short_msg}\n"
  msg = unreachable.inject(msg) do |msg, (env, vms)| 
           msg += "\nENVIRONMENT: #{env}\n\n"
           vms.each do |(vm, data)|
             msg += "    SERVER: #{vm}\n    IP: #{data[:ip]}\n    ERROR: #{data[:error_msg]}\n\n" 
           end; msg
         end 
else
  short_msg = "ALL SERVERS ARE ACCESSIBLE"
  msg = "#{short_msg}\n"
end         

#----------------------------------------------------------------------------------------------------
file = "ENVIRONMENT,SERVER,IP,ERROR MSG,TRIES,TRANSACTION(MS),UPTIME(HRS)\n" 
file += agg_response.inject([]) do |f, (env, vms)| 
          vms.each do |(vm, data)|
            f << [env, vm, data[:ip], data[:error_msg] || 'NO ERROR', data[:tries] || 'NA', data[:elapsed_time_ms] || 'NA', data[:data] || 'NA'].join(',')
          end; f
        end.join("\n")

#----------------------------------------------------------------------------------------------------
send_email(EMAIL_CONFIG['msg']['to'].join(', '), EMAIL_CONFIG['msg']['subject'] + " (#{short_msg})", msg, 'status.csv', file, EMAIL_CONFIG['server'])
