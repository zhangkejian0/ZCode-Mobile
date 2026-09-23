package app.zcode.mobile.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import app.zcode.mobile.model.Device
import app.zcode.mobile.util.AppLog
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Saved devices and the active device id are encrypted with AES-GCM.
 * The key lives in Android Keystore and never leaves the device.
 * Reads migrate the pre-multi-device single-connection payload transparently.
 */
class SecureStorage(context: Context) {
    private val lock = ReentrantLock()
    private val file = File(context.applicationContext.filesDir, FILE_NAME)
    // Guarded by [lock]; replaced wholesale because DeviceStore is immutable.
    private var cache: DeviceStore = lock.withLock { readUnlocked() }

    fun devices(): List<Device> = lock.withLock { cache.devices.toList() }

    fun activeId(): String? = lock.withLock { cache.activeId }

    /** Inserts or updates a device (matched by id) and makes it the active one. */
    fun upsert(device: Device) {
        lock.withLock {
            val others = cache.devices.filter { it.id != device.id }
            val updated = Device(id = device.id, name = device.name, remoteUrl = device.remoteUrl)
            writeUnlocked(DeviceStore(devices = others + updated, activeId = device.id))
        }
    }

    /** Inserts or updates a device matched by exact URL (a re-scanned link refreshes the entry). */
    fun upsertByUrl(remoteUrl: String, name: String): Device {
        lock.withLock {
            val existing = cache.devices.firstOrNull { it.remoteUrl == remoteUrl }
            val device = Device(
                id = existing?.id ?: newId(),
                name = existing?.name?.takeIf { it != "ZCode Desktop" } ?: name,
                remoteUrl = remoteUrl,
            )
            val others = cache.devices.filter { it.id != device.id }
            writeUnlocked(DeviceStore(devices = others + device, activeId = device.id))
            return device
        }
    }

    fun setActive(id: String): Boolean {
        lock.withLock {
            if (cache.devices.none { it.id == id }) return false
            if (cache.activeId == id) return true
            writeUnlocked(cache.copy(activeId = id))
            return true
        }
    }

    /** Removes a device. Returns true if it was the active one; the successor becomes active. */
    fun remove(id: String): Boolean {
        lock.withLock {
            val remaining = cache.devices.filter { it.id != id }
            if (remaining.size == cache.devices.size) return false
            val wasActive = cache.activeId == id
            val nextActive = if (wasActive) remaining.firstOrNull()?.id else cache.activeId
            writeUnlocked(DeviceStore(devices = remaining, activeId = nextActive))
            return wasActive
        }
    }

    /** Renames a device (blank keeps the old name); true when the device existed. */
    fun rename(id: String, newName: String): Boolean {
        lock.withLock {
            val index = cache.devices.indexOfFirst { it.id == id }
            if (index < 0) return false
            val trimmed = newName.trim()
            if (trimmed.isNotEmpty() && trimmed != cache.devices[index].name) {
                val updated = cache.devices[index].copy(name = trimmed)
                writeUnlocked(
                    DeviceStore(
                        devices = cache.devices.toMutableList().also { it[index] = updated },
                        activeId = cache.activeId,
                    ),
                )
            }
            return true
        }
    }

    fun clearAll() {
        lock.withLock { writeUnlocked(DeviceStore()) }
    }

    private fun readUnlocked(): DeviceStore {
        if (!file.exists()) return DeviceStore()
        return try {
            val decoded = Base64.decode(file.readText(), Base64.NO_WRAP)
            val (iv, cipherBytes) = SecurePayloadCodec.unpack(decoded, IV_SIZE) ?: return DeviceStore()
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
            SecurePayloadCodec.decodeStore(String(cipher.doFinal(cipherBytes), Charsets.UTF_8))
        } catch (t: Throwable) {
            AppLog.e(TAG, "failed to read secure payload", t)
            DeviceStore()
        }
    }

    private fun writeUnlocked(store: DeviceStore) {
        try {
            val json = SecurePayloadCodec.encodeStore(store)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
            val encrypted = cipher.doFinal(json.toByteArray(Charsets.UTF_8))
            val packed = SecurePayloadCodec.pack(cipher.iv, encrypted)
            file.writeText(Base64.encodeToString(packed, Base64.NO_WRAP))
        } catch (t: Throwable) {
            AppLog.e(TAG, "failed to write secure payload", t)
        }
        cache = store
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        private const val TAG = "SecureStorage"
        private const val FILE_NAME = "zcode_secure.enc"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val ALIAS = "zcode_mobile_aes"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_SIZE = 12
        private const val GCM_TAG_BITS = 128

        private fun newId(): String = java.util.UUID.randomUUID().toString()
    }
}
