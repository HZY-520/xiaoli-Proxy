package com.lico.proxy.vpn.socket

import com.lico.proxy.vpn.Connection

interface CloseableConnection {
    /**
     * 关闭连接
     */
    fun closeConnection(connection: Connection)
}