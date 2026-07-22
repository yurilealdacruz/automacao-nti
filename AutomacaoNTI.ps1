# ============================================================================
#  AUTOMAÇÃO NTI - SENAI CIMATEC / FIEB
#  yurilealdacruz.github.io
#
#  ESTE ARQUIVO É O FONTE. O QUE CIRCULA NOS PENDRIVES É O .EXE COMPILADO
#  COM Win-PS2EXE. O sistema de atualização baixa o .EXE, não o .ps1.
#
#  COMO CONFIGURAR O SISTEMA DE ATUALIZAÇÃO (leia antes de distribuir):
#   1. Crie um repositório no GitHub — recomendado deixar PÚBLICO (veja
#      motivo abaixo). Ex: "automacao-nti"
#   2. Crie um arquivo "version.txt" na raiz do repo, contendo SÓ o número
#      da versão, ex: 1.1.0  (esse arquivo é consultado toda vez que o
#      programa abre, por isso fica em raw.githubusercontent.com — leve,
#      cacheado, sem limite de requisições)
#   3. Compile este .ps1 com Win-PS2EXE gerando "AutomacaoNTI.exe"
#   4. No GitHub, crie uma Release com a tag "v1.1.0" (mesma versão do
#      version.txt) e anexe o AutomacaoNTI.exe como asset da release
#   5. Ajuste $repoOwner e $repoName logo abaixo
#   6. A cada atualização: recompile, suba uma nova Release com a tag nova
#      e atualize o version.txt — nessa ordem os colegas passam a ver o
#      botão "Baixar" automaticamente
#
#  POR QUE REPOSITÓRIO PÚBLICO: o .exe compilado com PS2EXE não é
#  ofuscado de verdade — o script embutido é extraível com ferramentas
#  simples. Como o .exe já circula inteiro nos pendrives dos colegas,
#  deixar o repo privado não esconde nada que eles já não tenham; só
#  complica o download (exigiria token, que também seria extraível do
#  .exe). Nenhuma credencial de domínio fica no código — é digitada em
#  tempo de execução — então não há segredo real para proteger aqui.
#
#  Obs: o raw.githubusercontent.com tem um cache de alguns minutos, então
#  depois de subir uma atualização pode levar um tempinho pra propagar.
# ============================================================================

# 1. Garante que o script está rodando como Administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    [System.Windows.Forms.MessageBox]::Show("Por favor, execute este script como ADMINISTRADOR.", "Erro de Privilégio", 0, 16)
    exit
}

# Define o local do script
$CaminhoAtual = $PSScriptRoot
if ([string]::IsNullOrEmpty($CaminhoAtual)) { $CaminhoAtual = Get-Location }

# Carrega as bibliotecas visuais do Windows
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ================== CONFIGURAÇÕES GLOBAIS ==================
$localVersion = "1.1.0"

# --- Sistema de atualização via GitHub ---
# TODO: troque pelos dados do SEU repositório
$repoOwner         = "yurilealdacruz"
$repoName          = "automacao-nti"
$repoBranch        = "main"
$updateCheckUrl = "https://raw.githubusercontent.com/$repoOwner/$repoName/refs/heads/$repoBranch/Version.txt"

# URL de download do .exe publicado como asset de uma Release do GitHub.
# Não usa a API do GitHub (api.github.com) de propósito: a API tem limite de
# 60 requisições/hora por IP para chamadas sem autenticação, e várias máquinas
# formatando na mesma rede/IP da escola poderiam bater nesse limite. Essa URL
# é montada direto a partir da versão lida do version.txt, sem chamar a API.
$updateDownloadUrlTemplate = "https://github.com/$repoOwner/$repoName/raw/refs/heads/main/AutomacaoNTI.exe"

# --- Configuração local salva (usuário / domínio / senha opcional) ---
$configPath = Join-Path $CaminhoAtual "config.json"

# Lista de domínios disponíveis para seleção
$dominiosDisponiveis = @("senaicimatec.edu.br", "fieb.org.br")

