param (
    [Parameter(
    HelpMessage="Select deploy profile to apply ('aggregator-collector','aggregator','collector','platform','worker','db','monitoring-only')")]
    [Alias("n")][string]$profile = "aggregator-collector",

    [Parameter(
    HelpMessage="Provide parentId of object to connect this application to.",
    Mandatory)][Alias("o")][string]$parentId,
    [Parameter(
    HelpMessage="Platform endpoint.")]
    [Alias("a")][string]$bindAddress = "preview.aparavi.com",
    [Parameter(
    HelpMessage="Logstash connecting endpoint.")]
    [Alias("l")][string]$logstashAddress = "logstash-ext.paas.aparavi.com:5044",

    [Parameter(
    HelpMessage="Automation branch name.")]
    [Alias("b")][string]$gitBranch = "main",
    [Parameter(
    HelpMessage="Application installer url.")]
    [Alias("u")][string]$downloadUrl = "https://aparavi.jfrog.io/artifactory/aparavi-installers-public/windows-installer-latest.exe",
    
    [Parameter(
    HelpMessage="Application Database username.")]
    [Alias("m")][string]$mysqlUser = "aparavi_app",
    [Parameter(
    HelpMessage="Application Database password ('none' to generate new).")]
    [string]$mysqlPass = "none",
    [Parameter(
    HelpMessage="Root database password ('none' to generate new).")]
    [string]$rootDbPass = "none",
    [Parameter(
    HelpMessage="Monitoring Database username.")]
    [string]$monitoringUser = "monitoring",
    [Parameter(
    HelpMessage="Monitoring Database password ('none' to generate new).")]
    [string]$monitoringDbPass = "none",
    [Parameter(
    HelpMessage="Mysql version to install.")]
    [string]$mysqlVersion = "8.0.32",
    [Parameter(
    HelpMessage="Mysql host to specify in application configuration.")]
    [string]$dbhost = "127.0.0.1",
    [Parameter(
    HelpMessage="Mysql port to specify in application configuration.")]
    [string]$dbport = "3306",

    [Parameter(
    HelpMessage="Monitoring 'environment' variable.")]
    [string]$environment = "nonprod",
    [Parameter(
    HelpMessage="Monitoring 'service_instance' variable to distinguish installations.")]
    [string]$installationName = "testing",

    [Parameter(
    HelpMessage="Redis host (platform specific).")]
    [string]$rdbhost = "127.0.0.1",
    [Parameter(
    HelpMessage="Redis port (platform specific).")]
    [string]$rdbport = "6379",
    [Parameter(
    HelpMessage="Platform bindUrl (platform specific).")]
    [string]$platformUrl = "preview.aparavi.com",

    [Parameter(
    HelpMessage="Print passwords at script end (useful for generated passwords).")]
    [bool]$printPasswords = $true
)

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name powershell-yaml -Force -Verbose -Scope CurrentUser
Import-Module powershell-yaml

$APPAGT_OPTIONS = @(
  'mysql',
  'app',
  'db_monitoring'
  'common_monitoring'
)

$AGGR_OPTIONS = @(
  'mysql',
  'app',
  'db_monitoring'
  'common_monitoring'
)

$COLL_OPTIONS = @(
  'app',
  'common_monitoring'
)

$WRKR_OPTIONS = @(
  'app',
  'common_monitoring'
)

$DB_OPTIONS = @(
  'mysql',
  'db_monitoring'
  'common_monitoring'
)

$MON_OPTIONS = @(
  'common_monitoring'
)

