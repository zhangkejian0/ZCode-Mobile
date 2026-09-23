package app.zcode.mobile.remote

import app.zcode.mobile.model.Device
import app.zcode.mobile.security.SecureStorage
import app.zcode.mobile.util.RemoteUrl
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Multiple saved ZCode Desktops with one active at a time. [device] is the active
 * connection the WebView follows; switching replaces it and the UI layer resets
 * the WebView session so devices never share cookies or observed tasks.
 */
class ZCodeRemoteManager(
    private val secureStorage: SecureStorage,
    private val sessionManager: SessionManager,
) {
    private val _devices = MutableStateFlow(secureStorage.devices())
    val devices: StateFlow<List<Device>> = _devices.asStateFlow()

    private val _device = MutableStateFlow(secureStorage.activeId()?.let { activeById(it) })
    val device: StateFlow<Device?> = _device.asStateFlow()

    val hasConnection: Boolean
        get() = !_device.value?.remoteUrl.isNullOrBlank()

    /** Saves (or refreshes an exact-URL match) and activates the device; true when the active device changed.
     *  New devices default to the link's host so several desktops stay distinguishable. */
    fun addOrActivate(url: String, name: String = ""): Boolean {
        val parsed = RemoteUrl.parse(url) ?: return false
        val fallbackName = RemoteUrl.displayHost(parsed.raw)
        val device = secureStorage.upsertByUrl(parsed.raw, name.ifBlank { fallbackName })
        val changed = _device.value?.id != device.id
        publish(device)
        return changed
    }

    fun switchTo(id: String): Boolean {
        if (!secureStorage.setActive(id)) return false
        val target = activeById(id) ?: return false
        if (_device.value?.id == id) return false
        publish(target)
        return true
    }

    /** Removes a saved device; true when the active device was removed (and a successor took over). */
    fun remove(id: String): Boolean {
        val wasActive = secureStorage.remove(id)
        if (!wasActive) {
            _devices.value = secureStorage.devices()
            return false
        }
        publish(secureStorage.activeId()?.let { activeById(it) })
        return true
    }

    fun clearAll(clearWebData: Boolean = false) {
        secureStorage.clearAll()
        if (clearWebData) {
            sessionManager.clear()
        }
        _devices.value = emptyList()
        _device.value = null
    }

    fun rename(id: String, newName: String) {
        if (!secureStorage.rename(id, newName)) return
        _devices.value = secureStorage.devices()
        _device.value = _device.value?.let { current ->
            if (current.id == id) current.copy(name = secureStorage.devices().firstOrNull { it.id == id }?.name ?: current.name) else current
        }
    }

    fun markConnected(connected: Boolean) {
        val current = _device.value ?: return
        _device.value = current.copy(connected = connected)
    }

    fun reconnect() {
        _device.value = secureStorage.activeId()?.let { activeById(it) }
    }

    fun currentUrl(): String? = _device.value?.remoteUrl

    private fun publish(active: Device?) {
        _devices.value = secureStorage.devices()
        _device.value = active
    }

    private fun activeById(id: String): Device? =
        secureStorage.devices().firstOrNull { it.id == id }?.let { Device(id = it.id, name = it.name, remoteUrl = it.remoteUrl) }
}
