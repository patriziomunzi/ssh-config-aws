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
identity_file = config.match(/IDENTITY_FILE=(.+)/)[1]
skip_regexp = config.match(/SKIP_REGEXP=(.+)/)[1]

# Add more regions here if necessary. No harm in adding all of them, just makes the generation take longer to query more regions.
regions = [
  'eu-west-1'
]

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
      if(tag.key != 'Name')
        next
      end
      instance_name = tag.value
    end

    if(instance_name != nil && !instance_name.match(/#{skip_regexp}/) )
      instance_name_tokens = instance_name.split("::")
      #instance_name = instance_name.gsub /[^a-zA-Z0-9\-_\.]/, '-'
      #instance_user = instance.tags['User'] || 'ubuntu'
      custom_user_regexp_res = config.match(/#{instance_name}\.USER=(.+)/)
      instance_user = custom_user_regexp_res ? custom_user_regexp_res[1] : 'ubuntu'

      #puts "#{instance.instance_id}: #{instance_name} #{instance.private_ip_address} (#{instance_user})"
      ssh_config << "Host #{instance_name}[#{instance.private_ip_address}]\n"
      ssh_config << "  # shuttle.name = #{slug}/#{instance_name_tokens[2]}/#{instance_name}[#{instance.private_ip_address}]\n"
      ssh_config << "  HostName #{instance.private_ip_address}\n"
      ssh_config << "  User #{instance_user}\n"
      ssh_config << "  IdentityFile ~/.ssh/#{identity_file}\n"
      ssh_config << "\n"
    end
  end
end

ssh_file = "ssh/#{slug}.sshconfig"
File.open(ssh_file, 'w') {|f| f.write(ssh_config) }

#puts "Complete! Now run rebuild-ssh-config.sh to update your .ssh/config file"
