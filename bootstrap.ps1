$ruby_version         = "2.1.6"
$imwops_data_drive    = "E:"
$imwops_root_dir      = "${ENV:ProgramData}\Immediate"
$imwops_tools_dir     = "tools"
$imwops_workspace_dir = "dev"

# If we're storing data somewhere other than the SystemDrive, create a symlink to point there.
$drives               = GET-WMIOBJECT win32_logicaldisk | where {$_.DriveType -eq 3} | select -Property DeviceId
if ($imwops_data_drive -in $drives) {
    if ($imwops_data_drive -ne $env:SystemDrive) {
        & mklink /D $imwops_root_dir $imwops_data_drive
    }
} else {
    throw ("$imwops_data_drive is not a valid drive.")
}

# Set environment variables (once for the current environment, once for future ones)
## Common directories
[Environment]::SetEnvironmentVariable("imwops_tools", "${imwops_root_dir}\${imwops_tools_dir}")
[Environment]::SetEnvironmentVariable("imwops_tools", $ENV:imwops_tools, 'Machine')
[Environment]::SetEnvironmentVariable("FACTER_imwops_tools", $ENV:imwops_tools)
[Environment]::SetEnvironmentVariable("FACTER_imwops_tools", $ENV:imwops_tools, 'Machine')
[Environment]::SetEnvironmentVariable("imwops_workspace", "${imwops_root_dir}\${imwops_workspace_dir}")
[Environment]::SetEnvironmentVariable("imwops_workspace", $ENV:imwops_workspace, 'Machine')
[Environment]::SetEnvironmentVariable("FACTER_imwops_workspace", $ENV:imwops_workspace)
[Environment]::SetEnvironmentVariable("FACTER_imwops_workspace", $ENV:imwops_workspace, 'Machine')
## Override HOME environemnt variable set from AD/GPOs
[Environment]::SetEnvironmentVariable("HOME", '%USERPROFILE%')
[Environment]::SetEnvironmentVariable("HOME", '%USERPROFILE%', 'User')
## pre-set some chocolatey variables
[Environment]::SetEnvironmentVariable("ChocolateyInstall", "${ENV:ProgramData}\chocolatey")
[Environment]::SetEnvironmentVariable("ChocolateyInstall", "${ENV:ProgramData}\chocolatey", 'Machine')
[Environment]::SetEnvironmentVariable("ChocolateyBinRoot", $ENV:imwops_tools)
[Environment]::SetEnvironmentVariable("ChocolateyBinRoot", $ENV:imwops_tools, 'Machine')

# Install chocolatey
iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
[Environment]::SetEnvironmentVariable("Path", $($([Environment]::GetEnvironmentVariable('Path','User')) + $([Environment]::GetEnvironmentVariable('Path','Machine'))))

# Install ruby and bundler
# Install https://bitbucket.org/jonforums/uru ?
# specify ruby version?
choco install ruby
[Environment]::SetEnvironmentVariable("Path", $($([Environment]::GetEnvironmentVariable('Path','User')) + $([Environment]::GetEnvironmentVariable('Path','Machine'))))
# SSL will be broken until we update gems
gem update --system
gem install bundler

# Now we should be able to bootstrap puppet into existence, pull down any required modules an get up and running
Set-Location $(Split-Path $script:MyInvocation.MyCommand.Path)
bundle install
librarian-puppet install
$module_path=$(puppet config print modulepath 2>NUL) + ':' + $bootstrap_dir
puppet apply -e 'include imwops_bootstrap'
