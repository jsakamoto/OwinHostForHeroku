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