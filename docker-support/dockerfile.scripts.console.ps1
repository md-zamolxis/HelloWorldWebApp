"Running dockerfile.scripts.console.ps1..."

$xml = [xml](Get-Content "RichMix.Platform.ServiceBusIntegration.exe.config")
$runtimeEnvironment= ($xml.configuration.appSettings.add |  Where-Object {$_.key -eq "RuntimeEnvironment"}).value

if($runtimeEnvironment -eq 'DOCKER')
{
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
}"Encrypting configuration"

Rename-Item -Path "c:\app\RichMix.Platform.ServiceBusIntegration.exe.config" -NewName "c:\app\web.config"

C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe -pef "appSettings" "c:\app" -prov "DataProtectionConfigurationProvider"
C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe -pef "connectionStrings" "c:\app" -prov "DataProtectionConfigurationProvider"

Rename-Item -Path "c:\app\web.config" -NewName "c:\app\RichMix.Platform.ServiceBusIntegration.exe.config"

"Done"
"Cleaning up..."
Remove-item 'dockerfile.scripts.console.ps1'
"Done."