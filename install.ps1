param (
    [Alias("n")][string]$profile = "default",
    [Parameter(Mandatory)][Alias("c")][string]$client,
    [Parameter(Mandatory)][Alias("o")][string]$parentId,

    [Alias("a")][string]$bindAddress = "preview.aparavi.com",
    [Alias("l")][string]$logstashAddress = "logstash.aparavi.com",
    [Alias("m")][string]$mysqlUser = "aparavi_app",

    [Alias("d")][string]$tmpDir = "/tmp/debian11-install",
    [Alias("b")][string]$gitBranch = "main",
    [Alias("u")][string]$downloadUrl = "https://aparavi.jfrog.io/artifactory/aparavi-installers-public/windows-installer-latest.exe"
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
  Remove-Item -Force -Recurse "aparavi-infrastructure"
  Rename-Item -Path "aparavi-infrastructure-${gitBranch}" -NewName "aparavi-infrastructure"
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
  if(!(Test-Path("$env:ProgramFiles\MySQL\bin\mysql.exe"))) { return $false }
  $rc = Start-Process -RedirectStandardOutput "NUL" -NoNewWindow -PassThru -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlpassword}", "-e", "`"SELECT 1;`""
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
    $mysqlinitialized = $false
  }
  Write-Host "Unzipping and copying MySQL executables..."
  unzip "mysql.zip" "$env:ProgramFiles"
  Rename-Item -Path "$env:ProgramFiles\mysql-${version}-winx64" -NewName "$env:ProgramFiles\MySQL"
  #Remove-Item -Force -Recurse "$env:ProgramFiles\mysql-${version}-winx64"
  #Remove-Item -Force "mysql.zip"
  Write-Host "Generating my.ini..."
  @"
[mysqld]
basedir="$env:ProgramFiles\MySQL"
datadir="$env:ProgramFiles\MySQL\data"
port=3306
"@ | Out-File "$env:ProgramFiles\MySQL\my.ini" -Force -Encoding ASCII
  if (-Not $mysqlinitialized) {
    Write-Host "Initializing MySQL database..."
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysqld.exe" -ArgumentList "--defaults-file=`"$env:ProgramFiles\MySQL\my.ini`"", "--initialize-insecure"
    Write-Host "Installing the MySQL service..."
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysqld.exe" -ArgumentList "--install", "MySQL", "--defaults-file=`"$env:ProgramFiles\MySQL\my.ini`""
    Write-Host "Starting MySQL service..."
    Start-Service -Name "MySQL"
    Write-Host "Setting MySQL root password..."
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-e", "`"ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysqlpassword}';`""
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
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"CREATE USER IF NOT EXISTS '${mysqlappuser}'@'%';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"ALTER USER IF EXISTS '${mysqlappuser}'@'%' IDENTIFIED BY '${mysqlapppassword}';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"GRANT ALL PRIVILEGES ON ``${type}\_%``.* TO '${mysqlappuser}'@'%';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"CREATE USER IF NOT EXISTS '${mysqlmonitoringuser}'@'%';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"ALTER USER IF EXISTS '${mysqlmonitoringuser}'@'%' IDENTIFIED BY '${mysqlmonitoringpassword}' WITH MAX_USER_CONNECTIONS 10;`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"GRANT SELECT, PROCESS, REPLICATION CLIENT, RELOAD, BACKUP_ADMIN ON *.* TO 'monitoring'@'%';`""
    Start-Process -NoNewWindow -Wait -FilePath "$env:ProgramFiles\MySQL\bin\mysql.exe" -ArgumentList "-u", "root", "-p${mysqlrootpassword}", "-e", "`"FLUSH PRIVILEGES;`""
  } else {
    Write-Error "Failed to run commands against MySQL!" -ErrorAction Stop
  }
}

function app_type_selector {
  param ([string]$profile)
  Switch ($profile) {
    default { return "appagt" }
  }
}

function app_type_name {
  param ([string]$type)
  Switch ($type) {
    'appagt' { return 'Aggregator-Collector' }
  }
}

function run_installer {
  param (
    [string]$type,
    [string]$address,
    [string]$dbuser,
    [string]$dbpassword
  )
  Write-Host "aparavi-installer.exe -- /APPTYPE=${type} /BINDTO=${address} /DBTYPE=mysql /DBHOST=127.0.0.1 /DBPORT=3306 /DBUSER=${dbuser} /DBPSWD=${dbpassword} /SILENT /NOSTART"
  Start-Process -Wait -FilePath "aparavi-installer.exe" -ArgumentList "--","/APPTYPE=${type}","/BINDTO=${address}","/DBTYPE=mysql","/DBHOST=127.0.0.1","/DBPORT=3306","/DBUSER=${dbuser}","/DBPSWD=${dbpassword}","/SILENT","/NOSTART"
  $apptypename = app_type_name -type $type
  while((Get-Service -Name "APARAVI Data IA ${apptypename}").Status -eq "StartPending") {
    Write-Host "Waiting for service start..."
    Start-Sleep 1
  }
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
  $config.node.nodeName = "${hostname}-appagent"
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
  #$template = (Get-Content "aparavi-infrastructure\windows\config.json.tpl") | out-string
  #$template = (Get-Content "config.json.tpl") | % {$_.replace('"','""')} | out-string
  #$data = Invoke-Expression "`"$template`""
  #$data | Out-File "${env:ProgramData}\aparavi-data-ia\${apptypename}\config\config.json"
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

$appType = app_type_selector -profile $profile
$appdbpass = "FooTest123"
$rootdbpass = "testpass123"
$monuser = "monitoring"
$monpass = "monpass123"
$mysqlver = "8.0.32"
$hostname = "testwindows"

get_git_repo -branch $gitBranch
get_mysql_archive -version $mysqlver
install_mysql_archive -version $mysqlver -mysqlpassword $rootdbpass
configure_mysql -type $appType -mysqlrootpassword $rootdbpass -mysqlappuser $mysqlUser -mysqlapppassword $appdbpass -mysqlmonitoringuser $monuser -mysqlmonitoringpassword $monpass
get_app_installer -url $downloadUrl
run_installer -type $appType -address $bindAddress -dbuser $mysqlUser -dbpassword $appdbpass
configure_app -type $appType -hostname $hostname -parentId $parentId -bindAddress $bindAddress -dbuser $mysqlUser -dbpass $appdbpass -dbname "${appType}-${hostname}"
start_app -type $appType
