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


SOCKS5 = (config = {}) ->
  @tcp_socket_info = {}
  @udp_socket_info = {}
  @socket_server_id = null
  {@server, @server_port, @password, @method, @local_port, @timeout} = config
  return


SOCKS5::handle_accept = (info) ->
  {socketId, clientSocketId} = info
  return if socketId isnt @socket_server_id
  @tcp_socket_info[clientSocketId] =
    type:            "local"
    status:          "auth"
    cipher:          new Encryptor @password, @method
    socket_id:       clientSocketId
    cipher_action:   "encrypt"
    peer_socket_id:  null
    last_connection: do Date.now
  chrome.sockets.tcp.setPaused clientSocketId, false
  console._debug "Accepting to new socket: #{clientSocketId}"


SOCKS5::handle_recv = (info) ->
  {socketId, data} = info
  if socketId not of @tcp_socket_info
    console._info "Unknown or closed TCP socket: #{socketId}"
    return @close_socket socketId, false, "tcp"
  console._verbose "TCP socket #{socketId}: data received."

  array = new Uint8Array data
  switch @tcp_socket_info[socketId].status
    when "cmd" then @cmd socketId, array
    when "auth" then @auth socketId, array
    when "tcp_relay" then @tcp_relay socketId, array
    when "udp_relay" then console._info "Unexcepted TCP packet received when relaying udp:", array
    else console._warn "FSM: Not a valid state for #{socketId}: #{@tcp_socket_info[socketId].status}."


SOCKS5::handle_udp_recv = (info) ->
  {socketId, data, remoteAddress, remotePort} = info
  if socketId not of @udp_socket_info
    console._info "Unknown or closed UDP socket: #{socketId}"
    return @close_socket socketId, false, "udp"
  console._verbose "UDP socket #{socketId}: data received."
  @udp_relay socketId, new Uint8Array(data), remoteAddress, remotePort


SOCKS5::handle_accepterr = (info) ->
  {socketId, resultCode} = info
  console._warn "Accepting on server socket #{socketId} occurs accept error #{resultCode}"


SOCKS5::handle_recverr = (info) ->
  {socketId, resultCode} = info
  console._info "TCP socket #{socketId} occurs receive error #{resultCode}" if resultCode isnt -100
  @close_socket socketId


SOCKS5::handle_udp_recverr = (info) ->
  {socketId, resultCode} = info
  console._info "UDP socket #{socketId} occurs receive error #{resultCode}"
  if socketId of @udp_socket_info
    @close_socket @udp_socket_info[socketId].host_tcp_id
  else
    @close_socket socketId, false, "udp"


SOCKS5::config = (config) ->
  {@server, @server_port, @password, @method, @local_port, @timeout} = config


SOCKS5::listen = (callback) ->
  chrome.sockets.tcpServer.create {}, (createInfo) =>
    @socket_server_id = createInfo.socketId
    chrome.sockets.tcpServer.listen @socket_server_id, '0.0.0.0', @local_port | 0, (result) =>
      if result < 0 or chrome.runtime.lastError
        console.error "Listen on port #{@local_port} failed:", chrome.runtime.lastError.message
        chrome.sockets.tcpServer.close @socket_server_id
        @socket_server_id = null
        callback.call null, "Listen on port #{@local_port} failed:" + chrome.runtime.lastError.message
        return

      console.info "Listening on port #{@local_port}..."
      chrome.sockets.tcpServer.onAccept.addListener      @accept_handler      = (info) => @handle_accept info
      chrome.sockets.tcpServer.onAcceptError.addListener @accepterr_handler   = (info) => @handle_accepterr info
      chrome.sockets.tcp.onReceive.addListener           @recv_handler        = (info) => @handle_recv info
      chrome.sockets.tcp.onReceiveError.addListener      @recverr_handler     = (info) => @handle_recverr info
      chrome.sockets.udp.onReceive.addListener           @udp_recv_handler    = (info) => @handle_udp_recv info
      chrome.sockets.udp.onReceiveError.addListener      @udp_recverr_handler = (info) => @handle_udp_recverr info

      @sweep_task_id = setInterval () =>
        do @sweep_socket
      , @timeout * 1000

      callback.call null, "Listening on port #{@local_port}..."


