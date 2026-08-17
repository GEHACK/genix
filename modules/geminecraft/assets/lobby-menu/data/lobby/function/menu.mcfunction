scoreboard players reset @s lobby_menu
tellraw @s {"text":"","extra":[{"text":"\n  GEHACK","color":"gold","bold":true},{"text":"  pick a game\n\n","color":"gray"}]}
tellraw @s [{"text":"  [ BedWars ]","color":"red","bold":true,"click_event":{"action":"run_command","command":"/server bedwars"},"hover_event":{"action":"show_text","value":{"text":"Cascade, 8 teams, joins you straight into the queue","color":"gray"}}},{"text":"   8 players, starts at 4","color":"dark_gray"}]
tellraw @s [{"text":"  [ Creative ]","color":"aqua","bold":true,"click_event":{"action":"run_command","command":"/server creative"},"hover_event":{"action":"show_text","value":{"text":"Creative building with WorldEdit","color":"gray"}}},{"text":"  building, WorldEdit","color":"dark_gray"}]
tellraw @s {"text":"\n  Reopen this menu with /trigger lobby_menu\n","color":"dark_gray","italic":true}
