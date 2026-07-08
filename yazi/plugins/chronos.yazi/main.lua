--- @since 26.5.6

local SELF_ID = "chronos"
local TITLE = "Chronos"

local SUCCESS_LEVEL = "info"
local WARN_LEVEL = "warn"
local ERROR_LEVEL = "error"

local NOTIFY_TIMEOUT = 12
local SUMMARY_TIMEOUT = 3
local DETAILED_SUMMARY_TIMEOUT = 2.5
local DETAILED_PAGE_TIMEOUT = 2.5
local DETAILED_GAP = 0.05

local DEFAULT_DETAIL_CHUNK_SIZE = 12

local function notify(content, level, timeout, title)
	ya.notify({
		title = title or TITLE,
		content = content,
		timeout = timeout or NOTIFY_TIMEOUT,
		level = level,
	})
end

local function to_positive_int(value)
	local n
	if type(value) == "number" then
		n = value
	elseif type(value) == "string" then
		n = tonumber((value:match("^%s*(.-)%s*$")))
	end

	if type(n) ~= "number" or n ~= n then
		return nil
	end

	n = math.floor(n)
	if n < 1 then
		return nil
	end
	return n
end

local function normalize_mode(mode)
	if mode == "summary" or mode == "detailed" then
		return mode
	end
	return nil
end