# --- FUNÇÕES DE AÇÃO ---

function Limpar-UsuariosLocais {
    $txtLog.AppendText("Limpando usuários locais...`r`n")
    $usersToDisable = "nti", "cimatec", "adm", "cimatecnti", "cimatec-nti", "YuriLeal"
    foreach ($u in $usersToDisable) {
        Disable-LocalUser -Name $u -ErrorAction SilentlyContinue
    }
    Enable-LocalUser -Name "Administrador" -ErrorAction SilentlyContinue
    $txtLog.AppendText("[✓] Usuários locais processados.`r`n")
}

function Ingressar-Dominio {
    $novo_nome = $inputNomePC.Text
    $usuario = $inputUsuario.Text
    $senha = $inputSenha.Text
    $dominioEscolhido = $comboDominio.SelectedItem

    if ([string]::IsNullOrEmpty($novo_nome) -or [string]::IsNullOrEmpty($usuario) -or [string]::IsNullOrEmpty($senha) -or [string]::IsNullOrEmpty($dominioEscolhido)) {
        [System.Windows.Forms.MessageBox]::Show("Preencha todos os campos e selecione o domínio!", "Aviso", 0, 48)
        return
    }

    try {
        $txtLog.AppendText("Verificando status do computador...`r`n")
        $sysInfo = Get-CimInstance Win32_ComputerSystem

        # Criar credencial segura a partir do input da janela
        $secSenha = ConvertTo-SecureString $senha -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ("$dominioEscolhido\$usuario", $secSenha)

        if ($sysInfo.PartOfDomain -and $sysInfo.Domain -eq $dominioEscolhido) {
            $txtLog.AppendText("O PC já está no domínio $dominioEscolhido. Alterando apenas o nome... (Reiniciando em breve)`r`n")
            Rename-Computer -NewName $novo_nome -DomainCredential $credential -Force -Restart
        }
        else {
            $txtLog.AppendText("Ingressando no domínio $dominioEscolhido e alterando nome... (Reiniciando em breve)`r`n")
            Add-Computer -DomainName $dominioEscolhido -NewName $novo_nome -Credential $credential -Force -Restart
        }
    }
    catch {
        $txtLog.AppendText("ERRO CRÍTICO: $($_.Exception.Message)`r`n")
    }
}

function Instalar-Force1 {
    $txtLog.AppendText("Iniciando instalação do Force 1...`r`n")
    $setupPath = Join-Path $CaminhoAtual "setup.exe"

    if (Test-Path $setupPath) {
        $txtLog.AppendText("Executando: $setupPath`r`n")
        Start-Process -FilePath $setupPath -ArgumentList "/qn", "ENTERPRISE_NAME=fieb" -Wait
        $txtLog.AppendText("[✓] Instalação concluída!`r`n")
    } else {
        $txtLog.AppendText("ERRO: Arquivo setup.exe não encontrado em: $CaminhoAtual`r`n")
    }
}

# --- PERSISTÊNCIA DE CONFIGURAÇÃO (SALVAR / CARREGAR) ---

function Salvar-Config {
    $senhaOfuscada = ""
    if ($chkLembrarSenha.Checked -and $inputSenha.Text -ne "") {
        # ATENÇÃO: Base64 NÃO é criptografia, é apenas codificação reversível.
        # Qualquer pessoa com acesso ao config.json consegue decodificar a senha.
        # Use com cautela e nunca suba esse arquivo para repositórios públicos.
        $senhaOfuscada = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($inputSenha.Text))
    }

    $config = [PSCustomObject]@{
        Dominio       = $comboDominio.SelectedItem
        Usuario       = $inputUsuario.Text
        LembrarSenha  = $chkLembrarSenha.Checked
        SenhaOfuscada = $senhaOfuscada
    }

    try {
        $config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8
        $txtLog.AppendText("[✓] Dados salvos (usuário/domínio" + $(if ($chkLembrarSenha.Checked) { "/senha" } else { "" }) + "). Não será preciso digitar de novo nesta máquina/pendrive.`r`n")
    } catch {
        $txtLog.AppendText("ERRO ao salvar configuração: $($_.Exception.Message)`r`n")
    }
}

