# =============================================================================
# start-ecosystem.ps1
# Script de inicializacao completa do ecossistema FIAP Cloud Games
#
# LOCALIZACAO: deve ficar dentro do repositorio OrchestrationApi
#
# PRE-REQUISITOS:
#   - Docker Desktop instalado e em execucao
#   - PowerShell 5.1 ou superior
#   - Repositorios clonados na mesma pasta pai:
#       Projeto/
#       +-- OrchestrationApi/   <- este repositorio
#       +-- UsersAPI/
#       +-- CatalogAPI/
#       +-- PaymentsAPI/
#       +-- NotificationsAPI/
#
# COMO EXECUTAR (a partir da pasta OrchestrationApi):
#   powershell -ExecutionPolicy Bypass -File ".\start-ecosystem.ps1"
# =============================================================================

$ErrorActionPreference = "Stop"

# O script esta dentro do OrchestrationApi.
# O pai do OrchestrationApi e a pasta raiz do projeto (onde ficam todos os repos).
$orchestraDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot     = Split-Path -Parent $orchestraDir
$notifDir     = Join-Path $repoRoot "NotificationsAPI"

# ------------------------------------------------------------------------------
# Funcoes auxiliares
# ------------------------------------------------------------------------------

function Write-Step {
    param([string]$Numero, [string]$Descricao)
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  ETAPA $Numero - $Descricao" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
}

function Write-Ok   { param([string]$Msg) Write-Host "  [OK] $Msg"   -ForegroundColor Green  }
function Write-Info { param([string]$Msg) Write-Host "  [..] $Msg"   -ForegroundColor Yellow }
function Write-Erro { param([string]$Msg) Write-Host "  [ERRO] $Msg" -ForegroundColor Red    }

function Wait-UrlOk {
    param(
        [string]$Url,
        [string]$Servico,
        [int]$MaxTentativas = 30,
        [int]$IntervaloSeg  = 3
    )
    Write-Info "Aguardando $Servico ficar disponivel..."
    for ($i = 1; $i -le $MaxTentativas; $i++) {
        try {
            $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($resp.StatusCode -lt 500) {
                Write-Ok "$Servico disponivel."
                return
            }
        }
        catch { }
        Write-Host "    tentativa $i/$MaxTentativas..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $IntervaloSeg
    }
    Write-Erro "$Servico nao respondeu em tempo. Verifique: docker logs [nome-do-container]"
    exit 1
}