SOCKS5::terminate = (callback) ->
  console.info "Terminating server..."
  chrome.sockets.tcpServer.onAccept.removeListener       @accept_handler
  chrome.sockets.tcpServer.onAcceptError.removeListener  @accepterr_handler
  chrome.sockets.tcp.onReceive.removeListener            @recv_handler
  chrome.sockets.tcp.onReceiveError.removeListener       @recverr_handler
  chrome.sockets.udp.onReceive.removeListener            @udp_recv_handler
  chrome.sockets.udp.onReceiveError.removeListener       @udp_recverr_handler

  if not @socket_server_id
    callback.call null, "Server had been terminated"
    return console.info "Server had been terminated"

  chrome.sockets.tcpServer.close @socket_server_id, () =>
    @socket_server_id = null

    clearInterval @sweep_task_id
    @close_socket socket_id, false, "tcp" for socket_id of @tcp_socket_info
    @close_socket socket_id, false, "udp" for socket_id of @udp_socket_info

    callback.call null, "Server has been terminated"
    console.info "Server has been terminated"


SOCKS5::auth = (socket_id, data) ->
  console._debug "Start processing auth procedure"
  if data[0] isnt 0x05  # VER
    @close_socket socket_id
    console._warn "Not a valid SOCKS5 auth packet, closed."
    return

  if Common.typedIndexOf(data, 0x00, 2) is -1   # Bypass VER and NMETHODS
    console._warn "Client doesn't support no authentication."
    chrome.sockets.tcp.send socket_id, new Uint8Array([0x05, 0xFF]).buffer, () =>
      @close_socket socket_id
    return

  chrome.sockets.tcp.send socket_id, new Uint8Array([0x05, 0x00]).buffer, (sendInfo) =>
    if not sendInfo or sendInfo.resultCode < 0 or chrome.runtime.lastError
      console._error "Failed to send choice no authentication method to client:", chrome.runtime.lastError.message
      @close_socket socket_id, false, "tcp"
      return
    @tcp_socket_info[socket_id].status = "cmd"
    @tcp_socket_info[socket_id].last_connection = do Date.now
    console._log "SOCKS5 auth passed"


SOCKS5::cmd = (socket_id, data) ->
  if data[0] isnt 0x05 or data[2] isnt 0x00   # VER and RSV
    console._warn "Not a valid SOCKS5 cmd packet."
    @close_socket socket_id
    return

  header = Common.parseHeader data
  switch header.cmd
    when 0x01 then @cmd_connect  socket_id, header, data
    when 0x02 then @cmd_bind     socket_id, header, data
    when 0x03 then @cmd_udpassoc socket_id, header, data
    else
      reply = Common.packHeader 0x07, 0x01, '0.0.0.0', 0
      chrome.sockets.tcp.send socket_id, reply.buffer, () =>
        @close_socket socket_id
      console._warn "Not a valid CMD field."
  @tcp_socket_info[socket_id].last_connection = do Date.now