function Carregar-Config {
    if (Test-Path $configPath) {
        try {
            $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

            if ($config.Dominio -and $dominiosDisponiveis -contains $config.Dominio) {
                $comboDominio.SelectedItem = $config.Dominio
            }
            if ($config.Usuario) { $inputUsuario.Text = $config.Usuario }
            if ($config.LembrarSenha) {
                $chkLembrarSenha.Checked = $true
                if ($config.SenhaOfuscada) {
                    $inputSenha.Text = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($config.SenhaOfuscada))
                }
            }
            $txtLog.AppendText("[i] Configuração salva anteriormente foi carregada.`r`n")
        } catch {
            $txtLog.AppendText("[i] Não foi possível carregar config.json (arquivo pode estar corrompido).`r`n")
        }
    } else {
        $txtLog.AppendText("[i] Nenhuma configuração salva encontrada (primeira execução).`r`n")
    }
}

# --- SISTEMA DE ATUALIZAÇÃO ---

function Verificar-Atualizacao {
    try {
        $txtLog.AppendText("Verificando atualizações...`r`n")
        $remoteVersion = (Invoke-RestMethod -Uri $updateCheckUrl -TimeoutSec 5 -ErrorAction Stop).ToString().Trim()

        if ([version]$remoteVersion -gt [version]$localVersion) {
            $txtLog.AppendText("[!] Nova versão disponível: $remoteVersion (atual: $localVersion)`r`n")
            $lblUpdate.Text = "🔔 Nova versão $remoteVersion disponível!"
            $lblUpdate.Visible = $true
            $btnUpdate.Visible = $true
            $btnUpdate.Tag = $remoteVersion
        } else {
            $txtLog.AppendText("[✓] Você já está na versão mais recente ($localVersion).`r`n")
            $lblUpdate.Visible = $false
            $btnUpdate.Visible = $false
        }
    } catch {
        $txtLog.AppendText("[i] Não foi possível verificar atualizações (sem internet ou repositório indisponível).`r`n")
    }
}

function Baixar-Atualizacao {
    try {
        $novaVersao = $btnUpdate.Tag
        $downloadUrl = $updateDownloadUrlTemplate -f $novaVersao

        # Pega o caminho real do .exe em execução (funciona mesmo compilado
        # com PS2EXE — $MyInvocation.MyCommand.Path não é confiável nesse caso)
        $exeAtual = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $pastaAtual = Split-Path $exeAtual -Parent
        $exeNovo = Join-Path $pastaAtual "AutomacaoNTI_novo.exe"

        $txtLog.AppendText("Baixando versão $novaVersao...`r`n")
        Invoke-WebRequest -Uri $downloadUrl -OutFile $exeNovo -TimeoutSec 60 -ErrorAction Stop

        if ((Get-Item $exeNovo).Length -eq 0) {
            throw "Arquivo baixado veio vazio."
        }

        # Um .exe não consegue se autosubstituir enquanto está rodando (o
        # Windows mantém o arquivo em uso). Por isso criamos um .bat auxiliar
        # que espera este processo fechar e só então troca os arquivos.
        $batPath = Join-Path $env:TEMP "atualizar_nti.bat"
        $batContent = @"
@echo off
:espera
tasklist /FI "PID eq $PID" 2>NUL | find "$PID" >NUL
if %ERRORLEVEL%==0 (
    timeout /t 1 /nobreak >NUL
    goto espera
)
move /y "$exeNovo" "$exeAtual" >NUL
del "%~f0"
"@
        Set-Content -Path $batPath -Value $batContent -Encoding ASCII

        Start-Process -FilePath $batPath -WindowStyle Hidden

        $txtLog.AppendText("[✓] Atualização baixada. Fechando para aplicar a versão $novaVersao...`r`n")
        [System.Windows.Forms.MessageBox]::Show("Atualização baixada!`r`n`r`nO programa vai fechar agora. Em poucos segundos o arquivo será substituído automaticamente pela versão $novaVersao — é só abrir o AutomacaoNTI.exe de novo.", "Atualização concluída", 0, 64)
        $form.Close()
    } catch {
        $txtLog.AppendText("ERRO ao baixar atualização: $($_.Exception.Message)`r`n")
        [System.Windows.Forms.MessageBox]::Show("Falha ao baixar atualização:`r`n$($_.Exception.Message)", "Erro", 0, 16)
    }
}

