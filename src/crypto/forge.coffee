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
Crypto.Forge = (cipher_name, key, iv, op) ->
  cipher_info = cipher_name.match /^(aes)-(128|192|256)-(cfb|ofb|ctr)$/i
  console.assert key.length is cipher_info[2] / 8, "Cipher and key length mismatch."
  if op is 1  # cipher
    @cipher = forge.cipher.createCipher "#{cipher_info[1]}-#{cipher_info[3]}", key
  else        # 0 is decipher
    @cipher = forge.cipher.createDecipher "#{cipher_info[1]}-#{cipher_info[3]}", key
  @cipher.start iv: iv
  return


# (Uint8Array) -> Uint8Array
Crypto.Forge::update = (data) ->
  @cipher.update forge.util.createBuffer Common.uint82Str data
  return Common.str2Uint8 do @cipher.output.getBytes