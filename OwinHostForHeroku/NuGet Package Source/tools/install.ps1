param($installPath, $toolsPath, $package, $project)
$solutionDir = [System.IO.Path]::Combine($installPath, "..\..\")
$solutionDir = [System.IO.Path]::GetFullPath($solutionDir)

# Install "Procfile".
$sourceProcfilePath = Join-Path $toolsPath "Procfile"
$destinationProcfilePath = Join-Path $solutionDir "Procfile"
if ((Test-Path -PathType Leaf $destinationProcfilePath) -eq $false) {
	copy $sourceProcfilePath $destinationProcfilePath

	$solution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
	$solutionFolder = $solution.Projects | where { $_.Name -eq "Solution Items"}
	if ($solutionFolder -eq $null) {
		$solutionFolder = $solution.AddSolutionFolder("Solution Items")
	}
	$projItemProcfile = $solutionFolder.ProjectItems | where { $_.Name -eq "Procfile" }
	if ($projItemProcfile -eq $null) {
		$solutionItems = Get-Interface $solutionFolder.ProjectItems ([EnvDTE.ProjectItems])
		$solutionItems.AddFromFile($destinationProcfilePath)
	}
}

# Add "OwinHostForHeroku.exe" as linked project item.
$owinHostName = "OwinHostForHeroku"
$owinHostFile = "$owinHostName.exe"
$markerFile = "README-$owinHostName.txt"
$owinHostPath = Join-Path $toolsPath $owinHostFile
$projectUri = [uri]$project.FullName
$owinHostUri = [uri]$owinHostPath
$owinHostRelativePath = $projectUri.MakeRelative($owinHostUri) -replace "/","\"

#   delete marker file.
$project.ProjectItems.Item($markerFile).Delete()

#   Add content item as a link that is Owin host binary saved at higher folder.
#   (This is normal case.)
if ($owinHostRelativePath -like "..\*") {
	$project.ProjectItems.AddFromFile($owinHostPath)
	$project.ProjectItems.Item($owinHostFile).Properties.Item("CopyToOutputDirectory").Value = 2
	$project.Save()
}

#   Add content item as a link that is Owin host binary saved at lower folder.
#   (This is the case that .csproj file and packages folder are in a same folder.)
if ($owinHostRelativePath -notlike "..\*") {
	# Treat the project file as a MSBuild script xml instead of DTEnv object model.
	Add-Type -AssemblyName 'Microsoft.Build, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'
	$projectXml = ([Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.GetLoadedProjects($project.FullName) | select -First 1).Xml

	$itemGrp = $projectXml.CreateItemGroupElement()
	$projectXml.AppendChild($itemGrp)
	$item = $itemGrp.AddItem("Content", $owinHostRelativePath)
	$item.AddMetadata("Link", $owinHostFile)
	$item.AddMetadata("CopyToOutputDirectory", "PreserveNewest")
	$project.Save()
}

# Install custom Web server provider.
$serverProvider = $dte.GetObject("CustomWebServerProvider")
if ($serverProvider -eq $null)
{
    return; # Only supported on VS 2013
}
$servers = $serverProvider.GetCustomServers($project.Name)
if ($servers -eq $null)
{
    return; # Not a WAP project
}
$relativeToolsDir = $toolsPath.SubString($solutionDir.Length)
$exeDir = '{solutiondir}\' + $relativeToolsDir + '\OwinHostForHeroku.exe'
$server = $servers.GetWebServer('OwinHost for Heroku')
if ($server -ne $null)
{
    $servers.UpdateWebServer('OwinHost for Heroku', $exeDir, $server.CommandLine, $server.Url, $server.WorkingDirectory)
}
else
{
    try
    {
       $servers.AddWebServer('OwinHost for Heroku', $exeDir, '{url}', 'http://localhost:12345/', '{projectdir}')
    }
    catch [System.OperationCanceledException]
    {
        # The user hit No when prompted about locking the VS version.
    }
}