function Wait-RabbitMq {
    $auth    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin"))
    $headers = @{ Authorization = "Basic $auth" }
    Write-Info "Aguardando RabbitMQ ficar disponivel..."
    for ($i = 1; $i -le 30; $i++) {
        try {
            Invoke-RestMethod -Method GET `
                -Uri "http://localhost:15672/api/overview" `
                -Headers $headers `
                -ErrorAction Stop | Out-Null
            Write-Ok "RabbitMQ disponivel."
            return
        }
        catch { }
        Write-Host "    tentativa $i/30..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
    }
    Write-Erro "RabbitMQ nao ficou pronto. Verifique: docker logs rabbitmq"
    exit 1
}

function Wait-LocalStack {
    Write-Info "Aguardando LocalStack ficar disponivel..."
    for ($i = 1; $i -le 40; $i++) {
        try {
            $health = Invoke-RestMethod `
                -Uri "http://localhost:4566/_localstack/health" `
                -ErrorAction Stop
            $lambdaStatus = $health.services.lambda
            Write-Host "    tentativa $i/40 - lambda status: $lambdaStatus" -ForegroundColor DarkGray
            if ($lambdaStatus -eq "running" -or $lambdaStatus -eq "available") {
                Write-Ok "LocalStack disponivel (Lambda: $lambdaStatus)."
                return
            }
        }
        catch {
            Write-Host "    tentativa $i/40 - sem resposta ainda..." -ForegroundColor DarkGray
        }
        Start-Sleep -Seconds 5
    }
    Write-Host ""
    Write-Host "  Diagnostico - logs do LocalStack:" -ForegroundColor Yellow
    docker logs localstack --tail 30
    Write-Erro "LocalStack nao ficou pronto em tempo."
    exit 1
}

function Wait-Kong {
    Write-Info "Aguardando Kong ficar disponivel..."
    for ($i = 1; $i -le 30; $i++) {
        try {
            $resp = Invoke-RestMethod `
                -Uri "http://localhost:8001/status" `
                -ErrorAction Stop
            if ($resp.database.reachability -eq "UNKNOWN" -or $resp.database -ne $null -or $resp -ne $null) {
                Write-Ok "Kong disponivel (Admin API: http://localhost:8001)."
                return
            }
        }
        catch { }
        Write-Host "    tentativa $i/30..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
    }
    Write-Erro "Kong nao ficou pronto. Verifique: docker logs kong"
    exit 1
}

# ==============================================================================
# ETAPA 1 - Verificar pre-requisitos
# ==============================================================================
Write-Step "1" "Verificando pre-requisitos"

try {
    docker info | Out-Null
    Write-Ok "Docker Desktop esta em execucao."
}
catch {
    Write-Erro "Docker Desktop nao esta em execucao. Inicie o Docker Desktop e tente novamente."
    exit 1
}

if (-not (Test-Path $notifDir)) {
    Write-Erro "Repositorio NotificationsAPI nao encontrado em: $notifDir"
    Write-Host "  Certifique-se de que todos os repositorios estao clonados na mesma pasta pai." -ForegroundColor Yellow
    exit 1
}

Write-Ok "Repositorio NotificationsAPI encontrado."

# ==============================================================================
# ETAPA 2 - Limpeza do ambiente anterior
# ==============================================================================
Write-Step "2" "Limpando ambiente anterior"

Write-Info "Derrubando stack do docker-compose (se houver) e removendo orfaos..."
Set-Location $orchestraDir
docker compose down -v --remove-orphans | Out-Null

Write-Info "Forcando remocao de containers ativos que podem causar conflito de nome..."
$running = docker ps -a -q
if ($running) {
    docker rm -f $running | Out-Null
}
Write-Ok "Containers removidos."

Write-Info "Removendo imagens, volumes e redes Docker nao utilizadas..."
docker system prune -a --volumes -f
Write-Ok "Docker limpo."

Write-Info "Limpando recursos do Kubernetes..."
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
kubectl delete all --all 2>&1 | Out-Null
$kubectlExit = $LASTEXITCODE
$ErrorActionPreference = $prevEAP
if ($kubectlExit -eq 0) {
    Write-Ok "Kubernetes limpo."
} else {
    Write-Host "  [AVISO] kubectl sem contexto ativo ou nao instalado - etapa ignorada." -ForegroundColor DarkYellow
}

# ==============================================================================
# ETAPA 3 - Subir infraestrutura e microsservicos via docker-compose
# ==============================================================================
Write-Step "3" "Subindo infraestrutura e microsservicos"

Write-Info "Executando docker compose up --build (pode demorar alguns minutos na primeira vez)..."
Set-Location $orchestraDir
docker compose up --build -d

if ($LASTEXITCODE -ne 0) {
    Write-Erro "Falha no docker compose up. Verifique os logs acima."
    exit 1
}

Write-Ok "docker compose iniciado."

# ==============================================================================
# ETAPA 4 - Aguardar servicos essenciais
# ==============================================================================
Write-Step "4" "Aguardando servicos essenciais ficarem prontos"

Wait-RabbitMq
Wait-LocalStack
Wait-UrlOk -Url "http://localhost:5001/swagger" -Servico "UsersAPI"
Wait-UrlOk -Url "http://localhost:5002/swagger" -Servico "CatalogAPI"
Wait-UrlOk -Url "http://localhost:5003/swagger" -Servico "PaymentsAPI"
Wait-Kong

# ==============================================================================
# ETAPA 5 - Deploy da Lambda no LocalStack
# ==============================================================================
Write-Step "5" "Deploy da Lambda NotificationsAPI no LocalStack"

Set-Location $notifDir
Write-Info "Executando build-deploy-localstack.ps1..."
powershell -ExecutionPolicy Bypass -File ".\scripts\build-deploy-localstack.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Erro "Falha no deploy da Lambda. Verifique os logs acima."
    exit 1
}

Write-Ok "Lambda notifications-api-function deployada no LocalStack."

# ==============================================================================
# ETAPA 6 - Iniciar o trigger RabbitMQ -> Lambda em nova janela
# ==============================================================================
Write-Step "6" "Iniciando trigger RabbitMQ -> Lambda"

Write-Info "Abrindo nova janela para o trigger (mantenha-a aberta durante os testes)..."

$triggerScript = Join-Path $notifDir "scripts\start-rabbitmq-lambda-trigger.ps1"
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$triggerScript`""

Write-Ok "Trigger iniciado em nova janela do PowerShell."

# ==============================================================================
# ETAPA 7 - Resumo final
# ==============================================================================
Write-Step "7" "Ecossistema operante - URLs de acesso"

Write-Host ""
Write-Host "  API GATEWAY (Kong)" -ForegroundColor White
Write-Host "  Kong Proxy    -> http://localhost:8000  (entrada unica para UsersAPI e CatalogAPI)" -ForegroundColor Green
Write-Host "  Kong Admin    -> http://localhost:8001  (consultar rotas e plugins)" -ForegroundColor Green
Write-Host "  Kong Manager  -> http://localhost:8002  (interface web)" -ForegroundColor Green
Write-Host ""
Write-Host "  MICROSSERVICOS (Swagger - acesso direto)" -ForegroundColor White
Write-Host "  UsersAPI    -> http://localhost:5001/swagger" -ForegroundColor Green
Write-Host "  CatalogAPI  -> http://localhost:5002/swagger" -ForegroundColor Green
Write-Host "  PaymentsAPI -> http://localhost:5003/swagger" -ForegroundColor Green
Write-Host ""
Write-Host "  MENSAGERIA E BANCO" -ForegroundColor White
Write-Host "  RabbitMQ      -> http://localhost:15672  (admin / admin)" -ForegroundColor Green
Write-Host "  Mongo-Express -> http://localhost:8081   (admin / admin)" -ForegroundColor Green
Write-Host ""
Write-Host "  OBSERVABILIDADE" -ForegroundColor White
Write-Host "  Prometheus -> http://localhost:9090" -ForegroundColor Green
Write-Host "  Grafana    -> http://localhost:3000  (admin / admin)" -ForegroundColor Green
Write-Host ""
Write-Host "  SERVERLESS" -ForegroundColor White
Write-Host "  LocalStack -> http://localhost:4566/_localstack/health" -ForegroundColor Green
Write-Host "  Lambda deployada: notifications-api-function" -ForegroundColor Green
Write-Host ""
Write-Host "  TESTE END-TO-END (opcional)" -ForegroundColor White
Write-Host "  cd $notifDir" -ForegroundColor DarkGray
Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\send-test-messages.ps1" -ForegroundColor DarkGray
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Ecossistema iniciado com sucesso!" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
