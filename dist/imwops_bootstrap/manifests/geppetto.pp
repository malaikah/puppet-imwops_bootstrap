class imwops_bootstrap::geppetto {

    package{'geppetto':
        ensure      => present,
        provider    => chocolatey,
    }

}