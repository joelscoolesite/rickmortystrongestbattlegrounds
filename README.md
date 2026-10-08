# Rick & Morty Strongest Battlegrounds

## Gun + Dummy met gore

Schiet op de dummy met het gun en je krijgt:

- **Bloedspray** bij de inslag én aan de achterkant (de kogel gaat erdoorheen), met spetters tegen de muur erachter
- **Kogelgaten** die blijven druppelen, en lichaamsdelen die steeds roder worden
- **Armen en benen eraf schieten**: 3 kogels op hetzelfde deel en hij vliegt eraf, de stomp spuit bloed als een kloppende slagader
- **Hoofd ontploft** bij een dodelijke headshot (of als je op het hoofd van een lijk schiet)
- **Stukjes vlees en bot** die wegvliegen met een bloedspoor en vlekken maken waar ze landen
- **Bloed op je scherm** als je van dichtbij schiet (of als jij zelf geraakt wordt)
- Bij doodgaan: alles vliegt uit elkaar, de romp spuit en er komt een bloedplas die langzaam groter wordt

Losse armen/benen kun je nog verder kapotschieten. Na 5 seconden komt er een nieuwe dummy.

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

Bovenaan `GunServer` staat `CONFIG` (damage, headshot damage, fire rate, waar de dummy staat, enz.), `LimbHealth` voor hoeveel damage er nodig is om een arm/been eraf te schieten,
`MaxGibs` / `MaxDroplets` / `MaxSplats` als het te veel lagt).

### Rojo

Gebruik je Rojo, dan staat er een `default.project.json`: `rojo serve`.

Na het aanpassen van de scripts: `python build.py` om `GunSystem.rbxmx` opnieuw te maken.
