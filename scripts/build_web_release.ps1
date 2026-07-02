param(
    [ValidateSet("hostinger", "github", "local")]
    [string]$Target = "hostinger",
    [string]$BaseHref = "",
    [switch]$Serve
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

if (-not (Test-Path ".env")) {
    Write-Error "Falta .env en la raiz del proyecto. Copia .env.example y configura SUPABASE_URL y SUPABASE_ANON_KEY."
}

if ([string]::IsNullOrWhiteSpace($BaseHref)) {
    $BaseHref = switch ($Target) {
        "github" { "/Banca-LosAndes-Ventas/" }
        default { "/" }
    }
}

Write-Host ">> Flutter web release [$Target] (base-href: $BaseHref)" -ForegroundColor Cyan
flutter pub get
flutter build web `
    --release `
    --base-href $BaseHref `
    --no-wasm-dry-run

$outDir = Join-Path $Root "build\web"
Copy-Item (Join-Path $Root "web\.htaccess") (Join-Path $outDir ".htaccess") -Force
Copy-Item (Join-Path $outDir "index.html") (Join-Path $outDir "404.html") -Force

$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$zipName = switch ($Target) {
    "hostinger" { "ventas-hostinger-$stamp.zip" }
    "github" { "ventas-github-pages-$stamp.zip" }
    default { "ventas-web-$stamp.zip" }
}
$zipPath = Join-Path $Root "dist\$zipName"
New-Item -ItemType Directory -Force -Path (Split-Path $zipPath) | Out-Null
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$outDir\*" -DestinationPath $zipPath

Write-Host ""
Write-Host "Build listo:" -ForegroundColor Green
Write-Host "  Carpeta: $outDir"
Write-Host "  ZIP:     $zipPath"
Write-Host ""

switch ($Target) {
    "hostinger" {
        Write-Host "Despliegue en Hostinger:" -ForegroundColor Yellow
        Write-Host "  1. Sube el contenido de build\web (o el ZIP) a public_html"
        Write-Host "  2. Debe quedar: public_html/index.html, main.dart.js, assets/, .htaccess"
        Write-Host "  3. Si usas subcarpeta (ej. /ventas/), rebuild con:"
        Write-Host "     .\scripts\build_web_release.ps1 -Target hostinger -BaseHref '/ventas/'"
        Write-Host "  4. En Supabase Auth agrega tu dominio Hostinger como Site URL y Redirect URL"
    }
    "github" {
        Write-Host "GitHub Pages:" -ForegroundColor Yellow
        Write-Host "  URL: https://axltech25.github.io/Banca-LosAndes-Ventas/"
    }
    default {
        Write-Host "Preview local:" -ForegroundColor Yellow
        Write-Host "  .\scripts\build_web_release.ps1 -Target local -Serve"
    }
}

if ($Serve) {
    Write-Host ""
    Write-Host "Sirviendo en http://localhost:8080 ..." -ForegroundColor Cyan
    Set-Location $outDir
    python -m http.server 8080
}
