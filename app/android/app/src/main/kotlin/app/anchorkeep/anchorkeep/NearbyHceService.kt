package app.anchorkeep.anchorkeep

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/** NFC отдаёт только одноразовый идентификатор Nearby, никогда текст заметки. */
class NearbyHceService : HostApduService() {
    companion object {
        // Proprietary AID для Anchorkeep nearby handshake.
        val aid = byteArrayOf(0xF0.toByte(), 0x43, 0x56, 0x54, 0x4E, 0x46, 0x43, 0x01)
        @Volatile var token: String? = null
    }

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        val expected = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00, aid.size.toByte()) + aid
        if (commandApdu.size < expected.size || !commandApdu.copyOfRange(0, expected.size).contentEquals(expected)) {
            return byteArrayOf(0x6A, 0x82.toByte())
        }
        val current = token ?: return byteArrayOf(0x6A, 0x82.toByte())
        return current.toByteArray(Charsets.US_ASCII) + byteArrayOf(0x90.toByte(), 0x00)
    }

    override fun onDeactivated(reason: Int) = Unit
}
