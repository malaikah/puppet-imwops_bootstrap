####################################
# ToDo: Stop farting around with elevated permissions
# just set permissions on directories.
############################################
$im_root_dir          = "${ENV:ProgramData}\Immediate"
$imwops_root_dir      = "${im_root_dir}\imwops"
$imwops_tools_dir     = "tools"
$imwops_workspace_dir = "dev"
$global_caccerts_file = "${imwops_root_dir}\${imwops_tools_dir}\cacerts.pem"
#$script_root          = Split-Path $script:MyInvocation.MyCommand.Path

# Set permissions
function Set-NTFSDACLEntry {
    Param (
        [String]$Rights = "Read",
        [Switch]$Allow = $true,
        [String]$User,
        [String]$Path
    )
    $colRights = [System.Security.AccessControl.FileSystemRights]$Rights
    $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None
    If ($Allow) {
        $objType = [System.Security.AccessControl.AccessControlType]::Allow
    } else {
        $objType = [System.Security.AccessControl.AccessControlType]::Deny
    }
    $objACE  = New-Object System.Security.AccessControl.FileSystemAccessRule `
        ($User, $colRights, $InheritanceFlag, $PropagationFlag, $objType)
    $objACL = Get-ACL $Path
    $objACL.AddAccessRule($objACE)
    Set-ACL $Path $objACL
}

# If we're storing data somewhere other than the SystemDrive, create a symlink to point there.
$drives               = GET-WMIOBJECT win32_logicaldisk | where {$_.DriveType -eq 3} | select -Property DeviceId -ExpandProperty DeviceId
if (!($im_data_drive)) {
    if ($ENV:im_data_drive) {
        $im_data_drive  = $ENV:imwops_data_drive
    } else {
        $im_data_drive = Read-Host -Prompt "Enter a drive to use to install imwops tools onto. Available drives: $drives"
    }
}

if ($drives -contains "${im_data_drive}:") {
    if (($im_data_drive -ne $env:SystemDrive) -and !(Test-Path $im_root_dir)) {
        & cmd /c "mklink /D $im_root_dir $im_data_drive"
    } elseif (!(Test-Path $im_root_dir)) {
        New-Item -Type Directory $im_root_dir
    }
} else {
    throw ("$im_data_drive is not a valid drive.")
}

# Set environment variables (once for the current environment, once for future ones)
## Common directories
[Environment]::SetEnvironmentVariable("im_root_dir", $im_root_dir)
[Environment]::SetEnvironmentVariable("FACTER_im_root_dir", $im_root_dir)
[Environment]::SetEnvironmentVariable("imwops_tools", "${imwops_root_dir}\${imwops_tools_dir}")
[Environment]::SetEnvironmentVariable("FACTER_imwops_tools", $ENV:imwops_tools)
[Environment]::SetEnvironmentVariable("imwops_workspace", "${imwops_root_dir}\${imwops_workspace_dir}")
[Environment]::SetEnvironmentVariable("FACTER_imwops_workspace", $ENV:imwops_workspace)
[Environment]::SetEnvironmentVariable("im_root_dir", $im_root_dir, "Machine")
[Environment]::SetEnvironmentVariable("im_root_dir", $FACTER_im_root_dir, "Machine")
[Environment]::SetEnvironmentVariable("imwops_tools", $ENV:imwops_tools, "Machine")
[Environment]::SetEnvironmentVariable("FACTER_imwops_tools", $ENV:FACTER_imwops_tools, "Machine")
[Environment]::SetEnvironmentVariable("imwops_workspace", $ENV:imwops_workspace, "Machine")
[Environment]::SetEnvironmentVariable("FACTER_imwops_workspace", $ENV:FACTER_imwops_workspace, "Machine")
## Override HOME environemnt variable set from AD/GPOs
[Environment]::SetEnvironmentVariable("HOME", $Env:USERPROFILE)
[Environment]::SetEnvironmentVariable("HOME", $Env:USERPROFILE, 'User')
## pre-set some chocolatey variables
[Environment]::SetEnvironmentVariable("ChocolateyInstall", "${ENV:ProgramData}\chocolatey")
[Environment]::SetEnvironmentVariable("ChocolateyBinRoot", '%imwops_tools%')
[Environment]::SetEnvironmentVariable("ChocolateyInstall", $ENV:ChocolateyInstall, 'Machine')
[Environment]::SetEnvironmentVariable("ChocolateyBinRoot", $ENV:ChocolateyBinRoot, 'Machine')
## Define Puppet version
[Environment]::SetEnvironmentVariable("PUPPET_VERSION", $puppet_version)

# create directories and allow .\Users to Modify
$dirs = @($imwops_root_dir, $Env:imwops_workspace,$ENV:imwops_tools)
ForEach ($dir in $dirs) {
    if (!(Test-Path $dir)) {
        New-Item -Type Directory -Path $dir
    }
    Set-NTFSDACLEntry -Path $dir -Rights Modify -User "BUILTIN\Users"
}

# Install chocolatey
try {
    if (Get-Command choco) {}
} catch {
    # If get-command choco returns an error, we need to install cohocolatey
    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    [Environment]::SetEnvironmentVariable("Path", $($([Environment]::GetEnvironmentVariable('Path','User')) + $([Environment]::GetEnvironmentVariable('Path','Machine'))))
}

# Install ruby and bundler
# Install https://bitbucket.org/jonforums/uru ?
# specify ruby version?
choco install -y ruby
[Environment]::SetEnvironmentVariable("Path", $($([Environment]::GetEnvironmentVariable('Path','User')) + $([Environment]::GetEnvironmentVariable('Path','Machine'))))
# SSL is broken on Windows unless we specify trusted root certs.
Copy-Item "${script_root}\dist\imwops_bootstrap\files\ssl\trusted_root_cacerts.pem" $global_caccerts_file
[Environment]::SetEnvironmentVariable("SSL_CERT_FILE", $global_caccerts_file)
[Environment]::SetEnvironmentVariable("SSL_CERT_FILE", $global_caccerts_file, 'Machine')
# update rubygems
gem update --system
gem install bundler -v $bundler_version

# ToDo: Set up putty and git to allow ssh auhtnetication to puppet git sources
#SOmethinglike:
#choco install putty
#Install switches?
#Do something to get putty onto path?
#Do we already have a private key? 
# If not, run puttygen and tell the user what to do with it
#Where's our private key?
#& pageant $ssh_private_key_path
#Configure this command to start on login
#choco install git -params '*/GitAndUnixToolsOnPath /NoAutoCrlf"
#[Environment]::SetEnvironmentVariable("GIT_SSH", 'plink.exe')
#[Environment]::SetEnvironmentVariable("GIT_SSH", 'plink.exe', 'Machine')


# Now we should be able to bootstrap puppet into existence, pull down any required modules an get up and running
#Set-Location $script_root
#bundle install
#$module_path = "modules:dist"
#r10k puppetfile install
#puppet apply --modulepath $module_path dist\imwops_bootstrap\manifests\init.pp
