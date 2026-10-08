-- GunServer
-- Zet dit als "Script" in ServerScriptService, met de LocalScript "GunClient" erin.
-- Maakt automatisch: een Gun (in StarterPack), een Dummy in de wereld,
-- en regelt het schieten + bloed/gore effecten.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CONFIG = {
	Damage = 20,
	HeadshotDamage = 50,
	FireRate = 0.15, -- seconden tussen schoten
	Range = 300,
	DummyPosition = Vector3.new(0, 5, -20),
	DummyHealth = 100,
	DummyRespawnTime = 5,
	MaxSplats = 300, -- max bloedvlekken tegelijk op de grond
	MaxDroplets = 200, -- max vliegende bloeddruppels tegelijk
	MaxWoundsPerPart = 10,
	MaxGibs = 80, -- max stukjes vlees/bot tegelijk
	GibLifetime = 10, -- seconden voordat vlees-stukjes verdwijnen
	LimbHealth = 45, -- zoveel damage op één arm/been = hij wordt eraf geschoten
	WoundDripTime = 8, -- zo lang druppelt een kogelgat
	ScreenSplatterRange = 15, -- dichterbij dan dit schieten = bloed op je scherm
}

local BLOOD_COLOR = Color3.fromRGB(110, 0, 0)
local BLOOD_COLOR_LIGHT = Color3.fromRGB(170, 10, 10)
local FLESH_COLOR = Color3.fromRGB(190, 70, 70)
local BONE_COLOR = Color3.fromRGB(235, 228, 210)

-- Deze delen kunnen niet los geschoten worden (hoofd ontploft apart)
local NOT_SEVERABLE = {
	HumanoidRootPart = true,
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
}

local rng = Random.new()

-- RemoteEvent waarmee de client laat weten waar hij op schiet
local shootEvent = ReplicatedStorage:FindFirstChild("ShootGun") or Instance.new("RemoteEvent")
shootEvent.Name = "ShootGun"
shootEvent.Parent = ReplicatedStorage

-- RemoteEvent voor bloed op je scherm
local screenEvent = ReplicatedStorage:FindFirstChild("GoreScreen") or Instance.new("RemoteEvent")
screenEvent.Name = "GoreScreen"
screenEvent.Parent = ReplicatedStorage

-- Map voor alle effecten (bloed, tracers), zodat raycasts ze kunnen negeren
local effectsFolder = workspace:FindFirstChild("GoreEffects") or Instance.new("Folder")
effectsFolder.Name = "GoreEffects"
effectsFolder.Parent = workspace

-- Map voor vlees-stukjes en afgeschoten armen/benen (die botsen wel met de grond)
local gibsFolder = workspace:FindFirstChild("GoreGibs") or Instance.new("Folder")
gibsFolder.Name = "GoreGibs"
gibsFolder.Parent = workspace

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function newPart(props)
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

-- Effect-part: botst nergens tegen en raycasts gaan erdoorheen
local function newEffectPart(props)
	local part = newPart(props)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Attachment op een wereld-positie, met de voorkant (LookVector) in een richting
local function newAttachment(part, name, worldPosition, direction)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = part -- eerst parent, anders klopt WorldCFrame niet
	attachment.WorldCFrame = CFrame.lookAt(worldPosition, worldPosition + direction)
	return attachment
end

-- Zoek de Motor6D die dit lichaamsdeel aan de rest vastmaakt
local function findJoint(character, part)
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part1 == part then
			return joint
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Gun
---------------------------------------------------------------------

