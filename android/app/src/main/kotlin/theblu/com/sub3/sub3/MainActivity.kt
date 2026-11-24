package theblu.com.sub3.sub3

import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ichi2.anki.api.AddContentApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingAnkiResult: MethodChannel.Result? = null
    private var pendingAnkiArgs: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "addNote") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val args = call.arguments as? Map<*, *>
            if (args == null) {
                result.error("ARGS", "Argumentos inválidos.", null)
                return@setMethodCallHandler
            }
            if (AddContentApi.getAnkiDroidPackageName(this) == null) {
                result.error("NO_ANKI", "Instale o AnkiDroid para enviar cartões.", null)
                return@setMethodCallHandler
            }
            if (ContextCompat.checkSelfPermission(this, AddContentApi.READ_WRITE_PERMISSION) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                if (pendingAnkiResult != null) {
                    result.error("BUSY", "Aguardando permissão do AnkiDroid.", null)
                    return@setMethodCallHandler
                }
                pendingAnkiResult = result
                pendingAnkiArgs = args
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(AddContentApi.READ_WRITE_PERMISSION),
                    PERMISSION_REQUEST,
                )
                return@setMethodCallHandler
            }
            addNote(args, result)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        val result = pendingAnkiResult
        val args = pendingAnkiArgs
        pendingAnkiResult = null
        pendingAnkiArgs = null
        if (result == null) return
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED && args != null) {
            addNote(args, result)
        } else {
            result.error("PERM", "Permissão do AnkiDroid recusada.", null)
        }
    }

    private fun addNote(
        args: Map<*, *>,
        result: MethodChannel.Result,
    ) {
        try {
            AnkiDroidHelper(this).addNote(
                sentence = args["sentence"] as? String ?: "",
                translation = args["translation"] as? String ?: "",
                audioPath = args["audioPath"] as? String,
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("ANKI", e.message ?: "Falha ao enviar para o AnkiDroid.", null)
        }
    }

    companion object {
        private const val CHANNEL = "sub3/anki"
        private const val PERMISSION_REQUEST = 4401
    }
}
