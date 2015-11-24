param($installPath, $toolsPath, $package, $project)
$solutionDir = [System.IO.Path]::Combine($installPath, "..\..\")
$solutionDir = [System.IO.Path]::GetFullPath($solutionDir)

# Uninstall "Procfile".
$sourceProcfilePath = Join-Path $toolsPath "Procfile"
$destinationProcfilePath = Join-Path $solutionDir "Procfile"
if ((Test-Path -PathType Leaf $destinationProcfilePath) -eq $true) {
	$sourceProcfileContent = cat $sourceProcfilePath
	$destinationProcfileContent = cat $destinationProcfilePath
	if ($sourceProcfileContent -ceq $destinationProcfileContent) {

		$solution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
		$solutionFolder = $solution.Projects | where { $_.Name -eq "Solution Items"}
		if ($solutionFolder -ne $null) {
			$projItemProcfile = $solutionFolder.ProjectItems | where { $_.Name -eq "Procfile" }
			if ($projItemProcfile -ne $null) {
				$projItemProcfile.Delete()
				del $destinationProcfilePath
			}
			if ($solutionFolder.ProjectItems.Count -eq 0) {
				$dte.Solution.Remove($solutionFolder)
			}
		}
	}
}

# Remove "OwinHostForHeroku.exe" from project item.
$owinHostName = "OwinHostForHeroku"
$owinHostFile = "$owinHostName.exe"
$owinHostPath = Join-Path $toolsPath $owinHostFile
$projectUri = [uri]$project.FullName
$owinHostUri = [uri]$owinHostPath
$owinHostRelativePath = $projectUri.MakeRelative($owinHostUri) -replace "/","\"

#   Delete content item that is Owin host binary saved at higher folder.
#   (This is normal case.)
if ($owinHostRelativePath -like "..\*") {
	$project.ProjectItems.Item($owinHostFile).Delete()
	$project.Save()
}

#   Delete content item that is Owin host binary saved at lower folder.
#   (This is the case that .csproj file and packages folder are in a same folder.)
if ($owinHostRelativePath -notlike "..\*") {

	# Treat the project file as a MSBuild script xml instead of DTEnv object model.
	Add-Type -AssemblyName 'Microsoft.Build, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'
	$projectXml = ([Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.GetLoadedProjects($project.FullName) | select -First 1).Xml

	$projectXml.Children | `
	where { $_ -is [Microsoft.Build.Construction.ProjectItemGroupElement] } | `
	foreach { $_.Children } | `
	where { ($_.Children | where {$_.Name -eq "Link" -and $_.Value -eq $owinHostFile}) -ne $null } | `
	foreach {
		$itemGrp = $_.Parent
		$itemGrp.RemoveChild($_)
		if ($itemGrp.Children.Count -eq 0) { $projectXml.RemoveChild($itemGrp) }
	}
	
	$project.Save()
}

# Uninstall custom Web server provider.
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
$server = $servers.GetWebServer('OwinHost for Heroku')
if ($server -ne $null)
{
    Add-Type -AssemblyName Microsoft.VisualBasic
    $prompt = [Microsoft.VisualBasic.Interaction]::MsgBox("Remove custom server settings?",'YesNo,Question', "Uninstalling Custom Server")
    if ($prompt -eq [Microsoft.VisualBasic.MsgBoxResult]::Yes)
    {
        $servers.RemoveWebServer('OwinHost for Heroku');
    }
}
