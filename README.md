# Rick & Morty Strongest Battlegrounds

## Gun + Dummy met gore

Schiet op de dummy met het gun → bloedspray, kogelgaten, bloeddruppels die vlekken op de grond maken.
Gaat de dummy dood, dan valt hij uit elkaar met een grote bloedplas. Na 5 seconden komt er een nieuwe dummy.

### In Roblox Studio zetten (kopiëren en plakken)

1. **Explorer** → rechtsklik op **ServerScriptService** → **Insert Object** → **Script**.
   Noem hem `GunServer` en plak de code uit `src/ServerScriptService/GunServer.server.lua`.
2. **Explorer** → open **StarterPlayer** → rechtsklik op **StarterPlayerScripts** → **Insert Object** → **LocalScript**.
   Noem hem `GunClient` en plak de code uit `src/StarterPlayer/StarterPlayerScripts/GunClient.client.lua`.
3. Druk op **Play**. Je hebt het gun in je backpack (toets `1`), de dummy staat bij `0, 5, -20`.

Je hoeft verder niks te bouwen; de scripts maken het gun en de dummy zelf.

### Instellingen

Bovenaan `GunServer` staat `CONFIG` (damage, headshot damage, fire rate, waar de dummy staat, enz.).

### Rojo

Gebruik je Rojo, dan staat er een `default.project.json`: `rojo serve`.
