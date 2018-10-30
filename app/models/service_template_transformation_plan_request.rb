class ServiceTemplateTransformationPlanRequest < ServiceTemplateProvisionRequest
  TASK_DESCRIPTION = 'VM Transformations'.freeze

  delegate :transformation_mapping, :vm_resources, :to => :source

  def requested_task_idx
    vm_resources.where(:status => ServiceResource::STATUS_APPROVED)
  end

  def customize_request_task_attributes(req_task_attrs, vm_resource)
    req_task_attrs[:source] = vm_resource.resource
  end

  def source_vms
    vm_resources.where(:status => [ServiceResource::STATUS_QUEUED, ServiceResource::STATUS_FAILED]).pluck(:resource_id)
  end

  def validate_conversion_hosts
    transformation_mapping.transformation_mapping_items.select { |item| %w(EmsCluster CloudTenant).include?(item.source_type) }.each do |item|
      return false if item.destination.ext_management_system.conversion_hosts.empty?
    end
    true
  end

  def validate_vm(_vm_id)
    # TODO: enhance the logic to determine whether this VM can be included in this request
    true
  end

  def approve_vm(vm_id)
    vm_resources.find_by(:resource_id => vm_id).update_attributes!(:status => ServiceResource::STATUS_APPROVED)
  end

  def cancel
    update_attributes(:cancelation_status => MiqRequest::CANCEL_STATUS_REQUESTED)
    miq_request_tasks.each(&:cancel)
  end

  def update_request_status
    super
    if request_state == 'finished' && status == 'Ok'
      Notification.create(:type => "transformation_plan_request_succeeded", :options => {:plan_name => description})
    elsif request_state == 'finished' && status != 'Ok'
      Notification.create(:type => "transformation_plan_request_failed", :options => {:plan_name => description}, :subject => self)
    end
  end
end
