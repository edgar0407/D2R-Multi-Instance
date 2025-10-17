# ==========================================
# D2R �h�}�Ұʾ�
# ==========================================

#Requires -RunAsAdministrator

# ==========================================
# �B�J 1 of 2: �b���]�w (�b���ק�)
# ==========================================
$Accounts = @(
    @{
        Username = "�b��1"
        Password = "�K�X1"
        DisplayName = "�b��1 ��ܦW�l"
        Server = "kr"
        LaunchArgs = "-mod LiYuiMod -txt -w"
    }
    @{
        Username = "�b��2"
        Password = "�K�X2"
        DisplayName = "�b��2 ��ܦW�l"
        Server = "kr"
        LaunchArgs = "-mod LiYuiMod -txt -w"
    }
)

# ==========================================
# �B�J 2 of 2: �ؿ��]�w
# ==========================================
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Handle.exe ���|
$HandleExePath = "D:\D2R�h�}\Handle\handle64.exe"
$TempFilePath = "D:\D2R�h�}\Handle\handles.txt"

# D2R �C�����|
$D2RGamePath = "D:\Diablo II Resurrected\D2R.exe"

# ��x�ؿ�
$LogDir = Join-Path $ScriptPath "logs"

# ==========================================
# ���A����}����
# ==========================================
$ServerAddresses = @{
    "us" = "us.actual.battle.net"
    "eu" = "eu.actual.battle.net"
    "kr" = "kr.actual.battle.net"
}

# ==========================================
# ���ҥ��n�ɮ�
# ==========================================
if (-not (Test-Path $HandleExePath)) {
    Write-Host "���~: �䤣�� handle64.exe�A���|: $HandleExePath" -ForegroundColor Red
    Read-Host "�� Enter ��h�X"
    exit 1
}

if (-not (Test-Path $D2RGamePath)) {
    Write-Host "���~: �䤣�� D2R �C���A���|: $D2RGamePath" -ForegroundColor Red
    Read-Host "�� Enter ��h�X"
    exit 1
}

# �إߤ�x�ؿ�
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# ==========================================
# ���: �g�J��x
# ==========================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogFile = Join-Path $LogDir "D2R_Launch_$(Get-Date -Format 'yyyyMMdd').log"
    $LogMessage = "[$Timestamp] [$Level] $Message"

    # �ϥ� mutex �קK�h�ӹ�ҦP�ɼg�J��x�ɮ׮ɵo�ͽĬ�
    try {
        $Mutex = New-Object System.Threading.Mutex($false, "D2RLauncherLogMutex")
        [void]$Mutex.WaitOne()
        Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
        $Mutex.ReleaseMutex()
        $Mutex.Dispose()
    }
    catch {
        # ������x�g�J���~
    }
}

# ==========================================
# ���: ���� D2R Handles
# ==========================================
function Close-D2RHandles {
    try {
        # ���� handle.exe �ÿ�X���{���ɮ�
        $HandleOutput = & $HandleExePath -a "Check For Other Instances" -nobanner 2>&1

        if ($LASTEXITCODE -ne 0 -and $HandleOutput -notmatch "No matching handles found") {
            Write-Log "ĵ�i: handle.exe ���沧�`" "WARNING"
        }

        # �x�s��X���ɮ�
        $HandleOutput | Out-File -FilePath $TempFilePath -Encoding UTF8

        # �ϥ� tokens=3,6 ��k�ѪR������ handles
        $CloseCount = 0
        $Lines = Get-Content $TempFilePath

        foreach ($Line in $Lines) {
            # �ΪŮ���Ψè��o�� 3 �M�� 6 �� token (ProcessID �M Handle ID)
            $Tokens = $Line -split '\s+' | Where-Object { $_ -ne '' }

            if ($Tokens.Count -ge 6) {
                $ProcessID = $Tokens[2]        # Token 3 (0-indexed = 2)
                $HandleIDRaw = $Tokens[5]      # Token 6 (0-indexed = 5)
                $HandleID = $HandleIDRaw -replace ':',''  # �����_��

                # ���� ProcessID �O�Ʀr�B HandleID �O�Q���i��
                if ($ProcessID -match '^\d+$' -and $HandleID -match '^[0-9A-Fa-f]+$') {
                    Write-Log "�o�{ handle - �i�{ ID: $ProcessID, Handle ID: $HandleID"

                    # ���� handle
                    $CloseResult = & $HandleExePath -p $ProcessID -c $HandleID -y 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "���\���� handle: $HandleID" "SUCCESS"
                        $CloseCount++
                    } else {
                        Write-Log "�L�k���� handle: $HandleID - $CloseResult" "ERROR"
                    }
                }
            }
        }

        if ($CloseCount -eq 0) {
            Write-Host "  [���A] �S���ݭn������ handles" -ForegroundColor Gray
            Write-Log "�S���o�{�ݭn������ handles"
        } else {
            Write-Host "  [���A] ���\���� $CloseCount �� handles" -ForegroundColor Green
            Write-Log "�`�@�����F $CloseCount �� handles" "SUCCESS"
        }

        return $true
    }
    catch {
        Write-Host "  [���~] ���� handles �ɵo�Ϳ��~: $_" -ForegroundColor Red
        Write-Log "���� handles �ɵo�Ϳ��~: $_" "ERROR"
        return $false
    }
}

