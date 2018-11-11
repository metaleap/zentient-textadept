local me = {}



local util = require 'metaleap_zentient.util'
local ux = require 'metaleap_zentient.ux'
local favdirs = require 'metaleap_zentient.favdirs'
local favcmds = require 'metaleap_zentient.favcmds'
local notify = require 'metaleap_zentient.notify'
local srcmod = require 'metaleap_zentient.srcmod'
local ipc = require 'metaleap_zentient.ipc'


me.langProgs = {}
me.favCmds = {}
me.favDirs = {}


function me.startUp()
    ux.init()
    favdirs.init(me.favDirs)
    favcmds.init(me.favCmds)
    notify.init()
    srcmod.init()
    ipc.init(me.langProgs)
end


function me.init()
    events.connect(events.BUFFER_NEW, function()
        if not buffer.bufid then buffer.bufid = tostring(math.random() * os.clock() * os.time()) end
    end)

    events.connect(events.INITIALIZED, me.startUp)
end



return me
