package com.pakelcomedy.qleon.model

data class ChatMessage(
    val sender: String,
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isSent: Boolean // true if the message is sent by the user, false if received
)
