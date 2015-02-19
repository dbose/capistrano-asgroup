require 'right_aws_api'

unless Capistrano::Configuration.respond_to?(:instance)
  abort 'capistrano/asgroup requires Capistrano >= 2'
end

module Capistrano
  class Configuration
    module Asgroup

      def asgroupname(which, *args)

        # Get Auto Scaling API obj
        @as_api ||= RightScale::CloudApi::AWS::AS::Manager::new(fetch(:aws_access_key_id), 
                                                                fetch(:aws_secret_access_key), 
                                                                'https://autoscaling.ap-southeast-2.amazonaws.com')
        
        # Get EC2 API obj
        @ec2_api ||= RightScale::CloudApi::AWS::EC2::Manager::new(fetch(:aws_access_key_id), 
                                                                  fetch(:aws_secret_access_key), 
                                                                  'https://ec2.ap-southeast-2.amazonaws.com')


        # Get descriptions of all the Auto Scaling groups
        autoScaleDesc = @as_api.DescribeAutoScalingGroups('AutoScalingGroupNames.member' => [which])
        autoScalingMembers = autoScaleDesc["DescribeAutoScalingGroupsResponse"]["DescribeAutoScalingGroupsResult"]["AutoScalingGroups"]["member"]["Instances"]["member"]

        if autoScalingMembers.empty?                        
            return
        end                        

        # Iron out the single or multiple instances
        autoScalingMembers = autoScalingMembers.is_a?(Hash) ? [autoScalingMembers] : autoScalingMembers   

        # Get the instance ids
        autoScaleInstances = autoScalingMembers.map{|he| he["InstanceId"]}
        puts "Instance Ids: #{autoScaleInstances}"

        # Get the instance meta data
        instanceMetaData = @ec2_api.DescribeInstances('InstanceId' => autoScaleInstances)        
        instanceItems = instanceMetaData["DescribeInstancesResponse"]["reservationSet"]["item"]
        instanceItems = instanceItems.is_a?(Hash) ? [instanceItems] : instanceItems
        instanceDNSNames = instanceItems.map do |instanceItem|  

            instancesInInstanceSet = instanceItem["instancesSet"]["item"]    
            instancesInInstanceSet = instancesInInstanceSet.is_a?(Hash) ? [instancesInInstanceSet] : instancesInInstanceSet

            instancesInInstanceSet.each do |instance|
                tags = instance["tagSet"]["item"]
                hostnameHash = tags.select {|el| el["value"] if el["key"] ==  "Name" }
                serverName = "#{hostnameHash.first["value"]}.dynamic.f2.com.au"
                puts "Server name - #{serverName}"

                # Plug to capistrano
                server(serverName, *args)
            end            
                        
        end
    
      end
    end

    include Asgroup
  end
end

