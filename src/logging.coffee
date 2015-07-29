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


logging = 
  VERBOSE:  0x01   # For raw data transfer log
  DEBUG:    0x03   # For handshake, auth, cmd and transfer event log
  LOG:      0x07   # For SOCKS5 link establish log 
  INFO:     0x0F   # For generic error
  WARN:     0x1F   # For warning
  ERROR:    0x3F   # For unrecoverable error
  _empty:   ()->

  error: (msg...) ->
    logging.sendMessage msg.join ' '
    console.error msg...

  sendMessage: (msg, responseCallback) ->
    chrome.runtime.sendMessage
      type: "LOGMSG"
      data:
        msg: msg
        type: "danger"
      timeout: 5000
    , responseCallback


logging.setLevel = (level) ->
  console._verbose = if (level & logging.VERBOSE) is level then console.debug else logging._empty
  console._debug   = if (level & logging.DEBUG)   is level then console.debug else logging._empty
  console._log     = if (level & logging.LOG)     is level then console.log   else logging._empty
  console._info    = if (level & logging.INFO)    is level then console.info  else logging._empty
  console._warn    = if (level & logging.WARN)    is level then console.warn  else logging._empty
  console._error   = if (level & logging.ERROR)   is level then logging.error else logging._empty
  return

logging.setLevel logging.WARN