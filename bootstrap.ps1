# Note environment variables won't work properly. Need to set them for the process and machine/user

# Set some paths
# .netty way to do this: [Environment]::SetEnvironmentVariable("Path", $envpath, 'Machine')
# May also want to set FACTER_ variables
& setx imwops_data_drive C:
& setx imwops_tools %imwops_data_drive%\imwops\tools
& setx imwops_dev %imwops_data_drive%\imwops\dev
& setx HOME %USERPROFILE%
& setx ChocolateyInstall C:\ProgramData\chocolatey
& setx ChocolateyBinRoot %imwops_tools%

# Install chocolatey
iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

# Install ruby and bundler
# specify ruby version?
choco install ruby
# Install https://bitbucket.org/jonforums/uru ?
# SSL will be broken until we update gems
gem update --system
gem install bundler

# Where are we?
$bootstrap_dir = Split-Path $script:MyInvocation.MyCommand.Path

Set-Location $bootstrap_dir
bundle install
librarian-puppet install
$module_path=$(puppet config print modulepath 2>NUL) + ':' + $bootstrap_dir
puppet apply -e 'include imwops_bootstrap'