package com.pakelcomedy.qleon.ui.chat

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.pakelcomedy.qleon.model.ChatMessage

class ChatViewModel : ViewModel() {

    // LiveData to observe messages
    private val _messages = MutableLiveData<List<ChatMessage>>(emptyList())
    val messages: LiveData<List<ChatMessage>> get() = _messages

    // Function to send a message
    fun sendMessage(content: String) {
        val newMessage = ChatMessage(
            sender = "User", // replace with actual sender, maybe from logged-in user
            content = content,
            isSent = true // Mark as sent message
        )
        val updatedMessages = _messages.value.orEmpty() + newMessage
        _messages.value = updatedMessages
    }

    // Function to simulate receiving a message
    fun receiveMessage(content: String) {
        val receivedMessage = ChatMessage(
            sender = "OtherUser", // replace with actual sender
            content = content,
            isSent = false // Mark as received message
        )
        val updatedMessages = _messages.value.orEmpty() + receivedMessage
        _messages.value = updatedMessages
    }
}
