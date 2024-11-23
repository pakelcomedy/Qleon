package com.pakelcomedy.qleon.ui.newchat

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel

class NewChatViewModel : ViewModel() {

    // LiveData untuk username input
    private val _username = MutableLiveData<String>()
    val username: LiveData<String> get() = _username

    // LiveData untuk menampilkan pesan
    private val _message = MutableLiveData<String>()
    val message: LiveData<String> get() = _message

    // Fungsi untuk mengupdate username
    fun updateUsername(newUsername: String) {
        _username.value = newUsername
    }

    // Fungsi untuk logika koneksi
    fun connectToUser() {
        if (_username.value.isNullOrEmpty()) {
            _message.value = "Please enter a username"
        } else {
            _message.value = "Connecting to ${_username.value}..."
        }
    }
}
