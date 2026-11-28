# Rival Store Robbery

Rockstar x AGDS FiveM Mod Jam 2026

## Team

Team name: **Merryweather**

| Name | Role |
|---|---|
| Emir Irkilata | Designer, weapon shop (gun van) |
| Suryaveer Bhandari | Coder, getaway car breakdown |
| Joao Almeida | Coder, store robbery, safe cracking, mission, money |

## What the mod is

A rival shop owner, Ghayoor Habibi, pays you to rob his rival chain that is putting him out of business. You buy a gun from a gun van, rob three stores one after another, crack the safes in the last two, and escape the police in a getaway car that might break down on you.

## How to start

The mission starts by itself when you spawn on the server.

If it doesn't, or you join after the resource started, type in chat (T):

```
/startmission
```

You can only start it once per session. Typing it again tells you that you already have the job.

## How to play

1. **Mission texts.** Ghayoor sends you three texts and $500. Your weapons are removed, so you have to buy one.
2. **Gun van.** Go to the red **Gun Van** blip. Stand behind the van, look at a weapon on display and press **E** to buy it. The pistol costs exactly $500.
3. **Rob the store.** Go to the yellow **Rival Store** blip. Aim your gun at the clerk. He puts his hands up, you get $500 and 2 wanted stars.
4. **Safes (stores 2 and 3).** In the back room, a green circle shows the safe once you've robbed the till (red means rob the till first). Press **E** to start cracking.
5. **Lose the cops.** When your stars are gone, the money is yours and the next rival store appears on the map.
6. **Getaway car.** The car you escape in can break down. Follow the on-screen help to restart or repair it.
7. **Dying.** If you die while you still have stars, you lose the money from that store and respawn outside it to try again.
8. After the third store and losing the cops: **Job done**.

## Controls

| Where | Key | Action |
|---|---|---|
| Anywhere | T, then `/startmission` | Start the mission |
| Store | Aim (right mouse) at the clerk | Rob the till |
| Gun van | E | Buy the weapon you're looking at |
| Safe | E | Start cracking |
| Safe dial | E | Turn left (hold to spin) |
| Safe dial | F | Turn right (hold to spin) |
| Safe dial | H | Confirm the number |
| Safe dial | S | Give up |
| Broken car | Hold X | Restart a stalled engine |
| Broken car | E at the bonnet | Repair (press E when the marker is in the green zone) |
| Repair | Backspace | Stop repairing |

**Safe cracking tip:** each safe has 3 random numbers. Turn the dial until you hear a different click, then press H. A wrong number resets all 3 locks. The lock icons next to the dial show how many you've opened.

## Prices and payouts

| Thing | Amount |
|---|---|
| Starting money | $500 |
| Store till | $500 |
| Safe | $2000 |
| Pistol / Micro SMG / Pump Shotgun | $500 / $1000 / $1500 |

## Server requirements

- One resource only: the `store-robbery` folder. Add `ensure store-robbery` to `server.cfg`.
- **OneSync must be on.** The server checks player positions, health and wanted level to stop cheating.
- The default **spawnmanager** resource must be running (it is in the default server). The mission auto-start and the respawn outside the store use it.

## Credits

- The safe cracking minigame is based on [FiveM-SafeCrackingMiniGame](https://github.com/TimothyDexter/FiveM-SafeCrackingMiniGame) by Timothy Dexter, rewritten in Lua with our own rules.
