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


Crypto = if Crypto? then Crypto else {}


# (String, binstr, binstr, 0|1)
Crypto.RC4_MD5 = (cipher_name, key, iv, op) ->
  md5 = do forge.md.md5.create
  md5.update key
  md5.update iv
  rc4_key = md5.digest().bytes()
  @cipher = new RC4 Common.str2Uint8 rc4_key
  return


# (Uint8Array) -> Uint8Array
Crypto.RC4_MD5::update = (data) ->
  len    = data.length
  buf    = new Uint8Array data
  result = new Uint8Array len
  @cipher.update result, buf, len
  return result