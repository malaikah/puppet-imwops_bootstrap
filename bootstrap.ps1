############################################
# Bootstrap script to get a windows box to a state
# from which can we use puppet to perform further configuration
############################################
$im_root_dir          = "${ENV:ProgramData}\Immediate"
$imwops_root_dir      = "${im_root_dir}\imwops"
$imwops_tools_dir     = "tools"
$imwops_workspace_dir = "dev"
$global_caccerts_file = "${imwops_root_dir}\${imwops_tools_dir}\cacerts.pem"
$script_root          = Split-Path $script:MyInvocation.MyCommand.Path
$bundler_version      = "1.10.6"

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

Function Get-FileName($initialDirectory)
{   
 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
 Out-Null

 $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $OpenFileDialog.initialDirectory = $initialDirectory
 $OpenFileDialog.filter = "All files (*.*)| *.*"
 $OpenFileDialog.ShowDialog() | Out-Null
 $OpenFileDialog.filename
} #end function Get-FileName


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
    Write-Host "Setting-up $dir"
    if (!(Test-Path $dir)) {
        New-Item -Type Directory -Path $dir
    }
    Set-NTFSDACLEntry -Path $dir -Rights Modify -User "BUILTIN\Users"
}

# Install chocolatey
Write-Host "configuring Chocolatey"
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
#ToDO: Can we replace this with a bit of powershell that exports root certs from the local machine?
Copy-Item "${script_root}\dist\imwops_bootstrap\files\ssl\trusted_root_cacerts.pem" $global_caccerts_file
[Environment]::SetEnvironmentVariable("SSL_CERT_FILE", $global_caccerts_file)
[Environment]::SetEnvironmentVariable("SSL_CERT_FILE", $global_caccerts_file, 'Machine')
# update rubygems
gem update --system
gem install bundler -v $bundler_version

# Set up putty and git to allow ssh auhtnetication to puppet git sources
choco install putty
choco install git -params '"/GitAndUnixToolsOnPath /NoAutoCrlf"'
[Environment]::SetEnvironmentVariable("GIT_SSH", 'plink.exe')
[Environment]::SetEnvironmentVariable("GIT_SSH", 'plink.exe', 'Machine')

# Create/load ssh private key to suthenticate to private Git repos
#Do we already have a private key? 
Write-Host "Looking for ssh key for communication with GitHub"
if ($ENV:GIT_SSH_PRIVATE_KEY) {
    $ssh_private_key = $ENV:GIT_SSH_PRIVATE_KEY
} else {
    $title = "ssh key"
    $message = "Do you already have an ssh key you can use to authenticate to private GitHub repositories?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "I have a private key I wish to load."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "I need to generate a new key."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 
    if ($result -eq 1) {
        Write-Host "Launching puttygen to create an ssh key for authentication to private repos."
        Write-Host "Generate a fresh ssh private key and save it to a sensible location on disk."
        & puttygen
    }
    Write-Host "Select your private key file."
    $ssh_private_key = Get-FileName -InitialDirectory $PWD
}
Write-Host "Loading ssh private key from ${ssh_private_key}."
#ToDo: Could configure this command to start on login
& pageant $ssh_private_key
[Environment]::SetEnvironmentVariable("GIT_SSH_PRIVATE_KEY", $ssh_private_key, 'User')

# Now we should be able to bootstrap puppet into existence, pull down any required modules an get up and running
Set-Location $script_root
bundle install
$module_path = "modules;dist"
# Blooming librarian-puppet is still being awkward.
#librarian-puppet install
r10k puppetfile install
puppet apply --modulepath $module_path -e "include: imwops_bootstrap"
