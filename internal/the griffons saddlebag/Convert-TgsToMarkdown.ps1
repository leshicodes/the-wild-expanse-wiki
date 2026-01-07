<#
.SYNOPSIS
    Converts Griffon's Saddlebag JSON data to standalone wiki markdown.

.DESCRIPTION
    Parses item data from JSON files and generates readable markdown with
    item descriptions, stats, tables, and features.

.PARAMETER BookNumber
    The book number to process (1-5). If not specified, processes all books.

.EXAMPLE
    .\Convert-TgsToMarkdown.ps1 -BookNumber 1
    
.EXAMPLE
    1..5 | ForEach-Object { .\Convert-TgsToMarkdown.ps1 -BookNumber $_ }
#>

param(
    [Parameter()]
    [ValidateRange(1, 5)]
    [int]$BookNumber
)

$ErrorActionPreference = 'Stop'

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

#region Helper Functions

function Convert-5eToolsMarkup {
    <#
    .SYNOPSIS
        Converts 5etools syntax to plain markdown
    #>
    param([string]$Text)
    
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    
    # {@spell X} -> *X* (italics)
    $Text = [regex]::Replace($Text, '\{@spell ([^}|]+)(?:\|[^}]*)?\}', '*$1*')
    
    # {@item X|source} or {@item X|source|display} -> **X**
    $Text = [regex]::Replace($Text, '\{@item ([^}|]+)(?:\|[^}]*)?\}', '**$1**')
    
    # {@dice XdY} or {@damage XdY} -> XdY
    $Text = [regex]::Replace($Text, '\{@(?:dice|damage) ([^}]+)\}', '$1')
    
    # {@dc N} -> DC N
    $Text = [regex]::Replace($Text, '\{@dc (\d+)\}', 'DC $1')
    
    # {@hit +N} -> +N
    $Text = [regex]::Replace($Text, '\{@hit ([^}]+)\}', '$1')
    
    # {@skill X}, {@sense X}, {@condition X} -> X
    $Text = [regex]::Replace($Text, '\{@(?:skill|sense|condition|action) ([^}|]+)(?:\|[^}]*)?\}', '$1')
    
    # {@creature X|source} -> X
    $Text = [regex]::Replace($Text, '\{@creature ([^}|]+)(?:\|[^}]*)?\}', '$1')
    
    # {@race X|source} -> X
    $Text = [regex]::Replace($Text, '\{@race ([^}|]+)(?:\|[^}]*)?\}', '$1')
    
    # {@class X|source} -> X
    $Text = [regex]::Replace($Text, '\{@class ([^}|]+)(?:\|[^}]*)?\}', '$1')
    
    # {@filter X|...} -> X
    $Text = [regex]::Replace($Text, '\{@filter ([^}|]+)(?:\|[^}]*)?\}', '$1')
    
    # {@quickref X|...} -> X
    $Text = [regex]::Replace($Text, '\{@quickref ([^}|]+)(?:\|[^}]*)?\}', '$1')
    
    # {@atk X} -> remove
    $Text = [regex]::Replace($Text, '\{@atk [^}]+\}', '')
    
    # {@recharge N} -> (Recharge N-6)
    $Text = [regex]::Replace($Text, '\{@recharge (\d+)\}', '(Recharge $1-6)')
    $Text = [regex]::Replace($Text, '\{@recharge\}', '(Recharge 6)')
    
    # {@chance N} -> N%
    $Text = [regex]::Replace($Text, '\{@chance (\d+)(?:\|[^}]*)?\}', '$1%')
    
    # {@scaledice ...} -> simplified
    $Text = [regex]::Replace($Text, '\{@scaledice [^}]+\|[^|]+\|([^}|]+)\}', '$1')
    
    # {@b X} -> **X** (bold)
    $Text = [regex]::Replace($Text, '\{@b ([^}]+)\}', '**$1**')
    
    # {@i X} -> *X* (italic)
    $Text = [regex]::Replace($Text, '\{@i ([^}]+)\}', '*$1*')
    
    # {@status X} -> X
    $Text = [regex]::Replace($Text, '\{@status ([^}|]+)(?:\|[^}]*)?\}', '$1')
    
    # Catch-all for any remaining {@type text|...} patterns
    $Text = [regex]::Replace($Text, '\{@\w+ ([^}|]+)(?:\|[^}]*)?\}', '$1')
    
    return $Text
}

