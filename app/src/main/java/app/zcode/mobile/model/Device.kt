package app.zcode.mobile.model

data class Device(
    /** Stable identity across link regenerations; assigned when the device is first saved. */
    val id: String,
    val name: String = "ZCode Desktop",
    val remoteUrl: String,
    val connected: Boolean = false,
)
