# Rick & Morty Strongest Battlegrounds

## Gun + Dummy met gore

Schiet op de dummy met het gun → bloedspray, kogelgaten, bloeddruppels die vlekken op de grond maken.
Gaat de dummy dood, dan valt hij uit elkaar met een grote bloedplas. Na 5 seconden komt er een nieuwe dummy.

### In Roblox Studio zetten (makkelijkst)

1. Download `GunSystem.rbxmx` (op GitHub: klik op het bestand → **Download raw file**).
2. In Studio, in de **Explorer**: rechtsklik op **ServerScriptService** → **Insert from File...** → kies `GunSystem.rbxmx`.
3. Druk op **Play**. Je hebt het gun in je backpack (toets `1`), de dummy staat bij `0, 5, -20`.

Je hoeft verder niks te bouwen; het script maakt het gun en de dummy zelf.

### Of handmatig (kopiëren en plakken)

1. Rechtsklik op **ServerScriptService** → **Insert Object** → **Script**, noem hem `GunServer`,
   plak `src/ServerScriptService/GunServer/init.server.lua`.
2. Rechtsklik op dat **GunServer** Script → **Insert Object** → **LocalScript**, noem hem `GunClient`,
   plak `src/ServerScriptService/GunServer/GunClient.client.lua`.

### Instellingen

Bovenaan `GunServer` staat `CONFIG` (damage, headshot damage, fire rate, waar de dummy staat, enz.).

### Rojo

Gebruik je Rojo, dan staat er een `default.project.json`: `rojo serve`.

Na het aanpassen van de scripts: `python build.py` om `GunSystem.rbxmx` opnieuw te maken.