local function createGun()
	local tool = Instance.new("Tool")
	tool.Name = "Gun"
	tool.CanBeDropped = false
	tool.ToolTip = "Klik om te schieten"

	local metal = Color3.fromRGB(35, 35, 40)

	-- Handle = de body van het gun. Loop van het gun wijst naar -Z.
	local handle = newPart({
		Name = "Handle",
		Size = Vector3.new(0.4, 0.6, 1.8),
		Color = metal,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CFrame = CFrame.new(),
	})
	handle.Parent = tool

	local function addPiece(name, size, offset, color, material)
		local piece = newPart({
			Name = name,
			Size = size,
			Color = color or metal,
			Material = material or Enum.Material.Metal,
			CanCollide = false,
			Massless = true,
			CFrame = handle.CFrame * offset,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = piece
		weld.Parent = piece
		piece.Parent = tool
		return piece
	end

	addPiece("Barrel", Vector3.new(0.22, 0.22, 1.2), CFrame.new(0, 0.12, -1.4))
	addPiece("Grip", Vector3.new(0.34, 0.9, 0.45), CFrame.new(0, -0.6, 0.45) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
	addPiece("Sight", Vector3.new(0.08, 0.15, 0.1), CFrame.new(0, 0.35, -0.7))
	addPiece("Mag", Vector3.new(0.28, 0.6, 0.35), CFrame.new(0, -0.55, -0.35))

	-- Punt waar de kogels uitkomen
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.12, -2.05)
	muzzle.Parent = handle

	local flashLight = Instance.new("PointLight")
	flashLight.Name = "FlashLight"
	flashLight.Color = Color3.fromRGB(255, 200, 100)
	flashLight.Range = 10
	flashLight.Brightness = 3
	flashLight.Enabled = false
	flashLight.Parent = muzzle

	-- Hand komt op de Grip
	tool.Grip = CFrame.new(0, -0.6, 0.45)

	return tool
end

local gunTemplate = createGun()
-- De client-code (GunClient) gaat mee in het gun, zo is er maar één Script nodig
local clientScript = script:FindFirstChild("GunClient")
if clientScript then
	clientScript:Clone().Parent = gunTemplate
else
	warn("GunServer: LocalScript 'GunClient' ontbreekt in dit Script, het gun kan niet schieten!")
end
gunTemplate.Parent = StarterPack

-- Spelers die al in de game zitten ook een gun geven
for _, player in Players:GetPlayers() do
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and not backpack:FindFirstChild("Gun") then
		gunTemplate:Clone().Parent = backpack
	end
end

---------------------------------------------------------------------
-- Bloed / gore
---------------------------------------------------------------------

local splats = {}
local activeDroplets = 0
local activeGibs = 0

-- Bloedvlek op een oppervlak. growTime = hoe lang hij erover doet om groot te worden.
local function addSplat(position, normal, size, growTime)
	-- Platte cilinder; de X-as van een cilinder wijst langs de normaal van het oppervlak
	local helper = math.abs(normal.Y) < 0.99 and Vector3.yAxis or Vector3.xAxis
	local up = (helper - normal * normal:Dot(helper)).Unit
	local cf = CFrame.fromMatrix(position + normal * 0.03, normal, up) * CFrame.Angles(rng:NextNumber(0, math.pi * 2), 0, 0)

	local splat = newEffectPart({
		Name = "BloodSplat",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 0.1, 0.1),
		Color = rng:NextNumber() < 0.5 and BLOOD_COLOR or BLOOD_COLOR_LIGHT,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.15,
		Anchored = true,
		CFrame = cf,
	})
	splat.Parent = effectsFolder

	TweenService:Create(splat, TweenInfo.new(growTime or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, size, size),
	}):Play()

	table.insert(splats, splat)
	if #splats > CONFIG.MaxSplats then
		table.remove(splats, 1):Destroy()
	end
end

-- Grote vlek met kleine spetters eromheen (zoals bloed tegen een muur)
local function addSpatter(position, normal, size)
	addSplat(position, normal, size)
	for _ = 1, 7 do
		local offset = rng:NextUnitVector() * rng:NextNumber(0.4, size * 1.3)
		local flat = offset - normal * offset:Dot(normal)
		addSplat(position + flat, normal, rng:NextNumber(0.15, size * 0.35))
	end
end

local dropletParams = RaycastParams.new()
dropletParams.FilterType = Enum.RaycastFilterType.Exclude
dropletParams.FilterDescendantsInstances = { effectsFolder, gibsFolder }