SOCKS5::cmd_connect = (socket_id, header, origin_data) ->
  # TODO: try/catch surround?
  console._debug "Start processing connect command"
  return if socket_id not of @tcp_socket_info
  chrome.sockets.tcp.create name: 'remote_socket', (createInfo) =>
    @tcp_socket_info[socket_id].peer_socket_id = createInfo.socketId
    console._verbose "TCP socket to remote server created on #{createInfo.socketId}"

    chrome.sockets.tcp.connect createInfo.socketId, @server, @server_port | 0, (result) =>
      error_reply = Common.packHeader 0x01, 0x01, '0.0.0.0', 0
      if result < 0 or chrome.runtime.lastError
        console._error "Failed to connect to shadowsocks server:", chrome.runtime.lastError.message
        chrome.sockets.tcp.send socket_id, error_reply.buffer, () =>
          @close_socket socket_id
          @close_socket createInfo.socketId
        return

      console._verbose "TCP socket #{createInfo.socketId} to remote server connection established"
      @tcp_socket_info[createInfo.socketId] =
        type:            "remote"
        status:          "tcp_relay"
        cipher:          @tcp_socket_info[socket_id].cipher
        socket_id:       createInfo.socketId
        peer_socket_id:  socket_id
        cipher_action:   "decrypt"
        last_connection: do Date.now

      data = @tcp_socket_info[socket_id].cipher.encrypt new Uint8Array origin_data.subarray 3
      chrome.sockets.tcp.send createInfo.socketId, data.buffer, (sendInfo) =>
        if not sendInfo or sendInfo.resultCode < 0 or chrome.runtime.lastError
          console._error "Failed to send encrypted request to shadowsocks server:", chrome.runtime.lastError.message
          chrome.sockets.tcp.send socket_id, error_reply.buffer, () =>
            @close_socket socket_id
          return

        console._verbose "TCP relay request had been sent to remote server"
        data = Common.packHeader 0x00, 0x01, '0.0.0.0', 0
        chrome.sockets.tcp.send socket_id, data.buffer, (sendInfo) =>
          if not sendInfo or sendInfo.resultCode < 0 or chrome.runtime.lastError
            console._error "Failed to send connect success reply to client:", chrome.runtime.lastError.message
            @close_socket socket_id
            return

          @tcp_socket_info[socket_id].status = "tcp_relay"
          console._log "SOCKS5 connect okay"


SOCKS5::cmd_bind = (socket_id, header, origin_data) ->
  console._warn "CMD BIND is not implemented in shadowsocks."
  data = Common.packHeader 0x07, 0x01, '0.0.0.0', 0
  chrome.sockets.tcp.send socket_id, data.buffer, () =>
    @close_socket socket_id


SOCKS5::cmd_udpassoc = (socket_id, header, origin_data) ->
  console._debug "Udp associated request on socket #{socket_id}"
  return if socket_id not of @tcp_socket_info
  chrome.sockets.udp.create name: "local_socket", (socketInfo) =>
    socketId = socketInfo.socketId    # local udp socket id

    @udp_socket_info[socketId] =
      type:            "local"
      socket_id:       socketId
      host_tcp_id:     socket_id
      peer_socket_id:  null
      last_connection: do Date.now

    chrome.sockets.udp.bind socketId, '127.0.0.1', 0, (result) =>
      if result < 0 or chrome.runtime.lastError
        console._error "Failed to bind local UDP socket to free port", chrome.runtime.lastError.message
        @close_socket socketId, false, "udp"
        @close_socket socket_id, false, "tcp"
        return

      console._verbose "UDP local-side socket created and bound"
      chrome.sockets.udp.create name: "remote_socket", (socketInfo) =>
        @udp_socket_info[socketId].peer_socket_id = socketInfo.socketId
        @udp_socket_info[socketInfo.socketId] =
          type:            "remote"
          socket_id:       socketInfo.socketId
          host_tcp_id:     socket_id
          peer_socket_id:  socketId
          last_connection: do Date.now

        chrome.sockets.udp.bind socketInfo.socketId, '0.0.0.0', 0, (result) =>
          if result < 0 or chrome.runtime.lastError
            console._error "Failed to bind remote UDP socket to free port", chrome.runtime.lastError.message
            @close_socket socket_id, false, "tcp"
            @close_socket socketInfo.socketId, true, "udp"
            return

          console._verbose "UDP remote-side socket created and bound"
          chrome.sockets.udp.getInfo socketId, (socketInfo) =>
            {localAddress, localPort} = socketInfo    # local udp socket addr and port
            console._verbose "UDP local-side socket bound on #{localAddress}:#{localPort}"

            data = Common.packHeader 0x00, null, localAddress, localPort
            chrome.sockets.tcp.send socket_id, data.buffer, (sendInfo) =>
              if not sendInfo or sendInfo.resultCode < 0 or chrome.runtime.lastError
                console._error "Failed to send UDP relay init success message", chrome.runtime.lastError.message
                @close_socket socketId, true, "udp"
                @close_socket socket_id, false, "tcp"
              return

              @tcp_socket_info[socket_id].status = "udp_relay"
              @tcp_socket_info[socket_id].peer_socket_id = socketId
              console._log "TCP reply for success init UDP relay sent"


