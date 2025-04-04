# Inicializa contadores e variáveis
$passo = 1
$resultadosWin10 = @()
$resultadosWin11 = @()
$requisitosWin11 = @()

function Show-Result {
    param (
        [int]$numero,
        [string]$descricao,
        [bool]$ok,
        [string]$detalhe
    )

    $status = if ($ok) { "OK" } else { "NOK" }
    $linha = "Passo $numero - ${descricao}: $status $detalhe"
    Write-Output $linha
    $global:resultadosWin10 += $ok
}

Clear-Host
Write-Host "`nValidando ambiente para atualização do Windows 10..." -ForegroundColor Cyan
Write-Host "------------------------------------------------------`n"

# Passo 1: Espaço em disco
$espaco = (Get-PSDrive C).Free / 1GB
$ok = $espaco -ge 20
$detalhe = "(Espaço livre: {0:N2} GB)" -f $espaco
$numero = $passo; $passo++
Show-Result -numero $numero -descricao "Verificar espaço livre em disco (mínimo 20 GB)" -ok $ok -detalhe $detalhe

# Passo 2: Windows Update
$wuserv = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
$ok = $wuserv.Status -eq "Running"
$detalhe = "(Status: $($wuserv.Status))"
$numero = $passo; $passo++
Show-Result -numero $numero -descricao "Verificar se o Windows Update está em execução" -ok $ok -detalhe $detalhe

# Passo 3: Reinicialização pendente
$rebootPending = Get-ItemProperty "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending" -ErrorAction SilentlyContinue
$ok = ($null -eq $rebootPending)
$detalhe = if ($ok) { "" } else { "(Reinicialização pendente detectada)" }
$numero = $passo; $passo++
Show-Result -numero $numero -descricao "Verificar se há reinicialização pendente" -ok $ok -detalhe $detalhe

# Passo 4: Verificação SFC
$sfcResult = sfc /scannow
$ok = $sfcResult -like "*100%*"
$detalhe = if ($ok) { "" } else { "(Erro na verificação SFC)" }
$numero = $passo; $passo++
Show-Result -numero $numero -descricao "Verificar integridade dos arquivos do sistema (SFC)" -ok $ok -detalhe $detalhe

# Passo 5: Secure Boot
$sbstatus = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
$ok = $sbstatus -eq $true
$detalhe = if ($ok) { "" } else { "(Secure Boot desativado ou não suportado)" }
$numero = $passo; $passo++
Show-Result -numero $numero -descricao "Verificar se o Secure Boot está ativado (UEFI)" -ok $ok -detalhe $detalhe

# Passo 6: Versão do Windows
$versao = (Get-ItemProperty "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion").ReleaseId
$ok = [int]$versao -ge 1909
$detalhe = "(Versão atual: $versao)"
$numero = $passo; $passo++
Show-Result -numero $numero -descricao "Verificar se a versão do Windows é 1909 ou superior" -ok $ok -detalhe $detalhe

# Passo 7: BitLocker
$bitlocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
$ok = $bitlocker.ProtectionStatus -eq "Off"
$detalhe = "(Proteção BitLocker: $($bitlocker.ProtectionStatus))"
$numero = $passo; $passo++
Show-Result -numero $numero -descricao "Verificar se o BitLocker está desativado na unidade C:" -ok $ok -detalhe $detalhe

# RESULTADO FINAL - Windows 10
Write-Host "`n------------------------------------------------------"
if ($resultadosWin10 -contains $false) {
    Write-Host "❌ O sistema **NÃO** está pronto para atualização do Windows 10 sem formatação." -ForegroundColor Red
} else {
    Write-Host "✅ O sistema está pronto para atualizar para o Windows 10 sem formatação." -ForegroundColor Green
}

# ------------------------------------------
# VALIDAR REQUISITOS PARA WINDOWS 11
# ------------------------------------------

Write-Host "`nValidando compatibilidade para Windows 11..." -ForegroundColor Cyan
Write-Host "------------------------------------------------------`n"

function Valida-Win11 {
    param (
        [string]$descricao,
        [bool]$ok,
        [string]$detalhe
    )
    $status = if ($ok) { "OK" } else { "NOK" }
    $linha = "${descricao}: $status $detalhe"
    Write-Output $linha
    $global:resultadosWin11 += $ok
    if (-not $ok) { $global:requisitosWin11 += "$descricao $detalhe" }
}

# Espaço mínimo
$ok = $espaco -ge 64
$detalhe = "(Espaço livre: {0:N2} GB)" -f $espaco
Valida-Win11 -descricao "Espaço em disco (mínimo 64 GB)" -ok $ok -detalhe $detalhe

# RAM mínima
$ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
$ok = $ram -ge 4
$detalhe = "(RAM: {0:N2} GB)" -f $ram
Valida-Win11 -descricao "Memória RAM (mínimo 4 GB)" -ok $ok -detalhe $detalhe

# TPM 2.0
$tpm = Get-WmiObject -Namespace "Root\\CIMv2\\Security\\MicrosoftTpm" -Class Win32_Tpm -ErrorAction SilentlyContinue
$ok = $tpm.SpecVersion -like "*2.0*"
$detalhe = if ($ok) { "(TPM: $($tpm.SpecVersion))" } else { "(TPM 2.0 não detectado)" }
Valida-Win11 -descricao "TPM 2.0" -ok $ok -detalhe $detalhe

# Processador compatível
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$ok = $cpu.AddressWidth -eq 64
$detalhe = "(CPU: $($cpu.Name), 64 bits: $($cpu.AddressWidth -eq 64))"
Valida-Win11 -descricao "Processador 64 bits" -ok $ok -detalhe $detalhe

# DirectX 12 com WDDM 2.0 (simplificado)
$dx = Get-ItemProperty "HKLM:\\SOFTWARE\\Microsoft\\DirectX" -ErrorAction SilentlyContinue
$ok = $dx.Version -ge "4.09.00.0904"
$detalhe = "(DirectX Version: $($dx.Version))"
Valida-Win11 -descricao "Compatibilidade gráfica (DirectX 12 / WDDM 2.0)" -ok $ok -detalhe $detalhe

# Secure Boot (já avaliado antes)
Valida-Win11 -descricao "Secure Boot Ativado" -ok $sbstatus -detalhe ""

# UEFI (presença do firmware UEFI)
$firmware = (Get-ComputerInfo -Property "BiosFirmwareType").BiosFirmwareType
$ok = $firmware -eq "UEFI"
$detalhe = "(Firmware: $firmware)"
Valida-Win11 -descricao "Firmware UEFI" -ok $ok -detalhe $detalhe

# RESULTADO FINAL - Windows 11
Write-Host "`n------------------------------------------------------"
if ($resultadosWin11 -contains $false) {
    Write-Host "❌ O sistema NÃO está pronto para Windows 11." -ForegroundColor Red
    Write-Host "Itens a corrigir para instalar o Windows 11:`n" -ForegroundColor Yellow
    foreach ($item in $requisitosWin11) {
        Write-Host "- $item" -ForegroundColor DarkYellow
    }
    Write-Host "`n⚠️ Provavelmente será necessário FORMATAR para atualizar para o Windows 11." -ForegroundColor Red
} else {
    Write-Host "✅ O sistema está PRONTO para atualizar para o Windows 11!" -ForegroundColor Green
    Write-Host "✔️ Você pode fazer a atualização sem precisar formatar." -ForegroundColor Green
}
Write-Host "------------------------------------------------------"