# ==========================================
# ���: �Ұ� D2R
# ==========================================
function Start-D2R {
    param(
        [string]$Username,
        [string]$Password,
        [string]$DisplayName,
        [string]$Server = "",
        [string]$LaunchArgs = ""
    )

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "  �Ұʱb��: $DisplayName" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Cyan

    try {
        # �إߧ��㪺�ҰʰѼư}�C
        $ArgsList = @()
        $ArgsList += "-username"
        $ArgsList += $Username
        $ArgsList += "-password"
        $ArgsList += $Password

        # �[�J���A����}
        if ($Server -and $ServerAddresses.ContainsKey($Server.ToLower())) {
            $ServerAddress = $ServerAddresses[$Server.ToLower()]
            $ArgsList += "-address"
            $ArgsList += $ServerAddress
            Write-Host "  [���A��] $Server" -ForegroundColor Cyan
            Write-Log "���A��: $Server ($ServerAddress)" "INFO"
        }

        # �[�J�ۭq�ҰʰѼ�
        if ($LaunchArgs) {
            $LaunchArgs.Split(' ') | ForEach-Object {
                if ($_.Trim()) {
                    $ArgsList += $_.Trim()
                }
            }
            Write-Host "  [�ҰʰѼ�] $LaunchArgs" -ForegroundColor Cyan
            Write-Log "�ϥΰѼ�: $LaunchArgs" "INFO"
        }

        # �ҰʹC��
        Write-Host "  [�ʧ@] ���b�ҰʹC��..." -ForegroundColor White
        $ProcessInfo = Start-Process -FilePath $D2RGamePath -ArgumentList $ArgsList -PassThru

        if ($ProcessInfo) {
            Write-Host "  [���\] �C���w�Ұ� (PID: $($ProcessInfo.Id))" -ForegroundColor Green
            Write-Log "D2R �i�{�w�Ұ� - PID: $($ProcessInfo.Id)" "SUCCESS"
            Write-Log "D2R �w�Ұ� - $DisplayName" "SUCCESS"
        } else {
            Write-Host "  [ĵ�i] �L�k���o�i�{��T" -ForegroundColor Yellow
            Write-Log "�L�k���o�i�{��T" "WARNING"
        }

        # ���ݹC����l��
        Write-Host "  [����] �C����l�Ƥ� (3 ��)..." -ForegroundColor White
        Start-Sleep -Seconds 3

        # ���� handle
        Write-Host "  [�ʧ@] ��������ˬd handle..." -ForegroundColor White
        if (-not (Close-D2RHandles)) {
            Write-Host "  [ĵ�i] �L�k���� handles" -ForegroundColor Yellow
            Write-Log "�L�k���� handles" "WARNING"
        }

        # ���ݫ���Ұ�
        Write-Host "  [����] �ǳƱҰʤU�@�ӹ�� (3 ��)..." -ForegroundColor White
        Write-Host "================================================" -ForegroundColor Cyan
        Start-Sleep -Seconds 3
    }
    catch {
        Write-Host "  [���~] �Ұʥ���: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "�Ұ� D2R �ɵo�Ϳ��~: $_" "ERROR"
    }
}

# ==========================================
# �D�{��
# ==========================================
function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "         D2R �h�}�Ұʾ�" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "�i�αb��:" -ForegroundColor White
    Write-Host ""

    for ($i = 0; $i -lt $Accounts.Count; $i++) {
        Write-Host "  [$($i + 1)] $($Accounts[$i].DisplayName)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  [A] �ҰʩҦ��b��" -ForegroundColor Green
    Write-Host "  [C] �u���� Handles (���ҰʹC��)" -ForegroundColor Magenta
    Write-Host "  [Q] �h�X" -ForegroundColor Red
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
}

# �D�j��
do {
    Show-Menu
    $Choice = Read-Host "�п��"

    switch ($Choice.ToUpper()) {
        "A" {
            Write-Host ""
            Write-Host "�}�l�妸�ҰʩҦ��b��..." -ForegroundColor Green
            foreach ($Account in $Accounts) {
                Start-D2R -Username $Account.Username -Password $Account.Password -DisplayName $Account.DisplayName -Server $Account.Server -LaunchArgs $Account.LaunchArgs
            }
            Write-Host ""
            Write-Host "�Ҧ��b���w�Ұʧ����I" -ForegroundColor Green
            Read-Host "�� Enter ��^���"
        }
        "C" {
            Write-Host ""
            Write-Host "���� Handle �����@�~..." -ForegroundColor Magenta
            Close-D2RHandles
            Write-Host ""
            Read-Host "�� Enter ��^���"
        }
        "Q" {
            Write-Log "�h�X�{��"
            exit 0
        }
        default {
            if ($Choice -match '^\d+$' -and [int]$Choice -ge 1 -and [int]$Choice -le $Accounts.Count) {
                $SelectedAccount = $Accounts[[int]$Choice - 1]
                Start-D2R -Username $SelectedAccount.Username -Password $SelectedAccount.Password -DisplayName $SelectedAccount.DisplayName -Server $SelectedAccount.Server -LaunchArgs $SelectedAccount.LaunchArgs
                Write-Host ""
                Read-Host "�� Enter ��^���"
            } else {
                Write-Host ""
                Write-Host "�L�Ī��ﶵ�I�Э��s��ܡC" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
} while ($true)
