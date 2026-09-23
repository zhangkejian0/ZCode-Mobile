package app.zcode.mobile.security

import app.zcode.mobile.model.Device
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SecurePayloadCodecTest {
    @Test
    fun jsonRoundTrip() {
        val json = SecurePayloadCodec.encodeJson("https://h/remote/x", "ZCode Desktop")
        val (url, name) = SecurePayloadCodec.decodeJson(json)
        assertEquals("https://h/remote/x", url)
        assertEquals("ZCode Desktop", name)
    }

    @Test
    fun packUnpack() {
        val iv = ByteArray(12) { it.toByte() }
        val cipher = byteArrayOf(1, 2, 3, 4)
        val packed = SecurePayloadCodec.pack(iv, cipher)
        val unpacked = SecurePayloadCodec.unpack(packed)
        assertArrayEquals(iv, unpacked!!.first)
        assertArrayEquals(cipher, unpacked.second)
        assertNull(SecurePayloadCodec.unpack(ByteArray(4)))
    }

    @Test
    fun storeRoundTrip() {
        val store = DeviceStore(
            devices = listOf(
                Device(id = "a", name = "工作室台式机", remoteUrl = "https://192.168.1.5/session/abc"),
                Device(id = "b", name = "笔记本", remoteUrl = "http://laptop.local:8421/session/def"),
            ),
            activeId = "b",
        )
        val decoded = SecurePayloadCodec.decodeStore(SecurePayloadCodec.encodeStore(store))
        assertEquals(store.devices, decoded.devices)
        assertEquals("b", decoded.activeId)
        assertEquals("笔记本", decoded.active?.name)
    }

    @Test
    fun storeRoundTripEmpty() {
        val decoded = SecurePayloadCodec.decodeStore(SecurePayloadCodec.encodeStore(DeviceStore()))
        assertEquals(emptyList<Device>(), decoded.devices)
        assertNull(decoded.activeId)
        assertNull(decoded.active)
    }

    @Test
    fun storeDecodeDropsBrokenEntriesAndHealsActiveId() {
        val json = """
            {"v":2,"active_id":"missing","devices":[
              {"id":"","name":"no id","remote_url":"https://h/1"},
              {"id":"c","name":"no url","remote_url":""},
              {"id":"ok","name":"好设备","remote_url":"https://h/session/k"}
            ]}
        """.trimIndent()
        val decoded = SecurePayloadCodec.decodeStore(json)
        assertEquals(listOf(Device(id = "ok", name = "好设备", remoteUrl = "https://h/session/k")), decoded.devices)
        assertEquals("ok", decoded.activeId)
    }

    @Test
    fun legacySingleConnectionMigratesToStore() {
        val legacy = SecurePayloadCodec.encodeJson("https://192.168.1.5/session/abc", "台式机")
        val decoded = SecurePayloadCodec.decodeStore(legacy)
        assertEquals(1, decoded.devices.size)
        assertEquals("https://192.168.1.5/session/abc", decoded.devices.first().remoteUrl)
        assertEquals("台式机", decoded.devices.first().name)
        assertEquals(decoded.devices.first().id, decoded.activeId)
    }

    @Test
    fun legacyEmptyPayloadBecomesEmptyStore() {
        val legacy = SecurePayloadCodec.encodeJson(null, "ZCode Desktop")
        val decoded = SecurePayloadCodec.decodeStore(legacy)
        assertEquals(emptyList<Device>(), decoded.devices)
        assertNull(decoded.activeId)
    }
}
