package de.benibela.videlibri.jni

fun BookListDisplayOptions.isGrouped() = groupingKey != ""

fun OptionsAndroidOnly.save(){
    Bridge.VLSetOptionsAndroidOnly(this)
}

lateinit var globalOptionsAndroid: OptionsAndroidOnly
lateinit var globalOptionsShared: OptionsShared


fun decodeIdEscapes(s: String): String =
    if (!s.contains("+")) s
    else s.replace("+ue", "ü")
        .replace("+oe", "ö")
        .replace("+ae", "ä")
        .replace("+sz", "ß")
        .replace("++", " ")

val LibraryDetails.searchMightWork
    get() = testingSearch <= 1
val LibraryDetails.accountMightWork
    get() = testingAccount <= 1