function unzip {
    param (
        [string]$archiveFilePath,
        [string]$destinationPath
    )

    if ($archiveFilePath -notlike '?:\*') {
        $archiveFilePath = [System.IO.Path]::Combine($PWD, $archiveFilePath)
    }

    if ($destinationPath -notlike '?:\*') {
        $destinationPath = [System.IO.Path]::Combine($PWD, $destinationPath)
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $archiveFile = [System.IO.File]::Open($archiveFilePath, [System.IO.FileMode]::Open)
    $archive = [System.IO.Compression.ZipArchive]::new($archiveFile)

    if (Test-Path $destinationPath) {
        foreach ($item in $archive.Entries) {
            $destinationItemPath = [System.IO.Path]::Combine($destinationPath, $item.FullName)

            if ($destinationItemPath -like '*/') {
                New-Item $destinationItemPath -Force -ItemType Directory > $null
            } else {
                New-Item $destinationItemPath -Force -ItemType File > $null

                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($item, $destinationItemPath, $true)
            }
        }
    } else {
        [System.IO.Compression.ZipFileExtensions]::ExtractToDirectory($archive, $destinationPath)
    }

    $archive.Dispose()
    $archiveFile.Dispose()
}

function get_git_repo {
  param ([string]$branch)
  Invoke-WebRequest -Uri "https://github.com/Aparavi-Operations/aparavi-infrastructure/archive/refs/heads/${branch}.zip" -OutFile "aparavi-infra.zip"
  unzip "aparavi-infra.zip" "."
  Remove-Item -Force "aparavi-infra.zip"
  if (Test-Path "aparavi-infrastructure") {
    Remove-Item -Force -Recurse "aparavi-infrastructure"
  }
  Rename-Item -Path "aparavi-infrastructure-${gitBranch}" -NewName "aparavi-infrastructure"
}

function install_mysql_exporter {
  param (
    [string]$username,
    [string]$password,
    [string]$version = "0.14.0",
    [string]$sslversion = "3_0_8",
    [string]$servicename = "prometheus-mysqld-exporter",
    [string]$nssmversion = "2.24-103-gdee49fc",
    [string]$listenaddress = "0.0.0.0",
    [string]$port = "9104",
    [string]$mysqlhost = "localhost",
    [string]$mysqlport = "3306"
  )
  Invoke-WebRequest -Uri "https://slproweb.com/download/Win64OpenSSL_Light-${sslversion}.msi" -OutFile "openssl.msi" -ErrorAction Stop

  Write-Host "Installing OpenSSL..."
  $installeropts = @(
    '/i'
    'openssl.msi'
    '/quiet'
  )
  Start-Process -Wait -NoNewWindow -FilePath "msiexec.exe" -ArgumentList $installeropts

  Write-Host "MySQL exporter config folder creation..."
  New-Item "$env:ProgramData\${servicename}" -Force -ItemType Directory > $null

  Write-Host "Generating self-signed certs..."
  $certgenoptions = @(
    "req"
    "-x509"
    "-newkey"
    "rsa:4096"
    "-keyout"
    "$env:ProgramData\${servicename}\cert.key"
    "-out"
    "$env:ProgramData\${servicename}\cert.crt"
    "-sha256"
    "-days"
    "365"
    "-nodes"
    "-subj"
    "`"/C=US/ST=CA/L=Santa Monica/O=Aparavi/OU=DevOps/CN=MYSQLEXPORTERSERVICE`""
  )
  Start-Process -Wait -NoNewWindow -FilePath "$env:ProgramFiles\OpenSSL-Win64\bin\openssl.exe" -ArgumentList $certgenoptions

  Write-Host "MySQL exporter config generation..."
  $exporterconfig = New-Object -TypeName PSObject
  Add-NoteProperty -InputObject $exporterconfig -Property "tls_server_config.cert_file" -Value "$env:ProgramData\${servicename}\cert.crt"
  Add-NoteProperty -InputObject $exporterconfig -Property "tls_server_config.key_file" -Value "$env:ProgramData\${servicename}\cert.key"
  $exporterconfig | ConvertTo-YAML | Out-File -encoding ASCII "$env:ProgramData\${servicename}\web_config.yml"

  Invoke-WebRequest -Uri "https://github.com/prometheus/mysqld_exporter/releases/download/v${version}/mysqld_exporter-${version}.windows-amd64.zip" -OutFile "pme.zip"
  Invoke-WebRequest -Uri "https://nssm.cc/ci/nssm-${nssmversion}.zip" -OutFile "nssm.zip"
  Stop-Service -Name "${servicename}" -ErrorAction SilentlyContinue > $null

  unzip "pme.zip" "$env:ProgramFiles"
  unzip "nssm.zip" "$env:ProgramFiles"

  Move-Item -Force -path "$env:ProgramFiles\nssm-${nssmversion}\win64\nssm.exe" -destination "$env:ProgramFiles\mysqld_exporter-${version}.windows-amd64"
  
  $nssmcleanup = @(
    "remove"
    "${servicename}"
    "confirm"
  )
  Start-Process -Wait -NoNewWindow -FilePath "$env:ProgramFiles\mysqld_exporter-${version}.windows-amd64\nssm.exe" -ArgumentList $nssmcleanup
  $nssminstalloptions = @(
    "install"
    "${servicename}"
    "`"$env:ProgramFiles\mysqld_exporter-${version}.windows-amd64\mysqld_exporter.exe`""
    "--web.listen-address=${listenaddress}:${port}"
    "--web.config.file=`"$env:ProgramData\${servicename}\web_config.yml`""
  )
  Start-Process -Wait -NoNewWindow -FilePath "$env:ProgramFiles\mysqld_exporter-${version}.windows-amd64\nssm.exe" -ArgumentList $nssminstalloptions

  $nssmenvupdate = @(
    "set"
    "${servicename}"
    "AppEnvironmentExtra"
    "DATA_SOURCE_NAME=${username}:${password}@(${mysqlhost}:${mysqlport})/"
  )
  Start-Process -Wait -NoNewWindow -FilePath "$env:ProgramFiles\mysqld_exporter-${version}.windows-amd64\nssm.exe" -ArgumentList $nssmenvupdate

  Set-Service -Name $servicename -StartupType Automatic -Status Running
}

function install_prometheus_exporter {
  param (
    [string]$version = "0.20.0",
    [string]$enabled_collectors = "cpu,cs,logical_disk,memory,net,os,process,system,tcp,time",
    [string]$listen_addr = "0.0.0.0",
    [string]$listen_port = "9182",
    [string]$collector_whitelist = "(node|engine)"
  )
  Write-Host "Downloading Prometheus windows exporter installer..."
  $url = "https://github.com/prometheus-community/windows_exporter/releases/download/v${version}/windows_exporter-${version}-amd64.msi"
  Invoke-WebRequest -Uri $url -OutFile "exporter.msi"
  Write-Host "Downloading Prometheus windows exporter installer. DONE"
  $installeropts = @(
    "/i"
    "exporter.msi"
    "ENABLED_COLLECTORS=${enabled_collectors}"
    "LISTEN_ADDR=${listen_addr}"
    "LISTEN_PORT=${listen_port}"
    "EXTRA_FLAGS=--collector.process.whitelist=`"${collector_whitelist}`""
  )
  Start-Process -Wait -NoNewWindow -FilePath "msiexec.exe" -ArgumentList $installeropts
}

function Add-NoteProperty {
    param(
        $InputObject,
        $Property,
        $Value,
        [switch]$Force,
        [char]$escapeChar = '#'
    )
    process {
        $path = $Property -split "\."
        $obj = $InputObject
        # loop all but the very last property
        for ($x = 0; $x -lt $path.count -1; $x ++) {
            $propName = $path[$x] -replace $escapeChar, '.'
            if (!($obj | Get-Member -MemberType NoteProperty -Name $propName)) {
                $obj | Add-Member NoteProperty -Name $propName -Value (New-Object PSCustomObject) -Force:$Force.IsPresent
            }
            $obj = $obj.$propName
        }
        $propName = ($path | Select-Object -Last 1) -replace $escapeChar, '.'
        if (!($obj | Get-Member -MemberType NoteProperty -Name $propName)) {
            $obj | Add-Member NoteProperty -Name $propName -Value $Value -Force:$Force.IsPresent
        }
    }
}

function filebeat_install {
  param (
    [string]$version = "7.17.3",
    [string]$environment = "nonprod",
    [string]$installationName = "testing",
    [string]$logstashurl = "logstash-ext.paas.aparavi.com:5044"
  )
  Write-Host "Downloading FileBeat installer..."
  Invoke-WebRequest -Uri "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${version}-windows-x86_64.msi" -OutFile "filebeat.msi"
  Write-Host "Downloading FileBeat installer. DONE"

  Write-Host "Installing FileBeat..."
  $installeropts = @(
    '/i'
    'filebeat.msi'
    '/passive'
  )
  Start-Process -Wait -NoNewWindow -FilePath "msiexec.exe" -ArgumentList $installeropts
  $config = Get-Content "aparavi-infrastructure\windows\filebeat.yml" | Out-String | ConvertFrom-YAML -Ordered
  $config.processors[0].add_fields.fields["service.environment"] = $environment
  $config.processors[1].add_fields.fields["service.instance"] = $installationName
  $config.output.logstash.hosts = $logstashurl
  $config | ConvertTo-YAML | Out-File -encoding ASCII "$env:ProgramData\Elastic\Beats\filebeat\filebeat.yml"

  $filebeatservice = Stop-Service -Name "filebeat" -PassThru
  $filebeatservice.WaitForStatus("Stopped")
  Start-Service -Name "filebeat"
}

function get_app_installer {
  param ([string]$url)
  Write-Host "Downloading App installer..."
  Invoke-WebRequest -Uri $url -OutFile "aparavi-installer.exe"
  Write-Host "Downloading App installer. DONE"
}

function get_mysql_archive {
  param ([string]$version = "8.0.32")
  $majorver = ($version -split "\." | select -SkipLast 1) -join "."
  Write-Host "Downloading MySQL archive..."
  $url = "https://cdn.mysql.com//Downloads/MySQL-${majorver}/mysql-${version}-winx64.zip"
  Invoke-WebRequest -Uri $url -OutFile "mysql.zip"
  Write-Host "Downloading MySQL archive. DONE"
}

function check_mysql_password {
  param (
    [string]$mysqlpassword,
    [string]$mysqluser = "root"
  )
  if(!(Test-Path("$env:ProgramFiles\MySQL\Server\bin\mysql.exe"))) { return $false }
  $rc = Start-Process -RedirectStandardOutput "NUL" -NoNewWindow -PassThru -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlpassword}", "-e", "`"SELECT 1;`""
  if ($rc.ExitCode -eq 0) { return $true } else { return $false }
}

