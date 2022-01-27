$config = Read-Host -Prompt "Enter Configuration";
$repository = Read-Host -Prompt "Repository";
$build = Read-Host -Prompt "Build (Yes/No)";
$deploy = Read-Host -Prompt "Deploy (Yes/No)";
$appVersion = Read-Host -Prompt "Version (e.g. v1)";

# Example AWS Repository: 329589958096.dkr.ecr.eu-west-1.amazonaws.com
# Example Azure Repository: kcemeaacrrichmixdev02.azurecr.io

if ($build -eq "Yes")
{
    "Building Begin"

    # msbuild
    $publishProfile = $config + ".pubxml";

    "msbuild Begin"

    msbuild -verbosity:quiet KantarRetail.RichMix8.WebSite/KantarRetail.RichMix8.WebSite.csproj /p:DeployOnBuild=true /p:PublishProfile=$publishProfile
    msbuild -verbosity:quiet KantarRetail.RichMix8.WebApiCors2/KantarRetail.RichMix8.WebApiCors2.csproj /p:DeployOnBuild=true /p:PublishProfile=$publishProfile
    msbuild -verbosity:quiet KantarRetail.RichMix8.CachingService/KantarRetail.RichMix8.CachingService.csproj /p:DeployOnBuild=true /p:PublishProfile=$publishProfile
    msbuild -verbosity:quiet KantarRetail.RichMix8.Hangfire.WebProcessor/KantarRetail.RichMix8.Hangfire.WebProcessor.csproj /p:DeployOnBuild=true /p:PublishProfile=$publishProfile
    msbuild -verbosity:quiet RichMix.Platform.ServiceBusIntegration/RichMix.Platform.ServiceBusIntegration.csproj /p:Configuration=$config
    "msbuild Completed"

    # Docker Build
    "Docker build begin"

    docker build  --no-cache -f ".\Publish\Website\Dockerfile" ".\Publish\Website" -t richmix8website
    docker build  --no-cache -f ".\Publish\WebApiCors2\Dockerfile" ".\Publish\WebApiCors2" -t richmix8api
    docker build  --no-cache -f ".\Publish\Cache\Dockerfile" ".\Publish\Cache" -t richmix8cache
    docker build  --no-cache -f ".\Publish\Hangfire\Dockerfile" ".\Publish\Hangfire" -t richmix8hangfire
    docker build  --no-cache -f ".\Publish\ServiceBusIntegration\Dockerfile" ".\Publish\ServiceBusIntegration" -t richmix8servicebusintegration

    "Docker build Completed"

    "Building End"
}

# Publishing
if ($deploy -eq "Yes") 
{
    "Publishing Begin"

	$repoPushWebsite = $repository + "/richmix8website:" + $appVersion;
	$repoPushAPI= $repository + "/richmix8api:" + $appVersion;
	$repoPushCache = $repository + "/richmix8cache:" + $appVersion;
	$repoPushHangfire = $repository + "/richmix8hangfire:" + $appVersion;
	$repoPushServiceBus = $repository + "/richmix8servicebusintegration:" + $appVersion;

	# Tag
	docker tag richmix8website:latest $repoPushWebsite
	docker tag richmix8api:latest $repoPushAPI
	docker tag richmix8cache:latest $repoPushCache
	docker tag richmix8hangfire:latest $repoPushHangfire
	docker tag richmix8servicebusintegration:latest $repoPushServiceBus

	# Publish
	docker push $repoPushWebsite
	docker push $repoPushAPI
	docker push $repoPushCache
	docker push $repoPushHangfire
	docker push $repoPushServiceBus

    "Publishing Completed"
}