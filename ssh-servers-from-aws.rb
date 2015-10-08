#!/usr/bin/env ruby
require 'aws-sdk'

Dir.chdir File.expand_path File.dirname(__FILE__)

slug = ARGV.join

config = File.read("aws/#{slug}.profile")

if !config
  puts "No config file found for #{slug}"
  exit
end

access_key_id = config.match(/AWS_ACCESS_KEY=(.+)/)[1]
secret_access_key = config.match(/AWS_SECRET_KEY=(.+)/)[1]

regions_matcher = config.match(/AWS_REGIONS=(.+)/)
regions_str = regions_matcher ? regions_matcher[1] : ''

regions = regions_str.split(",")
if regions.length == 0
  puts "No regions found for #{slug}"
  exit
end

identity_file = config.match(/IDENTITY_FILE=(.+)/)[1]

skip_regexp_matcher = config.match(/SKIP_REGEXP=(.+)/)
skip_regexp = skip_regexp_matcher ? skip_regexp_matcher[1] : ''

host_pattern_matcher = config.match(/HOST_PATTERN=(.+)/)
host_pattern = host_pattern_matcher ? host_pattern_matcher[1] : '$NAME[$ADDRESS]'

shuttlename_pattern_matcher = config.match(/SHUTTLE_NAME_PATTERN=(.+)/)
shuttlename_pattern = shuttlename_pattern_matcher ? shuttlename_pattern_matcher[1] : '$SLUG/$STAGE/$NAME[$ADDRESS]'

name_tag_name_matcher = config.match(/NAME_TAG_NAME=(.+)/)
name_tag_name = name_tag_name_matcher ? name_tag_name_matcher[1] : 'Name'

stage_tag_name_matcher = config.match(/STAGE_TAG_NAME=(.+)/)
stage_tag_name = stage_tag_name_matcher ? stage_tag_name_matcher[1] : 'Stage'


ssh_config = ''
ssh_config << "\#============================================\n"
ssh_config << "\# #{slug.upcase}\n"
ssh_config << "\#============================================\n\n"

regions.each do |region|
  Aws.config.update({
    region: region,
    credentials: Aws::Credentials.new(access_key_id, secret_access_key),
  })

  ec2 = Aws::EC2::Client.new()

  reservations = ec2.describe_instances(  
    {
      filters: [
        {
          name: "instance-state-name",
          values: ["running"]
        }
      ]
    }
  ).reservations

  if(reservations.length == 0) 
      next
  end
  
  reservations.each do |reservation|

    instance = reservation.instances[0]

    instance_name = nil
    instance.tags.each do |tag|
      if(tag.key != name_tag_name)
        next
      end
      instance_name = tag.value
    end
    instance_stage = ''
    instance.tags.each do |tag|
      if(tag.key != stage_tag_name )
        next
      end
      instance_stage = tag.value
    end

    if(instance_name != nil && !instance_name.match(/#{skip_regexp}/) )
      #instance_name_tokens = instance_name.split("::")
      #instance_name = instance_name.gsub /[^a-zA-Z0-9\-_\.]/, '-'
      #instance_user = instance.tags['User'] || 'ubuntu'
      custom_user_regexp_res = config.match(/#{instance_name}\.USER=(.+)/)
      instance_user = custom_user_regexp_res ? custom_user_regexp_res[1] : 'ubuntu'

      instance_ip_address = instance.private_ip_address

      host = host_pattern
      host = host.gsub /\$SLUG/, slug
      host = host.gsub /\$NAME/, instance_name
      host = host.gsub /\$ADDRESS/, instance_ip_address
      host = host.gsub /\$STAGE/, instance_stage

      shuttlename = shuttlename_pattern;
      shuttlename = shuttlename.gsub /\$PROFILE/, slug
      shuttlename = shuttlename.gsub /\$NAME/, instance_name
      shuttlename = shuttlename.gsub /\$ADDRESS/, instance_ip_address
      shuttlename = shuttlename.gsub /\$STAGE/, instance_stage

      #puts "#{instance.instance_id}: #{instance_name} #{instance.private_ip_address} (#{instance_user})"
      ssh_config << "Host #{host}\n"
      ssh_config << "  # shuttle.name = #{shuttlename}\n"
      ssh_config << "  HostName #{instance_ip_address}\n"
      ssh_config << "  User #{instance_user}\n"
      ssh_config << "  IdentityFile ~/.ssh/#{identity_file}\n"
      ssh_config << "\n"
    end
  end
end

ssh_file = "ssh/#{slug}.sshconfig"
File.open(ssh_file, 'w') {|f| f.write(ssh_config) }

#puts "Complete! Now run rebuild-ssh-config.sh to update your .ssh/config file"