-- Druppel die door de lucht vliegt en een vlek maakt waar hij landt
local function spawnDroplet(origin, velocity)
	if activeDroplets >= CONFIG.MaxDroplets then
		return
	end
	activeDroplets += 1

	local drop = newEffectPart({
		Name = "BloodDrop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * rng:NextNumber(0.15, 0.35),
		Color = BLOOD_COLOR_LIGHT,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		Position = origin,
	})
	drop.Parent = effectsFolder

	local pos, vel, age = origin, velocity, 0
	local connection
	local function finish()
		connection:Disconnect()
		drop:Destroy()
		activeDroplets -= 1
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		age += dt
		vel += Vector3.new(0, -workspace.Gravity, 0) * dt
		local step = vel * dt
		local hit = workspace:Raycast(pos, step, dropletParams)
		-- Alleen vlekken op vaste dingen (grond, muren); door lichamen vliegt hij heen
		if hit and hit.Instance.Anchored then
			addSplat(hit.Position, hit.Normal, rng:NextNumber(0.6, 1.6))
			finish()
			return
		end
		pos += step
		drop.Position = pos
		if age > 4 then
			finish()
		end
	end)
end

local function bloodBurst(position, normal, count, force)
	for _ = 1, count do
		local dir = (normal + rng:NextUnitVector() * 0.9).Unit
		local velocity = dir * rng:NextNumber(8, 20) * force + Vector3.new(0, rng:NextNumber(2, 8), 0)
		spawnDroplet(position + normal * 0.15, velocity)
	end
end

local function makeBloodEmitter(parent)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(BLOOD_COLOR_LIGHT, BLOOD_COLOR)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.3, 0.8)
	emitter.Speed = NumberRange.new(5, 15)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -workspace.Gravity * 0.3, 0)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Parent = parent
	return emitter
end

-- Bloedspray op de plek waar de kogel inslaat, + even nabloeden
local function bloodSpray(part, worldPosition, normal, bleedTime)
	local attachment = newAttachment(part, "BloodSpray", worldPosition, normal)
	local emitter = makeBloodEmitter(attachment)
	emitter:Emit(40)
	emitter.Rate = 30
	task.delay(bleedTime, function()
		emitter.Enabled = false
	end)
	Debris:AddItem(attachment, bleedTime + 1)
end

-- Spuitende slagader: klopt als een hart en wordt langzaam zwakker
local function arterialSpurt(attachment, duration)
	local emitter = makeBloodEmitter(attachment)
	emitter.Speed = NumberRange.new(10, 20)
	emitter.SpreadAngle = Vector2.new(15, 15)

	task.spawn(function()
		local start = os.clock()
		while attachment.Parent and os.clock() - start < duration do
			local t = os.clock() - start
			local strength = 1 - t / duration
			local pulse = math.max(0, math.sin(t * 9))
			emitter.Rate = 80 * pulse * strength

			local dir = attachment.WorldCFrame.LookVector
			for _ = 1, math.floor(3 * pulse * strength + 0.5) do
				local velocity = (dir + rng:NextUnitVector() * 0.2).Unit * ((6 + 16 * pulse) * strength + 2)
				spawnDroplet(attachment.WorldPosition, velocity)
			end
			task.wait(0.08)
		end
		emitter.Enabled = false
		Debris:AddItem(attachment, 1)
	end)
end

-- Kogelgat dat blijft druppelen
local function startDrip(wound, duration)
	task.spawn(function()
		local stop = os.clock() + duration
		while wound.Parent and os.clock() < stop do
			spawnDroplet(wound.Position, Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)))
			task.wait(rng:NextNumber(0.25, 0.6))
		end
	end)
end

-- Kogelgat dat aan het lichaam vast blijft zitten
local function addWound(part, position)
	local count = part:GetAttribute("Wounds") or 0
	if count >= CONFIG.MaxWoundsPerPart then
		return
	end
	part:SetAttribute("Wounds", count + 1)

	local wound = newEffectPart({
		Name = "Wound",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * rng:NextNumber(0.25, 0.45),
		Color = Color3.fromRGB(60, 0, 0),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		Massless = true,
		CFrame = CFrame.new(position),
	})
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = wound
	weld.Parent = wound
	wound.Parent = part

	startDrip(wound, CONFIG.WoundDripTime)
end

-- Lichaamsdeel wordt steeds roder van het bloed
local function stainPart(part, amount)
	if part.Name ~= "HumanoidRootPart" then
		part.Color = part.Color:Lerp(BLOOD_COLOR, amount)
	end