# --- CONSTRUÇÃO DA INTERFACE GRÁFICA (GUI) ---

$form = New-Object System.Windows.Forms.Form
$form.Text = "Automação NTI - v$localVersion"
$form.Size = New-Object System.Drawing.Size(550, 650)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

# Banner do Autor / Infos
$lblBanner = New-Object System.Windows.Forms.Label
$lblBanner.Text = "yurilealdacruz.github.io`r`nAutomação de Configuração de Máquinas"
$lblBanner.Location = New-Object System.Drawing.Point(20, 15)
$lblBanner.Size = New-Object System.Drawing.Size(400, 35)
$lblBanner.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblBanner)

# --- Área de atualização ---
$btnVerificarUpdate = New-Object System.Windows.Forms.Button
$btnVerificarUpdate.Text = "🔄 Verificar Atualizações"
$btnVerificarUpdate.Location = New-Object System.Drawing.Point(20, 58)
$btnVerificarUpdate.Size = New-Object System.Drawing.Size(160, 28)
$btnVerificarUpdate.Add_Click({ Verificar-Atualizacao })
$form.Controls.Add($btnVerificarUpdate)

$lblUpdate = New-Object System.Windows.Forms.Label
$lblUpdate.Text = ""
$lblUpdate.ForeColor = [System.Drawing.Color]::DarkOrange
$lblUpdate.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblUpdate.Location = New-Object System.Drawing.Point(190, 63)
$lblUpdate.Size = New-Object System.Drawing.Size(210, 20)
$lblUpdate.Visible = $false
$form.Controls.Add($lblUpdate)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = "⬇ Baixar"
$btnUpdate.Location = New-Object System.Drawing.Point(410, 58)
$btnUpdate.Size = New-Object System.Drawing.Size(100, 28)
$btnUpdate.Visible = $false
$btnUpdate.Add_Click({ Baixar-Atualizacao })
$form.Controls.Add($btnUpdate)

# Grupo 1: Limpeza Inicial
$btnLimparUsers = New-Object System.Windows.Forms.Button
$btnLimparUsers.Text = "1. Limpar Usuários Locais"
$btnLimparUsers.Location = New-Object System.Drawing.Point(20, 95)
$btnLimparUsers.Size = New-Object System.Drawing.Size(490, 35)
$btnLimparUsers.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnLimparUsers.Add_Click({ Limpar-UsuariosLocais })
$form.Controls.Add($btnLimparUsers)

# Grupo 2: Painel de Domínio / Nome
$grpDominio = New-Object System.Windows.Forms.GroupBox
$grpDominio.Text = " Configurações de Domínio e Nome "
$grpDominio.Location = New-Object System.Drawing.Point(20, 140)
$grpDominio.Size = New-Object System.Drawing.Size(490, 215)

$lblNomePC = New-Object System.Windows.Forms.Label
$lblNomePC.Text = "Novo Nome do PC:"
$lblNomePC.Location = New-Object System.Drawing.Point(15, 28)
$lblNomePC.Size = New-Object System.Drawing.Size(120, 20)
$inputNomePC = New-Object System.Windows.Forms.TextBox
$inputNomePC.Location = New-Object System.Drawing.Point(140, 25)
$inputNomePC.Size = New-Object System.Drawing.Size(330, 20)

