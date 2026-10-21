package app.anchorkeep.anchorkeep

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Запрещает скриншоты и запись экрана и скрывает содержимое в Recent Apps.
        // Ставим до super.onCreate, чтобы защищена была и заставка.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }
}
