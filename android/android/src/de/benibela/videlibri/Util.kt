package de.benibela.videlibri
import android.app.Activity
import android.content.Context
import android.content.DialogInterface
import android.os.Bundle
import android.support.annotation.StringRes
import android.view.Menu
import android.view.MenuItem
import android.widget.ArrayAdapter
import android.widget.Spinner
import android.widget.Toast
import de.benibela.videlibri.Util.tr
import java.io.InputStream

inline fun <reified T> currentActivity(): T? = (VideLibriApp.currentActivity as? T)
inline fun <reified T: Activity> withActivity(f: T.() -> Unit) = currentActivity<T>()?.run(f)

fun showToast(message: CharSequence) =
        Toast.makeText(VideLibriApp.currentContext(), message, Toast.LENGTH_SHORT).show()
fun showToast(@StringRes message: Int) =
        Toast.makeText(VideLibriApp.currentContext(), message, Toast.LENGTH_SHORT).show()

fun getString(@StringRes message: Int): String? = Util.tr(message)

internal typealias DialogEvent = (DialogInstance.(Util.DialogFragmentUtil) -> Unit)
internal typealias DialogInitEvent = (DialogInstance.() -> Unit)
internal typealias InputDialogEvent = (DialogInstance.(text: String) -> Unit)

//default dialogs, no customization, optional lambda argument is called after dialog completion (thus it MUST NOT LEAK)

fun showMessage(
        message: String? = null,
        title: String? = null
) = showDialog(message, title)
fun showMessage(
        @StringRes message: Int
) = showDialog(getString(message))

fun showMessageYesNo(
        message: String? = null,
        title: String? = null,
        onYes: DialogEvent
) = showDialog(message, title) {
    noButton()
    yesButton(onYes)
}
fun showMessageYesNo(
        @StringRes message: Int,
        onYes: DialogEvent
) = showMessageYesNo(getString(message), null, onYes)

fun showInputDialog(
        message: String? = null,
        title: String? = null,
        default: String? = null,
        onResult: InputDialogEvent? = null
) = showDialog(message, title) {
    args.putString("editTextDefault", default)
    args.putInt("special", DialogId.SPECIAL_INPUT_DIALOG)
    okButton { fragment ->
        onResult?.invoke(this, fragment.edit?.text?.toString() ?: "")
    }
}
fun showInputDialog(
        @StringRes message: Int,
        title: String? = null,
        default: String? = null,
        onResult: InputDialogEvent? = null
) = showInputDialog(getString(message), title, default, onResult)


//Customizable dialog, lambda runs before dialog creation

fun showDialog(
        message: String? = null,
        title: String? = null,
        dialogId: Int = 0,
        negative: String? = null,
        neutral: String? = null,
        positive: String? = null,
        more: Bundle? = null,
        init: DialogInitEvent? = null
) {
    val args = android.os.Bundle()
    args.putInt("id", dialogId)
    val instanceId = ++totalDialogInstances
    args.putInt("instanceId", instanceId)
    args.putString("message", message)
    args.putString("title", title)
    args.putString("negativeButton", negative)
    args.putString("neutralButton", neutral)
    args.putString("positiveButton", positive)
    if (more != null)
        args.putBundle("more", more)

    val instance = DialogInstance(args)
    dialogInstances.put(instanceId, instance)
    init?.invoke(instance)
    if ((args.getString("negativeButton") ?: args.getString("neutralButton") ?: args.getString("positiveButton")) == null)
        args.putString("neutralButton", Util.tr(R.string.ok))
    Util.showPreparedDialog(args)
}

private var totalDialogInstances = 0
private val dialogInstances = mutableMapOf<Int, DialogInstance>()

@Suppress("unused")
data class DialogInstance (
        val args: Bundle
) {
    var onNegativeButton: DialogEvent? = null
    var onNeutralButton: DialogEvent? = null
    var onPositiveButton: DialogEvent? = null
    var onDismiss: DialogEvent? = null

    fun message(caption: String) = args.putString("message", caption)
    fun message(@StringRes caption: Int,  vararg a: Any?) = message(tr(caption, *a))


    fun negativeButton(caption: String, onClicked: DialogEvent? = null){
        args.putString("negativeButton", caption)
        onNegativeButton = onClicked
    }
    fun negativeButton(@StringRes caption: Int, onClicked: DialogEvent? = null) =
        negativeButton(tr(caption), onClicked)


    fun neutralButton(caption: String, onClicked: DialogEvent? = null){
        args.putString("neutralButton", caption)
        onNeutralButton = onClicked
    }
    fun neutralButton(@StringRes caption: Int, onClicked: DialogEvent? = null) =
        neutralButton(tr(caption), onClicked)


    fun positiveButton(caption: String, onClicked: DialogEvent? = null){
        args.putString("positiveButton", caption)
        onPositiveButton = onClicked
    }
    fun positiveButton(@StringRes caption: Int, onClicked: DialogEvent? = null) =
        positiveButton(tr(caption), onClicked)


    fun noButton(onClicked: DialogEvent? = null) = negativeButton(R.string.no, onClicked)
    fun yesButton(onClicked: DialogEvent? = null) = positiveButton(R.string.yes, onClicked)
    fun okButton(onClicked: DialogEvent? = null) = neutralButton(R.string.ok, onClicked)

    companion object {
        @JvmStatic fun onFinished(dialogFragment: Util.DialogFragmentUtil, button: Int){
            val instanceId = dialogFragment.arguments?.getInt("instanceId", -1) ?: -1
            if (instanceId < 0) return
            dialogInstances.get(instanceId)?.apply {
                when (button) {
                    DialogInterface.BUTTON_NEGATIVE -> onNegativeButton?.invoke(this, dialogFragment)
                    DialogInterface.BUTTON_NEUTRAL -> onNeutralButton?.invoke(this, dialogFragment)
                    DialogInterface.BUTTON_POSITIVE -> onPositiveButton?.invoke(this, dialogFragment)
                }
                onDismiss?.invoke(this, dialogFragment)
                dialogInstances.remove(instanceId)
            }
        }
    }
}

fun Spinner.setItems(items: Array<String>) {
    val adapter = ArrayAdapter(this.context, android.R.layout.simple_spinner_item, items)
    adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    this.adapter = adapter
}

fun<T> Spinner.setSelection(item: T?, items: Array<T>) {
    val i = items.indexOf(item)
    if (i > 0) this.setSelection(i)
}

inline fun Menu.forItems(f: (MenuItem) -> Unit){
    for (i in 0 until size())
        f(getItem(i))
}


fun streamToString(stream: InputStream): String = stream.bufferedReader().use { it.readText() }

