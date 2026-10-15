--!strict

--[[
	Safe area, a scale that never shrinks tap targets, and a panel aspect.
]]

local MobileShell = {}

function MobileShell.mount(screen: ScreenGui)
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.IgnoreGuiInset = false
	local scale = Instance.new("UIScale")
	scale.Name = "Fit"
	scale.Parent = screen
	local function fit()
		local camera = workspace.CurrentCamera
		local height = if camera ~= nil then camera.ViewportSize.Y else 780
		if height < 1 then
			height = 780
		end
		scale.Scale = math.clamp(height / 780, 1, 1.25)
	end
	fit()
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

function MobileShell.aspect(parent: Instance, ratio: number)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Name = "FitAspect"
	aspect.AspectRatio = ratio
	aspect.AspectType = Enum.AspectType.ScaleWithParentSize
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = parent
	return aspect
end

function MobileShell.limit(parent: Instance, maxX: number, maxY: number)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(maxX, maxY)
	limit.Parent = parent
end

return MobileShell