end

-- Stukjes vlees en bot die wegvliegen, met een bloedspoor erachter
local function spawnGibs(position, direction, count, force)
	for _ = 1, count do
		if activeGibs >= CONFIG.MaxGibs then
			return
		end
		activeGibs += 1

		local isBone = rng:NextNumber() < 0.2
		local size = isBone and Vector3.new(0.15, 0.15, rng:NextNumber(0.4, 0.9))
			or Vector3.new(rng:NextNumber(0.2, 0.6), rng:NextNumber(0.2, 0.5), rng:NextNumber(0.2, 0.6))
		local gib = newEffectPart({
			Name = "Gib",
			Size = size,
			Color = isBone and BONE_COLOR or (rng:NextNumber() < 0.5 and FLESH_COLOR or BLOOD_COLOR),
			Material = Enum.Material.SmoothPlastic,
			Reflectance = isBone and 0 or 0.2, -- nat vlees glimt een beetje
			CFrame = CFrame.new(position + rng:NextUnitVector() * 0.3)
				* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
		})
		gib.CanCollide = true
		gib.CanTouch = true

		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.1, 0)
		a0.Parent = gib
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.1, 0)
		a1.Parent = gib
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(BLOOD_COLOR_LIGHT, BLOOD_COLOR)
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Lifetime = 0.3
		trail.FaceCamera = true
		trail.LightInfluence = 1
		trail.Parent = gib

		gib.Parent = gibsFolder
		local dir = (direction + rng:NextUnitVector() * 0.8 + Vector3.new(0, 0.6, 0)).Unit
		gib.AssemblyLinearVelocity = dir * rng:NextNumber(15, 35) * force
		gib.AssemblyAngularVelocity = rng:NextUnitVector() * 20

		-- Waar hij neerkomt (en stuitert) komt een vlek
		local splatsLeft, lastSplat = 3, 0
		gib.Touched:Connect(function(other)
			if splatsLeft > 0 and other.Anchored and os.clock() - lastSplat > 0.15 then
				splatsLeft -= 1
				lastSplat = os.clock()
				local hit = workspace:Raycast(gib.Position + Vector3.new(0, 1, 0), Vector3.new(0, -4, 0), dropletParams)
				if hit and hit.Instance.Anchored then
					addSplat(hit.Position, hit.Normal, rng:NextNumber(0.5, 1.2))
				end
			end
		end)

		task.delay(CONFIG.GibLifetime, function()
			local fade = TweenService:Create(gib, TweenInfo.new(1), { Transparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			gib:Destroy()
			activeGibs -= 1
		end)
	end
end

-- Kogel gaat erdoorheen: bloed uit de achterkant en tegen de muur erachter
local function exitWound(part, entry, direction, character)
	direction = direction.Unit

	-- Achterkant van het lichaamsdeel vinden (terug raycasten naar het deel zelf)
	local include = RaycastParams.new()
	include.FilterType = Enum.RaycastFilterType.Include
	include.FilterDescendantsInstances = { part }
	local back = workspace:Raycast(entry + direction * 6, -direction * 6, include)
	local exitPosition = back and back.Position or entry + direction

	bloodSpray(part, exitPosition, direction, 0.5)
	bloodBurst(exitPosition, direction, 8, 1.6)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, effectsFolder, gibsFolder }
	local wall = workspace:Raycast(exitPosition, direction * 20, params)
	if wall and wall.Instance.Anchored then
		addSpatter(wall.Position, wall.Normal, rng:NextNumber(1.2, 2.5))
	end
end

-- Arm of been eraf schieten
local function severLimb(character, part, direction)
	local joint = findJoint(character, part)
	local body = joint and joint.Part0
	if not body then
		return
	end
	local jointPosition = (body.CFrame * joint.C0).Position

	-- Alles wat aan dit deel vast zit gaat mee (bv. onderarm + hand)
	local limbParts = { part }
	local i = 1
	while i <= #limbParts do
		for _, other in character:GetDescendants() do
			if other:IsA("Motor6D") and other.Part0 == limbParts[i] and other.Part1 then
				table.insert(limbParts, other.Part1)
			end
		end
		i += 1
	end

	joint:Destroy()

	local limb = Instance.new("Model")
	limb.Name = "SeveredLimb"
	for _, limbPart in limbParts do
		limbPart.CanCollide = true
		limbPart:SetAttribute("Bloody", true)
		stainPart(limbPart, 0.3)
		limbPart.Parent = limb
	end
	limb.Parent = gibsFolder
	Debris:AddItem(limb, CONFIG.GibLifetime * 2)

	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	local push = (direction.Unit + Vector3.new(0, 0.8, 0)).Unit
	part:ApplyImpulse(push * part.AssemblyMass * rng:NextNumber(25, 40))

	-- Stomp aan het lichaam spuit, en het losse deel bloedt ook
	local outward = jointPosition - body.Position
	outward = outward.Magnitude > 0.01 and outward.Unit or Vector3.yAxis
	arterialSpurt(newAttachment(body, "Stump", jointPosition, outward), 6)
	arterialSpurt(newAttachment(part, "Stump", jointPosition, -outward), 3)
	spawnGibs(jointPosition, outward, 5, 0.8)
	bloodBurst(jointPosition, outward, 12, 1.3)
end

-- Hoofd ontploft
local function explodeHead(character, head, direction)
	local position = head.Position
	local neck = findJoint(character, head)
	local body = neck and neck.Part0

	spawnGibs(position, direction.Unit, 16, 1.4)
	bloodBurst(position, Vector3.yAxis, 25, 1.4)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, effectsFolder, gibsFolder }
	local wall = workspace:Raycast(position, direction.Unit * 25, params)
	if wall and wall.Instance.Anchored then
		addSpatter(wall.Position, wall.Normal, 3.5)
	end

	if body then
		local neckPosition = (body.CFrame * neck.C0).Position
		local outward = neckPosition - body.Position
		outward = outward.Magnitude > 0.01 and outward.Unit or Vector3.yAxis
		stainPart(body, 0.4)
		arterialSpurt(newAttachment(body, "Stump", neckPosition, outward), 7)
	end

	head:Destroy()
