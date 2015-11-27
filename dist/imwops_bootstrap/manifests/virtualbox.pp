class imwops_bootstrap::virtualbox {

    package {'virtualbox':
        provider    => chocolatey,
        ensure      => present,
    } ~> windows_env {'PATH':
        ensure      => present,
        value       => 'C:\Program Files\Oracle\VirtualBox',
    }
    
    exec {'vbox_machinefolder':
        path            => $path,
        command         => "VBoxManage setproperty machinefolder ${FACTER_imwops_workspace}\\vbox_vms",
        subscribe       => Package['virtualbox'],
        refreshonly     => true,
    }

}