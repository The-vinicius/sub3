package theblu.com.sub3.sub3

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import com.ichi2.anki.api.AddContentApi
import java.io.File

class AnkiDroidHelper(private val context: Context) {
    fun addNote(
        sentence: String,
        translation: String,
        audioPath: String?,
    ) {
        if (AddContentApi.getAnkiDroidPackageName(context) == null) {
            throw IllegalStateException("Instale o AnkiDroid para enviar cartões.")
        }

        val api = AddContentApi(context)
        val deckId =
            findIdByName(api.deckList, DECK_NAME)
                ?: api.addNewDeck(DECK_NAME)
                ?: throw IllegalStateException("Não foi possível criar o baralho $DECK_NAME.")
        val modelId =
            findIdByName(api.modelList, MODEL_NAME)
                ?: api.addNewCustomModel(
                    MODEL_NAME,
                    arrayOf("Sentence", "Audio", "Translation"),
                    arrayOf("Card 1"),
                    arrayOf("{{Audio}}<br>{{Sentence}}"),
                    arrayOf("{{FrontSide}}<hr id=answer>{{Translation}}"),
                    CSS,
                    deckId,
                    0,
                )
                ?: throw IllegalStateException("Não foi possível criar o modelo $MODEL_NAME.")

        val audioField = addAudio(api, audioPath).orEmpty()
        val noteId =
            api.addNote(
                modelId,
                deckId,
                arrayOf(sentence, audioField, translation),
                setOf("sub3"),
            )
        if (noteId == null) {
            throw IllegalStateException("O AnkiDroid recusou o cartão.")
        }
    }

    private fun addAudio(
        api: AddContentApi,
        audioPath: String?,
    ): String? {
        if (audioPath.isNullOrBlank()) return null
        val file = File(audioPath)
        if (!file.exists()) return null

        val uri: Uri =
            FileProvider.getUriForFile(
                context,
                "${context.packageName}.anki.fileprovider",
                file,
            )
        val ankiPackage = AddContentApi.getAnkiDroidPackageName(context) ?: return null
        context.grantUriPermission(
            ankiPackage,
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )
        return try {
            api.addMediaFromUri(uri, file.nameWithoutExtension, "audio")
        } finally {
            context.revokeUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    private fun findIdByName(
        items: Map<Long, String>?,
        name: String,
    ): Long? {
        if (items == null) return null
        for ((id, itemName) in items) {
            if (itemName == name) return id
        }
        return null
    }

    companion object {
        const val DECK_NAME = "sub3"
        const val MODEL_NAME = "sub3"
        const val CSS =
            ".card { font-family: arial; font-size: 22px; text-align: center; " +
                "color: black; background-color: white; }"
    }
}
