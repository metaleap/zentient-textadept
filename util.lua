local util = {}



util.envHome = os.getenv("HOME")
util.eventBufSwitch = 'metaleap_zentient.EVENT_BUFSWITCH'
util.resetBag = {}
local envHomeSlash = util.envHome .. '/'


function util.fsPathJoin(...)
    local parts = {...}
    local path = ''
    ui.statusbar_text = tostring(#parts)
    for i, part in ipairs(parts) do
        if part then
            while i > 1 and part:sub(1, 1) == '/' do
                part = part:sub(2)
            end
            while part:sub(-1) == '/' do
                part = part:sub(1, -2)
            end
            if #part > 0 then
                path = path .. part .. '/'
            end
        end
    end
    return path:sub(1, -2)
end


-- if `path` is prefixed with `~/`, changes the prefix to (actual, current) `$HOME/`
function util.fsPathExpandHomeDirTildePrefix(path)
    if path:sub(1, 2) == '~/' then
        path = util.envHome .. path:sub(2)
    end
    return path
end


-- if `homeTilde` and `path` is prefixed with (actual, current) `$HOME/`, the prefix is changed to `~/`.
-- if `spacedSlashes`, all slashes get surrounded by white-space.
function util.fsPathPrettify(path, homeTilde, spacedSlashes)
    if homeTilde and path:sub(1, #envHomeSlash) == envHomeSlash then
        path = '~' .. path:sub(#envHomeSlash)
    end
    if spacedSlashes then
        path = path:gsub('/', ' / ')
    end
    return path
end


-- returns the `baz` in `foo/bar/baz` and `/foo/bar/baz` etc.
function util.fsPathBaseName(path)
    return path:gsub("(.*/)(.*)", "%2")
end

-- returns the `foo/bar/` in `foo/bar/baz` and the `/foo/bar/` in `/foo/bar/baz` etc.
function util.fsPathParentDir(path)
    return path:gsub("(.*/)(.*)", "%1")
end


-- returns whether any segment in `path` begins with a period `.` char
function util.fsPathHasDotNames(path)
    for split in string.gmatch(path, "([^/]+)") do
        if split:sub(1, 1) == '.' then return true end
    end
    return false
end


-- returns the names of all sub-directories in `dirFullPath`
function util.fsSubDirNames(dirFullPath)
    local subdirs = {}
    lfs.dir_foreach(dirFullPath, function(fullpath)
        if fullpath:sub(-1) == '/' then
            local subdirname = fullpath:sub(2 + #dirFullPath)
            if subdirname:sub(1, 1) ~= '.' then
                subdirs[1 + #subdirs] = subdirname
            end
        end
    end, nil, 0, true)
    return subdirs
end


-- because get_sel_text concats all multiple selections, here's one that won't:
function util.bufSelText(fullTextIfNoSelection)
    if buffer.selection_empty then
        return fullTextIfNoSelection and buffer:get_text() or ''
    end
    return buffer:text_range(buffer.selection_start, buffer.selection_end)
end


function util.bufClearHighlightedWords()
    buffer.indicator_current = textadept.editing.INDIC_HIGHLIGHT
    buffer:indicator_clear_range(0, buffer.length)
end


function util.bufIndexOf(bufOrBufFilePathOrBufTabLabel)
    for i, buf in ipairs(_BUFFERS) do
        if ((not bufOrBufFilePathOrBufTabLabel) and buf == buffer)
            or bufOrBufFilePathOrBufTabLabel == buf
                or bufOrBufFilePathOrBufTabLabel == (buf.filename or buf.tab_label)
        then
            return i
        end
    end
    return nil
end


function util.bufIsUpdateOf(upd, ...)
    if upd then
        for _, chk in ipairs({...}) do
            if upd&chk == chk then
                return true
            end
        end
    end
    return false
end


function util.uxStrMenuable(text)
    return util.strBreakOn(util.strTrimLeft(text), '\n', "   ‹…›"):gsub('_', '__')
end


function util.uxStrNowTime(pref, suff)
    if (not pref) and (not suff) then pref, suff = '[ ', ' ]\t' end
    return os.date((pref or '') .. "%H:%M:%S" .. (suff or ''))
end


function util.arrFind(arr, chk)
    for _, val in ipairs(arr) do
        if chk(val) then return val end
    end
end


function util.strBreakOn(s, beforestr, suffix)
    if #s > #beforestr then
        for i = 1, #s do
            if beforestr == s:sub(i, (i - 1) + #beforestr) then
                return s:sub(1, i - 1) .. (suffix or '')
            end
        end
    end
    return s
end


-- avoiding patterns for such fundamental hi-freq aspire-to-realtime ops
function util.strTrimLeft(s) -- , dbg)
    local len = #s
    if (not s) or len == 0 then return '' end
    local pos = 0
    for i = 1, len do
        local chr = s:sub(i, i)
        if not (chr==' ' or chr=='	' or chr=='\t' or chr=='\r' or chr=='\n' or chr=='\v' or chr=='\b') then
            --if i == 1 and dbg then
                --ui.print(string.format("WUT::%q::",chr))
            --end
            pos = i
            break
        end
    end
    return (pos ~= 0) and ((pos == 1) and s or s:sub(pos)) or ''
end


function util.osSpawnProc(cmd, stdoutSplitSep, onStdout, stderrSplitSep, onStdErr, nonWritable, onFailOrExit)
    local lnout, lnerr = '', ''

    local onstdout, onstderr, onexit = function(txt)
        if txt and #txt > 0 then
            if txt:sub(-1) == stdoutSplitSep then
                onStdout(lnout..txt:sub(1, -2))
                lnout = ''
            else
                lnout = lnout..txt
            end
        end
    end, function(txt)
        if txt and #txt > 0 then
            if txt:sub(-1) == stderrSplitSep then
                onStderr(lnerr..txt:sub(1, -2))
                lnerr = ''
            else
                lnerr = lnerr..txt
            end
        end
    end, function(exitcode)
        if lnout ~= '' then onStdout(lnout) end
        if lnerr ~= '' then onStderr(lnerr) end
        if onFailOrExit then onFailOrExit(nil, exitcode) end
    end

    local proc, errmsg = os.spawn(cmd, onstdout, onstderr, onexit)
    if (not proc) then
        if onFailOrExit then onFailOrExit(errmsg, nil) end
    elseif nonWritable then
        proc:close()
    end
    return proc
end




do
    events.connect(events.RESET_BEFORE, function(bag)
        local stash = {}
        for k, v in pairs(util.resetBag) do
            stash[k] = v.get()
        end
        bag['metaleap_zentient.util.resetBag'] = stash
    end)
    events.connect(events.RESET_AFTER, function(bag)
        local stash = bag['metaleap_zentient.util.resetBag']
        if stash then
            for k, v in pairs(stash) do
                util.resetBag[k].set(v)
            end
        end
    end)

    local emitEventBufSwitch = function()
        events.emit(util.eventBufSwitch, util.bufIndexOf())
    end
    events.connect(events.FILE_OPENED, emitEventBufSwitch)
    events.connect(events.BUFFER_NEW, emitEventBufSwitch)
    events.connect(events.BUFFER_AFTER_SWITCH, emitEventBufSwitch)
end



return util
