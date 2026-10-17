$p = "C:\Users\pedro\Documents\Alien field"
$path = "$p\scripts\main.gd"
$lines = [System.IO.File]::ReadAllLines($path)
$lines[1492] = "`t`t`t`t`t`t# Shuriken: da 3 cargas para o jogador carregar e lancar com L"
$lines[1493] = "`t`t`t`t`t`tif player != null and is_instance_valid(player):"
$lines[1494] = "`t`t`t`t`t`t`tplayer.set(`"shuriken_cargas`", 3)"
$lines[1495] = "`t`t`t`t`t`t`t_num(player.position + Vector2(0, -90), `"SHURIKEN x3`", 30, Color(1.0, 0.55, 0.20))"
$lines[1496] = "`t`t`t`t`t`te.set(`"vivo`", false)"
$lines[1497] = "`t`t`t`t`t`te.queue_free()"
$lines[1498] = "`t`t`t`t`t`t`t`t`t`t`t`t`t"
$lines[1499] = "`t`t`t`t`t`t`t`t`t`t`t`t`t"
[System.IO.File]::WriteAllLines($path, $lines, (New-Object System.Text.UTF8Encoding($false)))
"done"