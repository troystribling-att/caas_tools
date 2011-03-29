require './caas_web'

#----------------------------------------------------------------------------------------------------
def create_session(user, password, site = 'https://206.17.20.10/CirrusServices/resources')
  user = [user].flatten
  password = [password].flatten
  sessions = []
  user.each_index do |i|
    puts "CREATING SESSION"
    puts "  USER: #{user[i]}"
    puts "  PASSWORD: #{password[i]}"
    puts "  SITE: #{site}"
    session = {}
    session[:caas]     = CaaS.new(user[i], password[i], site)
    CaaS.retry_until{session[:caas].login}
    session[:cloud]    = CaaS.retry_until{session[:caas].get_all_clouds.first}
    session[:vdc]      = CaaS.retry_until{session[:caas].get_all_vdcs(session[:cloud]).first}
    session[:cluster]  = CaaS.retry_until{session[:caas].get_all_clusters(session[:vdc]).first}
    session[:location] = CaaS.retry_until{session[:caas].get_all_locations[1]}
    session[:vnets]    = CaaS.retry_until{session[:caas].get_all_vnets(session[:cluster])}
    sessions << session
  end
  sessions
end
