package com.pakelcomedy.qleon.ui.newchat

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel

class NewChatViewModel : ViewModel() {

    // LiveData for username input, initializing with an empty string
    private val _username = MutableLiveData<String>().apply { value = "" }
    val username: LiveData<String> get() = _username

    // LiveData to display messages, initializing with an empty string
    private val _message = MutableLiveData<String>().apply { value = "" }
    val message: LiveData<String> get() = _message

    // Function to update the username
    fun updateUsername(newUsername: String) {
        _username.value = newUsername
    }

    // Function for the connection logic
    fun connectToUser() {
        if (_username.value.isNullOrEmpty()) {
            _message.value = "Please enter a username"
        } else {
            _message.value = "Connecting to ${_username.value}..."
        }
    }
}