function install_mysql_archive {
  param (
    [string]$version = "8.0.32",
    [string]$mysqlpassword
  )
  if ([System.IO.Directory]::Exists("$env:ProgramFiles\MySQL")) {
    Write-Host "Checking we already have initialized DB..."
    $mysqlinitialized = check_mysql_password -mysqlpassword $mysqlpassword
    Write-Host "Stopping MySQL service..."
    $mysqlservice = Stop-Service -Name "MySQL" -PassThru
    $mysqlservice.WaitForStatus("Stopped")
    Write-Host "Removing MySQL installation excluding DATA path"
    Get-ChildItem -Path  "$env:ProgramFiles\MySQL" -Recurse |
      Select -ExpandProperty FullName |
      Where {$_ -notlike "$env:ProgramFiles\MySQL\data*"} |
      sort length -Descending |
      Remove-Item -force
  } else {
    New-Item "$env:ProgramFiles\MySQL" -Force -ItemType Directory > $null
    $mysqlinitialized = $false
  }
  Write-Host "Unzipping and copying MySQL executables..."
  unzip "mysql.zip" "$env:ProgramFiles\MySQL"
  Rename-Item -Path "$env:ProgramFiles\MySQL\mysql-${version}-winx64" -NewName "$env:ProgramFiles\MySQL\Server"
  Write-Host "Generating my.ini..."
  @"
[mysqld]
basedir="$env:ProgramFiles\MySQL\Server"
datadir="$env:ProgramFiles\MySQL\data"
port=3306
"@ | Out-File "$env:ProgramFiles\MySQL\my.ini" -Force -Encoding ASCII
  if (-Not $mysqlinitialized) {
    Write-Host "Initializing MySQL database..."
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysqld.exe" -ArgumentList "--defaults-file=`"$env:ProgramFiles\MySQL\my.ini`"", "--initialize-insecure"
    Write-Host "Installing the MySQL service..."
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysqld.exe" -ArgumentList "--remove"
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysqld.exe" -ArgumentList "--install", "MySQL", "--defaults-file=`"$env:ProgramFiles\MySQL\my.ini`""
    Write-Host "Starting MySQL service..."
    Start-Service -Name "MySQL"
    Write-Host "Setting MySQL root password..."
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-e", "`"ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysqlpassword}';`""
  } else {
    Write-Host "Starting MySQL service..."
    Start-Service -Name "MySQL"
  }
  Write-Host "Base installation done"
}