end

local function hitFlash(character)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 1
	highlight.Parent = character
	Debris:AddItem(highlight, 0.1)
end

local function goreHit(result, character, direction, damage, dead)
	local part = result.Instance
	local isHead = part.Name == "Head"

	-- Dodelijk schot in het hoofd (of op een lijk): hoofd ontploft
	if isHead and dead then
		explodeHead(character, part, direction)
		return
	end

	addWound(part, result.Position)
	stainPart(part, 0.15)
	bloodSpray(part, result.Position, result.Normal, isHead and 2 or 1)
	bloodBurst(result.Position, result.Normal, isHead and 16 or 10, 1.2)
	exitWound(part, result.Position, direction, character)
	if rng:NextNumber() < 0.35 then
		spawnGibs(result.Position, result.Normal, 2, 0.6)
	end
	hitFlash(character)

	if not NOT_SEVERABLE[part.Name] then
		local limbDamage = (part:GetAttribute("LimbDamage") or 0) + damage
		part:SetAttribute("LimbDamage", limbDamage)
		if limbDamage >= CONFIG.LimbHealth then
			severLimb(character, part, direction)
		end
	end
end

-- Grote gore-explosie als iemand doodgaat
local function goreDeath(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.CanQuery then
			bloodBurst(part.Position, rng:NextUnitVector(), 6, 1.5)
			stainPart(part, 0.3)
			-- Lichaamsdelen wegschieten
			if not part.Anchored then
				local push = (rng:NextUnitVector() + Vector3.new(0, 1, 0)).Unit
				part:ApplyImpulse(push * part.AssemblyMass * rng:NextNumber(20, 40))
			end
		end
	end

	if torso then
		local top = torso.Position + torso.CFrame.UpVector * torso.Size.Y / 2
		spawnGibs(torso.Position, Vector3.yAxis, 16, 1.2)
		arterialSpurt(newAttachment(torso, "Stump", top, torso.CFrame.UpVector), 6)
		bloodSpray(torso, torso.Position, Vector3.yAxis, 3)
	end

	-- Bloedplas onder het lichaam die langzaam groter wordt
	if root then
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), dropletParams)
		if hit and hit.Instance.Anchored then
			addSplat(hit.Position, hit.Normal, 9, 4)
		end
	end
