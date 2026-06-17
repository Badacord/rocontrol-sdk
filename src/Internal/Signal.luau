--!strict
-- BindableEvent-backed signal so `onFailedOperation` can return a real
-- RBXScriptConnection (matching the public API type). Falls back to nil-safe
-- behavior if BindableEvent cannot be created (non-Roblox harness).

export type Signal<T> = {
	connect: (self: Signal<T>, callback: (T) -> ()) -> RBXScriptConnection,
	fire: (self: Signal<T>, payload: T) -> (),
	destroy: (self: Signal<T>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T>(): Signal<T>
	local bindable: BindableEvent? = nil
	local ok, created = pcall(function()
		return Instance.new("BindableEvent")
	end)
	if ok then
		bindable = created
	end

	local self = setmetatable({ _bindable = bindable }, Signal)
	return (self :: any) :: Signal<T>
end

function Signal.connect(self: any, callback: (any) -> ()): RBXScriptConnection
	assert(self._bindable ~= nil, "Signal requires BindableEvent support")
	return self._bindable.Event:Connect(callback)
end

function Signal.fire(self: any, payload: any)
	if self._bindable ~= nil then
		self._bindable:Fire(payload)
	end
end

function Signal.destroy(self: any)
	if self._bindable ~= nil then
		self._bindable:Destroy()
		self._bindable = nil
	end
end

return Signal
