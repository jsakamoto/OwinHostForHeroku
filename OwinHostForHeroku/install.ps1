param($installPath, $toolsPath, $package, $project)
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
$solutionDir = [System.IO.Path]::Combine($installPath, "..\..\")
$solutionDir = [System.IO.Path]::GetFullPath($solutionDir)
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