SOCKS5::tcp_relay = (socket_id, data_array) ->
  # TODO: try/catch surround?
  return if socket_id not of @tcp_socket_info
  now = do Date.now
  socket_info = @tcp_socket_info[socket_id]
  socket_info.last_connection = now
  peer_socket_id = socket_info.peer_socket_id
  return if peer_socket_id not of @tcp_socket_info
  @tcp_socket_info[peer_socket_id].last_connection = now
  # console._verbose "Relaying TCP data from #{socket_id} to #{peer_socket_id}"

  data = socket_info.cipher[socket_info.cipher_action] data_array
  chrome.sockets.tcp.send peer_socket_id, data.buffer, (sendInfo) =>
    if not sendInfo or sendInfo.resultCode < 0 or chrome.runtime.lastError and socket_id of @tcp_socket_info
      console._info "Failed to relay TCP data from #{socket_info.type}
        #{socket_id} to peer #{peer_socket_id}:", chrome.runtime.lastError
      return @close_socket socket_id


SOCKS5::udp_relay = (socket_id, data_array, remoteAddress, remotePort) ->
  # TODO: try/catch surround?
  return @close_socket socket_id, true, "udp" if data_array[2] isnt 0x00
  now = do Date.now
  socket_info = @udp_socket_info[socket_id]
  socket_info.last_connection = now
  peer_socket_id = socket_info.peer_socket_id
  @udp_socket_info[peer_socket_id].last_connection = now
  @tcp_socket_info[socket_info.host_tcp_id].last_connection = now
  # console._verbose "Relaying UDP data from #{socket_id} to #{peer_socket_id}"

  if socket_info.type is "local"
    data = Encryptor.encrypt_all @password, @method, 1, new Uint8Array data_array.subarray 3
    addr = @server; port = @server_port | 0
  else
    decrypted = Encryptor.encrypt_all @password, @method, 0, data_array
    data = new Uint8Array decrypted.length + 3
    data.set decrypted, 3   # First 3 elements default to 0 when created
    addr = remoteAddress; port = remotePort

  chrome.sockets.udp.send peer_socket_id, data.buffer, addr, port, (sendInfo) =>
    if sendInfo.resultCode < 0 or chrome.runtime.lastError
      console._info "Failed to relay UDP data from #{socket_info.type}
        #{socket_id} to peer #{peer_socket_id}:", chrome.runtime.lastError
      return @close_socket socket_info.host_tcp_id, true, "tcp"


SOCKS5::close_socket = (socket_id, close_peer = true, protocol = "tcp") ->
  console._debug "Closing #{protocol} socket #{socket_id}"
  socket_id |= 0  # convert possible string to number
  if socket_id of @["#{protocol}_socket_info"]
    peer_socket_id = @["#{protocol}_socket_info"][socket_id].peer_socket_id
    if close_peer and @["#{protocol}_socket_info"][socket_id].status is "udp_relay"
      @close_socket peer_socket_id, true, "udp"
      close_peer = false
    delete @["#{protocol}_socket_info"][socket_id]['cipher']
    delete @["#{protocol}_socket_info"][socket_id]
  chrome.sockets[protocol].close socket_id, () =>
    if chrome.runtime.lastError and chrome.runtime.lastError.message isnt "Socket not found"
      console._info "Error on close #{protocol} socket #{socket_id}:",
                    chrome.runtime.lastError.message
    console._log "#{protocol} socket #{socket_id} closed"
    if close_peer and peer_socket_id of @["#{protocol}_socket_info"]
      @close_socket peer_socket_id, false, protocol


SOCKS5::sweep_socket = () ->
  console._debug "Sweeping timeouted socket..."
  for socket_id, socket of @tcp_socket_info
    if Date.now() - socket.last_connection >= @timeout * 1000
      chrome.sockets.tcp.getInfo socket_id|0, (socketInfo) =>
        @close_socket socket_id if not socketInfo.connected
        console._log "TCP socket #{socket_id} has been swept"
  for socket_id, socket of @udp_socket_info
    if Date.now() - socket.last_connection >= @timeout * 1000
      @close_socket socket_id, true, "udp"
      console._log "UDP socket #{socket_id} has been swept"
  return