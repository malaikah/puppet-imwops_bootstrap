<#
.SYNOPSIS
    Script to bootstrap a windows puppet development environment
.DESCRIPTION
    This script configures some base directory structure, installs chocolatey package management software, ruby and puppet.
    This allows us to call puppet to configure other aspects of the system.
.PARAMETER imwops_root_dir
    This script and the puppet module it call will install a number of tools and configure data directories.
    This parameter defines where on the file system these will appear to be located.
    Defaults to C:\ProgramData\Immediate
.PARAMETER imwops_data_drive
    It is often convenient to have the files created under $imwops_root_dir to be located somewhere other than the system disk.
    Setting this parameter to a drive letter other than C: makes this happen.
.PARAMETER ruby_version
    The version of ruby to install.
.EXAMPLE
    iex ((new-object net.webclient).DownloadString('https://raw.github.immediate.co.uk/BenPriestman/puppet-imwops_bootstrap/master/bootstrap.ps1'))
.NOTES
    Author: Ben Priestman
    Created: 25th Septemeber 2015
#>

[CmdletBinding(SupportsShouldProcess=$true,confirmimpact = "High")]
Param(
    [String]
    $imwops_root_dir      = "${ENV:ProgramData}\Immediate",
    [String]
    $imwops_data_drive,
    [String]
    $ruby_version         = "2.1.6",
    [String]
    $puppet_version       = "3.7.2"
)

$imwops_tools_dir     = "imwops\tools"
$imwops_workspace_dir = "imwops\dev"
$global_caccerts_file = "${imwops_root_dir}\${imwops_tools_dir}\cacerts.pem"
$script_root          = Split-Path $script:MyInvocation.MyCommand.Path

# If we're storing data somewhere other than the SystemDrive, create a symlink to point there.
$drives               = GET-WMIOBJECT win32_logicaldisk | where {$_.DriveType -eq 3} | select -Property DeviceId -ExpandProperty DeviceId
if (!($imwops_data_drive)) {
    $imwops_data_drive = Read-Host -Prompt "Enter a drive to use to install imwops tools onto. Available drives: $drives"
}
if ($drives -contains $imwops_data_drive) {
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
[Environment]::SetEnvironmentVariable("HOME", $Env:USERPROFILE)
[Environment]::SetEnvironmentVariable("HOME", $Env:USERPROFILE, 'User')
## pre-set some chocolatey variables
[Environment]::SetEnvironmentVariable("ChocolateyInstall", "${ENV:ProgramData}\chocolatey")
[Environment]::SetEnvironmentVariable("ChocolateyInstall", "${ENV:ProgramData}\chocolatey", 'Machine')
[Environment]::SetEnvironmentVariable("ChocolateyBinRoot", $ENV:imwops_tools)
[Environment]::SetEnvironmentVariable("ChocolateyBinRoot", $ENV:imwops_tools, 'Machine')
## Define Puppet version
[Environment]::SetEnvironmentVariable("PUPPET_VERSION", $puppet_version)

# Install chocolatey
iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
[Environment]::SetEnvironmentVariable("Path", $($([Environment]::GetEnvironmentVariable('Path','User')) + $([Environment]::GetEnvironmentVariable('Path','Machine'))))

# Install ruby and bundler
# Install https://bitbucket.org/jonforums/uru ?
# specify ruby version?
choco install -y ruby ruby2.devkit
[Environment]::SetEnvironmentVariable("Path", $($([Environment]::GetEnvironmentVariable('Path','User')) + $([Environment]::GetEnvironmentVariable('Path','Machine'))))
# SSL is broken on Windows unless we specify trusted root certs.
Copy-Item "${script_root}\files\ssl\trusted_root_cacerts.pem" $global_caccerts_file
[Environment]::SetEnvironmentVariable("SSL_CERT_FILE", $global_caccerts_file)
[Environment]::SetEnvironmentVariable("SSL_CERT_FILE", $global_caccerts_file, 'Machine')
# update rubygems
gem update --system
gem install bundler

# Now we should be able to bootstrap puppet into existence, pull down any required modules an get up and running
Set-Location $script_root
bundle install
librarian-puppet install
$module_path=$(puppet config print modulepath 2>NUL) + ':' + $bootstrap_dir
puppet apply -e 'include imwops_bootstrap'
