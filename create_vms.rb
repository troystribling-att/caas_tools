require 'caas_web'

#### args
user = ARGV[0]
password = ARGV[1]
nvms = ARGV[2] || 5
site = ARGV[3] || 'https://206.17.20.10/CirrusServices/resources'

### cretae cluster
caas = CaaS.new(user, password, site)
caas.login








