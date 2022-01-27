"Running dockerfile.scripts.web.ps1..."

$xml = [xml](Get-Content "web.config")
$runtimeEnvironment= ($xml.configuration.appSettings.add |  Where-Object {$_.key -eq "RuntimeEnvironment"}).value

if($runtimeEnvironment -eq 'DOCKER')
{
    "Installing Development SSL Certificate..."
    $certPath="Development Certificate.pfx";
    $base64Cert= ($xml.configuration.appSettings.add |  Where-Object {$_.key -eq "DevelopmentCertificate"}).value;
    $byteArray = [System.Convert]::FromBase64String($base64Cert);
    [System.IO.File]::WriteAllBytes($certPath, $byteArray)

    $certPassword= ($xml.configuration.appSettings.add |  Where-Object {$_.key -eq "DevelopmentCertificatePassword"}).value;
    $securePfxPass = ConvertTo-SecureString  $certPassword -AsPlainText -Force
  
    Import-PfxCertificate -Password $securePfxPass -CertStoreLocation Cert:\LocalMachine\My -FilePath $certPath
    $pfxThumbprint = (Get-PfxData -FilePath $certPath -Password $securePfxPass).EndEntityCertificates.Thumbprint
    $binding = New-WebBinding -Name "Default Web Site" -Protocol https -IPAddress * -Port 443;
    $binding = Get-WebBinding -Name "Default Web Site" -Protocol https;
    $binding.AddSslCertificate($pfxThumbprint, "my");

    Remove-item  $certPath
    "Done Installing SSL Certificate."
    
    "Updating hosts file..."
    $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
    
    try {
        $DnsEntries = @("host.docker.internal", "gateway.docker.internal")
        # Tries resolving names for Docker
        foreach ($Entry in $DnsEntries) {
            # If any of the names are not resolved, throws an exception
            Resolve-DnsName -Name $Entry -ErrorAction Stop
        }

        # If it passes, means that DNS is already configured
        Write-Host("DNS settings are already configured.")
      } catch {
        # Gets the gateway IP address, that is the Host's IP address in the Docker network
        $ip = (ipconfig | where-object {$_ -match "Default Gateway"} | foreach-object{$_.Split(":")[1]}).Trim()
        # Read the current content from Hosts file
        $src = [System.IO.File]::ReadAllLines($hostsFile)
        # Add the a new line after the content
        $lines = $src += ""

        # Check the hosts file and write it in if its not there...
        if((cat $hostsFile | Select-String -Pattern "host.docker.internal") -And (cat $hostsFile | Select-String -Pattern "gateway.docker.internal")) {
            For ($i=0; $i -le $lines.length; $i++) {
                if ($lines[$i].Contains("host.docker.internal"))
                {
                    $lines[$i] = ("{0} host.docker.internal" -f $ip)
                    $lines[$i+1] = ("{0} gateway.docker.internal" -f $ip)
                    break
                }
            }
        } else {
            $lines = $lines += "# Added by Docker for Windows"
            $lines = $lines += ("{0} host.docker.internal" -f $ip)
            $lines = $lines += ("{0} gateway.docker.internal" -f $ip)
            $lines = $lines += "# End of section"
        }
        # Writes the new content to the Hosts file
        [System.IO.File]::WriteAllLines($hostsFile, [string[]]$lines)
    
        Write-Host("New DNS settings written successfully.")
     }
      "Done Updating hosts file..."
}

"Granting rights over user directories..."
$userDataDirectory = ($xml.configuration.appSettings.add |  Where-Object {$_.key -eq "UserDataDirectory"}).value
if($userDataDirectory)
{
    $userDataDirectory = $userDataDirectory -replace "~", "c:\inetpub\wwwroot" ;
    icacls $userDataDirectory /grant 'IIS_IUSRS:(F)' /t
}

"Grant rights over logs directory"
md "c:\inetpub\wwwroot\logs"
icacls "c:\inetpub\wwwroot\logs" /grant 'IIS_IUSRS:(F)' /t

if (Test-Path -Path "c:\inetpub\wwwroot\UploadedFiles")
{
    icacls "c:\inetpub\wwwroot\UploadedFiles" /grant 'IIS_IUSRS:(F)' /t
}
"Done."

"Encrypting configuration"

if (Test-Path -Path "c:\inetpub\wwwroot\bin\KantarRetail.RichMix8.Core.dll")
{
    Copy-Item -Path "c:\inetpub\wwwroot\bin\KantarRetail.RichMix8.Core.dll" -Destination "C:\Windows\Microsoft.NET\Framework\v4.0.30319\KantarRetail.RichMix8.Core.dll"
    C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe -pef "richMix" "c:\inetpub\wwwroot" -prov "DataProtectionConfigurationProvider"
}

C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe -pef "appSettings" "c:\inetpub\wwwroot" -prov "DataProtectionConfigurationProvider"         
C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe -pef "connectionStrings" "c:\inetpub\wwwroot" -prov "DataProtectionConfigurationProvider"                                                             

"Done"

"Cleaning up..."
Remove-item dockerfile.scripts.web.ps1
"Done."

