# Test FCM notification script
# Usage: .\test_fcm.ps1 <FCM_TOKEN>

param(
    [Parameter(Mandatory=$false)]
    [string]$FcmToken = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Command = "test"
)

$EdgeFunctionUrl = "https://xyzttzqvbescdpihvyfu.supabase.co/functions/v1/gate-notify"
$AnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5enR0enF2YmVzY2RwaWh2eWZ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1NTQ5OTMsImV4cCI6MjA2OTEzMDk5M30.OpIs65YShePgpV2KG4Uqjpkj3RDNv12Rj9eLudveWQY"

Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    FCM TEST NOTIFICATION SENDER" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($FcmToken -eq "") {
    Write-Host "⚠️  No FCM token provided!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\test_fcm.ps1 <FCM_TOKEN>" -ForegroundColor Gray
    Write-Host "  .\test_fcm.ps1 <FCM_TOKEN> -Command 'open_gate'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Example:" -ForegroundColor White
    Write-Host "  .\test_fcm.ps1 'dXYz...' -Command 'test'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Available commands: test, open_gate" -ForegroundColor Gray
    exit 1
}

Write-Host "📱 FCM Token: $($FcmToken.Substring(0, [Math]::Min(50, $FcmToken.Length)))..." -ForegroundColor White
Write-Host "📋 Command: $Command" -ForegroundColor White
Write-Host "🌐 Edge Function: $EdgeFunctionUrl" -ForegroundColor White
Write-Host ""

# Prepare request body
$body = @{
    deviceId = "default"
    command = $Command
    commandId = [int](Get-Random -Minimum 90000 -Maximum 99999)
} | ConvertTo-Json

Write-Host "📤 Sending test notification..." -ForegroundColor Yellow
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri $EdgeFunctionUrl `
        -Method Post `
        -Headers @{
            "Authorization" = "Bearer $AnonKey"
            "Content-Type" = "application/json"
        } `
        -Body $body `
        -ErrorAction Stop
    
    Write-Host "✅ SUCCESS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor White
    Write-Host ($response | ConvertTo-Json -Depth 5) -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔔 Check your device for the notification!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ ERROR!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