function configure_mysql {
  param (
    [string]$type,
    [string]$mysqlrootpassword,
    [string]$mysqlappuser,
    [string]$mysqlapppassword,
    [string]$mysqlmonitoringuser,
    [string]$mysqlmonitoringpassword
  )
  Write-Host "Doing MySQL schema configuration..."
  if (check_mysql_password -mysqlpassword $mysqlrootpassword) {
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"CREATE USER IF NOT EXISTS '${mysqlappuser}'@'%';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"ALTER USER IF EXISTS '${mysqlappuser}'@'%' IDENTIFIED BY '${mysqlapppassword}';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"GRANT ALL PRIVILEGES ON ``${type}\_%``.* TO '${mysqlappuser}'@'%';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"CREATE USER IF NOT EXISTS '${mysqlmonitoringuser}'@'%';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"ALTER USER IF EXISTS '${mysqlmonitoringuser}'@'%' IDENTIFIED BY '${mysqlmonitoringpassword}' WITH MAX_USER_CONNECTIONS 10;`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"GRANT SELECT, PROCESS, REPLICATION CLIENT, RELOAD, BACKUP_ADMIN ON *.* TO 'monitoring'@'%';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\Server\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"FLUSH PRIVILEGES;`""
  } else {
    Write-Error "Failed to run commands against MySQL!" -ErrorAction Stop
  }
}

