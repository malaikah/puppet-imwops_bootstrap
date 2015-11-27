class imwops_bootstrap::vagrant {

    package{'vagrant':
        provider    => 'chocolatey',
        ensure      => present,
    }

}