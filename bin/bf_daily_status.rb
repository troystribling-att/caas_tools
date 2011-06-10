#-------------------------------------------------------------------------------------------------
this_dir = File.expand_path(File.dirname(__FILE__))
$:.unshift(this_dir)
require 'yaml'
require "#{this_dir}/../lib/cmds"
require "#{this_dir}/../lib/apigee_cmds"
require "#{this_dir}/../lib/send_email"

#-------------------------------------------------------------------------------------------------
CONFIG = File.open(ARGV.first){|yf| YAML::load(yf)}
EMAIL_CONFIG = File.open("#{this_dir}/../send_email.yml") {|yf| YAML::load(yf)}

#----------------------------------------------------------------------------------------------------
puts "INFO: STARTING RUN: #{Time.now.to_s}"
bash_response = Cmds.uptime(CONFIG['bash_vms'])
apigee_response = APIGeeCmds.uptime(CONFIG['apigee_vms'])

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
report_time = Time.now
file = "#{report_time.strftime("%Y-%m-%d %H:%M %Z")}\nENVIRONMENT,SERVER,IP,ERROR MSG,TRIES,TRANSACTION(MS),UPTIME(HRS)\n" 
file += agg_response.inject([]) do |f, (env, vms)| 
          vms.each do |(vm, data)|
            f << [env, vm, data[:ip], data[:error_msg] || 'NO ERROR', data[:tries] || 'NA', data[:elapsed_time_ms] || 'NA', data[:data] || 'NA'].join(',')
          end; f
        end.join("\n")

#----------------------------------------------------------------------------------------------------
email_status_to = EMAIL_CONFIG['msg']['to'].join(', ')
puts "INFO: SENDING REPORT TO: #{email_status_to}"
try_count = 0
begin
  try_count += 1
  send_email(email_status_to, EMAIL_CONFIG['msg']['subject'] + " (#{short_msg}) #{report_time.strftime("%Y-%m-%d %H:%M %Z")}", msg, "status-#{report_time.strftime("%Y-%m-%d")}.csv", file, EMAIL_CONFIG['server'])
rescue Net::SMTPServerBusy
  if try_count < 5 
    sleep(10)
    puts "ERROR: FAILED TO MAIL REPORT TO: #{email_status_to} #{try_count} TIMES. RETRYING"
    retry 
  else
    puts "ERROR: FAILED TO MAIL REPORT TO: #{email_status_to} #{try_count} TIMES. ABORTING"
  end
end
puts "INFO: ENDING RUN: #{Time.now.to_s}"
