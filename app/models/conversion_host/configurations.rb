module ConversionHost::Configurations
  extend ActiveSupport::Concern
  module ClassMethods
    def notify_configuration_result(op, success, resource_info)
      Notification.create(
        :type    => success ? :conversion_host_config_success : :conversion_host_config_failure,
        :options => {
          :op_name => op,
          :op_arg  => resource_info,
        }
      )
    end

    def queue_configuration(op, instance_id, resource, params, auth_user = nil)
      task_opts = {
        :action => "Configuring a conversion_host: operation=#{op} resource=(name: #{resource.name} type: #{resource.class.name} id: #{resource.id})",
        :userid => auth_user
      }

      queue_opts = {
        :class_name  => name,
        :method_name => op,
        :instance_id => instance_id,
        :role        => 'ems_operations',
        :zone        => resource.ext_management_system.my_zone,
        :args        => [params, auth_user]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end

    def enable_queue(params, auth_user = nil)
      params = params.symbolize_keys
      resource = params.delete(:resource)

      params[:resource_id] = resource.id
      params[:resource_type] = resource.class.name

      queue_configuration('enable', nil, resource, params, auth_user)
    end

    def enable(params, auth_user = nil)
      params = params.symbolize_keys
      _log.info("Enabling a conversion_host with parameters: #{params}")

      params.delete(:task_id)     # In case this is being called through *_queue which will stick in a :task_id
      params.delete(:miq_task_id) # The miq_queue.activate_miq_task will stick in a :miq_task_id

      vmware_vddk_package_url = params.delete(:vmware_vddk_package_url)
      params[:vddk_transport_supported] = !vmware_vddk_package_url.nil?
      vmware_ssh_private_key = params.delete(:vmware_ssh_private_key)
      params[:ssh_transport_supported] = !vmware_ssh_private_key.nil?

      ssh_key = params.delete(:conversion_host_ssh_private_key)

      new(params).tap do |conversion_host|
        conversion_host.enable_conversion_host_role(vmware_vddk_package_url, vmware_ssh_private_key)

        if ssh_key
          conversion_host.authentications << AuthPrivateKey.create!(
            :name     => conversion_host.name,
            :auth_key => ssh_key,
            :userid   => auth_user,
            :authtype => 'v2v'
          )
        end

        conversion_host.save!
      end
    rescue StandardError => error
      raise
    ensure
      resource_info = "type=#{params[:resource_type]} id=#{params[:resource_id]}"
      notify_configuration_result('enable', error.nil?, resource_info)
    end
  end

  def disable_queue(auth_user = nil)
    self.class.queue_configuration('disable', id, resource, {}, auth_user)
  end

  def disable
    resource_info = "type=#{resource.class.name} id=#{resource.id}"
    _log.info("Disabling a conversion_host #{resource_info}")

    disable_conversion_host_role
    destroy!
  rescue StandardError => error
    raise
  ensure
    self.class.notify_configuration_result('disable', error.nil?, resource_info)
  end
end
