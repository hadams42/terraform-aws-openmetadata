param(
  [string]$Namespace = "itpipes-openmetadata",
  [string]$KubeContext = "",
  [switch]$TryHelm = $true,
  [switch]$VerboseOutput = $true
)

$ErrorActionPreference = "Stop"

function Exec($cmd, $ignoreError=$false) {
  # Normalize to a single command string (PowerShell 5.x friendly)
  if ($cmd -is [System.Array]) { $cmd = ($cmd -join ' ') }
  $cmd = [string]$cmd
  if ($VerboseOutput) { Write-Host ">> $cmd" -ForegroundColor Cyan }
  try { Invoke-Expression $cmd | Out-Null; return $true }
  catch {
    if ($ignoreError) { if ($VerboseOutput) { Write-Warning $_.Exception.Message }; return $false }
    throw
  }
}

function Kubectl($CmdLine, $ignoreError=$false) {
  $ctx = ""
  if ($KubeContext -ne "") { $ctx = "--context `"$KubeContext`"" }
  return Exec("kubectl $ctx $CmdLine", $ignoreError)
}

function NsExists() {
  $ctx = ""
  if ($KubeContext -ne "") { $ctx = "--context `"$KubeContext`"" }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "kubectl"
  $psi.Arguments = "$ctx get ns $Namespace --no-headers"
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $p = [System.Diagnostics.Process]::Start($psi)
  $p.WaitForExit()
  return ($p.ExitCode -eq 0)
}

# 1) (Optional) Uninstall Helm releases so controllers don't recreate pods
if ($TryHelm) {
  try {
    $releases = (helm list -n $Namespace -o json | ConvertFrom-Json) 2>$null
    if ($releases) {
      foreach ($rel in $releases) {
        Write-Host "Helm uninstall $($rel.name) -n $Namespace" -ForegroundColor Yellow
        Exec("helm uninstall $($rel.name) -n $Namespace", $true) | Out-Null
      }
    }
  } catch {
    Write-Host "Helm not available or no releases found; continuing..." -ForegroundColor DarkGray
  }
}

if (-not (NsExists)) {
  Write-Host "Namespace '$Namespace' not found. Nothing to clean." -ForegroundColor Green
  exit 0
}

# 2) Delete workload controllers first (so pods don't come back)
$ctrlKinds = @("deploy", "statefulset", "daemonset", "job", "cronjob")
foreach ($k in $ctrlKinds) {
  Kubectl "-n $Namespace delete $k --all --ignore-not-found" $true | Out-Null
}

# 3) Defensive: scale any remaining controllers to zero
kubectl -n $Namespace get deploy -o name 2>$null | ForEach-Object { Kubectl "-n $Namespace scale $_ --replicas=0" $true | Out-Null }
kubectl -n $Namespace get statefulset -o name 2>$null | ForEach-Object { Kubectl "-n $Namespace scale $_ --replicas=0" $true | Out-Null }

# 4) Force delete Pods
Kubectl "-n $Namespace delete pod --all --ignore-not-found --force --grace-period=0" $true | Out-Null

# 5) Remove Services/Ingress/ConfigMaps/Secrets to release references
$leftovers = @("svc", "ingress", "cm", "secret")
foreach ($k in $leftovers) {
  Kubectl "-n $Namespace delete $k --all --ignore-not-found" $true | Out-Null
}

# 6) PVCs: delete & strip finalizers if stuck (common with EFS CSI)
$pvcList = & kubectl -n $Namespace get pvc -o json 2>$null | ConvertFrom-Json
if ($pvcList -and $pvcList.items) {
  foreach ($pvc in $pvcList.items) {
    $name = $pvc.metadata.name
    Write-Host "Deleting PVC $name" -ForegroundColor Yellow
    Kubectl "-n $Namespace delete pvc $name --ignore-not-found" $true | Out-Null

    Start-Sleep -Seconds 1
    # If still present (Terminating), remove finalizers
    $pvcJson = & kubectl -n $Namespace get pvc $name -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and $pvcJson) {
      Write-Host "Removing finalizers from PVC $name" -ForegroundColor DarkYellow
      $patch = "[{`"op`":`"remove`",`"path`":`"/metadata/finalizers`"}]"
      Kubectl "-n $Namespace patch pvc $name --type=json -p `"$patch`"" $true | Out-Null
    }
  }
}

# 7) ServiceAccounts last
Kubectl "-n $Namespace delete sa --all --ignore-not-found" $true | Out-Null

# 8) Try normal namespace deletion
Kubectl "delete ns $Namespace --ignore-not-found" $true | Out-Null
Start-Sleep -Seconds 2

# 9) If the namespace is stuck, clear its finalizers via /finalize
if (NsExists) {
  Write-Host "Namespace '$Namespace' still exists; attempting finalizer removal..." -ForegroundColor Yellow
  $nsJson = kubectl get ns $Namespace -o json | Out-String
  if ($nsJson) {
    $nsPatched = $nsJson -replace '"finalizers"\s*:\s*\[[^\]]*\]', '"finalizers": []'
    $tmp = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmp, $nsPatched, [System.Text.Encoding]::UTF8)
    $ctx = ""
    if ($KubeContext -ne "") { $ctx = "--context `"$KubeContext`"" }
    Exec("kubectl $ctx replace --raw /api/v1/namespaces/$Namespace/finalize -f `"$tmp`"", $true) | Out-Null
    Remove-Item $tmp -Force
  }
}

# 10) Final sweep of any list-able resources, then one last delete
if (NsExists) {
  Write-Host "Final sweep of namespaced resources..." -ForegroundColor Yellow
  $types = kubectl api-resources --namespaced --verbs=list -o name 2>$null
  foreach ($t in $types) {
    Kubectl "-n $Namespace delete $t --all --ignore-not-found --force --grace-period=0" $true | Out-Null
  }
  Kubectl "delete ns $Namespace --ignore-not-found" $true | Out-Null
}

if (NsExists) {
  Write-Warning "Namespace '$Namespace' still exists. Inspect with: kubectl get all -n $Namespace -o wide"
  exit 1
} else {
  Write-Host "Namespace '$Namespace' removed successfully." -ForegroundColor Green
  exit 0
}
