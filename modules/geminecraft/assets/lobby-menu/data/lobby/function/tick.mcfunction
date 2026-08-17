scoreboard players enable @a lobby_menu
execute as @a unless score @s lobby_greeted matches 1 run function lobby:greet
execute as @a[scores={lobby_menu=1..}] run function lobby:menu
