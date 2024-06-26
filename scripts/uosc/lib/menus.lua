---@param data MenuData
---@param opts? {submenu?: string; mouse_nav?: boolean; on_close?: string | string[]}
function open_command_menu(data, opts)
	local function run_command(command)
		if type(command) == 'string' then
			mp.command(command)
		else
			---@diagnostic disable-next-line: deprecated
			mp.commandv(unpack(command))
		end
	end
	---@type MenuOptions
	local menu_opts = {}
	if opts then
		menu_opts.mouse_nav = opts.mouse_nav
		if opts.on_close then menu_opts.on_close = function() run_command(opts.on_close) end end
	end
	local menu = Menu:open(data, run_command, menu_opts)
	if opts and opts.submenu then menu:activate_submenu(opts.submenu) end
	return menu
end

---@param opts? {submenu?: string; mouse_nav?: boolean; on_close?: string | string[]}
function toggle_menu_with_items(opts)
	if Menu:is_open('menu') then Menu:close()
	else open_command_menu({type = 'menu', items = config.menu_items}, opts) end
end

---@param options {type: string; title: string; list_prop: string; active_prop?: string; serializer: fun(list: any, active: any): MenuDataItem[]; on_select: fun(value: any); on_move_item?: fun(from_index: integer, to_index: integer, submenu_path: integer[]); on_delete_item?: fun(index: integer, submenu_path: integer[])}
function create_self_updating_menu_opener(options)
	return function()
		if Menu:is_open(options.type) then Menu:close() return end
		local list = mp.get_property_native(options.list_prop)
		local active = options.active_prop and mp.get_property_native(options.active_prop) or nil
		local menu

		local function update() menu:update_items(options.serializer(list, active)) end

		local ignore_initial_list = true
		local function handle_list_prop_change(name, value)
			if ignore_initial_list then ignore_initial_list = false
			else list = value update() end
		end

		local ignore_initial_active = true
		local function handle_active_prop_change(name, value)
			if ignore_initial_active then ignore_initial_active = false
			else active = value update() end
		end

		local initial_items, selected_index = options.serializer(list, active)

		-- Items and active_index are set in the handle_prop_change callback, since adding
		-- a property observer triggers its handler immediately, we just let that initialize the items.
		menu = Menu:open(
			{type = options.type, title = options.title, items = initial_items, selected_index = selected_index},
			options.on_select, {
			on_open = function()
				mp.observe_property(options.list_prop, 'native', handle_list_prop_change)
				if options.active_prop then
					mp.observe_property(options.active_prop, 'native', handle_active_prop_change)
				end
			end,
			on_close = function()
				mp.unobserve_property(handle_list_prop_change)
				mp.unobserve_property(handle_active_prop_change)
			end,
			on_move_item = options.on_move_item,
			on_delete_item = options.on_delete_item,
		})
	end
end

require('lib/mediainfo')