$lblUsuario = New-Object System.Windows.Forms.Label
$lblUsuario.Text = "Usuário do Domínio:"
$lblUsuario.Location = New-Object System.Drawing.Point(15, 58)
$lblUsuario.Size = New-Object System.Drawing.Size(120, 20)
$inputUsuario = New-Object System.Windows.Forms.TextBox
$inputUsuario.Location = New-Object System.Drawing.Point(140, 55)
$inputUsuario.Size = New-Object System.Drawing.Size(330, 20)

$lblSenha = New-Object System.Windows.Forms.Label
$lblSenha.Text = "Senha do Domínio:"
$lblSenha.Location = New-Object System.Drawing.Point(15, 88)
$lblSenha.Size = New-Object System.Drawing.Size(120, 20)
$inputSenha = New-Object System.Windows.Forms.TextBox
$inputSenha.PasswordChar = '*'
$inputSenha.Location = New-Object System.Drawing.Point(140, 85)
$inputSenha.Size = New-Object System.Drawing.Size(330, 20)

$lblDominioSel = New-Object System.Windows.Forms.Label
$lblDominioSel.Text = "Domínio:"
$lblDominioSel.Location = New-Object System.Drawing.Point(15, 118)
$lblDominioSel.Size = New-Object System.Drawing.Size(120, 20)
$comboDominio = New-Object System.Windows.Forms.ComboBox
$comboDominio.Location = New-Object System.Drawing.Point(140, 115)
$comboDominio.Size = New-Object System.Drawing.Size(200, 22)
$comboDominio.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboDominio.Items.AddRange($dominiosDisponiveis)
$comboDominio.SelectedIndex = 0

$chkLembrarSenha = New-Object System.Windows.Forms.CheckBox
$chkLembrarSenha.Text = "Lembrar senha ao salvar (fica gravada no pendrive)"
$chkLembrarSenha.Location = New-Object System.Drawing.Point(140, 142)
$chkLembrarSenha.Size = New-Object System.Drawing.Size(340, 20)

$btnDominio = New-Object System.Windows.Forms.Button
$btnDominio.Text = "Aplicar Domínio / Alterar Nome"
$btnDominio.Location = New-Object System.Drawing.Point(140, 168)
$btnDominio.Size = New-Object System.Drawing.Size(220, 28)
$btnDominio.Add_Click({ Ingressar-Dominio })

$btnSalvarConfig = New-Object System.Windows.Forms.Button
$btnSalvarConfig.Text = "💾 Salvar"
$btnSalvarConfig.Location = New-Object System.Drawing.Point(370, 168)
$btnSalvarConfig.Size = New-Object System.Drawing.Size(100, 28)
$btnSalvarConfig.Add_Click({ Salvar-Config })

$grpDominio.Controls.AddRange(@($lblNomePC, $inputNomePC, $lblUsuario, $inputUsuario, $lblSenha, $inputSenha, $lblDominioSel, $comboDominio, $chkLembrarSenha, $btnDominio, $btnSalvarConfig))
$form.Controls.Add($grpDominio)

# Grupo 3: Instalação Force 1
$btnForce1 = New-Object System.Windows.Forms.Button
$btnForce1.Text = "2. Instalar Force 1"
$btnForce1.Location = New-Object System.Drawing.Point(20, 365)
$btnForce1.Size = New-Object System.Drawing.Size(490, 35)
$btnForce1.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnForce1.Add_Click({ Instalar-Force1 })
$form.Controls.Add($btnForce1)

# Caixa de Log (Substitui o terminal para dar feedback visual)
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = "Log de Operações:"
$lblLog.Location = New-Object System.Drawing.Point(20, 410)
$lblLog.Size = New-Object System.Drawing.Size(150, 15)
$form.Controls.Add($lblLog)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.BackColor = "Black"
$txtLog.ForeColor = "White"
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.Location = New-Object System.Drawing.Point(20, 430)
$txtLog.Size = New-Object System.Drawing.Size(490, 120)
$form.Controls.Add($txtLog)

# Carrega dados salvos anteriormente (se existirem) e verifica atualização ao abrir
Carregar-Config
$form.Add_Shown({ Verificar-Atualizacao })

# Inicia a Janela
$form.ShowDialog()