end

---------------------------------------------------------------------
-- Dummy
---------------------------------------------------------------------

local function createDummy()
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(200, 200, 200)
	description.HeadColor = skin
	description.TorsoColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.LeftLegColor = skin
	description.RightLegColor = skin

	local dummy = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	dummy.Name = "Dummy"

	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Dummy"
	humanoid.MaxHealth = CONFIG.DummyHealth
	humanoid.Health = CONFIG.DummyHealth
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.BreakJointsOnDeath = true -- valt uit elkaar als hij doodgaat

	dummy:PivotTo(CFrame.new(CONFIG.DummyPosition) * CFrame.Angles(0, math.pi, 0))
	dummy.Parent = workspace

	local root = dummy:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil)
	end

	humanoid.Died:Connect(function()
		task.defer(goreDeath, dummy)
		task.delay(CONFIG.DummyRespawnTime, function()
			dummy:Destroy()
			createDummy()
		end)
	end)
end

createDummy()

---------------------------------------------------------------------
-- Schieten
---------------------------------------------------------------------

local function tracer(from, to)
	local distance = (to - from).Magnitude
	local beam = newEffectPart({
		Name = "Tracer",
		Size = Vector3.new(0.06, 0.06, distance),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = Color3.fromRGB(255, 220, 120),
		Material = Enum.Material.Neon,
		Anchored = true,
	})
	beam.Parent = effectsFolder
	Debris:AddItem(beam, 0.05)
end

local function muzzleFlash(muzzle)
	local light = muzzle:FindFirstChild("FlashLight")
	if light then
		light.Enabled = true
		task.delay(0.05, function()
			light.Enabled = false
		end)
	end
	local flash = newEffectPart({
		Name = "MuzzleFlash",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.5,
		Color = Color3.fromRGB(255, 200, 80),
		Material = Enum.Material.Neon,
		Anchored = true,
		Position = muzzle.WorldPosition,
	})
	flash.Parent = effectsFolder
	Debris:AddItem(flash, 0.05)
end

local lastShot = {}

shootEvent.OnServerEvent:Connect(function(player, targetPosition)
	if typeof(targetPosition) ~= "Vector3" then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local tool = character:FindFirstChild("Gun")
	local handle = tool and tool:IsA("Tool") and tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	if not muzzle then
		return
	end

	-- Anti-spam: niet sneller schieten dan de fire rate
	local now = os.clock()
	if lastShot[player] and now - lastShot[player] < CONFIG.FireRate * 0.8 then
		return
	end
	lastShot[player] = now

	local origin = muzzle.WorldPosition
	local direction = targetPosition - origin
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit * CONFIG.Range

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, effectsFolder }

	local result = workspace:Raycast(origin, direction, params)
	local hitPosition = result and result.Position or origin + direction

	muzzleFlash(muzzle)
	tracer(origin, hitPosition)

	if not result then
		return
	end

	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
	if targetHumanoid then
		local damage = 0
		if targetHumanoid.Health > 0 then
			damage = result.Instance.Name == "Head" and CONFIG.HeadshotDamage or CONFIG.Damage
			targetHumanoid:TakeDamage(damage)
		end
		goreHit(result, model, direction, damage, targetHumanoid.Health <= 0)

		-- Bloed op het scherm van de schutter (van dichtbij) en van wie geraakt wordt
		if (hitPosition - origin).Magnitude <= CONFIG.ScreenSplatterRange then
			screenEvent:FireClient(player, 1)
		end
		local victim = Players:GetPlayerFromCharacter(model)
		if victim then
			screenEvent:FireClient(victim, 0.6)
		end
	elseif result.Instance:GetAttribute("Bloody") then
		-- Losse arm/been raken: bloedt en vliegt weg
		local part = result.Instance
		bloodBurst(result.Position, result.Normal, 8, 1)
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
		part:ApplyImpulse(direction.Unit * part.AssemblyMass * 25)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastShot[player] = nil
end)
