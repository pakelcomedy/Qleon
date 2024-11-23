package com.pakelcomedy.qleon.ui.homechat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.liveData
import com.pakelcomedy.qleon.model.Contact
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

class HomeChatViewModel : ViewModel() {

    private val _recentContacts = liveData {
        // Fetch the recent contacts from repository or database
        emit(listOf<Contact>()) // For now, an empty list
    }

    val recentContacts = _recentContacts

    // SharedFlow to handle navigation events
    private val _navigationEvent = MutableSharedFlow<String>()
    val navigationEvent = _navigationEvent.asSharedFlow()

    fun onContactSelected(contact: Contact) {
        // Emit the contact name to trigger navigation
        _navigationEvent.tryEmit(contact.name)
    }
}