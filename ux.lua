local me = {}

-- to read the module, begin from the bottom-most func `init`


local currentlyOpenedFiles = {} -- most-recently opened is last
local recentlyClosedFiles = {} -- most-recently closed is first
local envHomePrefix = os.getenv("HOME") .. '/'



local function filePathBaseName(path)
    return path:gsub("(.*/)(.*)", "%2")
end
local function filePathParentDir(path)
    return path:gsub("(.*/)(.*)", "%1")
end
local function prettifiedHomeDirPrefix(path)
    if path:sub(1, #envHomePrefix) == envHomePrefix then
        path = '~' .. path:sub(#envHomePrefix)
    end
    return path
end


-- allows alt+1, alt+2 .. alt+0 to switch to that tab
local function goToBuftab(tabNo)
    local buf = nil
    if tabNo == 0 then
        buf = _BUFFERS[#_BUFFERS]
    elseif tabNo > 0 and tabNo <= #_BUFFERS then
        buf = _BUFFERS[tabNo]
    end
    if buf ~= nil then
        view.goto_buffer(view, buf)
    end
end


-- ensures no duplicate tab labels by including file paths when necessary
local function setupSaneBuftabLabels()
    local ensure = function()
        local all = {}
        for _, buf in ipairs(_BUFFERS) do
            if buf.filename then
                local namepref, namesuff = '    ', '    '
                if buf.modify then namepref, namesuff = '    ', '      ' end

                local filebasename = filePathBaseName(buf.filename)
                buf.tab_label = namepref .. filebasename .. namesuff
                local byname = all[filebasename]
                if byname == nil then
                    all[filebasename] = { buf }
                else
                    byname[1 + #byname] = buf
                end
            end
        end

        for name, bufs in pairs(all) do
            if #bufs > 1 then -- name occurs more than once
                for _, buf in ipairs(bufs) do
                    local namepref, namesuff = '    ', '    '
                    if buf.modify then namepref, namesuff = '    ', '      ' end

                    buf.tab_label = buf.filename
                    buf.tab_label = prettifiedHomeDirPrefix(buf.tab_label)
                    buf.tab_label = namepref .. buf.tab_label .. namesuff
                end
            end
        end
    end

    events.connect(events.BUFFER_DELETED, ensure)
    events.connect(events.FILE_OPENED, ensure)
    events.connect(events.BUFFER_NEW, ensure)
    events.connect(events.BUFFER_AFTER_SWITCH, ensure)
    events.connect(events.FILE_AFTER_SAVE, ensure)
    events.connect(events.UPDATE_UI, function(upd)
        if upd == buffer.UPDATE_CONTENT then ensure() end
    end)

    ensure()
end


-- allows ctrl+shift+tab to reopen recently-closed tabs
local function setupReopenClosedBuftabs()
    for _, buf in ipairs(_BUFFERS) do
        currentlyOpenedFiles[1 + #currentlyOpenedFiles] = buf.filename
    end

    events.connect(events.FILE_OPENED, function(fullFilePath)
        currentlyOpenedFiles[1 + #currentlyOpenedFiles] = fullFilePath
        for i = #recentlyClosedFiles, 1, -1 do
            if recentlyClosedFiles[i] == fullFilePath then
                table.remove(recentlyClosedFiles, i)
            end
        end
    end)

    events.connect(events.BUFFER_DELETED, function()
        for i = #currentlyOpenedFiles, 1, -1 do
            local fullFilePath, found = currentlyOpenedFiles[i], false
            for _, buf in ipairs(_BUFFERS) do
                if buf.filename == fullFilePath then
                    found = true
                    break
                end
            end
            if not found then -- this one was just closed
                table.insert(recentlyClosedFiles, 1, fullFilePath)
                --recentlyClosedFiles[1 + #recentlyClosedFiles] = fullFilePath
                table.remove(currentlyOpenedFiles, i)
            end
        end
    end)

    return function()
        if #recentlyClosedFiles > 0 then
            local restoreFile = recentlyClosedFiles[1] -- #recentlyClosedFiles]
            io.open_file(restoreFile)
        end
    end
end


-- opens dialog to select "recent files" to open, but sorted by most-recently-
-- closed and without listing files that are already currently opened
local function setupRecentlyClosed()
    return function()
        if #recentlyClosedFiles > 0 then
            local filelistitems = {}
            for _, fullfilepath in ipairs(recentlyClosedFiles) do
                filelistitems[1 + #filelistitems] = prettifiedHomeDirPrefix(filePathParentDir(fullfilepath))
                filelistitems[1 + #filelistitems] = filePathBaseName(fullfilepath)
            end

            local button, selfiles = ui.dialogs.filteredlist {
                title = 'Re-open recently closed:', width = 2345, height = 1234, select_multiple = true,
                columns = { 'Directory', 'File' }, items = filelistitems,
            }
            if button == 1 then
                local fullfilepaths = {}
                for _, idx in ipairs(selfiles) do
                    fullfilepaths[1 + #fullfilepaths] = recentlyClosedFiles[idx]
                end
                io.open_file(fullfilepaths)
            end
        end
    end
end


-- when typing opening-brace-or-quote char while selection/s: enclose (rather
-- than overwrite) selection(s), and crucially also preserve all selection(s)
local function setupAutoEnclosers()
    local encloser = function(left, right)
        return function()
            if buffer.selection_empty then
                return false
            else
                local incr, newsels, numsels = 1, {}, buffer.selections
                for i = 1, numsels do
                    newsels[i] = { buffer.selection_n_start[i - 1] , buffer.selection_n_end[i - 1] }
                    if newsels[i][2] < newsels[i][1] then
                        newsels[i][1], newsels[i][2] = newsels[i][2], newsels[i][1]
                    end
                end
                table.sort(newsels, function(dis, dat)
                    return dis[1] < dat[1] and dis[2] < dat[2]
                end)
                textadept.editing.enclose(left, right)
                for i = 0, numsels - 1 do
                    buffer.selection_n_start[i], buffer.selection_n_end[i] = incr + newsels[i+1][1], incr + newsels[i+1][2]
                    incr = incr + 2
                end
            end
        end
    end

    textadept.editing.auto_pairs[96] = '`'
    for l, right in pairs(textadept.editing.auto_pairs) do
        local left = string.char(l)
        keys[left] = encloser(left, right)
    end
end


-- buf-tab context-menu item: "close others" / close-all-but-this-tab
local function setupBuftabCloseOthers()
    textadept.menu.tab_context_menu[1 + #textadept.menu.tab_context_menu] = { 'Close Others', function()
        local curfilename = buffer.filename
        for _, buf in ipairs(_BUFFERS) do
            if buf.filename == nil or buf.filename ~= curfilename then
                -- we don't buffer.delete(buf) as we might lose unsaved-changes
                view:goto_buffer(buf)
                io.close_buffer()
            end
        end
    end }
end


-- all built-in menus are relocated under a single top-level menu that always
-- shows the full file path of the currently active buf-tab
local function setupShowCurFileFullPath()
    local menu = { title = prettifiedHomeDirPrefix(buffer.filename or buffer.tab_label) }
    for _, stdmenu in ipairs(textadept.menu.menubar) do
        menu[1 + #menu] = stdmenu
    end
    textadept.menu.menubar = { menu }

    local ensure = function()
        textadept.menu.menubar[1].title = prettifiedHomeDirPrefix(filePathParentDir(buffer.filename or buffer.tab_label)):gsub('_', '__') .. '\t'
    end

    events.connect(events.FILE_AFTER_SAVE, ensure)
    events.connect(events.BUFFER_AFTER_SWITCH, ensure)
    events.connect(events.FILE_OPENED, ensure)
    events.connect(events.BUFFER_NEW, ensure)
end


-- keeps a buf-tab's caret-position in mem to restore it on reopen-after-close
local function setupBuftabSelStateCapture()
    local caretpos = {}

    events.connect(events.UPDATE_UI, function(upd)
        if upd == buffer.UPDATE_SELECTION and buffer.filename then
            caretpos[buffer.filename] = buffer.current_pos
        end
    end)

    events.connect(events.FILE_OPENED, function(filepath)
        local pos = caretpos[filepath]
        if pos then buffer.goto_pos(pos) end
    end)
end


function me.init()
    keys.a0 = function() goToBuftab(0) end
    keys.a1 = function() goToBuftab(1) end
    keys.a2 = function() goToBuftab(2) end
    keys.a3 = function() goToBuftab(3) end
    keys.a4 = function() goToBuftab(4) end
    keys.a5 = function() goToBuftab(5) end
    keys.a6 = function() goToBuftab(6) end
    keys.a7 = function() goToBuftab(7) end
    keys.a8 = function() goToBuftab(8) end
    keys.a9 = function() goToBuftab(9) end

    setupShowCurFileFullPath()
    setupSaneBuftabLabels()
    keys.cT = setupReopenClosedBuftabs()
    keys.cO = setupRecentlyClosed()
    setupBuftabCloseOthers()
    setupBuftabSelStateCapture()
    setupAutoEnclosers()
end



return me
