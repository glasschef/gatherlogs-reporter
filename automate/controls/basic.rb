title 'Basic checks for the automate configuration'

include_controls 'common'

automate = installed_packages('automate')

control "gatherlogs.automate.package" do
  title "check that automate is installed"
  desc "
  Automate was not found or is running an older version, please upgraded
  to a newer version of Automate: https://downloads.chef.io/automate
  "

  impact 1.0

  describe automate do
    it { should exist }
    its('version') { should cmp >= '1.8.38'}
  end
end


services = service_status(:automate)

services.each do |service|
  control "gatherlogs.automate.service_status.#{service.name}" do
    title "check that #{service.name} service is running"
    desc "
    #{service.name} service is not running or has a short runtime, check the logs
    and make sure the service is not flapping.
    "

    describe service do
      its('status') { should eq 'run' }
      its('runtime') { should cmp >= 60 }
    end
  end
end

df = disk_usage()

%w(/ /var /var/opt /var/opt/delivery /var/log).each do |mount|
  control "gatherlogs.automate.critical_disk_usage.#{mount}" do
    title "check that the automate has plenty of free space"
    desc "
      There are several key directories that we need to make sure have enough
      free space for automate to operate succesfully
    "

    only_if { df.exists?(mount) }

    describe df.mount(mount) do
      its('used_percent') { should cmp < 100 }
      its('available') { should cmp > 1 }
    end
  end
end


control "gatherlogs.common.sysctl-settings" do
  title "check that the sysctl settings make sense"
  desc "
    Recommended sysctl settings are not correct, recommend that these get updated
    to ensure the best performance possible for Automate.
  "
  only_if { sysctl_a.exists? }
  describe sysctl_a do
    its('vm_swappiness') { should cmp >= 1 }
    its('vm_swappiness') { should cmp <= 20 }
    its('fs_file-max') { should cmp >= 64000 }
    its('vm_max_map_count') { should cmp >= 256000 }
    its('vm_dirty_ratio') { should cmp >= 5 }
    its('vm_dirty_ratio') { should cmp <= 30 }
    its('vm_dirty_background_ratio') { should cmp >= 10 }
    its('vm_dirty_background_ratio') { should cmp <= 60 }
    its('vm_dirty_expire_centisecs') { should cmp >= 10000 }
    its('vm_dirty_expire_centisecs') { should cmp >= 30000 }
  end
end