function Get-ItemTypeName {
    param([string]$TypeCode)
    
    $typeMap = @{
        'A'   = 'Armor'
        'AF'  = 'Ammunition'
        'AT'  = 'Artisan Tools'
        'G'   = 'Adventuring Gear'
        'GS'  = 'Gaming Set'
        'INS' = 'Instrument'
        'M'   = 'Melee Weapon'
        'P'   = 'Potion'
        'R'   = 'Ranged Weapon'
        'RD'  = 'Rod'
        'RG'  = 'Ring'
        'S'   = 'Shield'
        'SC'  = 'Scroll'
        'SCF' = 'Spellcasting Focus'
        'ST'  = 'Staff'
        'T'   = 'Tools'
        'W'   = 'Wand'
        'WD'  = 'Wondrous Item'
    }
    
    # Handle composite types like "RD|DMG"
    $code = $TypeCode -split '\|' | Select-Object -First 1
    
    if ($typeMap.ContainsKey($code)) {
        return $typeMap[$code]
    }
    return $null
}

function Format-Table {
    <#
    .SYNOPSIS
        Converts a 5etools table object to markdown
    #>
    param($TableObj)
    
    $lines = @()
    
    if ($TableObj.caption) {
        $lines += "**$($TableObj.caption)**"
        $lines += ""
    }
    
    # Header row
    $headers = $TableObj.colLabels -join ' | '
    $lines += "| $headers |"
    
    # Separator
    $sep = ($TableObj.colLabels | ForEach-Object { '---' }) -join ' | '
    $lines += "| $sep |"
    
    # Data rows
    foreach ($row in $TableObj.rows) {
        if ($row -is [array]) {
            $cells = $row | ForEach-Object { Convert-5eToolsMarkup $_ }
            $lines += "| $($cells -join ' | ') |"
        }
    }
    
    return $lines -join "`n"
}

function Format-Entry {
    <#
    .SYNOPSIS
        Recursively formats an entry object to markdown
    #>
    param($Entry, [int]$Depth = 0)
    
    $output = @()
    
    if ($Entry -is [string]) {
        $output += Convert-5eToolsMarkup $Entry
    }
    elseif ($Entry.type -eq 'entries') {
        if ($Entry.name) {
            $output += ""
            $output += "**$($Entry.name).** $(Convert-5eToolsMarkup ($Entry.entries | Where-Object { $_ -is [string] } | Select-Object -First 1))"
            # Process remaining entries
            $remaining = $Entry.entries | Select-Object -Skip 1
            foreach ($e in $remaining) {
                $output += Format-Entry $e ($Depth + 1)
            }
        }
        else {
            foreach ($e in $Entry.entries) {
                $output += Format-Entry $e ($Depth + 1)
            }
        }
    }
    elseif ($Entry.type -eq 'table') {
        $output += ""
        $output += Format-Table $Entry
    }
    elseif ($Entry.type -eq 'list') {
        $output += ""
        foreach ($item in $Entry.items) {
            if ($item -is [string]) {
                $output += "- $(Convert-5eToolsMarkup $item)"
            }
            elseif ($item.name) {
                $output += "- **$($item.name).** $(Convert-5eToolsMarkup ($item.entries -join ' '))"
            }
        }
    }
    elseif ($Entry.type -eq 'quote') {
        $text = $Entry.entries -join ' '
        $output += ""
        $output += "> $(Convert-5eToolsMarkup $text)"
        if ($Entry.by) {
            $output += "> — $($Entry.by)"
        }
    }
    
    return $output -join "`n"
}

