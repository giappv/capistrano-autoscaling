require "aws"
require "capistrano-autoscaling/version"
require "yaml"

module Capistrano
  module AutoScaling
    def self.extended(configuration)
      configuration.load {
        namespace(:autoscaling) {
## AWS
          _cset(:autoscaling_region, nil)
          _cset(:autoscaling_autoscaling_endpoint) {
            case autoscaling_region
            when "us-east-1"      then "autoscaling.us-east-1.amazonaws.com"
            when "us-west-1"      then "autoscaling.us-west-1.amazonaws.com"
            when "us-west-2"      then "autoscaling.us-west-2.amazonaws.com"
            when "sa-east-1"      then "autoscaling.sa-east-1.amazonaws.com"
            when "eu-west-1"      then "autoscaling.eu-west-1.amazonaws.com"
            when "ap-southeast-1" then "autoscaling.ap-southeast-1.amazonaws.com"
            when "ap-southeast-2" then "autoscaling.ap-southeast-2.amazonaws.com"
            when "ap-northeast-1" then "autoscaling.ap-northeast-1.amazonaws.com"
            end
          }
          _cset(:autoscaling_cloudwatch_endpoint) {
            case autoscaling_region
            when "us-east-1"      then "monitoring.us-east-1.amazonaws.com"
            when "us-west-1"      then "monitoring.us-west-1.amazonaws.com"
            when "us-west-2"      then "monitoring.us-west-2.amazonaws.com"
            when "sa-east-1"      then "monitoring.sa-east-1.amazonaws.com"
            when "eu-west-1"      then "monitoring.eu-west-1.amazonaws.com"
            when "ap-southeast-1" then "monitoring.ap-southeast-1.amazonaws.com"
            when "ap-southeast-2" then "monitoring.ap-southeast-2.amazonaws.com"
            when "ap-northeast-1" then "monitoring.ap-northeast-1.amazonaws.com"
            end
          }
          _cset(:autoscaling_ec2_endpoint) {
            case autoscaling_region
            when "us-east-1"      then "ec2.us-east-1.amazonaws.com"
            when "us-west-1"      then "ec2.us-west-1.amazonaws.com"
            when "us-west-2"      then "ec2.us-west-2.amazonaws.com"
            when "sa-east-1"      then "ec2.sa-east-1.amazonaws.com"
            when "eu-west-1"      then "ec2.eu-west-1.amazonaws.com"
            when "ap-southeast-1" then "ec2.ap-southeast-1.amazonaws.com"
            when "ap-southeast-2" then "ec2.ap-southeast-2.amazonaws.com"
            when "ap-northeast-1" then "ec2.ap-northeast-1.amazonaws.com"
            end
          }
          _cset(:autoscaling_elb_endpoint) {
            case autoscaling_region
            when "us-east-1"      then "elasticloadbalancing.us-east-1.amazonaws.com"
            when "us-west-1"      then "elasticloadbalancing.us-west-1.amazonaws.com"
            when "us-west-2"      then "elasticloadbalancing.us-west-2.amazonaws.com"
            when "sa-east-1"      then "elasticloadbalancing.sa-east-1.amazonaws.com"
            when "eu-west-1"      then "elasticloadbalancing.eu-west-1.amazonaws.com"
            when "ap-southeast-1" then "elasticloadbalancing.ap-southeast-1.amazonaws.com"
            when "ap-southeast-2" then "elasticloadbalancing.ap-southeast-2.amazonaws.com"
            when "ap-northeast-1" then "elasticloadbalancing.ap-northeast-1.amazonaws.com"
            end
          }
          _cset(:autoscaling_access_key_id) {
            fetch(:aws_access_key_id, ENV["AWS_ACCESS_KEY_ID"]) or abort("AWS_ACCESS_KEY_ID is not set")
          }
          _cset(:autoscaling_secret_access_key) {
            fetch(:aws_secret_access_key, ENV["AWS_SECRET_ACCESS_KEY"]) or abort("AWS_SECRET_ACCESS_KEY is not set")
          }
          _cset(:autoscaling_aws_options) {
            {
              :access_key_id => autoscaling_access_key_id,
              :secret_access_key => autoscaling_secret_access_key,
              :log_level => fetch(:autoscaling_log_level, :debug),
              :auto_scaling_endpoint => autoscaling_autoscaling_endpoint,
              :cloud_watch_endpoint => autoscaling_cloudwatch_endpoint,
              :ec2_endpoint => autoscaling_ec2_endpoint,
              :elb_endpoint => autoscaling_elb_endpoint,
            }.merge(fetch(:autoscaling_aws_extra_options, {}))
          }
          _cset(:autoscaling_autoscaling_client) { AWS::AutoScaling.new(fetch(:autoscaling_autoscaling_aws_options, autoscaling_aws_options)) }
          _cset(:autoscaling_cloudwatch_client) { AWS::CloudWatch.new(fetch(:autoscaling_cloudwatch_options, autoscaling_aws_options)) }
          _cset(:autoscaling_ec2_client) { AWS::EC2.new(fetch(:autoscaling_ec2_options, autoscaling_aws_options)) }
          _cset(:autoscaling_elb_client) { AWS::ELB.new(fetch(:autoscaling_elb_options, autoscaling_aws_options)) }

          def autoscaling_name_mangling(s)
            s.to_s.gsub(/[^0-9A-Za-z]/, "-")
          end

## general
          _cset(:autoscaling_application) { autoscaling_name_mangling(application) }
          _cset(:autoscaling_timestamp) { Time.now.strftime("%Y%m%d%H%M%S") }
          _cset(:autoscaling_availability_zones) { autoscaling_ec2_client.availability_zones.to_a.map { |az| az.name } }
          _cset(:autoscaling_wait_interval, 1.0)
          _cset(:autoscaling_keep_images, 2)
          _cset(:autoscaling_instance_type, "t1.micro")
          _cset(:autoscaling_security_groups, %w(default))
          _cset(:autoscaling_min_size, 1)
          _cset(:autoscaling_max_size) { autoscaling_min_size }

## behaviour
          _cset(:autoscaling_create_elb, true)
          _cset(:autoscaling_create_image, true)
          _cset(:autoscaling_create_launch_configuration) {
            autoscaling_create_image or ( autoscaling_image and autoscaling_image.exists? )
          }
          _cset(:autoscaling_create_group) {
            ( autoscaling_create_elb or ( autoscaling_elb_instance and autoscaling_elb_instance.exists? ) ) and
              autoscaling_create_launch_configuration
          }
          _cset(:autoscaling_create_policy) { autoscaling_create_group }
          _cset(:autoscaling_create_alarm) { autoscaling_create_policy }

## ELB
          _cset(:autoscaling_elb_instance_name_prefix, "elb-")
          _cset(:autoscaling_elb_instance_name) { "#{autoscaling_elb_instance_name_prefix}#{autoscaling_application}" }
          _cset(:autoscaling_elb_instance) { autoscaling_elb_client.load_balancers[autoscaling_elb_instance_name] }
          _cset(:autoscaling_elb_listeners) {
            [
              {
                :port => fetch(:autoscaling_elb_port, 80),
                :protocol => fetch(:autoscaling_elb_protocol, :http),
                :instance_port => fetch(:autoscaling_elb_instance_port, 80),
                :instance_protocol => fetch(:autoscaling_elb_instance_protocol, :http),
              },
            ]
          }
          _cset(:autoscaling_elb_instance_options) {
            {
              :availability_zones => fetch(:autoscaling_elb_availability_zones, autoscaling_availability_zones),
              :listeners => autoscaling_elb_listeners,
            }.merge(fetch(:autoscaling_elb_instance_extra_options, {}))
          }
          _cset(:autoscaling_elb_health_check_target_path, "/")
          _cset(:autoscaling_elb_health_check_target) {
            autoscaling_elb_listeners.map { |listener|
              if /^https?$/i =~ listener[:instance_protocol]
                "#{listener[:instance_protocol].to_s.upcase}:#{listener[:instance_port]}#{autoscaling_elb_health_check_target_path}"
              else
                "#{listener[:instance_protocol].to_s.upcase}:#{listener[:instance_port]}"
              end
            }.first
          }
          _cset(:autoscaling_elb_health_check_options) {
            {
              :healthy_threshold => fetch(:autoscaling_elb_healthy_threshold, 10).to_i,
              :unhealthy_threshold => fetch(:autoscaling_elb_unhealthy_threshold, 2).to_i,
              :interval => fetch(:autoscaling_elb_health_check_interval, 30).to_i,
              :timeout => fetch(:autoscaling_elb_health_check_timeout, 5).to_i,
              :target => autoscaling_elb_health_check_target,
            }.merge(fetch(:autoscaling_elb_health_check_extra_options, {}))
          }

## EC2
          _cset(:autoscaling_ec2_instance_name) { autoscaling_application }
          _cset(:autoscaling_ec2_instances) {
            if autoscaling_elb_instance and autoscaling_elb_instance.exists?
              autoscaling_elb_instance.instances.to_a
            else
              abort("ELB is not ready: #{autoscaling_elb_instance_name}")
            end
          }
          _cset(:autoscaling_ec2_instance_dns_names) { autoscaling_ec2_instances.map { |instance| instance.dns_name } }
          _cset(:autoscaling_ec2_instance_private_dns_names) { autoscaling_ec2_instances.map { |instance| instance.private_dns_name } }

## AMI
          _cset(:autoscaling_image_name) { "#{autoscaling_ec2_instance_name}/#{autoscaling_timestamp}" }
          _cset(:autoscaling_image_instance) {
            if 0 < autoscaling_ec2_instances.length
              autoscaling_ec2_instances.reject { |instance| instance.root_device_type != :ebs }.last
            else
              abort("No EC2 instances are ready to create AMI.")
            end
          }
          _cset(:autoscaling_image_options) {
            { :no_reboot => true }.merge(fetch(:autoscaling_image_extra_options, {}))
          }
          _cset(:autoscaling_image_tag_name) { autoscaling_application }
          _cset(:autoscaling_image) {
            autoscaling_ec2_client.images.with_owner("self").tagged("Name").tagged_values(autoscaling_image_name).to_a.first
          }
          _cset(:autoscaling_images) {
            autoscaling_ec2_client.images.with_owner("self").tagged(autoscaling_image_tag_name).reject { |image| image.state != :available }
          }

## LaunchConfiguration
          _cset(:autoscaling_launch_configuration) {
            autoscaling_autoscaling_client.launch_configurations[autoscaling_launch_configuration_name]
          }
          _cset(:autoscaling_launch_configuration_name_prefix, "lc-")
          _cset(:autoscaling_launch_configuration_name) { "#{autoscaling_launch_configuration_name_prefix}#{autoscaling_image_name}" }
          _cset(:autoscaling_launch_configuration_instance_type) { autoscaling_instance_type }
          _cset(:autoscaling_launch_configuration_options) {
            {
              :security_groups => fetch(:autoscaling_launch_configuration_security_groups, autoscaling_security_groups),
            }.merge(fetch(:autoscaling_launch_configuration_extra_options, {}))
          }

## AutoScalingGroup
          _cset(:autoscaling_group_name_prefix, "asg-")
          _cset(:autoscaling_group_name) { "#{autoscaling_group_name_prefix}#{autoscaling_application}" }
          _cset(:autoscaling_group_options) {
            {
              :availability_zones => fetch(:autoscaling_group_availability_zones, autoscaling_availability_zones),
              :min_size => fetch(:autoscaling_group_min_size, autoscaling_min_size),
              :max_size => fetch(:autoscaling_group_max_size, autoscaling_max_size),
            }.merge(fetch(:autoscaling_group_extra_options, {}))
          }
          _cset(:autoscaling_group) { autoscaling_autoscaling_client.groups[autoscaling_group_name] }

## ScalingPolicy
          _cset(:autoscaling_expand_policy_name_prefix, "expand-")
          _cset(:autoscaling_shrink_policy_name_prefix, "shrink-")
          _cset(:autoscaling_expand_policy_name) { "#{autoscaling_expand_policy_name_prefix}#{autoscaling_application}" }
          _cset(:autoscaling_shrink_policy_name) { "#{autoscaling_shrink_policy_name_prefix}#{autoscaling_application}" }
          _cset(:autoscaling_expand_policy_options) {{
            :adjustment => fetch(:autoscaling_expand_policy_adjustment, 1),
            :cooldown => fetch(:autoscaling_expand_policy_cooldown, 300),
            :type => fetch(:autoscaling_expand_policy_type, "ChangeInCapacity"),
          }}
          _cset(:autoscaling_shrink_policy_options) {
            {
              :adjustment => fetch(:autoscaling_shrink_policy_adjustment, -1),
              :cooldown => fetch(:autoscaling_shrink_policy_cooldown, 300),
              :type => fetch(:autoscaling_shrink_policy_type, "ChangeInCapacity"),
            }.merge(fetch(:autoscaling_shrink_policy_extra_options, {}))
          }
          _cset(:autoscaling_expand_policy) { autoscaling_group.scaling_policies[autoscaling_expand_policy_name] }
          _cset(:autoscaling_shrink_policy) { autoscaling_group.scaling_policies[autoscaling_shrink_policy_name] }

## Alarm
          _cset(:autoscaling_expand_alarm_options) {
            {
              :period => fetch(:autoscaling_expand_alarm_period, 60),
              :evaluation_periods => fetch(:autoscaling_expand_alarm_evaluation_periods, 1),
            }.merge(fetch(:autoscaling_expand_alarm_extra_options, {}))
          }
          _cset(:autoscaling_shrink_alarm_options) {
            {
              :period => fetch(:autoscaling_shrink_alarm_period, 60),
              :evaluation_periods => fetch(:autoscaling_shrink_alarm_evaluation_periods, 1),
            }.merge(fetch(:autoscaling_shrink_alarm_extra_options, {}))
          }
          _cset(:autoscaling_expand_alarm_name_prefix, "alarm-expand-")
          _cset(:autoscaling_shrink_alarm_name_prefix, "alarm-shrink-")
          _cset(:autoscaling_expand_alarm_name) { "#{autoscaling_expand_alarm_name_prefix}#{autoscaling_application}" }
          _cset(:autoscaling_shrink_alarm_name) { "#{autoscaling_shrink_alarm_name_prefix}#{autoscaling_application}" }
          _cset(:autoscaling_expand_alarm_definitions) {{
            autoscaling_expand_alarm_name => {
              :statistic => fetch(:autoscaling_expand_alarm_evaluation_statistic, "Average"),
              :namespace => fetch(:autoscaling_expand_alarm_namespace, "AWS/EC2"),
              :metric_name => fetch(:autoscaling_expand_alarm_metric_name, "CPUUtilization"),
              :comparison_operator => fetch(:autoscaling_expand_alarm_comparison_operator, "LessThanThreshold"),
              :threshold => fetch(:autoscaling_expand_alarm_threshold, 30),
            },
          }}
          _cset(:autoscaling_shrink_alarm_definitions) {{
            autoscaling_shrink_alarm_name => {
              :statistic => fetch(:autoscaling_shrink_alarm_evaluation_statistic, "Average"),
              :namespace => fetch(:autoscaling_shrink_alarm_namespace, "AWS/EC2"),
              :metric_name => fetch(:autoscaling_shrink_alarm_metric_name, "CPUUtilization"),
              :comparison_operator => fetch(:autoscaling_shrink_alarm_comparison_operator, "LessThanThreshold"),
              :threshold => fetch(:autoscaling_shrink_alarm_threshold, 30),
            },
          }}

          desc("Setup AutoScaling.")
          task(:setup, :roles => :app, :except => { :no_release => true }) {
            setup_elb
          }

          task(:setup_elb, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_create_elb
              if autoscaling_elb_instance and autoscaling_elb_instance.exists?
                logger.debug("Found ELB: #{autoscaling_elb_instance.name}")
                autoscaling_elb_listeners.each do |listener|
                  autoscaling_elb_instance.listeners.create(listener)
                end
              else
                logger.debug("Creating ELB instance: #{autoscaling_elb_instance_name}")
                set(:autoscaling_elb_instance, autoscling_elb_client.load_balancers.create(
                  autoscaling_elb_instance_name, autoscaling_elb_instance_options))
                sleep(autoscaling_wait_interval) unless autoscaling_elb_instance.exists?
                logger.debug("Created ELB instance: #{autoscaling_elb_instance.name}")
                logger.info("You must setup EC2 instance(s) behind the ELB manually: #{autoscaling_elb_instance_name}")
              end
              logger.debug("Configuring ELB health check: #{autoscaling_elb_instance_name}")
              autoscaling_elb_instance.configure_health_check(autoscaling_elb_health_check_options)
            else
              logger.info("Skip creating ELB instance: #{autoscaling_elb_instance_name}")
            end
          }

          desc("Remove AutoScaling settings.")
          task(:destroy, :roles => :app, :except => { :no_release => true }) {
            abort("FIXME: Not yet implemented.")
          }

          desc("Register current instance for AutoScaling.")
          task(:update, :roles => :app, :except => { :no_release => true }) {
            suspend
            update_image
            update_launch_configuration
            update_group
            update_policy
            resume
          }

          task(:update_image, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_create_image
              if autoscaling_image and autoscaling_image.exists?
                logger.debug("Found AMI: #{autoscaling_image.name} (#{autoscaling_image.id})")
              else
                logger.debug("Creating AMI: #{autoscaling_image_name}")
                run("sync; sync; sync") # force flushing to disk
                set(:autoscaling_image, autoscaling_ec2_client.images.create(
                  autoscaling_image_options.merge(:name => autoscaling_image_name, :instance_id => autoscaling_image_instance.id)))
                sleep(autoscaling_wait_interval) until autoscaling_image.exists?
                logger.debug("Created AMI: #{autoscaling_image.name} (#{autoscaling_image.id})")
                [["Name", {:value => autoscaling_image_name}], [autoscaling_image_tag_name]].each do |tag_name, tag_options|
                  begin
                    autoscaling_image.add_tag(tag_name, tag_options)
                  rescue AWS::EC2::Errors::InvalidAMIID::NotFound => error
                    logger.info("[ERROR] " + error.inspect)
                    sleep(autoscaling_wait_interval)
                    retry
                  end
                end
              end
            else
              logger.info("Skip creating AMI: #{autoscaling_image_name}")
            end
          }

          task(:update_launch_configuration, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_create_launch_configuration
              if autoscaling_launch_configuration.exists?
                logger.debug("Found LaunchConfiguration: #{autoscaling_launch_configuration.name} (#{autoscaling_launch_configuration.image_id})")
              else
                logger.debug("Creating LaunchConfiguration: #{autoscaling_launch_configuration_name} (#{autoscaling_image.id})")
                set(:autoscaling_launch_configuration, autoscaling_autoscaling_client.launch_configurations.create(
                  autoscaling_launch_configuration_name, autoscaling_image, autoscaling_launch_configuration_instance_type,
                  autoscaling_launch_configuration_options))
                sleep(autoscaling_wait_interval) unless autoscaling_launch_configuration.exists?
                logger.debug("Created LaunchConfiguration: #{autoscaling_launch_configuration.name} (#{autoscaling_launch_configuration.image_id})")
              end
            else
              logger.info("Skip creating LaunchConfiguration: #{autoscaling_launch_configuration_name}")
            end
          }

          task(:update_group, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_create_group
              if autoscaling_group and autoscaling_group.exists?
                logger.debug("Found AutoScalingGroup: #{autoscaling_group.name} (#{autoscaling_group.launch_configuration_name})")
                autoscaling_group.update(autoscaling_group_options.merge(:launch_configuration => autoscaling_launch_configuration))
              else
                if autoscaling_elb_instance.exists? and autoscaling_launch_configuration.exists?
                  logger.debug("Creating AutoScalingGroup: #{autoscaling_group_name} (#{autoscaling_launch_configuration.name})")
                  set(:autoscaling_group, autoscaling_autoscaling_client.groups.create(autoscaling_group_name,
                    autoscaling_group_options.merge(:launch_configuration => autoscaling_launch_configuration,
                    :load_balancers => [ autoscaling_elb_instance ])))
                  logger.debug("Created AutoScalingGroup: #{autoscaling_group.name} (#{autoscaling_group.launch_configuration_name})")
                else
                  logger.info("Skip creating AutoScalingGroup: #{autoscaling_group_name} (#{autoscaling_launch_configuration_name})")
                end
              end
            else
              logger.info("Skip creating AutoScalingGroup: #{autoscaling_group_name}")
            end
          }

          task(:update_policy, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_create_policy
              if autoscaling_expand_policy and autoscaling_expand_policy.exists?
                logger.debug("Found ScalingPolicy for expansion: #{autoscaling_expand_policy.name}")
              else
                logger.debug("Createing ScalingPolicy for expansion: #{autoscaling_expand_policy_name}")
                set(:autoscaling_expand_policy, autoscaling_group.scaling_policies.create(autoscaling_expand_policy_name,
                                                                                          autoscaling_expand_policy_options))
                sleep(autoscaling_wait_interval) unless autoscaling_expand_policy.exists?
                logger.debug("Created ScalingPolicy for expansion: #{autoscaling_expand_policy.name}")
              end
            else
              logger.info("Skip creating ScalingPolicy for expansion: #{autoscaling_expand_policy_name}")
            end

            if autoscaling_create_policy
              if autoscaling_shrink_policy and autoscaling_shrink_policy.exists?
                logger.debug("Found ScalingPolicy for shrinking: #{autoscaling_shrink_policy.name}")
              else
                logger.debug("Createing ScalingPolicy for shrinking: #{autoscaling_shrink_policy_name}")
                set(:autoscaling_shrink_policy, autoscaling_group.scaling_policies.create(autoscaling_shrink_policy_name,
                                                                                          autoscaling_shrink_policy_options))
                sleep(autoscaling_wait_interval) unless autoscaling_shrink_policy.exists?
                logger.debug("Created ScalingPolicy for shrinking: #{autoscaling_shrink_policy.name}")
              end
            else
              logger.info("Skip creating ScalingPolicy for shrinking: #{autoscaling_shrink_policy_name}")
            end
          }

          def autoscaling_default_alarm_dimensions(namespace)
            case namespace
            when %r{AWS/EC2}i
              [{"Name" => "AutoScalingGroupName", "Value" => autoscaling_group_name}]
            when %r{AWS/ELB}i
              [{"Name" => "LoadBalancerName", "Value" => autoscaling_elb_instance_name}]
            else
              abort("Unknown metric namespace to generate dimensions: #{namespace}")
            end
          end

          task(:update_alarm, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_create_alarm
              autoscaling_expand_alarm_definitions.each do |alarm_name, alarm_options|
                alarm = autoscaling_cloudwatch_client.alarms[alarm_name]
                if alarm and alarm.exists?
                  logger.debug("Found Alarm for expansion: #{alarm.name}")
                else
                  logger.debug("Creating Alarm for expansion: #{alarm_name}")
                  options = autoscaling_expand_alarm_options.merge(alarm_options)
                  options[:alarm_actions] = [ autoscaling_expand_policy.arn ] unless options.has_key?(:alarm_actions)
                  options[:dimensions] = autoscaling_default_alarm_dimensions(options[:namespace]) unless options.has_key?(:dimensions)
                  alarm = autoscaling_cloudwatch_client.alarms.create(alarm_name, options)
                  logger.debug("Created Alarm for expansion: #{alarm.name}")
                end
              end
            else
              logger.info("Skip creating Alarm for expansion")
            end

            if autoscaling_create_alarm
              autoscaling_shrink_alarm_definitions.each do |alarm_name, alarm_options|
                alarm = autoscaling_cloudwatch_client.alarms[alarm_name]
                if alarm and alarm.exists?
                  logger.debug("Found Alarm for shrinking: #{alarm.name}")
                else
                  logger.debug("Creating Alarm for shrinking: #{alarm_name}")
                  options = autoscaling_shrink_alarm_options.merge(alarm_options)
                  options[:alarm_actions] = [ autoscaling_shrink_policy.arn ] unless options.has_key?(:alarm_actions)
                  options[:dimensions] = autoscaling_default_alarm_dimensions(options[:namespace]) unless options.has_key?(:dimensions)
                  alarm = autoscaling_cloudwatch_client.alarms.create(alarm_name, options)
                  logger.debug("Created Alarm for shrinking: #{alarm.name}")
                end
              end
            else
              logger.info("Skip creating Alarm for shrinking")
            end
          }

          desc("Suspend AutoScaling processes.")
          task(:suspend, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_group and autoscaling_group.exists?
              logger.info("Suspending Group: #{autoscaling_group.name}")
              autoscaling_group.suspend_all_processes
            else
              logger.info("Skip suspending AutoScalingGroup: #{autoscaling_group_name}")
            end
          }

          desc("Resume AutoScaling processes.")
          task(:resume, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_group and autoscaling_group.exists?
              logger.info("Resuming Group: #{autoscaling_group.name}")
              autoscaling_group.resume_all_processes
            else
              logger.info("Skip resuming AutoScalingGroup: #{autoscaling_group_name}")
            end
          }

          desc("Show AutoScaling status.")
          task(:status, :roles => :app, :except => { :no_release => true }) {
            if autoscaling_group and autoscaling_group.exists?
              STDOUT.puts({
                :availability_zone_names => autoscaling_group.availability_zone_names.to_a,
                :desired_capacity => autoscaling_group.desired_capacity,
                :launch_configuration => {
                  :iam_instance_profile => autoscaling_group.launch_configuration.iam_instance_profile,
                  :image => {
                    :id => autoscaling_group.launch_configuration.image.id,
                    :name => autoscaling_group.launch_configuration.image.name,
                    :state => autoscaling_group.launch_configuration.image.state,
                  },
                  :instance_type => autoscaling_group.launch_configuration.instance_type,
                  :name => autoscaling_group.launch_configuration.name,
                },
                :load_balancers => autoscaling_group.load_balancers.to_a.map { |lb|
                  {
                    :availability_zone_names => lb.availability_zone_names.to_a,
                    :dns_name => lb.dns_name,
                    :instances => lb.instances.map { |i|
                      {
                        :dns_name => i.dns_name,
                        :id => i.id,
                        :private_dns_name => i.private_dns_name,
                        :status => i.status,
                      }
                    },
                    :name => lb.name,
                  }
                },
                :max_size => autoscaling_group.max_size,
                :min_size => autoscaling_group.min_size,
                :name => autoscaling_group.name,
                :scaling_policies => autoscaling_group.scaling_policies.map { |policy|
                  {
                    :adjustment_type => policy.adjustment_type,
                    :alarms => policy.alarms.to_hash.keys,
                    :cooldown => policy.cooldown,
                    :name => policy.name,
                    :scaling_adjustment => policy.scaling_adjustment,
                  }
                },
                :scheduled_actions => autoscaling_group.scheduled_actions.map { |action|
                  {
                    :desired_capacity => action.desired_capacity,
                    :end_time => action.end_time,
                    :max_size => action.max_size,
                    :min_size => action.min_size,
                    :name => action.name,
                    :start_time => action.start_time,
                  }
                },
                :suspended_processes => autoscaling_group.suspended_processes,
              }.to_yaml)
            end
          }

          desc("Show AutoScaling history.")
          task(:history, :roles => :app, :except => { :no_release => true }) {
            abort("FIXME: Not yet implemented.")
          }

          desc("Delete old AMIs.")
          task(:cleanup, :roles => :app, :except => { :no_release => true }) {
            images = autoscaling_images.sort { |x, y| x.name <=> y.name }.reject { |image|
              autoscaling_group.launch_configuration.image_id == image.id
            }
            (images - images.last(autoscaling_keep_images-1)).each do |image|
              if autoscaling_create_image and ( image and image.exists? )
                snapshots = image.block_device_mappings.map { |device, block_device| block_device.snapshot_id }
                logger.debug("Deregistering AMI: #{image.id}")
                image.deregister()
                sleep(autoscaling_wait_interval) unless image.exists?

                snapshots.each do |id|
                  snapshot = autoscaling_ec2_client.snapshots[id]
                  if snapshot and snapshot.exists?
                    logger.debug("Deleting EBS snapshot: #{snapshot.id}")
                    begin
                      snapshot.delete()
                    rescue AWS::EC2::Errors::InvalidSnapshot::InUse => error
                      logger.info("[ERROR] " + error.inspect)
                      sleep(autoscaling_wait_interval)
                      retry
                    end
                  end
                end
              else
                logger.info("Skip deleting AMI: #{image.name} (#{image.id})")
              end

              launch_configuration_name = "#{autoscaling_launch_configuration_name_prefix}#{image.name}"
              launch_configuration = autoscaling_autoscaling_client.launch_configurations[launch_configuration_name]
              if autoscaling_create_launch_configuration and ( launch_configuration and launch_configuration.exists? )
                logger.debug("Deleting LaunchConfiguration: #{launch_configuration.name}")
                launch_configuration.delete()
              else
                logger.info("Skip deleting LaunchConfiguration: #{launch_configuration_name}")
              end
            end
          }
        }
      }
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend(Capistrano::AutoScaling)
end

# vim:set ft=ruby ts=2 sw=2 :