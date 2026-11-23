package app.anchorkeep.anchorkeep

import android.os.Bundle
import android.os.Build
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.content.Intent
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var nfcChannel: MethodChannel? = null
    private var adapter: NfcAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Запрещает скриншоты и запись экрана и скрывает содержимое в Recent Apps.
        // Ставим до super.onCreate, чтобы защищена была и заставка.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
        adapter = NfcAdapter.getDefaultAdapter(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfcChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anchorkeep/nearby_nfc")
        nfcChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(mapOf(
                    "supported" to (adapter != null),
                    "enabled" to (adapter?.isEnabled == true),
                    "hce" to packageManager.hasSystemFeature("android.hardware.nfc.hce"),
                ))
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                "openNfcSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("SETTINGS_UNAVAILABLE", "Cannot open NFC settings", null)
                    }
                }
                "setToken" -> {
                    NearbyHceService.token = call.argument<String>("token")
                    result.success(null)
                }
                "startReader" -> {
                    val nfc = adapter
                    if (nfc == null || !nfc.isEnabled) {
                        result.error("NFC_UNAVAILABLE", "NFC is disabled or unavailable", null)
                    } else {
                        nfc.enableReaderMode(this, { tag -> readToken(tag) },
                            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK, null)
                        result.success(null)
                    }
                }
                "stopReader" -> {
                    adapter?.disableReaderMode(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readToken(tag: Tag) {
        val iso = IsoDep.get(tag) ?: return
        try {
            iso.connect()
            iso.timeout = 3000
            val aid = NearbyHceService.aid
            val command = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00, aid.size.toByte()) + aid + byteArrayOf(0x00)
            val response = iso.transceive(command)
            if (response.size < 3 || response[response.size - 2] != 0x90.toByte() || response.last() != 0x00.toByte()) return
            val token = String(response.copyOfRange(0, response.size - 2), Charsets.US_ASCII)
            if (token.length == 16 && token.all { it in '0'..'9' || it in 'a'..'f' }) {
                runOnUiThread { nfcChannel?.invokeMethod("tokenRead", token) }
            }
        } catch (_: Exception) {
            // Следующее касание может повторить чтение.
        } finally {
            try { iso.close() } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        adapter?.disableReaderMode(this)
        NearbyHceService.token = null
        nfcChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
