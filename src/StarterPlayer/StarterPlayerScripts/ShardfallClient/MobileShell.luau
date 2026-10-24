--!strict

--[[
	Safe area, a scale that never shrinks tap targets, and a panel aspect.
]]

local MobileShell = {}

function MobileShell.mount(screen: ScreenGui)
	-- Device safe insets are the GUI's own box. Scale stays at 1.
	-- Growing from the screen center pushed the travel sidebar and the
	-- odds panel onto each other.
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.IgnoreGuiInset = false
	local scale = Instance.new("UIScale")
	scale.Name = "Fit"
	scale.Scale = 1
	scale.Parent = screen
end

function MobileShell.view(screen: ScreenGui): (number, number)
	local size = screen.AbsoluteSize
	if size.X >= 200 and size.Y >= 200 then
		return size.X, size.Y
	end
	local camera = workspace.CurrentCamera
	local vx = if camera ~= nil then camera.ViewportSize.X else 1280
	local vy = if camera ~= nil then camera.ViewportSize.Y else 720
	local GuiService = game:GetService("GuiService")
	local inset = GuiService:GetGuiInset()
	vy -= inset.Y
	if vx < 1 then
		vx = 1280
	end
	if vy < 1 then
		vy = 720
	end
	return vx, vy
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