function app_type_selector {
  param ([string]$profile)
  Switch ($profile) {
    "aggregator-collector" { return "appagt" }
    "aggregator" { return "appliance" }
    "collector" { return "agent" }
    "platform" { return "platform" }
    "worker" { return "worker" }
    "db" { return "none" }
    "monitoring-only" { return "none" }
    default { return "none" }
  }
}

function app_type_name {
  param ([string]$type)
  Switch ($type) {
    'appagt' { return 'Aggregator-Collector' }
    'appliance' { return 'Aggregator' }
    'agent' { return 'Collector' }
    'platform' { return 'Platform' }
    'worker' { return 'Worker' }
    'none' { return 'none' }
  }
}

function run_installer {
  param (
    [string]$type,
    [string]$address,
    [string]$dbuser,
    [string]$dbpassword,
    [string]$hostname,
    [string]$parentId,
    [string]$dbname,
    [string]$dbhost = "127.0.0.1",
    [string]$dbport = "3306",
    [string]$platformurl = "test.platform",
    [string]$redishost = "127.0.0.1",
    [string]$redisport = "6379"
  )
  $installeropts = @(
    "--"
    "/APPTYPE=${type}"
    "/SILENT"
    "/NOSTART" 
  )
  if (@("appagt", "appliance", "agent") -contains $type) {
    $installeropts = $installeropts + @(
      "/BINDTO=${address}"
      "/cfg.node.parentObjectId=`"${parentId}`""
    )
  }
  if (@("worker") -contains $type) {
    $installeropts = $installeropts + @(
      "/BINDTO=${address}"
    )
  }
  if (@("appagt", "appliance", "platform") -contains $type) {
    $installeropts = $installeropts + @(
      "/cfg.node.nodeName=`"${hostname}-${type}`""
      "/cfg.node.hostName=`"${hostname}`""
      "/DBTYPE=mysql"
      "/DBHOST=${dbhost}"
      "/DBPORT=${dbport}"
      "/DBUSER=`"${dbuser}`""
      "/DBPSWD=`"${dbpassword}`""
      "/cfg.database.database=`"${dbname}`""
    )
  }
  if ($type -eq "platform") {
    $installeropts = $installeropts + @(
      "/LOCALURL=`"${platformurl}`""
      "/RDBHOST=`"${redishost}`""
      "/RDBPORT=`"${redisport}`""
    )
  }
  Write-Host $installeropts | ConvertTo-Json -Depth 20 | Out-String
  Start-Process -Wait -FilePath "aparavi-installer.exe" -ArgumentList $installeropts
  $apptypename = app_type_name -type $type
  while((Get-Service -Name "APARAVI Data IA ${apptypename}").Status -eq "StartPending") {
    Write-Host "Waiting for service start..."
    Start-Sleep 1
  }
}

function pwgen {
  param (
    [int]$length = 16
  )
  Add-Type -AssemblyName System.Web
  # Generate random password
  return ([System.Web.Security.Membership]::GeneratePassword($length,2) -Replace '[?@"'':()|]', '_')
}

function fill_password {
  param (
    [string]$initial
  )
  if ($initial -eq "none") {
    return pwgen
  } else { return $initial }
}

function print_password {
  param (
    [string]$type,
    [string]$password,
    [string]$name
  )

  Write-Host "!!! ${type} password will follow in login/password pair !!!"
  Write-Host "!!! Keep this password in secret place !!!"
  Write-Host "!!! `"${name}`" password is `"${password}`" !!!"
}

function configure_app {
  param (
    [string]$type,
    [string]$hostname,
    [string]$parentId,
    [string]$bindAddress,
    [string]$dbuser,
    [string]$dbpassword,
    [string]$dbname
  )

  $apptypename = app_type_name -type $type
  $apptypenamelower = $apptypename.ToLower()
  $configfile = "${env:ProgramData}\aparavi-data-ia\${apptypenamelower}\config\config.json"
  $retry = 0 
  while(!(Test-Path($configfile)) -and ($retry -lt 60)) {
    Write-Host "Waiting for ${configfile} generation..."
    Start-Sleep 1
    $retry = $retry + 1
  }
  Write-Host "Stopping App service..."
  Stop-Service -Name "APARAVI Data IA ${apptypename}"
  $retry = 0
  while(!((Get-Service -Name "APARAVI Data IA ${apptypename}").Status -eq "Stopped") -and ($retry -lt 60)) {
    Write-Host "Waiting for app stop..."
    Start-Sleep 1
    $retry = $retry + 1
  }

  Write-Host "Generating config.json..."
  $config = Get-Content $ConfigFile | Out-String | ConvertFrom-Json
  $config.node.nodeName = "${hostname}-${type}"
  $config.node.hostName = $hostname
  $config.node.PSObject.Properties.Remove("hostId")
  $config.node.PSObject.Properties.Remove("nodeId")
  $config.node.parentObjectId = $parentId
  $config.node.bindTo = $bindAddress
  $config.database.database = $dbname
  $config.database.user = $dbuser
  $config.database.password = $dbpassword
  $config.database.host = "127.0.0.1"
  $config.database.port = 3306

  $config | ConvertTo-Json -Depth 20 | Out-File -encoding ASCII $configfile
}

function start_app {
  param (
    [string]$type
  )
  $apptypename = app_type_name -type $type
  $svcstate = (Get-Service -Name "APARAVI Data IA ${apptypename}").Status
  Write-Host "Service state is ${svcstate}"
  Write-Host "Starting App service..."
  Start-Service -Name "APARAVI Data IA ${apptypename}"
}

function check_option_by_profile {
  param (
    [string]$profile,
    [string]$option
  )

  Switch ($profile) {
    "aggregator-collector" { return ($APPAGT_OPTIONS -Contains $option) }
    "aggregator" { return ($AGGR_OPTIONS -Contains $option) }
    "collector" { return ($COLL_OPTIONS -Contains $option) }
    "platform" { return ($PLAT_OPTIONS -Contains $option) }
    "worker" { return ($WRKR_OPTIONS -Contains $option) }
    "db" { return ($DB_OPTIONS -Contains $option) }
    "monitoring-only" { return ($MON_OPTIONS -Contains $option) }
    default { return $false }
  }
}

# Fill variables
$appType = app_type_selector -profile $profile
$hostname = $env:computername
$mysqlPass = fill_password -initial $mysqlPass
$rootDbPass = fill_password -initial $rootDbPass
$monitoringDbPass = fill_password -initial $monitoringDbPass

# Common operations for all profiles
get_git_repo -branch $gitBranch

# Database related operations
if (check_option_by_profile -profile $profile -option "mysql") {
  get_mysql_archive -version $mysqlVersion
  install_mysql_archive -version $mysqlVersion -mysqlpassword $rootDbPass
  configure_mysql -type $appType -mysqlrootpassword $rootDbPass -mysqlappuser $mysqlUser -mysqlapppassword $mysqlPass -mysqlmonitoringuser $monitoringUser -mysqlmonitoringpassword $monitoringDbPass
}
if (check_option_by_profile -profile $profile -option "app") {
  get_app_installer -url $downloadUrl
  run_installer -type $appType -hostname $hostname -parentId $parentId -dbname "${appType}-${hostname}" -address $bindAddress -dbuser $mysqlUser -dbpassword $mysqlPass -platformurl $platformUrl -dbhost $dbhost -dbport $dbport -rdbhost $rdbhost -rdbport $rdbport
  configure_app -type $appType -hostname $hostname -parentId $parentId -bindAddress $bindAddress -dbuser $mysqlUser -dbpass $mysqlPass -dbname "${appType}-${hostname}"
  start_app -type $appType
}

# Monitoring stuff goes next
if (check_option_by_profile -profile $profile -option "common_monitoring") {
  install_prometheus_exporter
  filebeat_install -environment $environment -installationName $installationName -logstashurl $logstashAddress
}
if (check_option_by_profile -profile $profile -option "db_monitoring") {
  install_mysql_exporter -username $monitoringUser -password $monitoringDbPass
}

# Printing passwords (enabled by default)
# the only way to get generated passwords
if ($printPasswords) {
  print_password -type "MySQL DB" -password $mysqlPass -name $mysqlUser
  print_password -type "MySQL DB" -password $rootDbPass -name "root"
  print_password -type "MySQL DB" -password $monitoringDbPass -name $monitoringUser
}
