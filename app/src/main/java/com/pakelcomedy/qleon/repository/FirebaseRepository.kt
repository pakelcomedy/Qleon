package com.pakelcomedy.qleon.repository

import com.pakelcomedy.qleon.model.Chat

class FirebaseRepository {

    fun getChats(onSuccess: (List<Chat>) -> Unit, onFailure: (String) -> Unit) {
        // Simulate Firebase query or API call
        try {
            // Assume fetching chats from Firebase (this is just a mock)
            val chatsList = listOf(
                Chat("Chat 1", "This is a message", "User1"),
                Chat("Chat 2", "Another message", "User2")
            )
            onSuccess(chatsList)
        } catch (exception: Exception) {
            onFailure("Failed to fetch chats: ${exception.message}")
        }
    }
}
