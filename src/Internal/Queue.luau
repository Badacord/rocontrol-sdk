--!strict
-- Bounded FIFO work queue. When full, the lowest-priority item is dropped first
-- (lower numeric `priority` = more important, matching the resolver convention),
-- so a flood of low-priority events can never starve a critical one or grow
-- memory without bound.

export type QueueItem<T> = {
	value: T,
	priority: number,
	seq: number,
}

export type Queue<T> = {
	size: (self: Queue<T>) -> number,
	isEmpty: (self: Queue<T>) -> boolean,
	-- Returns true if enqueued, false if rejected/dropped due to capacity.
	push: (self: Queue<T>, value: T, priority: number?) -> boolean,
	pop: (self: Queue<T>) -> T?,
	clear: (self: Queue<T>) -> (),
}

local Queue = {}
Queue.__index = Queue

local DEFAULT_PRIORITY = 1000

function Queue.new<T>(maxSize: number): Queue<T>
	local self = setmetatable({
		_items = {} :: { QueueItem<T> },
		_maxSize = math.max(1, maxSize),
		_seq = 0,
	}, Queue)
	return (self :: any) :: Queue<T>
end

function Queue.size(self: any): number
	return #self._items
end

function Queue.isEmpty(self: any): boolean
	return #self._items == 0
end

-- Finds the index of the worst (highest numeric priority, then oldest) item to
-- evict when the queue is full.
local function findEvictionIndex(items: { QueueItem<any> }): number
	local worstIndex = 1
	local worst = items[1]
	for i = 2, #items do
		local candidate = items[i]
		if
			candidate.priority > worst.priority
			or (candidate.priority == worst.priority and candidate.seq < worst.seq)
		then
			worst = candidate
			worstIndex = i
		end
	end
	return worstIndex
end

function Queue.push(self: any, value: any, priority: number?): boolean
	self._seq += 1
	local item: QueueItem<any> = {
		value = value,
		priority = priority or DEFAULT_PRIORITY,
		seq = self._seq,
	}

	if #self._items < self._maxSize then
		table.insert(self._items, item)
		return true
	end

	-- Full: evict the worst existing item, but only if the newcomer is at least
	-- as important. Otherwise reject the newcomer.
	local evictIndex = findEvictionIndex(self._items)
	local victim = self._items[evictIndex]
	if item.priority <= victim.priority then
		table.remove(self._items, evictIndex)
		table.insert(self._items, item)
		return true
	end

	return false
end

function Queue.pop(self: any): any?
	local item = table.remove(self._items, 1)
	if item == nil then
		return nil
	end
	return (item :: QueueItem<any>).value
end

function Queue.clear(self: any)
	table.clear(self._items)
end

return Queue
