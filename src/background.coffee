# Copyright (C) 2015  Sunny <ratsunny@gmail.com>
#
# This file is part of shadowsocks-chromeapp.
#
# Shadowsocks-chromeapp is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Shadowsocks-chromeapp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


sswindow = null
sslocal = new SOCKS5()

chrome.app.runtime.onLaunched.addListener () ->
  chrome.app.window.create '../views/window.html',
    id: 'shadowsocks-gui'
    innerBounds:
      width:  345
      height: 410
    resizable: false
  , (createdWindow) ->
    if createdWindow isnt sswindow
      sswindow = createdWindow
      sswindow.onMinimized.addListener () ->
        do sswindow.hide
    do sswindow.show


chrome.runtime.onMessage.addListener (msg, sender, sendResp) ->
  {type, config} = msg;
  return if type isnt "SOCKS5OP"
  sslocal.terminate () ->
    sslocal.config config if config
    sslocal.listen (info) ->
      sendResp info
  return true