# ================================
# DevBoost Pro Max Setup Script
# ================================

# Bypass execution policy (you already did this)
# Set-ExecutionPolicy Bypass -Scope Process

# Check Node.js
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host 'Node.js not found. Please install it from https://nodejs.org/'
    exit
}

# Install VSCE if not installed
if (!(Get-Command vsce -ErrorAction SilentlyContinue)) {
    npm install -g @vscode/vsce
}

# -------------------------------
# Base directories
# -------------------------------
$base = Join-Path -Path $PWD -ChildPath "devboost-pro-max"
$snippetsDir = Join-Path -Path $base -ChildPath "snippets"
$emmetDir = Join-Path -Path $base -ChildPath "emmet"

# Create directories
New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path $snippetsDir | Out-Null
New-Item -ItemType Directory -Force -Path $emmetDir | Out-Null

# -------------------------------
# Function to write JSON (UTF8)
# -------------------------------
function Write-Json($Path, $Object) {
    $json = $Object | ConvertTo-Json -Depth 20
    $json | Out-File -FilePath $Path -Encoding UTF8
}

# -------------------------------
# package.json
# -------------------------------
$package = @{
    name = 'devboost-pro-max'
    displayName = 'DevBoost Pro Max'
    description = 'Ultimate VSCode booster: HTML/CSS/JS + React + Tailwind + Next.js + Zod + Emmet + Prettier + keybindings'
    version = '1.0.0'
    publisher = 'keopiii'
    license = 'MIT'
    repository = @{
        type = 'git'
        url = 'https://github.com/keopiii/devboost-pro-max.git'
    }
    engines = @{
        vscode = '^1.60.0'
    }
    categories = @('Snippets','Other')
    contributes = @{
        snippets = @(@{language='*'; path='./snippets/all-snippets.json'})
        keybindings = @(
            @{ key='ctrl+alt+q'; command='editor.action.insertSnippet'; when='editorTextFocus'; args=@{ name='Console Log' } },
            @{ key='ctrl+alt+a'; command='editor.action.insertSnippet'; when='editorTextFocus'; args=@{ name='Async Function' } },
            @{ key='ctrl+alt+r'; command='editor.action.insertSnippet'; when='editorTextFocus'; args=@{ name='React FC' } },
            @{ key='ctrl+alt+t'; command='editor.action.insertSnippet'; when='editorTextFocus'; args=@{ name='Tailwind Button' } },
            @{ key='ctrl+alt+h'; command='editor.action.insertSnippet'; when='editorTextFocus'; args=@{ name='HTML5 Boilerplate' } },
            @{ key='ctrl+alt+c'; command='editor.action.insertSnippet'; when='editorTextFocus'; args=@{ name='Flex Center' } },
            @{ key='ctrl+alt+f'; command='editor.action.formatDocument'; when='editorTextFocus' }
        )
    }
}

Write-Json -Path (Join-Path $base 'package.json') -Object $package

# -------------------------------
# all-snippets.json
# -------------------------------
$snippets = @{
    'HTML5 Boilerplate' = @{ prefix='html5'; body=@('<!DOCTYPE html>','<html lang="en">','<head>','  <meta charset="UTF-8">','  <meta name="viewport" content="width=device-width, initial-scale=1.0">','  <title>${1:Document}</title>','</head>','<body>$0</body>','</html>'); description='HTML5 Boilerplate' }
    'Console Log' = @{ prefix='clg'; body=@('console.log($1);'); description='Console log' }
    'Async Function' = @{ prefix='afn'; body=@('async function ${1:name}(${2:params}) {','  $0','}'); description='Async function' }
    'React FC' = @{ prefix='rfc'; body=@('import React from "react";','const ${1:Component}=(${2:props}) => {','  $0','  return (<div class="p-4 bg-gray-100 rounded shadow">$3</div>);','};','export default ${1:Component};'); description='React Functional Component' }
    'Tailwind Button' = @{ prefix='twbtn'; body=@('<button class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded">$0</button>'); description='Tailwind Button' }
}

Write-Json -Path (Join-Path $snippetsDir 'all-snippets.json') -Object $snippets

# -------------------------------
# Emmet
# -------------------------------
$emmet = @{
    html = @{
        snippets = @{
            navul='<nav><ul><li>$1</li></ul></nav>'
            section='<section>$1</section>'
            article='<article>$1</article>'
        }
    }
}

Write-Json -Path (Join-Path $emmetDir 'emmet.json') -Object $emmet

# -------------------------------
# settings.json
# -------------------------------
$settings = @{
    'editor.formatOnSave' = $true
    'editor.defaultFormatter' = 'esbenp.prettier-vscode'
    'emmet.includeLanguages' = @{ 'javascript' = 'javascriptreact' }
    'emmet.showSuggestionsAsSnippets' = $true
    'emmet.triggerExpansionOnTab' = $true
    'editor.snippetSuggestions' = 'top'
}

Write-Json -Path (Join-Path $base 'settings.json') -Object $settings

# -------------------------------
# Prettier config
# -------------------------------
'{ "semi": false, "singleQuote": true, "tabWidth": 2, "trailingComma": "es5" }' | Out-File -FilePath (Join-Path $base 'prettierrc') -Encoding UTF8

# -------------------------------
# README.md
# -------------------------------
'# DevBoost Pro Max 🚀`nUltimate Godspeed Package for VSCode`nIncludes 50+ snippets: React, Tailwind, Next.js, Zod, Emmet, Prettier, custom React Hooks, and keybindings.' | Out-File -FilePath (Join-Path $base 'README.md') -Encoding UTF8

# -------------------------------
# Create VSIX
# -------------------------------
Push-Location $base
vsce package
Pop-Location

# -------------------------------
# Create ZIP backup
# -------------------------------
$zipFile = Join-Path $PWD 'devboost-pro-max.zip'
if (Test-Path $zipFile) { Remove-Item $zipFile }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($base, $zipFile)

Write-Host '✅ Pro-Max VSIX and ZIP created successfully!'
Pause
