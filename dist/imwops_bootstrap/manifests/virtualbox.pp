class imwops_bootstrap::virtualbox {

    package {'virtualbox':
        provider    => chocolatey,
        ensure      => present,
    }

}