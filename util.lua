local util = {}



envHome = os.getenv("HOME")
local envHomeSlash = envHome .. '/'


-- if `path` is prefixed with `~/`, changes the prefix to (actual, current) `$HOME/`
function util.fsPathExpandHomeDirTildePrefix(path)
    if path:sub(1, 2) == '~/' then
        path = envHome .. path:sub(2)
    end
    return path
end


-- if `homeTilde` and `path` is prefixed with (actual, current) `$HOME/`, the prefix is changed to `~/`.
-- if `slashSpaces`, all slashes get surrounded by white-space.
function util.fsPathPrettify(path, homeTilde, slashSpaces)
    if homeTilde and path:sub(1, #envHomeSlash) == envHomeSlash then
        path = '~' .. path:sub(#envHomeSlash)
    end
    if slashSpaces then
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



return util