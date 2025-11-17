Param(
  [string]$Namespace = "itpipes-openmetadata",
  [string]$DeployWeb = "openmetadata-deps-web",
  [string]$DeployScheduler = "openmetadata-deps-scheduler",
  [string]$DeployTriggerer = "openmetadata-deps-triggerer",
  [string]$PvcLogs = "airflow-logs",
  [string]$PvcDags = "airflow-dags",
  [int]$TimeoutSeconds = 300
)

function Invoke-KubectlSafe($args) {
  try {
    & kubectl @args 2>$null | Out-String | Write-Output
  } catch {
    # ignore
  }
}

Write-Host "Scaling Airflow deployments to 0 in namespace '$Namespace'..."
Invoke-KubectlSafe @("-n", $Namespace, "scale", "deploy/$DeployWeb", "--replicas=0")
Invoke-KubectlSafe @("-n", $Namespace, "scale", "deploy/$DeployScheduler", "--replicas=0")
Invoke-KubectlSafe @("-n", $Namespace, "scale", "deploy/$DeployTriggerer", "--replicas=0")

Write-Host "Deleting EFS provision job (if present)..."
Invoke-KubectlSafe @("-n", $Namespace, "delete", "job", "efs-provision", "--ignore-not-found")

Write-Host "Waiting for pods using PVCs to terminate..."
$start = Get-Date
while ((New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds -lt $TimeoutSeconds) {
  $pods = Invoke-KubectlSafe @("-n", $Namespace, "get", "pods", "-o", "name")
  if ($pods -notmatch "openmetadata-deps-web" -and $pods -notmatch "openmetadata-deps-scheduler" -and $pods -notmatch "openmetadata-deps-triggerer") {
    break
  }
  Start-Sleep -Seconds 5
}

Write-Host "Deleting PVCs (non-blocking)..."
Invoke-KubectlSafe @("-n", $Namespace, "delete", "pvc", $PvcLogs, "--wait=false", "--ignore-not-found")
Invoke-KubectlSafe @("-n", $Namespace, "delete", "pvc", $PvcDags, "--wait=false", "--ignore-not-found")

Write-Host "Waiting for PVCs to be removed..."
$start = Get-Date
while ((New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds -lt $TimeoutSeconds) {
  $pvcs = Invoke-KubectlSafe @("-n", $Namespace, "get", "pvc", "-o", "name")
  if ($pvcs -notmatch $PvcLogs -and $pvcs -notmatch $PvcDags) { break }
  Start-Sleep -Seconds 5
}

if ($pvcs -match $PvcLogs -or $pvcs -match $PvcDags) {
  Write-Host "PVCs still present; patching finalizers (last resort)..."
  Invoke-KubectlSafe @("-n", $Namespace, "patch", "pvc", $PvcLogs, "--type=merge", "-p", '{"metadata":{"finalizers":[]}}')
  Invoke-KubectlSafe @("-n", $Namespace, "patch", "pvc", $PvcDags, "--type=merge", "-p", '{"metadata":{"finalizers":[]}}')

  $pvs = Invoke-KubectlSafe @("get", "pv", "-o", "name")
  $pvsLogs = ($pvs -split "`n") | Where-Object { $_ -match $PvcLogs }
  $pvsDags = ($pvs -split "`n") | Where-Object { $_ -match $PvcDags }
  foreach ($pv in @($pvsLogs + $pvsDags)) {
    if ($pv) {
      Write-Host "Patching PV finalizers: $pv"
      Invoke-KubectlSafe @("patch", $pv.Trim(), "--type=merge", "-p", '{"metadata":{"finalizers":[]}}')
    }
  }
}

Write-Host "Running 'terraform destroy' from ./deploy ..."
Push-Location (Join-Path $PSScriptRoot ".." "deploy")
try {
  terraform destroy -auto-approve
} finally {
  Pop-Location
}


