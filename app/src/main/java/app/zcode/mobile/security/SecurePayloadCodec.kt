package app.zcode.mobile.security

import app.zcode.mobile.model.Device
import org.json.JSONArray
import org.json.JSONObject

/** Saved devices plus the active device id, as persisted (encrypted) by [SecureStorage]. */
data class DeviceStore(
    val devices: List<Device> = emptyList(),
    val activeId: String? = null,
) {
    val active: Device?
        get() = devices.firstOrNull { it.id == activeId }
}

object SecurePayloadCodec {
    /**
     * v2 payload: multiple devices plus the active id.
     * {
     *   "v": 2,
     *   "active_id": "…",
     *   "devices": [{"id": "…", "name": "…", "remote_url": "…"}]
     * }
     */
    fun encodeStore(store: DeviceStore): String {
        val devices = JSONArray()
        store.devices.forEach { device ->
            devices.put(
                JSONObject()
                    .put("id", device.id)
                    .put("name", device.name)
                    .put("remote_url", device.remoteUrl),
            )
        }
        return JSONObject()
            .put("v", 2)
            .put("active_id", store.activeId ?: "")
            .put("devices", devices)
            .toString()
    }

    /** Decodes v2 payloads, and migrates the pre-multi-device single-connection payload. */
    fun decodeStore(json: String): DeviceStore {
        val obj = JSONObject(json)
        if (obj.optInt("v") == 2) {
            val devices = mutableListOf<Device>()
            val arr = obj.optJSONArray("devices") ?: JSONArray()
            for (i in 0 until arr.length()) {
                val entry = arr.optJSONObject(i) ?: continue
                val id = entry.optString("id")
                val url = entry.optString("remote_url")
                if (id.isBlank() || url.isBlank()) continue
                devices.add(
                    Device(
                        id = id,
                        name = entry.optString("name").ifBlank { "ZCode Desktop" },
                        remoteUrl = url,
                    ),
                )
            }
            val activeId = obj.optString("active_id").ifBlank { null }
            return DeviceStore(
                devices = devices,
                activeId = if (devices.any { it.id == activeId }) activeId else devices.firstOrNull()?.id,
            )
        }
        // Legacy single-connection payload: remote_url / device_name.
        val (url, name) = decodeJson(json)
        if (url.isNullOrBlank()) return DeviceStore()
        val device = Device(id = "legacy", name = name, remoteUrl = url)
        return DeviceStore(devices = listOf(device), activeId = device.id)
    }

    fun encodeJson(remoteUrl: String?, deviceName: String): String {
        return JSONObject()
            .put("remote_url", remoteUrl ?: "")
            .put("device_name", deviceName)
            .toString()
    }

    fun decodeJson(json: String): Pair<String?, String> {
        val obj = JSONObject(json)
        val url = obj.optString("remote_url").ifBlank { null }
        val name = obj.optString("device_name", "ZCode Desktop")
        return url to name
    }

    fun pack(iv: ByteArray, ciphertext: ByteArray): ByteArray {
        val packed = ByteArray(iv.size + ciphertext.size)
        System.arraycopy(iv, 0, packed, 0, iv.size)
        System.arraycopy(ciphertext, 0, packed, iv.size, ciphertext.size)
        return packed
    }

    fun unpack(packed: ByteArray, ivSize: Int = 12): Pair<ByteArray, ByteArray>? {
        if (packed.size <= ivSize) return null
        val iv = packed.copyOfRange(0, ivSize)
        val cipher = packed.copyOfRange(ivSize, packed.size)
        return iv to cipher
    }
}