function create_select_tracklist_type_menu_opener(menu_title, track_type, track_prop, load_command)
	local function serialize_tracklist(tracklist)
		local items = {}

		if load_command then
			items[#items + 1] = {
				title = t('Load'), bold = true, italic = true, hint = t('open file'), value = '{load}', separator = true,
			}
		end
		if options.use_media_info then
			media_info_string = get_media_info()
		end
		if media_info_string then
			media_info_string = string.gsub(media_info_string, "\\n", "§")
			media_info_table = split(media_info_string,'§')
		end

		vid_string={}
		aid_string={}
		sid_string={}
		if media_info_table then
			for _, track in ipairs(media_info_table) do
				if track:sub(1,1) == 'V' then
					table.insert(vid_string, track:sub(3))
				end
				if track:sub(1,1) == 'A' then
					table.insert(aid_string, track:sub(3))
				end
				if track:sub(1,1) == 'S' then
					table.insert(sid_string, track:sub(3))
				end
				if track:sub(1,1) == 'G' then
					container = track:sub(3)
				end
			end
		end

		local first_item_index = #items + 1
		local active_index = nil
		local disabled_item = nil

		-- Add option to disable a subtitle track. This works for all tracks,
		-- but why would anyone want to disable audio or video? Better to not
		-- let people mistakenly select what is unwanted 99.999% of the time.
		-- If I'm mistaken and there is an active need for this, feel free to
		-- open an issue.
		if track_type == 'sub' then
			disabled_item = {title = t('Disabled'), italic = true, muted = true, hint = '—', value = nil, active = true}
			items[#items + 1] = disabled_item
		end

		local vid_index = 1
		local aid_index = 1
		local sid_index = 1
		for _, track in ipairs(tracklist) do
			if track_type == 'all' or track.type == track_type then

				local hint_values = {}

				if track.type == 'sub' then
					if track.external then hint_values["External"] = 'External' end
					if track.forced then hint_values["Forced"] = 'Forced' end
					if track.default then hint_values["Default"] = 'Default' end
					if sid_string and #sid_string >= sid_index then
						streamSize = formatMediainfoStringIndexNumber(sid_string[sid_index], 5)
						if streamSize and streamSize ~= '' then hint_values["Stream-Size"] = streamSize end
					end
					if track.lang then hint_values["Language"] = track.lang:upper() end
					hint_values["Codec"] = track.codec:upper()
					sid_index = sid_index + 1
				end
				if track.type == 'audio' then
					if track.external then hint_values["External"] = 'External' end
					if track.forced then hint_values["Forced"] = 'Forced' end
					if track.default then hint_values["Default"] = 'Default' end
					if track['demux-channel-count'] then hint_values["Channel-Count"] = t(track['demux-channel-count'] == 1 and '%s Channel' or '%s Channels', track['demux-channel-count']) end
					if track['demux-samplerate'] then hint_values["Samplerate"] = string.format('%.3gkHz', track['demux-samplerate'] / 1000) end
					hint_values["Codec"] = track.codec:upper()
					if track.lang then hint_values["Language"] = track.lang:upper() end
					if aid_string and #aid_string >= aid_index then
						streamSize = formatMediainfoStringIndexNumber(aid_string[aid_index], 8)
						if streamSize and streamSize ~= '' then hint_values["Stream-Size"] = streamSize end
					end
					if aid_string and #aid_string >= aid_index then
						bitrate = formatMediainfoStringIndexNumber(aid_string[aid_index], 4)
						if bitrate and bitrate ~= '' then
							hint_values["Bitrate"] = bitrate
						end
					end			
					aid_index = aid_index + 1
				end
				if track.type == 'video' then
					if track.lang then hint_values["Language"] = track.lang:upper() end
					if track.external then hint_values["External"] = 'External' end
					if track.forced then hint_values["Forced"] = 'Forced' end
					if track.default then hint_values["Default"] = 'Default' end
					if vid_string and #vid_string >= vid_index then
						local format = formatMediainfoStringIndexNumber(vid_string[vid_index], 1)
						if format and format ~= '' then hint_values["Codec"] = format end

						local formatProfile =formatMediainfoStringIndexNumber(vid_string[vid_index], 2)
						if formatProfile and formatProfile ~= '' then hint_values["Codec-Profile"] = formatProfile end

						local hdr = formatMediainfoStringIndexNumber(vid_string[vid_index], 3)
						if hdr and hdr ~= '' then hint_values["HDR-DV"] = hdr end

						local scanType = formatMediainfoStringIndexNumber(vid_string[vid_index], 8)
						local scanOrder = formatMediainfoStringIndexNumber(vid_string[vid_index], 9)
						if scanType and scanType ~= '' and scanOrder and scanOrder ~= '' then
							hint_values["Scan-Type-Order"] = scanType .. ', ' .. scanOrder
						end

						local fps = formatMediainfoStringIndexNumber(vid_string[vid_index], 6)
						if fps and fps ~= '' then hint_values["FPS"] = fps end

						local dimensions = formatMediainfoStringIndexNumber(vid_string[vid_index], 4)
						if dimensions and dimensions ~= '' then hint_values["Dimensions"] = dimensions end

						local streamSize = formatMediainfoStringIndexNumber(vid_string[vid_index], 7)
						if streamSize and streamSize ~= '' then hint_values["Stream-Size"] = streamSize end

						local bitrate = formatMediainfoStringIndexNumber(vid_string[vid_index], 5)
						if bitrate and bitrate ~= '' then hint_values["Bitrate"] = bitrate end
					else
						hint_values["Codec"] = track.codec:upper()

						if track['demux-fps'] then hint_values["FPS"] = string.format('%.5g FPS', track['demux-fps']) end

						if track['demux-h'] then hint_values["Dimensions"] = track['demux-w'] and (track['demux-w'] .. 'x' .. track['demux-h']) or (track['demux-h'] .. 'p') end
					end
					vid_index = vid_index + 1
				end

				local item = {
					title = (track.title and track.title or t('Track %s', track.id)),
					hint = hint_values,
					value = track.id * 10 + 0,
					active = track.selected,
				}
				if track.type == 'video' then
					vid_string[vid_index-1] = item
					vid_string[vid_index-1].value = track.id * 10 + 1
				end
				if track.type == 'audio' then
					aid_string[aid_index-1] = item
					aid_string[aid_index-1].value = track.id * 10 + 2
				end
				if track.type == 'sub' then
					sid_string[sid_index-1] = item
					sid_string[sid_index-1].value = track.id * 10 + 3
				end

				if track.selected then
					if disabled_item then disabled_item.active = false end
					active_index = #items
				end
			end
		end



		video_order = {}
		table.insert(video_order, "Language")
		table.insert(video_order, "External")
		table.insert(video_order, "Forced")
		table.insert(video_order, "Default")
		table.insert(video_order, "Scan-Type-Order")
		table.insert(video_order, "Codec")
		table.insert(video_order, "Codec-Profile")
		table.insert(video_order, "HDR-DV")
		table.insert(video_order, "FPS")
		table.insert(video_order, "Dimensions")
		table.insert(video_order, "Stream-Size")
		table.insert(video_order, "Bitrate")

		audio_order = {}
		table.insert(audio_order, "External")
		table.insert(audio_order, "Forced")
		table.insert(audio_order, "Default")
		table.insert(audio_order, "Language")
		table.insert(audio_order, "Codec")
		table.insert(audio_order, "Channel-Count")
		table.insert(audio_order, "Samplerate")
		table.insert(audio_order, "Stream-Size")
		table.insert(audio_order, "Bitrate")

		subtitle_order = {}
		table.insert(subtitle_order, "External")
		table.insert(subtitle_order, "Forced")
		table.insert(subtitle_order, "Default")
		table.insert(subtitle_order, "Stream-Size")
		table.insert(subtitle_order, "Language")
		table.insert(subtitle_order, "Codec")

		function addByOrder(insertTable, order)
			-- get biggest length
			maxLength = {}
			for _, item in ipairs(insertTable) do
				hint = item.hint
				for _, item in ipairs(order) do
					if not maxLength[item .. '-length'] or maxLength[item .. '-length'] < (hint[item] and hint[item]:len() or 0) then
						if hint[item] then
							maxLength[item .. '-length'] = hint[item]:len()
						else
							maxLength[item .. '-length'] = 0
						end
					end
				end
			end


			function padMaxLength(string, maxLength)
				if not string then
					string = ''
				end
				while string:len() < maxLength do
					string = ' ' .. string
				end
				return string
			end

			-- create hint with spaces
			for _, item in ipairs(insertTable) do
				hint = item.hint
				local newHint = ''
				for _, item in ipairs(order) do
					if newHint == '' then
						newHint = padMaxLength(hint[item], maxLength[item .. '-length'])
					else
						newHint = newHint .. ', ' .. padMaxLength(hint[item], maxLength[item .. '-length'])
					end
				end

				newHint = trim(newHint)
				
				newHint = string.gsub(newHint, ", , , , ", ", ")
				newHint = string.gsub(newHint, ", , , ", ", ")
				newHint = string.gsub(newHint, ", , ", ", ")
				newHint = string.gsub(newHint, "  , ", "    ")

				item.hint = newHint
				items[#items + 1] = item
			end
		end
		
		function addItem(string)
			items[#items + 1] = {
				title = t(string), bold = true, separator = true, active = false, selectable = false, align='center'
			}
		end
		if track_type == 'all' or track_type == 'video' then
			if track_type == 'all' and #vid_string >= 1 then addItem('———————————————— Video ————————————————') end
			addByOrder(vid_string, video_order)
		end
		if track_type == 'all' or track_type == 'audio' then
			if track_type == 'all' and #aid_string >= 1 then addItem('———————————————— Audio ————————————————') end
			addByOrder(aid_string, audio_order)
		end
		if track_type == 'all' or track_type == 'sub' then
			if track_type == 'all' and #sid_string >= 1 then addItem('—————————————— Subtitles ——————————————') end
			addByOrder(sid_string, subtitle_order)
		end
		if track_type == 'all' then
			if media_info_table then
				addItem('—————————————— Container ——————————————')
				addItem(container)
			end
		end

		return items, active_index or first_item_index
	end

	local function selection_handler(value)
		if value == '{load}' then
			mp.command(load_command)
		else
			if value then
				value = tostring(value)
				id = tonumber(value:sub(1,-2))
				a_track_type = tonumber(value:sub(-1))

				if a_track_type == 1 then
					track_prop = 'vid'
				end
				if a_track_type == 2 then
					track_prop = 'aid'
				end
				if a_track_type == 3 then
					track_prop = 'sid'
				end
			else
				id = nil
			end
			mp.commandv('set', track_prop, id and id or 'no')

			-- If subtitle track was selected, assume user also wants to see it
			if id and (track_type == 'sub' or a_track_type == 3) then
				mp.commandv('set', 'sub-visibility', 'yes')
			end
		end
	end

	if track_type == 'all' then
		menu_title = t('All Tracks')
	end

	return create_self_updating_menu_opener({
		title = menu_title,
		type = track_type,
		list_prop = 'track-list',
		serializer = serialize_tracklist,
		on_select = selection_handler,
	})
end

---@alias NavigationMenuOptions {type: string, title?: string, allowed_types?: string[], active_path?: string, selected_path?: string; on_open?: fun(); on_close?: fun()}

-- Opens a file navigation menu with items inside `directory_path`.
---@param directory_path string
---@param handle_select fun(path: string): nil
---@param opts NavigationMenuOptions
function open_file_navigation_menu(directory_path, handle_select, opts)
	directory = serialize_path(normalize_path(directory_path))
	opts = opts or {}

	if not directory then
		msg.error('Couldn\'t serialize path "' .. directory_path .. '.')
		return
	end

	local files, directories = read_directory(directory.path, opts.allowed_types)
	local is_root = not directory.dirname
	local path_separator = path_separator(directory.path)

	if not files or not directories then return end

	sort_filenames(directories)
	sort_filenames(files)

	-- Pre-populate items with parent directory selector if not at root
	-- Each item value is a serialized path table it points to.
	local items = {}

	if is_root then
		if state.platform == 'windows' then
			items[#items + 1] = {title = '..', hint = t('Drives'), value = '{drives}', separator = true}
		end
	else
		items[#items + 1] = {title = '..', hint = t('parent dir'), value = directory.dirname, separator = true}
	end

	local back_path = items[#items] and items[#items].value
	local selected_index = #items + 1

	for _, dir in ipairs(directories) do
		items[#items + 1] = {title = dir, value = join_path(directory.path, dir), hint = path_separator}
	end

	for _, file in ipairs(files) do
		items[#items + 1] = {title = file, value = join_path(directory.path, file)}
	end

	for index, item in ipairs(items) do
		if not item.value.is_to_parent and opts.active_path == item.value then
			item.active = true
			if not opts.selected_path then selected_index = index end
		end

		if opts.selected_path == item.value then selected_index = index end
	end

	---@type MenuCallback
	local function open_path(path, meta)
		local is_drives = path == '{drives}'
		local is_to_parent = is_drives or #path < #directory_path
		local inheritable_options = {
			type = opts.type, title = opts.title, allowed_types = opts.allowed_types, active_path = opts.active_path,
		}

		if is_drives then
			open_drives_menu(function(drive_path)
				open_file_navigation_menu(drive_path, handle_select, inheritable_options)
			end, {
				type = inheritable_options.type, title = inheritable_options.title, selected_path = directory.path,
				on_open = opts.on_open, on_close = opts.on_close,
			})
			return
		end

		local info, error = utils.file_info(path)

		if not info then
			msg.error('Can\'t retrieve path info for "' .. path .. '". Error: ' .. (error or ''))
			return
		end

		if info.is_dir and not meta.modifiers.ctrl then
			--  Preselect directory we are coming from
			if is_to_parent then
				inheritable_options.selected_path = directory.path
			end

			open_file_navigation_menu(path, handle_select, inheritable_options)
		else
			handle_select(path)
		end
	end

	local function handle_back()
		if back_path then open_path(back_path, {modifiers = {}}) end
	end

	local menu_data = {
		type = opts.type, title = opts.title or directory.basename .. path_separator, items = items,
		selected_index = selected_index,
	}
	local menu_options = {on_open = opts.on_open, on_close = opts.on_close, on_back = handle_back}

	return Menu:open(menu_data, open_path, menu_options)
end

-- Opens a file navigation menu with Windows drives as items.
---@param handle_select fun(path: string): nil
---@param opts? NavigationMenuOptions
function open_drives_menu(handle_select, opts)
	opts = opts or {}
	local process = mp.command_native({
		name = 'subprocess',
		capture_stdout = true,
		playback_only = false,
		args = {'wmic', 'logicaldisk', 'get', 'name', '/value'},
	})
	local items, selected_index = {}, 1

	if process.status == 0 then
		for _, value in ipairs(split(process.stdout, '\n')) do
			local drive = string.match(value, 'Name=([A-Z]:)')
			if drive then
				local drive_path = normalize_path(drive)
				items[#items + 1] = {
					title = drive, hint = t('drive'), value = drive_path, active = opts.active_path == drive_path,
				}
				if opts.selected_path == drive_path then selected_index = #items end
			end
		end
	else
		msg.error(process.stderr)
	end

	return Menu:open(
		{type = opts.type, title = opts.title or t('Drives'), items = items, selected_index = selected_index},
		handle_select
	)
end