function Format-ItemSubtitle {
    <#
    .SYNOPSIS
        Creates the subtitle line for an item (rarity, type, attunement)
    #>
    param($Item)
    
    $parts = @()
    
    # Type
    if ($Item.wondrous) {
        $parts += 'Wondrous item'
    }
    elseif ($Item.type) {
        $typeName = Get-ItemTypeName $Item.type
        if ($typeName) {
            if ($Item.baseItem) {
                $baseName = ($Item.baseItem -split '\|')[0]
                $parts += "$typeName ($baseName)"
            }
            else {
                $parts += $typeName
            }
        }
        elseif ($Item.baseItem) {
            # Type not recognized but we have baseItem
            $baseName = ($Item.baseItem -split '\|')[0]
            $parts += $baseName
        }
    }
    elseif ($Item.armor) {
        $parts += "Armor ($($Item.armor))"
    }
    
    # Rarity
    if ($Item.rarity -and $Item.rarity -ne 'none') {
        $rarity = (Get-Culture).TextInfo.ToTitleCase($Item.rarity)
        $parts += $rarity
    }
    
    # Attunement
    if ($Item.reqAttune -eq $true) {
        $parts += '(requires attunement)'
    }
    elseif ($Item.reqAttune -is [string]) {
        $parts += "(requires attunement $($Item.reqAttune))"
    }
    
    return "*$($parts -join ', ')*"
}

function Format-Item {
    <#
    .SYNOPSIS
        Formats a single item to markdown
    #>
    param($Item)
    
    $lines = @()
    
    # Item name as header
    $lines += "#### $($Item.name)"
    
    # Subtitle (rarity, type, attunement)
    $subtitle = Format-ItemSubtitle $Item
    if ($subtitle -ne '**') {
        $lines += $subtitle
    }
    
    $lines += ""
    
    # Process entries
    if ($Item.entries) {
        foreach ($entry in $Item.entries) {
            $formatted = Format-Entry $entry
            if ($formatted) {
                $lines += $formatted
            }
        }
    }
    
    # Curse notice
    if ($Item.curse) {
        # Curse info is usually in the entries, but we can add a note if not
    }
    
    return $lines -join "`n"
}

#endregion

#region Main Processing

function Process-Book {
    param([int]$BookNum)
    
    $jsonPath = Join-Path $ScriptDir "griffons saddlebag book $BookNum.json"
    $outputPath = Join-Path $ScriptDir "griffons saddlebag book $BookNum - items.md"
    
    if (-not (Test-Path $jsonPath)) {
        Write-Warning "JSON file not found: $jsonPath"
        return
    }
    
    Write-Host "Processing Book $BookNum..." -ForegroundColor Cyan
    
    # Load JSON
    $json = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    
    $items = $json.item
    if (-not $items) {
        Write-Warning "No items found in $jsonPath"
        return
    }
    
    Write-Host "  Found $($items.Count) items" -ForegroundColor Gray
    
    # Sort items alphabetically
    $sortedItems = $items | Where-Object { $_.name -and $_.name.Length -gt 0 } | Sort-Object -Property name
    
    # Group by first letter
    $grouped = $sortedItems | Group-Object { $_.name.Substring(0, 1).ToUpper() }
    
    # Build output
    $output = @()
    $output += "# Griffon's Saddlebag Book $BookNum - Item Descriptions"
    $output += ""
    $output += "This document contains the full descriptions for all $($items.Count) magic items from The Griffon's Saddlebag, Book $BookNum."
    $output += ""
    $output += "---"
    $output += ""
    
    foreach ($group in $grouped | Sort-Object Name) {
        $letter = $group.Name
        $output += "## $letter"
        $output += ""
        
        foreach ($item in $group.Group) {
            try {
                $output += Format-Item $item
            }
            catch {
                Write-Warning "Error formatting item '$($item.name)': $($_.Exception.Message)"
                Write-Warning "Stack: $($_.ScriptStackTrace)"
                throw
            }
            $output += ""
            $output += "---"
            $output += ""
        }
    }
    
    # Write output
    $output -join "`n" | Out-File $outputPath -Encoding UTF8
    
    Write-Host "  Created: $outputPath" -ForegroundColor Green
}

# Main execution
if ($BookNumber) {
    Process-Book $BookNumber
}
else {
    # Process all books
    1..5 | ForEach-Object {
        $jsonPath = Join-Path $ScriptDir "griffons saddlebag book $_.json"
        if (Test-Path $jsonPath) {
            Process-Book $_
        }
    }
}

Write-Host "`nDone!" -ForegroundColor Green

#endregion
