#-------------------------------------------------------------------------------------------------
require 'rubygems'
require 'rest_client'
require 'nokogiri'
require 'logger'

#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
class VCDTimeout < Exception; end
class VCDFileMissing < Exception; end
class VCDFilePathMissing < Exception; end
class VCDVappTemplateCreateFailed < Exception; end
class VCDCatalogItemCreateFailed < Exception; end

#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
class VCD

  #-------------------------------------------------------------------------------
  attr_accessor :user_org, :site, :user, :password, :cookie, :x_vcloud_authorization,
                :logger, :url

  #-------------------------------------------------------------------------------
  # API
  #-------------------------------------------------------------------------------
  def initialize(user, password, url, opts={})
    @url = url
    root = File.expand_path(File.dirname(__FILE__))
    @logger = opts[:logger] || Logger.new(File.join(root, '../log', 'vcd.log'), 10, 1024000)
    RestClient.log = @logger
    @user, @user_org = user.split('@')
    @password = password
    @site = RestClient::Resource.new @url, "#{self.user}@#{self.user_org}", self.password
  end
  
  #-------------------------------------------------------------------------------
  def login
    headers = (@site['login'].post '').headers
    logger.info "VCD login for user: #{self.user}@#{self.user_org}"
    @cookie, @x_vcloud_authorization = headers[:set_cookie], headers[:x_vcloud_authorization]
  end

  #------------------------------------------------------------------------------
  def upload_ovf(args)
    raise ArgumentError, 'org required'           unless (org = args[:org])
    raise ArgumentError, 'vdc required'           unless (vdc = args[:vdc])
    raise ArgumentError, 'catalog_name required'  unless (catalog_name = args[:catalog_name])
    raise ArgumentError, 'template_name required' unless (template_name = args[:template_name]) 
    raise ArgumentError, 'template_dir required'  unless (template_dir = args[:template_dir]) 
    desc = args[:desc] || args[:template_name]
    count = 0
    begin
      count += 1
      begin
        vapp_template      = post_vapp_template(vdc, template_name, desc)
        catalog_item = post_catalog_item(org, vapp_template, catalog_name)
        ovf_vapp_template  = put_ovf_file(template_dir, vapp_template)
        mf_vapp_template   = put_mf_file(template_dir, ovf_vapp_template)
        vmdk_vapp_template = put_vmdk_files(template_dir, mf_vapp_template)
        if vmdk_vapp_template[:status].eql?(-1)
          logger.warn "ovf upload error retrying: #{org[:name]}#{catalog_name}/#{template_name}, #{count}"
          break unless clean_up_on_upload_failure(vapp_template, catalog_item)
        else
          logger.info "vapp template upload complete: #{org[:name]}#{catalog_name}/#{template_name}"
          break
        end
      rescue VCDFilePathMissing => err
        logger.warn err
        logger.warn "ovf upload failed retrying: #{org[:name]}#{catalog_name}/#{template_name}, #{count}"
        break unless clean_up_on_upload_failure(vapp_template, catalog_item)
      rescue VCDFileMissing => err
        logger.warn err
        logger.warn "ovf upload failed: #{org[:name]}#{catalog_name}/#{template_name}"
        clean_up_on_upload_failure(vapp_template, catalog_item)
        break
      rescue VCDVappTemplateCreateFailed => err
        logger.warn err
        logger.warn "ovf upload failed retrying: #{org[:name]}#{catalog_name}/#{template_name}, #{count}"
      rescue VCDCatalogItemCreateFailed => err
        logger.warn err
        logger.warn "ovf upload failed retrying: #{org[:name]}#{catalog_name}/#{template_name}, #{count}"
        break unless clean_up_on_upload_failure(vapp_template)
      rescue Exception => err
        logger.warn err
        logger.warn "ovf upload failed retrying: #{org[:name]}#{catalog_name}/#{template_name}, #{count}"
        break unless clean_up_on_upload_failure(vapp_template, catalog_item)
      end
      sleep(30)
    end while count < 5
    logger.warn("ovf upload failed forever stopping: #{org[:name]}#{catalog_name}/#{template_name}") if count.eql?(5)
  end

  #------------------------------------------------------------------------------
  def upload_media(org, vdc, catalog_name, media_name, desc, media_dir)
    raise ArgumentError, 'org required'          unless (org = args[:org])
    raise ArgumentError, 'vdc required'          unless (vdc = args[:vdc])
    raise ArgumentError, 'catalog_name required' unless (catalog_name = args[:catalog_name])
    raise ArgumentError, 'media_name required'   unless (media_name = args[:media_name])
    raise ArgumentError, 'media_dir required'    unless (media_dir = args[:media_dir]) 
    desc = args[:desc] || args[:media_name]
    begin
      media       = post_media(vdc, media_name, desc. media_dir)
      post_catalog_item(org, media, catalog_name)
      media_file  = put_media_file(media_dir, media)
      logger.info "iso upload complete: #{org[:name]}/#{catalog_name}/#{media_name}"
    rescue VCDFileMissing
      logger.warn "media upload failed: #{org[:name]}/#{catalog_name}/#{media_name}"
    end
  end

  #-------------------------------------------------------------------------------
  # get objects
  #-------------------------------------------------------------------------------
  def get_orgs
    resp = get('/org')
    build_orgs(resp)
  end

  #-------------------------------------------------------------------------------
  def get_org(orgs, org)
    if orgs[:org][org]
      resp = get(orgs[:org][org][:href])
      build_org(resp)
    else; {}; end
  end

  #------------------------------------------------------------------------------
  def get_org_by_id(orgs, org_id)
    org_href = orgs[:org].keys.find{|oid| oid.include?(org_id)}
    get_org(orgs, org_href)
  end

  #-------------------------------------------------------------------------------
  def get_catalog(org, catalog)
    if org[:link][:catalog][catalog]
      resp = get(org[:link][:catalog][catalog][:href])
      build_catalog(resp)
    else; {}; end
  end

  #-------------------------------------------------------------------------------
  def get_catalog_item(catalog, catalog_item)
    if catalog[:catalog_item][catalog_item]
      resp = get(catalog[:catalog_item][catalog_item][:href])
      build_catalog_item(resp)
    else; {}; end
  end

  #-------------------------------------------------------------------------------
  def get_vdc(org, vdc)
    if org[:link][:vdc][vdc]
      resp = get(org[:link][:vdc][vdc][:href])
      build_vdc(resp)
    else; {}; end
  end

  #-------------------------------------------------------------------------------
  def get_vapp(vdc, vapp_name)
    if vapp = vdc[:resource_entity][:v_app][vapp_name]
      resp = get(vapp[:href])
      build_vapp_response(resp)
    else; {}; end
  end

  #-------------------------------------------------------------------------------
  def get_vapp_template(vdc, vapp_template)
    if vapp = vdc[:resource_entity][:v_app_template][vapp_template]
      resp = get(vapp[:href])
      build_vapp_template_response(resp)
    else; {}; end
  end

  #-------------------------------------------------------------------------------
  def get_media(vdc, media_name)
    if media = vdc[:resource_entity][:media][media_name]
      resp = get(media[:href])
      build_media_response(resp)
    else; {}; end
  end

  #-------------------------------------------------------------------------------
  def get_network(org, network_name)
    if network = org[:link][:network][network_name]
      resp = get(network[:href])
      build_network_response(resp)
    else; {}; end
  end

  #-------------------------------------------------------------------------------
  def get(href)
    @site[href].get :x_vcloud_authorization => self.x_vcloud_authorization
  end

  #-------------------------------------------------------------------------------
  # check for objects
  #-------------------------------------------------------------------------------
  def catalog_item_exists?(org, catalog_name, catalog_item_name)
    catalog = get_catalog(org, catalog_name)
    if catalog_items = catalog[:catalog_item]
      catalog_items[catalog_item_name].nil? ? false : true; 
    else; false; end
  end

  #-------------------------------------------------------------------------------
  def vapp_template_exists?(vdc, vapp_template_name)
    return false unless vdc[:resource_entity]
    return false unless vdc[:resource_entity][:v_app_template]
    not vdc[:resource_entity][:v_app_template][vapp_template_name].nil?
  end

  #-------------------------------------------------------------------------------
  def media_exists?(vdc, media_name)
    return false unless vdc[:resource_entity]
    return false unless vdc[:resource_entity][:media]
    not vdc[:resource_entity][:media][media_name].nil?
  end

  #-------------------------------------------------------------------------------
  # create objects
  #-------------------------------------------------------------------------------
  def post_vapp_template(vdc, vapp_name, desc)
    begin
      body = "<UploadVAppTemplateParams name=\"#{vapp_name}\" manifestRequired=\"true\" xmlns=\"http://www.vmware.com/vcloud/v1\">" +
              "<Description>#{desc}</Description>" +
           "</UploadVAppTemplateParams>"
      href = vdc[:href] + '/action/uploadVAppTemplate'
      create_resp = @site[href].post body, :content_type => 'application/vnd.vmware.vcloud.uploadVAppTemplateParams+xml', 
        :x_vcloud_authorization => self.x_vcloud_authorization
      logger.info "created vapp template '#{vapp_name}' in vdc '#{vdc[:name]}'"
      build_vapp_template_response(create_resp)
    rescue Exception => err
      raise VCDVappTemplateCreateFailed, err.to_str
    end
  end

  #-------------------------------------------------------------------------------
  def post_media(vdc, media_name, desc, file_dir)
    file_path = get_iso_path(file_dir)
    body = "<Media name=\"#{media_name}\" imageType=\"iso\" size=\"#{File.size(file_path)}\" xmlns=\"http://www.vmware.com/vcloud/v1\">" +
              "<Description>#{desc}</Description>" +
           "</Media>"
    href = vdc[:href] + '/media'
    create_resp = @site[href].post body, :content_type => 'application/vnd.vmware.vcloud.media+xml', 
        :x_vcloud_authorization => self.x_vcloud_authorization
    logger.info "created media '#{media_name}' in vdc '#{vdc[:name]}'"
    build_media_response(create_resp)
  end

  #-------------------------------------------------------------------------------
  def post_catalog_item(org, item, catalog_name)
    begin
      body = "<CatalogItem name=\"#{item[:name]}\" xmlns=\"http://www.vmware.com/vcloud/v1\">" +
             "<Description>#{item[:description]}</Description>" +
             "<Entity href=\"#{self.url + item[:href]}\"/>" +
             "</CatalogItem>"
      href = org[:link][:catalog][catalog_name][:href] + '/catalogItems'
      create_resp = @site[href].post body, :content_type => 'application/vnd.vmware.vcloud.catalogItem+xml', 
        :x_vcloud_authorization => self.x_vcloud_authorization
      logger.info "created catalog item '#{item[:name]}' in catalog '#{catalog_name}' and organization '#{org[:name]}'"
      build_catalog_item(create_resp)
    rescue Exception => err
      raise VCDCatalogItemCreateFailed, err.to_str
    end      
  end

  #-------------------------------------------------------------------------------
  def put_ovf_file(template_path, vapp_template)
    file_path = get_ovf_path(template_path)
    ovf_file = vapp_template[:files].find{|f| /ovf$/.match(f[:name])}
    raise(VCDFileMissing, "ovf file not found") if file_path.nil?
    raise(VCDFilePathMissing, "ovf upload path not found") unless ovf_file
    put_file(file_path, ovf_file[:link][:href], 'text/html')
    logger.info "uploaded ovf file: #{file_path}"
    wait_for_vapp_template_files(vapp_template)
  end

  #-------------------------------------------------------------------------------
  def put_mf_file(template_path, vapp_template)
    file_path = get_mf_path(template_path)
    mf_file = vapp_template[:files].find{|f| /mf$/.match(f[:name])}
    raise(VCDFileMissing, "mf file not found") if file_path.nil?
    raise(VCDFilePathMissing, "mf upload path not found") unless mf_file
    put_file(file_path, mf_file[:link][:href], 'text/html')
    logger.info "uploaded mf file: #{file_path}"
    wait_for_vapp_template_files(vapp_template)
  end

  #-------------------------------------------------------------------------------
  def put_vmdk_files(template_path, vapp_template)
    file_paths = get_vmdk_paths(template_path)
    vmdk_files = vapp_template[:files].select{|f| /vmdk$/.match(f[:name])}
    raise(VCDFileMissing, "vmdk files not found") if file_paths.empty?
    raise(VCDFilePathMissing, "vmdk upload path not found") if vmdk_files.empty?
    vmdk_files.each do |f| 
      file_path = file_paths.find{|p| p.include?(f[:name])}
      put_file(file_path, f[:link][:href])
      logger.info "uploaded vmdk file: #{file_path}"
    end
    update_vapp_template(vapp_template)
  end

  #-------------------------------------------------------------------------------
  def put_media_file(media_path, media)
    file_path = get_iso_path(media_path)
    media_file = media[:files].first
    put_file(file_path, media_file[:link][:href], 'text/html')
    logger.info "uploaded iso file: #{file_path}"
    update_media(media)
  end

  #-------------------------------------------------------------------------------
  def put_file(file_path, href, content_type = nil)
    if file_path
      file = File.open(file_path, 'r')
      file_size = File.size(file_path)
      if content_type
        RestClient.put href, file, :x_vcloud_authorization => self.x_vcloud_authorization, 
          :content_type => content_type, :content_length => file_size
      else
        RestClient.put href, file, :x_vcloud_authorization => self.x_vcloud_authorization, 
          :content_length => file_size
      end
    end
  end

  #-------------------------------------------------------------------------------
  # delete objects
  #-------------------------------------------------------------------------------
  def delete_catalog_item(catalog_item)
    delete(catalog_item[:link][:catalog_item][:href])
  end

  #-------------------------------------------------------------------------------
  def delete_vapp_template(vapp)
    delete(vapp[:href])
  end

  #-------------------------------------------------------------------------------
  def delete(href)
    @site[href].delete :x_vcloud_authorization => self.x_vcloud_authorization    
  end

  #-------------------------------------------------------------------------------
  # build response structues from returnes XML
  #-------------------------------------------------------------------------------
  def build_orgs(resp)
    doc = Nokogiri.parse(resp.to_str)
    build_items(doc, 'Org')
  end

  #-------------------------------------------------------------------------------
  def build_org(resp)
    doc = Nokogiri.parse(resp.to_str)
    org = build_item(doc, 'Org')
    org[:link] = build_links(doc)
    org
  end

  #-------------------------------------------------------------------------------
  def build_vdc(resp)
    doc = Nokogiri.parse(resp.to_str)
    vdc = build_item(doc, 'Vdc')
    vdc[:link]            = build_links(doc)
    vdc[:resource_entity] =  build_items(doc, 'ResourceEntity')
    vdc
  end

  #-------------------------------------------------------------------------------
  def build_catalog(resp)
    doc = Nokogiri.parse(resp.to_str)
    catalog = build_item(doc, 'Catalog')
    catalog[:link]          = build_links(doc)
    catalog.update(build_items(doc, 'CatalogItem'))
    catalog[:description]  = (desc = doc.search('Description').first).nil? ? '' : desc.content
    catalog[:is_published] = (pub = doc.search('IsPublished').first).nil? ? '' : pub.content
    catalog
  end

  #-------------------------------------------------------------------------------
  def build_catalog_item(resp)
    doc = Nokogiri.parse(resp.to_str)
    item = build_item(doc, 'CatalogItem')
    item[:link]    = build_links(doc)
    entity              = doc.search('Entity').first
    item[:entity]       = {:href => get_href(entity), :type => entity['type']} 
    item
  end

  #-------------------------------------------------------------------------------
  def build_vapp_template_response(resp)
    doc = Nokogiri.parse(resp.to_str)
    attr = doc.search('VAppTemplate').first
    vapp_tmp = {:name => attr['name'], :href => get_href(attr), 
      :ovfDescriptorUploaded => attr['ovfDescriptorUploaded'], 
      :type => attr['type'], :status => attr['status']}
    vapp_tmp[:link] = build_links(doc)
    vapp_tmp[:description] = doc.search('Description').first.content
    vapp_tmp[:files] = build_files(doc)
    vapp_tmp
  end

  #-------------------------------------------------------------------------------
  def build_vapp_response(resp)
    doc = Nokogiri.parse(resp.to_str)
    attr = doc.search('VApp').first
    vapp = {:name => attr['name'], :href => get_href(attr), :type => attr['type'], 
      :status => attr['status']}
    vapp[:link] = build_links(doc)
    vapp[:link] = build_links(doc, 'VApp > Link')
    vapp[:vm] = build_vm_response(resp)
    vapp
  end

  #-------------------------------------------------------------------------------
  def build_vm_response(resp)
    doc = Nokogiri.parse(resp.to_str)
    doc.search('VApp > Children > Vm').map do |v|
      vm = {:name => v['name'], :href => get_href(v), :size => v['size'],
        :type => v['type'], :status => v['status'], :deployed => v['deployed']}
      vm[:link] = build_links(v, 'Link')
      vm[:description] = (desription_content = v.search('Description').first) ? desription_content.content : ''
      vm[:network_connection] = v.search('NetworkConnection').map do |n|
        ip_address = (ip_address_content = n.search('IpAddress').first) ? ip_address_content. content : ''
        is_connected = (is_connected_conent = n.search('IsConnected').first) ? is_connected_conent.content : ''
        mac_address = (mac_address_content = n.search('MACAddress').first) ? mac_address_content.content : ''
        {:network => n['network'], :ip_address => ip_address, :is_connected => is_connected,
          :mac_address => mac_address}
      end
      vm
    end
  end

  #-------------------------------------------------------------------------------
  def build_media_response(resp)
    doc = Nokogiri.parse(resp.to_str)
    attr = doc.search('Media').first
    media = {:name => attr['name'], :href => get_href(attr), :size => attr['size'], :image_type => attr['imageType'],
      :type => attr['type'], :status => attr['status']}
    media[:link] = build_links(doc)
    media[:description] = doc.search('Description').first.content
    media[:files] = build_files(doc)
    media
  end

  #-------------------------------------------------------------------------------
  def build_network_response(resp)
    doc = Nokogiri.parse(resp.to_str)
    attr = doc.search('OrgNetwork').first
    network = {:name => attr['name'], :href => get_href(attr), :type => attr['type']}
    network[:link] = build_links(doc)
    network[:nat_service] = doc.search('NatService > NatRule > PortForwardingRule').map do |r|
      external_ip = r.search('ExternalIP').first.content
      external_port = r.search('ExternalPort').first.content
      internal_ip = r.search('InternalIP').first.content
      internal_port = r.search('InternalPort').first.content
      protocol = r.search('Protocol').first.content
      {:external_ip => external_ip, :external_port => external_port, 
       :internal_ip => internal_ip, :internal_port => internal_port, :protocol => protocol}
    end
    network
  end

  #-------------------------------------------------------------------------------
  def build_files(doc)
    doc.search('Files > File').map do |f|
      file = {:name => f['name'], :bytesTransferred => f['bytesTransferred'], :size => f['size']}
      link = f.search('Link').first
      file[:link] = {:rel => link['rel'], :href => link['href']}
      file
    end
  end

  #-------------------------------------------------------------------------------
  def build_links(doc, tag='Link')
    doc.search(tag).inject({}) do |o, l|
      type = get_type(l)
      if type
        if name = l['name']
          href = get_href(l)
          data = {:href => href, :name=> name, :rel => l['rel'], :type => l['type']}
          update_object(o, type, href, data)
        else
          o.update(type => {:href => get_href(l), :type => l['type']})
        end
      else; o; end
    end
  end

  #-------------------------------------------------------------------------------
  def build_items(doc, item_name)
    doc.search(item_name).inject({}) do |v, i|
      type = get_type(i)
      if type
        if name = i['name']
          href = get_href(i)
          data = {:href => href, :name=> name, :type => i['type']}
          update_object(v, type, href, data)
        else
          v.update(type => {:href => get_href(i), :type => i['type']})
        end
      else; v; end
     end
  end

  #-------------------------------------------------------------------------------
  def build_item(doc, item_name)
    attr = doc.search(item_name).first
    {:name => attr['name'], :href => get_href(attr), :type => attr['type']}
  end

  #-------------------------------------------------------------------------------
  # utils
  #-------------------------------------------------------------------------------
  def update_object(o, t, n, d)
    o[t] ? (o[t].update({n => d}); o) : o.update({t => {n => d}})
  end

  #-------------------------------------------------------------------------------
  def update_vapp_template(vapp_template)
    href = vapp_template.kind_of?(Hash) ? vapp_template[:href] : vapp_template
    resp = get(href)
    build_vapp_template_response(resp)
  end

  #-------------------------------------------------------------------------------
  def update_media(media)
    href = media.kind_of?(Hash) ? media[:href] : media
    resp = get(href)
    build_media_response(resp)
  end

  #-------------------------------------------------------------------------------
  def get_href(item)
    item['href'].slice(self.url.length..-1)
  end

  #-------------------------------------------------------------------------------
  def get_ovf_path(dir)
    Dir.glob(File.join(dir, '*.ovf')).first
  end
  
  #-------------------------------------------------------------------------------
  def get_type(item)
    item['type'].nil? ? nil : tableize(item['type'].split('.').last.split('+').first).to_sym
  end

  #-------------------------------------------------------------------------------
  def get_mf_path(dir)
    Dir.glob(File.join(dir, '*.mf')).first
  end

  #-------------------------------------------------------------------------------
  def get_vmdk_paths(dir)
    Dir.glob(File.join(dir, '*.vmdk'))
  end

  #-------------------------------------------------------------------------------
  def get_iso_path(dir)
    Dir.glob(File.join(dir, '*.iso')).first
  end

  #-------------------------------------------------------------------------------
  def wait_for_vapp_template_files(vapp_template)
    template, files, count = {}, [], 0
    while files.empty? and count < 6
      sleep(10)
      template = update_vapp_template(vapp_template)
      files = template[:files]
      count += 1
    end
    if template[:files].empty?
      logger.warn "OVF upload failed becuase file list not retrived before timeout"
      raise VCDTimeout, 'file list not retrieved before timeout'
    end; template
  end

  #-------------------------------------------------------------------------------
  def clean_up_on_upload_failure(vapp_template, catalog_item=nil)
    sleep(30)
    begin
      delete_vapp_template(vapp_template)
      delete_catalog_item(catalog_item) if catalog_item
      true
    rescue Exception => cleanup_error
      logger.warn cleanup_error
      logger.warn "ovf upload failed and cleanup failed"
      false
    end
  end  

  #-------------------------------------------------------------------------------
  def tableize(s)
    res = ''
    s.each_char do |c|
      res += c.eql?(c.upcase) ? ('_' + c.downcase) : c  
    end; res
  end
end