local function resolve_opts(opts)
	local cfg = {
		enable = false,
		notify_mode = "summary",
		detail_chunk_size = DEFAULT_DETAIL_CHUNK_SIZE,
	}
	local errors = {}

	if opts == nil then
		return cfg, errors
	end

	if type(opts) ~= "table" then
		errors[#errors + 1] = "Invalid `setup(opts)`: expected table"
		return cfg, errors
	end

	if opts.enable ~= nil then
		if type(opts.enable) == "boolean" then
			cfg.enable = opts.enable
		else
			errors[#errors + 1] =
				string.format("Invalid `enable`: got `%s`, expected boolean", tostring(opts.enable))
		end
	end

	if opts.notify_mode ~= nil then
		local mode = normalize_mode(opts.notify_mode)
		if mode then
			cfg.notify_mode = mode
		else
			errors[#errors + 1] = string.format(
				"Invalid `notify_mode`: got `%s`, expected \"summary\" or \"detailed\"",
				tostring(opts.notify_mode)
			)
		end
	end

	if opts.detail_chunk_size ~= nil then
		local size = to_positive_int(opts.detail_chunk_size)
		if size then
			cfg.detail_chunk_size = size
		else
			errors[#errors + 1] = string.format(
				"Invalid `detail_chunk_size`: got `%s`, expected positive integer",
				tostring(opts.detail_chunk_size)
			)
		end
	end

	return cfg, errors
end

local function round_ms(ms)
	return tonumber(string.format("%.3f", ms))
end

local function plugins_path()
	local yazi_config = os.getenv("YAZI_CONFIG_HOME")
	if yazi_config and yazi_config ~= "" then
		return yazi_config .. "/plugins"
	end

	if ya.target_family() == "windows" then
		local appdata = os.getenv("APPDATA")
		if appdata and appdata ~= "" then
			return appdata .. "\\yazi\\config\\plugins"
		end
	end

	local xdg_config = os.getenv("XDG_CONFIG_HOME")
	if xdg_config and xdg_config ~= "" then
		return xdg_config .. "/yazi/plugins"
	end

	local home = os.getenv("HOME") or os.getenv("USERPROFILE")
	if home and home ~= "" then
		return home .. "/.config/yazi/plugins"
	end

	return nil
end

local function plugin_ids(path)
	local files, err = fs.read_dir(Url(path), { glob = "*.yazi", resolve = false })
	if not files then
		return nil, err
	end

	local ids = {}
	for _, file in ipairs(files) do
		if file.cha and file.cha.is_dir then
			local id = file.name:gsub("%.yazi$", "")
			if id ~= "" and id ~= SELF_ID and id:match("^[%w._-]+$") then
				ids[#ids + 1] = id
			end
		end
	end

	table.sort(ids)
	return ids, nil
end

---@class BenchItem
---@field id string
---@field ok boolean
---@field ms number
---@field err string?

local function bench_one(id)
	-- Drop any cached copy so we measure a real load, not a cache hit.
	package.loaded[id] = nil

	local start = ya.time() or 0
	local ok, mod_or_err = pcall(require, id)
	local finish = ya.time() or start

	return {
		id = id,
		ok = ok,
		ms = round_ms((finish - start) * 1000),
		err = ok and nil or tostring(mod_or_err),
	}
end

local function format_result_line(item)
	if item.ok then
		return string.format("%s: %.3f ms", item.id, item.ms)
	end
	return string.format("%s: %.3f ms (ERROR)", item.id, item.ms)
end

local function build_summary(results, total_ms, failed)
	local lines = {
		string.format("Total: %d plugins %.3f ms", #results, total_ms),
	}
	if failed > 0 then
		lines[#lines + 1] = string.format("Failed: %d", failed)
	end
	return table.concat(lines, "\n")
end

local function build_detail_pages(results, chunk_size)
	local pages = {}
	local lines = {}
	for _, item in ipairs(results) do
		lines[#lines + 1] = format_result_line(item)
	end

	for i = 1, #lines, chunk_size do
		local chunk = {}
		for j = i, math.min(i + chunk_size - 1, #lines) do
			chunk[#chunk + 1] = lines[j]
		end
		pages[#pages + 1] = table.concat(chunk, "\n")
	end

	if #pages == 0 then
		pages[1] = "No external plugins found"
	end
	return pages
end

local function sleep_wait(seconds)
	if seconds <= 0 then
		return true
	end

	local ok, err = pcall(ya.sleep, seconds)
	if not ok then
		ya.err(string.format("[%s] sleep failed: %s", SELF_ID, tostring(err)))
		return false
	end
	return true
end

local function notify_summary(summary, failed)
	notify(summary, failed > 0 and WARN_LEVEL or SUCCESS_LEVEL, SUMMARY_TIMEOUT)
end

local function notify_detailed(summary, pages, failed)
	local level = failed > 0 and WARN_LEVEL or SUCCESS_LEVEL
	local total_pages = #pages

	local ok, err = pcall(ya.async, function()
		notify(summary, level, DETAILED_SUMMARY_TIMEOUT)

		if total_pages == 0 then
			return
		end
		if not sleep_wait(DETAILED_SUMMARY_TIMEOUT + DETAILED_GAP) then
			return
		end

		for i = 1, total_pages do
			notify(
				pages[i],
				level,
				DETAILED_PAGE_TIMEOUT,
				string.format("%s (%d/%d)", TITLE, i, total_pages)
			)
			if i < total_pages and not sleep_wait(DETAILED_PAGE_TIMEOUT + DETAILED_GAP) then
				return
			end
		end
	end)

	if not ok then
		ya.err(string.format("[%s] async delivery failed: %s", SELF_ID, tostring(err)))
		notify(summary, level, NOTIFY_TIMEOUT)
	end
end

local function notify_report(cfg, results, total_ms, failed)
	local summary = build_summary(results, total_ms, failed)
	if cfg.notify_mode == "summary" then
		notify_summary(summary, failed)
		return
	end

	local pages = build_detail_pages(results, cfg.detail_chunk_size)
	notify_detailed(summary, pages, failed)
end

local function notify_validation_errors(errors)
	if #errors == 0 then
		return
	end
	notify(table.concat(errors, "\n"), ERROR_LEVEL, NOTIFY_TIMEOUT)
end

local function setup(_, opts)
	local cfg, validation_errors = resolve_opts(opts)
	if not cfg.enable then
		return
	end

	if #validation_errors > 0 then
		notify_validation_errors(validation_errors)
		return
	end

	local path = plugins_path()
	if not path then
		notify("Cannot detect plugins directory", ERROR_LEVEL, NOTIFY_TIMEOUT)
		return
	end

	local ids, read_err = plugin_ids(path)
	if not ids then
		notify("Failed to read plugins directory: " .. tostring(read_err), ERROR_LEVEL, NOTIFY_TIMEOUT)
		return
	end

	local started = ya.time() or 0
	local failed = 0
	local results = {}

	for _, id in ipairs(ids) do
		local item = bench_one(id)
		results[#results + 1] = item
		if not item.ok then
			failed = failed + 1
			ya.err(string.format("[%s] Failed to load `%s`: %s", SELF_ID, id, item.err))
		end
	end

	local finished = ya.time() or started
	notify_report(cfg, results, (finished - started) * 1000, failed)
end

return { setup = setup }
